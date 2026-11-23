////////////////////////////////////////////////////////////////////////////////
// Module: PDM (pulse density modulation)
// Author: Iztok Jeras <iztok.jeras@redpitaya.com>
// (c) Red Pitaya  (redpitaya.com)
//
// The datapath is pipelined to close timing; the output is delayed by 3 clock
// cycles. In steady state the pulse pattern is bit identical, except for one
// spurious output cycle on reset release, when the pre-computed dsr is still 0.
//
// The module runs at 250 MHz (4 ns), where a long route is already a violation,
// and it sits in designs that fill the 7z010 (the logic project: every slice).
// The changes against the first pipelined version keep the paths short and add
// no control set (a reset or enable of its own), which a full device cannot pack:
//  - the output register has no reset: it sits in the IO block, far from the
//    rest, and the reset of the top reached it over a route of 3 ns. Its input
//    is reset, so the output is 0 one cycle later;
//  - the load of the data copy is a registered strobe (ld), not the counter
//    compare straight into the clock enables. A new str_dat is taken one clock
//    later than the cycle end, only seen in the first cycle of a period after
//    the value changed;
//  - the output decision is taken one clock after the subtraction (sub_q): the
//    carry chain and the zero detect in one clock were five logic levels.
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

// load strobe of the data copy (the counter reached its end), registered
logic ld;
always_ff @(posedge clk)
  ld <= ena & str_rdy;

// counter cycle end
assign str_rdy = nxt == rng;

generate
for (genvar i=0; i<CHN; i++) begin: for_chn

logic [DWC-1:0] dat;      // stream input data copy
logic [DWC-1:0] dat_q;    // stream input data copy (pipelined)
logic [DWC  :0] dsr;      // pre-computed (dat_q - rng), modulo 2**(DWC+1)

logic [DWC-1:0] acu;  // accumulator
// `keep` is required to hold the two carry chains below in parallel
(* keep = "true" *) logic [DWC  :0] sum;  // summation      (acu + dat_q)
(* keep = "true" *) logic [DWC  :0] sub;  // subtraction    (acu + dat_q - rng)

logic [DWC  :0] sub_q;  // sub, registered for the output decision
logic           ena_q;  // ena, registered with it
logic           pdm_d;  // PDM output (pipelined)

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

// stream input data copy
always_ff @(posedge clk)
if (~rstn)    dat <= '0;
else if (ld)  dat <= str_dat[i];

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
if (~rstn) begin
  sub_q <= '0;
  ena_q <= 1'b0;
end else begin
  sub_q <= sub;
  ena_q <= ena;
end

always_ff @(posedge clk)
if (~rstn)  pdm_d <= 1'b0;
else        pdm_d <= ena_q & (~sub_q[DWC] | ~|sub_q[DWC-1:0]);

// no reset: pdm_d is reset, the output follows it one cycle later
always_ff @(posedge clk)
  pdm[i] <= pdm_d;

end: for_chn
endgenerate

endmodule: pdm
