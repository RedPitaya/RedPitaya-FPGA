////////////////////////////////////////////////////////////////////////////////
// Module: PDM (pulse density modulation)
// Author: Iztok Jeras <iztok.jeras@redpitaya.com>
// (c) Red Pitaya  (redpitaya.com)
//
// The datapath is pipelined to close timing; the output is delayed by 2 clock
// cycles, the pulse pattern is bit identical.
////////////////////////////////////////////////////////////////////////////////

module pdm #(
  int unsigned DWC = 8,  // counter width (resolution)
  int unsigned CHN = 1   // output  width
)(
  // system signals
  input  logic                    clk ,  // clock
  input  logic                    rstn,  // reset (active low)
  input  logic                    cke ,  // clock enable (synchronous)
  // configuration
  input  logic                    ena,   // enable
  input  logic          [DWC-1:0] rng,   // range
  // stream input
  input  logic [CHN-1:0][DWC-1:0] str_dat,  // data
  input  logic                    str_vld,  // valid (it is ignored for now
  output logic                    str_rdy,  // ready
  // PDM output
  output logic [CHN-1:0]          pdm
);

// local signals
logic [DWC-1:0] cnt;  // counter current value
logic [DWC-1:0] nxt;  // counter next value

// counter current value
always_ff @(posedge clk)
if (~rstn)  cnt <= '0;
else begin
  if (ena)  cnt <= str_rdy ? '0 : nxt;
  else      cnt <= '0;
end

// counter next value
assign nxt = cnt + cke;

// counter cycle end
assign str_rdy = nxt == rng;

generate
for (genvar i=0; i<CHN; i++) begin: for_chn

logic [DWC-1:0] dat;      // stream input data copy
logic [DWC-1:0] dat_nxt;  // stream input data copy (next value)
logic [DWC-1:0] dat_q;    // stream input data copy (pipelined)
logic [DWC  :0] dsr;      // pre-computed (dat_q - rng), modulo 2**(DWC+1)

logic [DWC-1:0] acu;  // accumulator
// `keep` is required to hold the two carry chains below in parallel
(* keep = "true" *) logic [DWC  :0] sum;  // summation      (acu + dat_q)
(* keep = "true" *) logic [DWC  :0] sub;  // subtraction    (acu + dat_q - rng)

logic           pdm_d;  // PDM output (pipelined)

// stream input data copy
assign dat_nxt = ~rstn ? '0 : ((ena & str_rdy) ? str_dat[i] : dat);

// The accumulator loop needs both (acu+dat) and (acu+dat-rng). Chaining the two
// adders puts two carry chains in series in the feedback loop, which does not
// close timing; pre-computing (dat-rng) makes them parallel instead (carry
// select modulo accumulator). Modulo 2**(DWC+1) arithmetic keeps this bit
// exact, sub[DWC] included. `rng` takes effect one cycle later than before.
always_ff @(posedge clk)
if (~rstn) begin
  dat_q <= '0;
  dsr   <= '0;
end else begin
  dat_q <= dat;
  dsr   <= {1'b0, dat} - {1'b0, rng};
end

always_ff @(posedge clk)
  dat <= dat_nxt;

// summation
assign sum = {1'b0, acu} + {1'b0, dat_q};

// subtraction
assign sub = {1'b0, acu} + dsr;

// accumulator
always_ff @(posedge clk)
if (~rstn)  acu <= '0;
else begin
  if (ena)  acu <= ~sub[DWC] ? sub[DWC-1:0] : sum[DWC-1:0];
  else      acu <= '0;
end

// PDM output
// The output register sits in the IO block, far from the accumulator logic, so
// this extra stage splits that path into a logic part and a route only part.
always_ff @(posedge clk)
if (~rstn)  pdm_d <= 1'b0;
else        pdm_d <= ena & (~sub[DWC] | ~|sub[DWC-1:0]);

always_ff @(posedge clk)
if (~rstn)  pdm[i] <= 1'b0;
else        pdm[i] <= pdm_d;

end: for_chn
endgenerate

endmodule: pdm
