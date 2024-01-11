/*
* Copyright (c) 2016 Instrumentation Technologies, d.d.
* All Rights Reserved.
*
* $Id: $
*/

// synopsys translate_off
`timescale 1ps/1ps
// synopsys translate_on

module clk_gen
#(
  parameter   CLKA_PERIOD   = 9156   ,
  parameter   CLKA_JIT      = 10     ,
  parameter   CLKB_PERIOD   = 8000   ,
  parameter   CLKB_JIT      = 10     ,
  parameter   CLKC_PERIOD   = 100000 ,
  parameter   CLKC_JIT      = 10     ,
  parameter   CLKD_PERIOD   = 100000 ,
  parameter   CLKD_JIT      = 10     ,
  parameter   DEL           = 0
)
(
  input  wire clk_i   ,
  output reg  clk_o   ,

  output reg  clka_o  ,
  output reg  clkb_o  ,
  output reg  clkc_o  ,
  output reg  clkd_o
);


// clock periods
real clka_per;
real clkb_per ;
real clkc_per ;
real clkd_per ;
real clkpll_per;


// jitters in percent units of clock period
integer clka_jit  ;
integer clkb_jit  ;
integer clkc_jit  ;
integer clkd_jit  ;
integer clkpll_jit  ;

integer pll_del ;
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
reg clkpll;
initial
begin:clkpll_gen_blk
  clkpll_per = CLKA_PERIOD/2  ;
  clkpll_jit = CLKA_JIT     ;
  pll_del    = CLKA_PERIOD*DEL/100;

  clkpll = 1'b0           ;

  #pll_del;
  
  forever
  begin
    #((clkpll_per + ({$random} % clkpll_jit)) / 2) clkpll = ~clkpll ;
  end
end

always @ (negedge clkpll) begin
  clk_o <= clk_i;
end
//------------------------------------------------------------------------------



//------------------------------------------------------------------------------
initial
begin:clka_gen_blk
  clka_per = CLKA_PERIOD  ;
  clka_jit = CLKA_JIT     ;
  clka_o = 1'b0           ;

  forever
  begin
    #((clka_per + ({$random} % clka_jit)) / 2) clka_o = ~clka_o ;
  end
end
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
initial
begin:clkb_gen_blk
  clkb_per = CLKB_PERIOD  ;
  clkb_jit = CLKB_JIT     ;
  clkb_o = 1'b0           ;
  
  forever
  begin
    #((clkb_per + ({$random} % clkb_jit)) / 2) clkb_o = ~clkb_o ;
  end
end
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
initial
begin:clkc_gen_blk
  clkc_per = CLKC_PERIOD  ;
  clkc_jit = CLKC_JIT     ;
  clkc_o = 1'b0           ;

  forever
  begin
    #((clkc_per + ({$random} % clkc_jit)) / 2) clkc_o = ~clkc_o ;
  end
end
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
initial
begin:clkd_gen_blk
  clkd_per = CLKD_PERIOD  ;
  clkd_jit = CLKD_JIT     ;
  clkd_o = 1'b0           ;

  forever
  begin
    #((clkd_per + ({$random} % clkd_jit)) / 2) clkd_o = ~clkd_o ;
  end
end
//------------------------------------------------------------------------------

endmodule
