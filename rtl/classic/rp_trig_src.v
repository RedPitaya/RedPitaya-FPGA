/**
 * $Id: rp_trig_src.v 2024-03-15
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
This module selects the trigger source for acquisition. 
Also includes trigger protection logic.
*/

module rp_trig_src #(
  parameter CHN   = 0
)(
  // ADC
  input                 adc_clk_i       ,  // ADC clock
  input                 adc_rstn_i      ,  // ADC reset - active low

  input                 adc_rst_do_i    ,
  input                 adc_dly_do_i    ,
  input                 trig_dis_clr_i  ,

  input       [ 4-1: 0] set_trg_src_i   ,
  input                 set_trg_new_i   ,



  input                 adc_trig_sw_i   ,
  input       [ 4-1: 0] adc_trig_p_i    ,
  input       [ 4-1: 0] adc_trig_n_i    ,
  input                 ext_trig_p_i    ,
  input                 ext_trig_n_i    ,
  input                 asg_trig_p_i    ,
  input                 asg_trig_n_i    ,
  input       [ 4-1: 0] trig_ch_i       ,

  output      [ 8-1: 0] trg_state_o     ,
  output                adc_trig_o
);

reg   [   4-1: 0] set_trig_src     ;
reg               adc_trg_dis      ;
reg               adc_trig         ;

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   adc_trg_dis   <= 1'b0 ;
   set_trig_src  <= 4'h0 ;
end else begin
   if (set_trg_new_i)
      set_trig_src <= set_trg_src_i ;
   else if (adc_dly_do_i || adc_trig || adc_rst_do_i) //delay reached or reset
      set_trig_src <= 4'h0 ;

   if (trig_dis_clr_i)
      adc_trg_dis <= 1'b0 ;
   else if (adc_trig)
      adc_trg_dis <= 1'b1 ;

   case (set_trig_src & ({4{!adc_trg_dis}}))
       4'd1 : adc_trig <= adc_trig_sw_i   ; // manual
       4'd2 : adc_trig <= CHN == 0 ? adc_trig_p_i[0] : trig_ch_i[0] ; // A ch rising edge
       4'd3 : adc_trig <= CHN == 0 ? adc_trig_n_i[0] : trig_ch_i[1] ; // A ch falling edge
       4'd4 : adc_trig <= CHN == 0 ? adc_trig_p_i[1] : trig_ch_i[2] ; // B ch rising edge
       4'd5 : adc_trig <= CHN == 0 ? adc_trig_n_i[1] : trig_ch_i[3] ; // B ch falling edge
       4'd6 : adc_trig <= ext_trig_p_i  ; // external - rising edge
       4'd7 : adc_trig <= ext_trig_n_i  ; // external - falling edge
       4'd8 : adc_trig <= asg_trig_p_i  ; // ASG - rising edge
       4'd9 : adc_trig <= asg_trig_n_i  ; // ASG - falling edge
       4'd10: adc_trig <= CHN == 1 ? adc_trig_p_i[0] : trig_ch_i[0] ; // from the other two ADC channels: C ch rising edge
       4'd11: adc_trig <= CHN == 1 ? adc_trig_n_i[0] : trig_ch_i[1] ; // from the other two ADC channels: C ch falling edge
       4'd12: adc_trig <= CHN == 1 ? adc_trig_p_i[1] : trig_ch_i[2] ; // from the other two ADC channels: D ch rising edge
       4'd13: adc_trig <= CHN == 1 ? adc_trig_n_i[1] : trig_ch_i[3] ; // from the other two ADC channels: D ch falling edge
    default : adc_trig <= 1'b0          ; 
   endcase
end

assign adc_trig_o    = adc_trig;
assign trg_state_o   = {3'h0, adc_trg_dis, set_trig_src};

endmodule