/**
 * @brief Red Pitaya PWM module
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */

module red_pitaya_pdm #(
  int unsigned DWC = 8,  // counter width (resolution)
  int unsigned CHN = 4   // output  width
)(
  // system signals
  input  logic                      clk ,  // clock
  input  logic                      rstn,  // reset
  // configuration
  input  logic [CHN-1:0] [DWC-1:0]  cfg ,  // 
  input  logic                      ena ,
  input  logic           [DWC-1:0]  rng ,
  // PWM outputs
  output logic [CHN-1:0]            pdm    // PWM output - driving RC
);
generate
for (genvar i=0; i<CHN; i++) begin: for_chn

logic [DWC-1:0] dat;
`ifdef Z20_LL
logic [DWC-1:0] dat_q;
logic [DWC  :0] dat_minus_rng;
logic             pdm_d;
`endif

// input data copy
always_ff @(posedge clk)
if (~rstn)            dat <= '0;
else begin
  if (ena)  dat <= cfg[i];
end

logic [DWC-1:0] acu;  // accumulator
logic [DWC  :0] sum;  // summation
logic [DWC  :0] sub;  // subtraction

`ifdef Z20_LL
// Pipeline the configured value and pre-compute dat-rng.  The accumulator can
// then choose between two parallel carry chains instead of traversing
// acu+dat-rng serially in one cycle.
always_ff @(posedge clk)
if (~rstn) begin
  dat_q         <= '0;
  dat_minus_rng <= '0;
end else begin
  dat_q         <= dat;
  dat_minus_rng <= {1'b0, dat} - {1'b0, rng};
end
`endif

// accumulator
always_ff @(posedge clk)
if (~rstn)  acu <= '0;
else begin
  if (ena)  acu <= ~sub[DWC] ? sub[DWC-1:0] : sum[DWC-1:0];
  else      acu <= '0;
end

// summation
`ifdef Z20_LL
assign sum = {1'b0, acu} + {1'b0, dat_q};
`else
assign sum = acu + dat;
`endif

// subtraction
`ifdef Z20_LL
assign sub = {1'b0, acu} + dat_minus_rng;
`else
assign sub = sum - rng;
`endif

// PDM output
`ifdef Z20_LL
always_ff @(posedge clk)
if (~rstn)  pdm_d <= 1'b0;
else        pdm_d <= ena & (~sub[DWC] | ~|sub[DWC-1:0]);

always_ff @(posedge clk)
if (~rstn)  pdm[i] <= 1'b0;
else        pdm[i] <= pdm_d;
`else
always_ff @(posedge clk)
if (~rstn)  pdm[i] <= 1'b0;
else        pdm[i] <= ena & (~sub[DWC] | ~|sub[DWC-1:0]);
`endif

end: for_chn
endgenerate
endmodule: red_pitaya_pdm
