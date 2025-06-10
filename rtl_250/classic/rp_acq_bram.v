/**
 * $Id: rp_acq_bram.v 2024-03-15
 *
 * @brief Red Pitaya trigger selector logic
 *
 * @Author Jure Trnovec
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */


/*
GENERAL DESCRIPTION:
Acquisition BRAM interface; write and read logic. 
*/

module rp_acq_bram #(
  parameter DW   = 14,
  parameter RSZ  = 14
)(
   input                 adc_clk_i  ,  // ADC clock
   input                 adc_rstn_i ,  // ADC reset - active low

   input      [RSZ-1: 0] bram_wp_i  ,
   input      [DW -1: 0] bram_dat_i ,
   input                 bram_val_i ,  // data valid
   input                 bram_we_i  ,  // write enable 
   input                 bram_ack_i ,

   input      [RSZ-1: 0] bram_rp_i  , // address
   output reg [DW -1: 0] bram_dat_o ,
   output                bram_ack_o
);

reg  [ DW-1: 0] adc_buf [0:(1<<RSZ)-1] ;
reg  [RSZ-1: 0] adc_raddr;
reg  [RSZ-1: 0] adc_raddr_r;
reg  [  4-1: 0] adc_rval;

always @(posedge adc_clk_i) begin
  if (bram_we_i && bram_val_i) begin
    adc_buf[bram_wp_i] <= bram_dat_i ;
  end
end

always @(posedge adc_clk_i) begin
  if (adc_rstn_i == 1'b0)
    adc_rval <= 4'h0 ;
  else
    adc_rval <= {adc_rval[2:0], bram_ack_i};
end
assign bram_ack_o = adc_rval[3];

always @(posedge adc_clk_i) begin
  adc_raddr   <= bram_rp_i ; // address synchronous to clock
  adc_raddr_r <= adc_raddr ; // double register 
  bram_dat_o  <= adc_buf[adc_raddr_r] ;
end

endmodule
