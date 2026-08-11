////////////////////////////////////////////////////////////////////////////////
// Module: PDM (pulse density modulation)
// Author: Iztok Jeras <iztok.jeras@redpitaya.com>
// (c) Red Pitaya  (redpitaya.com)
//
// Timing note: the datapath is pipelined (see the comments inside the channel
// loop). The output is delayed by 2 clock cycles with respect to the original
// non pipelined description; the generated pulse pattern (and therefore the
// average pulse density for a given input code) is otherwise bit identical.
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
logic [DWC  :0] sum;  // summation      (acu + dat_q)
logic [DWC  :0] sub;  // subtraction    (acu + dat_q - rng)

logic           pdm_d;  // PDM output (pipelined)

// stream input data copy
assign dat_nxt = ~rstn ? '0 : ((ena & str_rdy) ? str_dat[i] : dat);

// The accumulator loop below needs both (acu+dat) and (acu+dat-rng). Computing
// them as two chained adders (the straightforward description) puts two ripple
// carry chains between the accumulator register and itself, which does not
// close timing at 250MHz on a -1 speed grade part. Since `dat` is a register
// and `rng` is a (quasi) static configuration value, (dat-rng) is pre-computed
// here, so that both sums become a single carry chain fanning out from `acu`
// in parallel (carry-select style modulo accumulator).
//
// Modulo 2**(DWC+1) arithmetic makes this bit exact: acu + ((dat-rng) mod
// 2**(DWC+1)) == (acu + dat - rng) mod 2**(DWC+1), so `sub` (including its
// sign/borrow bit sub[DWC]) is identical to the chained form.
//
// The only behavioural difference: a change of `rng` takes effect one clock
// cycle later than before (`dsr` is registered). `rng` is a configuration
// input, constant in all instantiations in this repository, so the average
// output pulse density for a given input code is unchanged.
//
// `dsr` is computed from the already registered `dat` (not from its
// combinational next value), so that the pre-computation is a plain
// register-to-register subtraction. `dat_q` carries `dat` along the same extra
// pipeline stage, keeping `dat_q` and `dsr` bit exactly aligned.
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
// The output register is placed inside the IO block, which is far away from
// the accumulator logic. The extra pipeline stage splits the (logic + long
// route) path into a logic path and a route only path.
always_ff @(posedge clk)
if (~rstn)  pdm_d <= 1'b0;
else        pdm_d <= ena & (~sub[DWC] | ~|sub[DWC-1:0]);

always_ff @(posedge clk)
if (~rstn)  pdm[i] <= 1'b0;
else        pdm[i] <= pdm_d;

end: for_chn
endgenerate

endmodule: pdm
