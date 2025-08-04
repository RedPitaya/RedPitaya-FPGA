/**
 * $Id: rp_axi_sm.v 2025-08-01
 *
 * @brief Red Pitaya AXI acquisition state machine
 *
 * @Author 
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */


/*
GENERAL DESCRIPTION:
*/
module rp_dv_65 #(
  parameter DW = 14
)(
  // ADC
  input                 adc_clk_i       ,  // ADC clock
  input                 adc_rstn_i      ,  // ADC reset - active low
  input                 dv_en_i         ,  // data valid chop enable 

  input                 adc_dv_i        ,
  output                adc_dv_o      
);

logic adc_dv; // chopped data valid signal


assign adc_dv_o = (adc_dv_i && dv_en_i) ? adc_dv : adc_dv_i;

always @(posedge adc_clk_i) begin
    if(adc_rstn_i == 1'b0)
      adc_dv <= 1'b1;
    else
      adc_dv <= ~adc_dv;
end

endmodule
