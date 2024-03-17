/**
 * $Id: rp_delay.v 2024-03-15
 *
 * @brief Red Pitaya ADC data delay
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
This module delays ADC data so it can be perfectly aligned to the trigger.
*/

module rp_delay #(
  parameter DW   = 14
)(
  // ADC
  input                adc_clk_i       ,  // ADC clock
  input                adc_rstn_i      ,  // ADC reset - active low

  input                axi_clk_i       ,  // ADC clock
  input                axi_rstn_i      ,  // ADC reset - active low

  input      [DW-1: 0] dly_dat_i       ,
  input                dly_val_i       ,
  input      [ 4-1: 0] set_trg_src_i   ,
  input                set_trg_new_i   ,

  output reg           axidly_val_o    ,
  output reg [DW-1: 0] axidly_dat_o    ,

  output reg           dly_val_o       ,
  output reg [DW-1: 0] dly_dat_o
);

//---------------------------------------------------------------------------------
//  Decimate input data
reg  [ DW-1: 0] adc_fifo [3:0]  ;
reg  [ DW-1: 0] axi_fifo [3:0]  ;

reg  [  4-1: 0] last_src        ;
reg  [  4-1: 0] adc_dv_r        ;
reg  [  4-1: 0] axi_dv_r        ;


always @(posedge adc_clk_i) begin
  adc_dv_r     <= {adc_dv_r[3-1:0], dly_val_i};

  adc_fifo[0]  <= dly_dat_i;
  adc_fifo[1]  <= adc_fifo[0];
  adc_fifo[2]  <= adc_fifo[1];
  adc_fifo[3]  <= adc_fifo[2];
end

always @(posedge axi_clk_i) begin
  axi_dv_r     <= {axi_dv_r[3-1:0], dly_val_i};

  axi_fifo[0]  <= dly_dat_i;
  axi_fifo[1]  <= axi_fifo[0];
  axi_fifo[2]  <= axi_fifo[1];
  axi_fifo[3]  <= axi_fifo[2];
end

always @(posedge adc_clk_i) begin
  if (adc_rstn_i == 1'b0)
    last_src <= 4'h0;
  else begin
    if (set_trg_new_i)
      last_src <= set_trg_src_i ;
  end
end

reg [2-1:0] dat_dly  ;
reg [2-1:0] prev_dly ;
always @(posedge adc_clk_i) begin //delay to trigger
  if (adc_rstn_i == 1'b0) begin
    dat_dly  <= 2'h0;
    prev_dly <= 2'h0;
  end else begin
    case (last_src)
      4'd2,
      4'd3,
      4'd4,
      4'd5,
      4'd10,
      4'd11,
      4'd12,
      4'd13   : begin dat_dly <= 2'h1; prev_dly <= 2'h1; end // level trigger
      4'd6,
      4'd7,
      4'd8,
      4'd9    : begin dat_dly <= 2'h2; prev_dly <= 2'h2; end // external and ASG trigger
      default : begin dat_dly <= prev_dly;              end // manual trigger
    endcase
  end
end

always @(posedge adc_clk_i) begin
  dly_dat_o    <= adc_fifo[dat_dly]; 
  dly_val_o    <= adc_dv_r[dat_dly];
end

always @(posedge axi_clk_i) begin
  axidly_val_o <= adc_dv_r[1];
  axidly_dat_o <= axi_fifo[2];
end

endmodule