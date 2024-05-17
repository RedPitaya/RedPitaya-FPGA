/**
 * $Id: rp_bram_sm.v 2024-03-15
 *
 * @brief Red Pitaya BRAM access state machine
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
Within this module we create the acquisition enable signals, write pointers and save the trigger write pointer.
*/

module rp_bram_sm #(
  parameter RSZ = 14
)(
  // ADC
  input                 adc_clk_i       ,  // ADC clock
  input                 adc_rstn_i      ,  // ADC reset - active low

  input      [ 32-1: 0] set_dly_i       ,
  input                 set_dec1_i      ,
  input                 adc_rst_do_i    ,
  input                 adc_we_keep_i   ,
  input                 adc_arm_do_i    ,
  input                 adc_trig_i      ,
  input                 adc_dv_i        ,
  input                 indep_mode_i    ,
  input                 trig_dis_clr_i  ,

  output reg [RSZ-1: 0] adc_wp_o        ,
  output reg [RSZ-1: 0] adc_wp_cur_o    ,
  output reg [RSZ-1: 0] adc_wp_trig_o   ,
  output reg [ 32-1: 0] adc_we_cnt_o    ,
  output     [  8-1: 0] adc_state_o     ,
  output                adc_dly_do_o    ,
  output                adc_we_o
);

reg   [  32-1: 0] adc_dly_cnt   ;
reg               adc_dly_do    ;
reg               adc_dly_end_reg;
reg               adc_trg_rd    ;
reg               adc_trg_rd_reg;

reg               adc_dly_end;
reg               adc_we;


assign adc_state_o = {2'h0, indep_mode_i, adc_dly_end, adc_we_keep_i, adc_trg_rd, 1'b0, adc_we};

always @(posedge adc_clk_i) begin
  if (adc_rstn_i == 1'b0) begin
    adc_we     <=  1'b0      ;
    adc_we_cnt_o <= 32'h0      ;
  end else begin
    if (adc_arm_do_i)
      adc_we <= 1'b1 ;
    else if (((adc_dly_do || adc_trig_i) && (adc_dly_cnt == 32'h1) && ~adc_we_keep_i) || adc_rst_do_i) //delayed reached or reset
      adc_we <= 1'b0 ;

    // count how much data was written into the buffer before trigger
    if ((adc_rst_do_i || adc_arm_do_i) || (trig_dis_clr_i && adc_we_keep_i)) // at arm, in cont mode at trigger protect clear
      adc_we_cnt_o <= 32'h0;
    else if (adc_we & ~adc_dly_do & adc_dv_i & ~&adc_we_cnt_o)
      adc_we_cnt_o <= adc_we_cnt_o + 1;         
  end
end

always @(posedge adc_clk_i) begin
  if (adc_rstn_i == 1'b0) begin
    adc_wp_o      <= {RSZ{1'b0}};
    adc_wp_trig_o <= {RSZ{1'b0}};
    adc_wp_cur_o  <= {RSZ{1'b0}};
  end else begin
    if (adc_rst_do_i)
      adc_wp_o <= {RSZ{1'b0}};
    else if (adc_we && adc_dv_i)
      adc_wp_o <= adc_wp_o + 1;

    if (adc_rst_do_i)
      adc_wp_trig_o <= {RSZ{1'b0}};
    else if (adc_trig_i && !adc_dly_do)
      adc_wp_trig_o <= adc_wp_o; // save write pointer at trigger arrival

    if (adc_rst_do_i)
      adc_wp_cur_o <= {RSZ{1'b0}};
    else if (adc_we && adc_dv_i)
      adc_wp_cur_o <= adc_wp_o; // save current write pointer
  end
end

always @(posedge adc_clk_i) begin
  if (adc_rstn_i == 1'b0) begin
    adc_trg_rd  <=  1'b0      ;
    adc_trg_rd_reg  <= 1'b0   ;
  end else begin
    adc_trg_rd_reg <= adc_trig_i;
    if (~adc_trg_rd_reg && adc_trig_i) //check if trigger happenned
      adc_trg_rd <= 1'b1; //register remains 1 until next arm or reset
    else if (adc_rst_do_i || adc_arm_do_i)
      adc_trg_rd <= 1'b0;
  end
end

always @(posedge adc_clk_i) begin
  if (adc_rstn_i == 1'b0) begin
    adc_dly_cnt <= 32'h0      ;
    adc_dly_do  <=  1'b0      ;
    adc_dly_end <=  1'b0      ;
    adc_dly_end_reg <= 1'b0   ;
  end else begin
    if (adc_trig_i)
      adc_dly_do  <= 1'b1;
    else if ((adc_dly_do && (adc_dly_cnt <= 32'h1)) || adc_rst_do_i || adc_arm_do_i) //delayed reached or reset; delay is shortened by 1
      adc_dly_do  <= 1'b0;
    
    adc_dly_end_reg <= adc_dly_do; 
      
    if (adc_rst_do_i || adc_arm_do_i)
      adc_dly_end <= 1'b0;
    else if (adc_dly_end_reg && ~adc_dly_do) //check if delay is over
      adc_dly_end <= 1'b1; //register remains 1 until next arm or reset

    if ((adc_dly_do && adc_we && adc_dv_i) || (adc_trig_i && set_dec1_i))
      adc_dly_cnt <= adc_dly_cnt - 1;
    else if (!adc_dly_do)
      adc_dly_cnt <= set_dly_i ;
  end
end
assign adc_we_o     = adc_we;
assign adc_dly_do_o = adc_dly_do;

endmodule
