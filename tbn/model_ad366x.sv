

`timescale 1ns/1ps

module model_ad366x #(
  parameter TPHS = 0    ,
  parameter LW   = 2    ,
  parameter TSER = 0.1  ,
  parameter TDLY = 0.1   
)
(
  input      [ 14-1:0] dat_a    , // data
  input      [ 14-1:0] dat_b    , // data

  input                dco_i    , // data clock
  output reg           dco_o    , // data clock
  output reg           fr_o     , // frame
  output reg [ LW-1:0] da_o     , // data
  output reg [ LW-1:0] db_o       // data
);

localparam PW = 16/LW;
localparam CW = $clog2(PW) + 1;

always @(*) begin
/* #TSER*/ dco_o <= dco_i;
end

reg  [16-1: 0] data = 0;
reg  [16-1: 0] outa = 0;
reg  [16-1: 0] datb = 0;
reg  [16-1: 0] outb = 0;
reg  [CW-1: 0] bsel = 1;

reg            frl   = 0;
reg  [LW-1: 0] outal = 0;
reg  [LW-1: 0] outbl = 0;

always @(dco_o) begin

  if (&bsel[2:0])begin
   outa <= {dat_a, 2'h0} ;
   outb <= {dat_b, 2'h0} ;
  end
end



//if (LW==2) begin
 always @(dco_o) begin
  frl  <= bsel[3]  ;
  bsel <= bsel + 1 ;

  case (bsel[2:0])
    3'h0 : outal <=  {outa[15], outa[14]} ;  // 1 0
    3'h1 : outal <=  {outa[13], outa[12]} ;  // 1 0
    3'h2 : outal <=  {outa[11], outa[10]} ;  // 1 0
    3'h3 : outal <=  {outa[ 9], outa[ 8]} ;  // 1 0
    3'h4 : outal <=  {outa[ 7], outa[ 6]} ;  // 1 0
    3'h5 : outal <=  {outa[ 5], outa[ 4]} ;  // 1 0
    3'h6 : outal <=  {outa[ 3], outa[ 2]} ;  // 1 0
    3'h7 : outal <=  {outa[ 1], outa[ 0]} ;  // 1 0
  endcase
  case (bsel[2:0])
    3'h0 : outbl <=  {outb[15], outb[14]} ;  // 1 0
    3'h1 : outbl <=  {outb[13], outb[12]} ;  // 1 0
    3'h2 : outbl <=  {outb[11], outb[10]} ;  // 1 0
    3'h3 : outbl <=  {outb[ 9], outb[ 8]} ;  // 1 0
    3'h4 : outbl <=  {outb[ 7], outb[ 6]} ;  // 1 0
    3'h5 : outbl <=  {outb[ 5], outb[ 4]} ;  // 1 0
    3'h6 : outbl <=  {outb[ 3], outb[ 2]} ;  // 1 0
    3'h7 : outbl <=  {outb[ 1], outb[ 0]} ;  // 1 0
  endcase
 end
//end






always @(dco_o)
  #TDLY  fr_o <= frl   ;
always @(dco_o)
  #TDLY  da_o <= outal ;
always @(dco_o)
  #TDLY  db_o <= outbl ;



endmodule
