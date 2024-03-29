/**
 * $Id: rp_adc_trig.v 2024-03-15
 *
 * @brief Red Pitaya ADC trigger
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
Within this module we create the ADC signal threshold triggers.
*/

module rp_adc_trig #(
  parameter DW  = 14
)(
  // ADC
  input                 adc_clk_i       ,  // ADC clock
  input                 adc_rstn_i      ,  // ADC reset - active low

  input      [ DW-1: 0] adc_dat_i       ,
  input                 adc_dv_i        ,
  input      [ DW-1: 0] set_tresh_i     ,
  input      [ DW-1: 0] set_hyst_i      ,

  output reg            adc_trig_p_o    ,
  output reg            adc_trig_n_o
);

reg  [  2-1: 0] adc_scht_p  ;
reg  [  2-1: 0] adc_scht_n  ;
reg  [ DW-1: 0] set_treshp ;
reg  [ DW-1: 0] set_treshm ;

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   adc_scht_p   <=  2'h0 ;
   adc_scht_n   <=  2'h0 ;
   adc_trig_p_o <=  1'b0 ;
   adc_trig_n_o <=  1'b0 ;
end else begin
   set_treshp <= set_tresh_i + set_hyst_i ; // calculate positive
   set_treshm <= set_tresh_i - set_hyst_i ; // and negative treshold

   if (adc_dv_i) begin
           if ($signed(adc_dat_i) >= $signed(set_tresh_i ))      adc_scht_p[0] <= 1'b1 ;  // treshold reached
      else if ($signed(adc_dat_i) <  $signed(set_treshm  ))      adc_scht_p[0] <= 1'b0 ;  // wait until it goes under hysteresis
           if ($signed(adc_dat_i) <= $signed(set_tresh_i ))      adc_scht_n[0] <= 1'b1 ;  // treshold reached
      else if ($signed(adc_dat_i) >  $signed(set_treshp  ))      adc_scht_n[0] <= 1'b0 ;  // wait until it goes over hysteresis
   end

   adc_scht_p[1] <= adc_scht_p[0] ;
   adc_scht_n[1] <= adc_scht_n[0] ;

   adc_trig_p_o <= adc_scht_p[0] && !adc_scht_p[1] ; // make 1 cyc pulse 
   adc_trig_n_o <= adc_scht_n[0] && !adc_scht_n[1] ;
end

endmodule