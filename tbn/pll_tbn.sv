
////////////////////////////////////////////////////////////////////////////////
// Module: Red Pitaya top FPGA module
// Author: Iztok Jeras
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module top_tb_pll #(
  // time period
  realtime  TP = 8.0ns,  // 250MHz
  realtime  SP = 100.0ns,  // ~10MHz
  realtime  RP = 99.99ns  // ~10MHz
);

////////////////////////////////////////////////////////////////////////////////
// IO port signals
////////////////////////////////////////////////////////////////////////////////

logic                  pll_sys;

logic                  pll_lo;
logic                  pll_hi;
logic                  pll_ref;

logic               clk ;

logic               rstn;

////////////////////////////////////////////////////////////////////////////////
// Clock and reset generation
////////////////////////////////////////////////////////////////////////////////

// default clocking 

default clocking cb @ (posedge clk);
  input  rstn;
endclocking: cb

initial        clk = 1'b0;
always #(TP/2) clk = ~clk;

initial        pll_sys = 1'b0;
always #(SP/2) pll_sys = ~pll_sys;

initial  begin      
    pll_ref = 1'b0;
    ##10; pll_ref = 1'b0;
end
always #(RP/2) pll_ref = ~pll_ref;

// reset
initial begin
        rstn = 1'b0;
  ##4;  rstn = 1'b1;
end


// clock cycle counter
int unsigned cyc=0;
always_ff @ (posedge clk)
cyc <= cyc+1;





//---------------------------------------------------------------------------------
//
//  Simple FF PLL 

// detect RF clock
reg  [16-1:0] pll_ref_cnt = 16'h0;
reg  [ 3-1:0] pll_sys_syc  ;
reg  [21-1:0] pll_sys_cnt  ;
reg           pll_sys_val  ;
reg           pll_cfg_en   ;
wire [32-1:0] pll_cfg_rd   ;

always @(posedge clk) begin
if (rstn == 1'b0)
  pll_cfg_en   <= 1'b1 ;
end

always @(posedge pll_ref) begin
  pll_ref_cnt <= pll_ref_cnt + 16'h1;
end

always @(posedge clk) 
if (rstn == 1'b0) begin
  pll_sys_syc <=  3'h0 ;
  pll_sys_cnt <= 21'h100000;
  pll_sys_val <=  1'b0 ;
end else begin
  pll_sys_syc <= {pll_sys_syc[3-2:0], pll_ref_cnt[14-1]} ;

  if (pll_sys_syc[3-1] ^ pll_sys_syc[3-2])
    pll_sys_cnt <= 21'h1;
  else if (!pll_sys_cnt[21-1])
    pll_sys_cnt <= pll_sys_cnt + 21'h1;

  // pll_sys_clk must be around 102400 (125000000/(10000000/2^13))
  if (pll_sys_syc[3-1] ^ pll_sys_syc[3-2])
    pll_sys_val <= (pll_sys_cnt > 102385) && (pll_sys_cnt < 102415) ;
  else if (pll_sys_cnt[21-1])
    pll_sys_val <= 1'b0 ;
end


reg  pll_ff_sys ;
reg  pll_ff_ref ;
wire pll_ff_rst ;
wire pll_ff_lck ;

// FF PLL functionality
always @(posedge pll_sys or negedge pll_ff_rst) begin
  if (!pll_ff_rst)  pll_ff_sys <= 1'b0 ;
  else              pll_ff_sys <= 1'b1 ;
end
always @(posedge pll_ref or negedge pll_ff_rst) begin
  if (!pll_ff_rst)  pll_ff_ref <= 1'b0 ;
  else              pll_ff_ref <= 1'b1 ;
end
assign pll_ff_rst = !(pll_ff_sys && pll_ff_ref) ;
assign pll_ff_lck = (!pll_ff_sys && !pll_ff_ref);

assign pll_lo = !pll_ff_sys && ( pll_sys_val &&  pll_cfg_en);
assign pll_hi =  pll_ff_ref || (!pll_sys_val || !pll_cfg_en);


// filter out PLL lock status
reg  [21-1:0] pll_lck_lcnt  ;
reg  [21-1:0] pll_lck_hcnt  ;
reg  [ 4-1:0] pll_lck_sts  ;

always @(posedge clk) 
if (rstn == 1'b0) begin
  pll_lck_lcnt <= 21'h0 ;
  pll_lck_hcnt <= 21'h0 ;
  pll_lck_sts <=   2'b0 ;
end else begin

  if (pll_sys_syc[3-1] ^ pll_sys_syc[3-2])
    pll_lck_lcnt <= 21'h1;
  else if (pll_lo)
    pll_lck_lcnt <= pll_lck_lcnt + 21'h1;

  if (pll_sys_syc[3-1] ^ pll_sys_syc[3-2])
    pll_lck_hcnt <= 21'h1;
  else if (!pll_hi)
    pll_lck_hcnt <= pll_lck_hcnt + 21'h1;


  // pll_lck_cnt threshold 70% of whole period
  if (pll_sys_syc[3-1] ^ pll_sys_syc[3-2])
    pll_lck_sts[0] <= (pll_lck_lcnt > 21'd80000) && (pll_lck_hcnt > 21'd80000);

  pll_lck_sts[1] <= pll_lck_sts[0] && pll_sys_val;

  if (pll_sys_syc[3-1] ^ pll_sys_syc[3-2])
    pll_lck_sts[3:2] <= {(pll_lck_lcnt > 21'd80000), (pll_lck_hcnt > 21'd80000)};
end

assign pll_cfg_rd = {{32-14{1'h0}}, pll_lck_sts[3:2], 3'h0,pll_lck_sts[1], 3'h0,pll_sys_val, 3'h0,pll_cfg_en};

endmodule: top_tb_pll
