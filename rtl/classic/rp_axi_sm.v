/**
 * $Id: rp_axi_sm.v 2024-03-15
 *
 * @brief Red Pitaya AXI acquisition state machine
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
This module includes acquisition logic to the AXI bus and handles the AXI bus master. 
The data is concatenated into 4*16 bit samples and a trigger indicator is saved. 
Based on that the trigger write pointer is also saved. 
*/
module rp_axi_sm #(
  parameter DW = 14
)(
  // ADC
  input                 axi_clk_i       ,  // ADC clock
  input                 axi_rstn_i      ,  // ADC reset - active low

  // AXI master
  output     [ 32-1: 0] axi_waddr_o     ,  // system write address
  output     [ 64-1: 0] axi_wdata_o     ,  // system write data
  output     [  8-1: 0] axi_wsel_o      ,  // system write byte select
  output                axi_wvalid_o    ,  // system write data valid
  output     [  4-1: 0] axi_wlen_o      ,  // system write burst length
  output                axi_wfixed_o    ,  // system write burst type (fixed / incremental)
  input                 axi_werr_i      ,  // system write error
  input                 axi_wrdy_i      ,  // system write ready

  input      [ DW-1: 0] axi_dat_i       ,
  input                 axi_dv_i        ,
  input      [ 32-1: 0] set_dly_i       ,
  input                 set_dec1_i      ,
  input                 indep_mode_i    ,

  input                 adc_rst_do_i    ,
  input                 adc_we_keep_i   ,
  input                 adc_arm_do_i    ,
  input                 adc_trig_i      ,
  input                 axi_en_pulse_i  ,
  input                 set_axi_en_i    ,
  input      [ 32-1: 0] set_axi_start_i ,
  input      [ 32-1: 0] set_axi_stop_i  ,

  output                axi_trig_o      ,
  output reg [ 32-1: 0] axi_wp_cur_o    ,
  output reg [ 32-1: 0] axi_wp_trig_o   ,
  output     [  8-1: 0] axi_state_o
);

reg             axi_we           ;
reg             axi_we_r         ;
reg  [ 64-1: 0] axi_dat          ;

wire            axi_trig    ;
reg  [  4-1: 0] axi_trig_r  ;
wire [  2-1: 0] axi_sel     ;
reg  [ 75-1: 0] axi_dat_fifo [0:3];
reg  [ 75-1: 0] axi_fifo_o       ;
reg  [  2-1: 0] axi_dat_fifo_lvl ;
wire            axi_fifo_rd ;
reg             axi_fifo_rdr;

reg  [  2-1: 0] axi_dat_sel      ;
reg  [  3-1: 0] axi_md           ;

reg  [  1-1: 0] axi_dat_dv       ;
reg  [ 32-1: 0] axi_dly_cnt      ;
reg             axi_dly_do       ;
reg             axi_dly_end      ;
reg             axi_dly_end_reg  ;
wire            axi_clr          ;
wire [ 32-1: 0] axi_cur_addr     ;
reg  [  8-1: 0] axi_val_byte     ;
wire [  8-1: 0] axi_val_byte_f   ;
reg             axi_trg_rd_reg   ;
reg             axi_trg_rd       ;

assign axi_clr = adc_rst_do_i || axi_en_pulse_i ; // when AXI A is enabled
assign axi_state_o = {2'h0, indep_mode_i, axi_dly_end, adc_we_keep_i, axi_trg_rd, 1'b0, axi_we};
assign axi_trig_o  = axi_trig;

assign axi_fifo_rd    = ~axi_dat_dv && axi_dat_fifo_lvl > 0 && ~(axi_trig || |axi_trig_r); // disable FIFO reads when there is a trigger
assign axi_trig       = axi_fifo_o[64] && axi_fifo_rdr;
assign axi_sel        = axi_fifo_o[66:65];
assign axi_val_byte_f = axi_fifo_o[74:67];

always @(posedge axi_clk_i) begin
  if (axi_rstn_i == 1'b0) begin
    axi_trg_rd_reg <= 1'b0;
    axi_trg_rd     <= 1'b0;
  end else begin
    axi_trg_rd_reg <= adc_trig_i;
    if (~axi_trg_rd_reg && adc_trig_i) //check if trigger happenned
      axi_trg_rd <= 1'b1; //register remains 1 until next arm or reset
    else if (adc_rst_do_i || adc_arm_do_i)
      axi_trg_rd <= 1'b0;
  end
end

always @(posedge axi_clk_i) begin
  if (axi_rstn_i == 1'b0) begin
      axi_we <=  1'b0 ;
  end else begin
    if (adc_arm_do_i && set_axi_en_i)
      axi_we <= 1'b1 ;
    else if (((axi_dly_do || adc_trig_i) && (axi_dly_cnt == 32'h1)) || adc_rst_do_i) //delay reached or reset
      axi_we <= 1'b0 ;
  end
end

always @(posedge axi_clk_i) begin
  if (axi_rstn_i == 1'b0) begin
      axi_dly_cnt <= 32'h0 ;
      axi_dly_do  <=  1'b0 ;
      axi_dly_end <=  1'b0      ;
      axi_dly_end_reg <= 1'b0   ;
  end else begin
    if (adc_trig_i && axi_we)
      axi_dly_do  <= 1'b1 ;
    else if ((axi_dly_do && (axi_dly_cnt <= 32'h1)) || axi_clr || adc_arm_do_i) // end of delay
      axi_dly_do  <= 1'b0 ;

    axi_dly_end_reg <= axi_dly_do; 

    if ((axi_dly_do && axi_we && axi_dv_i) || (adc_trig_i && set_dec1_i)) // shorthen by 1 if decimation is 1
      axi_dly_cnt <= axi_dly_cnt - 1;
    else if (!axi_dly_do)
      axi_dly_cnt <= set_dly_i ;

    if (adc_rst_do_i || adc_arm_do_i)
      axi_dly_end<=1'b0;
    else if (axi_dly_end_reg && ~axi_dly_do) //check if delay is over
      axi_dly_end<=1'b1; //register remains 1 until next arm or reset
  end
end


always @(posedge axi_clk_i) begin
  if (axi_rstn_i == 1'b0) begin
    axi_dat_dv   <=  1'b0 ;
    axi_val_byte <=  8'h0;
    axi_dat_sel  <=  2'h0 ;
  end else begin
    axi_trig_r <= {axi_trig_r[3-1:0],axi_trig}; //axi_trig fifod
    axi_we_r   <= axi_we;
    axi_dat_dv <= (axi_we && (axi_dat_sel == 2'b11) && axi_dv_i) || ((axi_dat_sel != 2'b00) && (~axi_we && axi_we_r)) ;
    axi_fifo_rdr <= axi_fifo_rd;

    if (axi_clr || (~axi_we && axi_we_r))
      axi_dat_sel <= 2'h0 ;
    else if (axi_we && axi_dv_i)
      axi_dat_sel <= axi_dat_sel + 2'h1 ;

    if (axi_we && axi_dv_i) begin
      if (axi_dat_sel == 2'b00) begin axi_dat[ 16-1:  0] <= $signed(axi_dat_i); axi_val_byte <= {2'b00, 2'b00, 2'b00, 2'b11}; end
      if (axi_dat_sel == 2'b01) begin axi_dat[ 32-1: 16] <= $signed(axi_dat_i); axi_val_byte <= {2'b00, 2'b00, 2'b11, 2'b11}; end
      if (axi_dat_sel == 2'b10) begin axi_dat[ 48-1: 32] <= $signed(axi_dat_i); axi_val_byte <= {2'b00, 2'b11, 2'b11, 2'b11}; end
      if (axi_dat_sel == 2'b11) begin axi_dat[ 64-1: 48] <= $signed(axi_dat_i); axi_val_byte <= {2'b11, 2'b11, 2'b11, 2'b11}; end
    end
  end
end

always @(posedge axi_clk_i) begin
  if (axi_rstn_i == 1'b0) begin
    axi_md           <=  3'h0;
  end else begin
    if (adc_trig_i)
      axi_md <= {axi_dat_sel,(!axi_dly_do && axi_we)}; //valid trig
    else if (axi_dat_dv)
      axi_md <= 3'h0;
  end
end

always @(posedge axi_clk_i) begin
  if (axi_rstn_i == 1'b0) begin
      axi_dat_fifo_lvl <=  4'h0;
      axi_fifo_o       <= 75'h0;
  end else begin
    if (axi_dat_dv) begin
      axi_dat_fifo[0] <= {axi_val_byte, axi_md, axi_dat};
      axi_dat_fifo[1] <= axi_dat_fifo[0];
      axi_dat_fifo[2] <= axi_dat_fifo[1];
      axi_dat_fifo[3] <= axi_dat_fifo[2];
      axi_dat_fifo_lvl <= axi_dat_fifo_lvl + 1;
    end else if (axi_fifo_rd) begin
      axi_fifo_o <= axi_dat_fifo[axi_dat_fifo_lvl-1];
      axi_dat_fifo_lvl <= axi_dat_fifo_lvl - 1;
    end
  end
end

always @(posedge axi_clk_i) begin
  if (axi_rstn_i == 1'b0) begin
    axi_wp_trig_o <= 32'h0 ;
    axi_wp_cur_o  <= 32'h0 ;
  end else begin
    if (axi_clr)
      axi_wp_trig_o <= {32{1'b0}};
    else if (axi_trig_r[1]) // wait for the address to update from last write to AXI FIFO
      axi_wp_trig_o <= {axi_cur_addr[32-1:3],axi_sel, 1'b0}; // save write pointer at trigger arrival

    if (axi_clr)
      axi_wp_cur_o <= set_axi_start_i ;
    else if (axi_wvalid_o)
      axi_wp_cur_o <= axi_cur_addr ;
  end
end


axi_wr_fifo #(
  .DW  (  64    ), // data width (8,16,...,1024)
  .AW  (  32    ), // address width
  .FW  (   8    ),  // address width of FIFO pointers
  .BYTE_SEL ( 1 )
) i_wr0 (
   // global signals
  .axi_clk_i          (  axi_clk_i        ), // global clock
  .axi_rstn_i         (  axi_rstn_i       ), // global reset

   // Connection to AXI master
  .axi_waddr_o        (  axi_waddr_o      ), // write address
  .axi_wdata_o        (  axi_wdata_o      ), // write data
  .axi_wsel_o         (  axi_wsel_o       ), // write byte select
  .axi_wvalid_o       (  axi_wvalid_o     ), // write data valid
  .axi_wlen_o         (  axi_wlen_o       ), // write burst length
  .axi_wfixed_o       (  axi_wfixed_o     ), // write burst type (fixed / incremental)
  .axi_werr_i         (  axi_werr_i       ), // write error
  .axi_wrdy_i         (  axi_wrdy_i       ), // write ready

   // data and configuration
  .wr_data_i          (  axi_fifo_o[63:0] ), // write data
  .wr_byte_val_i      (  axi_val_byte_f   ),
  .wr_val_i           (  axi_fifo_rdr     ), // write data valid
  .ctrl_start_addr_i  (  set_axi_start_i  ), // range start address
  .ctrl_stop_addr_i   (  set_axi_stop_i   ), // range stop address
  .ctrl_trig_size_i   (  4'hF             ), // trigger level
  .ctrl_wrap_i        (  1'b1             ), // start from begining when reached stop
  .ctrl_clr_i         (  axi_clr          ), // clear / flush
  .stat_overflow_o    (                   ), // overflow indicator
  .stat_cur_addr_o    (  axi_cur_addr     ), // current write address
  .stat_write_data_o  (                   )  // write data indicator
);

endmodule