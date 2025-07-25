/**
 * $Id: rp_scope_cfg.v 2024-03-15
 *
 * @brief Red Pitaya scope register access module
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
This module gives access to all internal registers and buffers through the simplified sys bus.
 */

module rp_scope_cfg #(
  parameter CHN  = 0 ,
  parameter N_CH = 2 ,
  parameter DW   = 14,
  parameter RSZ  = 14  // RAM size 2^RSZ
)(
   // ADC
   input                      adc_clk_i            ,  // ADC clock
   input                      adc_rstn_i           ,  // ADC reset - active low
  
   // System bus
   input      [      32-1: 0] sys_addr             ,
   input      [      32-1: 0] sys_wdata            ,
   input                      sys_wen              ,
   input                      sys_ren              ,
   output reg [      32-1: 0] sys_rdata            ,
   output reg                 sys_err              ,
   output reg                 sys_ack              ,

   input      [   4*8  -1: 0] adc_state_i          ,
   input      [   4*8  -1: 0] axi_state_i          ,
   input      [   4*8  -1: 0] trg_state_i          ,
   input      [   2*8  -1: 0] adc_state_ext_i      ,
   input      [   2*8  -1: 0] axi_state_ext_i      ,
   input      [   2*8  -1: 0] trg_state_ext_i      ,

   input      [   4*RSZ-1: 0] adc_wp_cur_i         ,
    input      [   4*RSZ-1: 0] adc_wp_trig_i        ,
   input      [   4*32 -1: 0] adc_we_cnt_i         ,

   input      [   4*32 -1: 0] axi_wp_cur_i         ,
   input      [   4*32 -1: 0] axi_wp_trig_i        ,

   input      [   4*DW -1: 0] bram_rd_dat_i        ,
   input      [       4-1: 0] bram_ack_i           ,

   output     [       4-1: 0] adc_arm_do_o         ,
   output     [       4-1: 0] adc_rst_do_o         ,
   output     [       4-1: 0] adc_trig_sw_o        ,
   output     [       4-1: 0] adc_we_keep_o        ,
   output     [       4-1: 0] trig_dis_clr_o       ,
   output     [       4-1: 0] indep_mode_o         ,
   output     [       4-1: 0] axi_en_pulse_o       ,
   output     [       4-1: 0] new_trg_src_o        ,
   output     [   4*4  -1: 0] trg_src_o            ,
   output     [       4-1: 0] set_dec1_o           ,
   output     [       4-1: 0] filt_rstn_o          ,
   output     [   4*DW -1: 0] set_tresh_o          ,
   output     [   4*32 -1: 0] set_dly_o            ,
   output     [   4*17 -1: 0] set_dec_o            ,
   output     [   4*DW -1: 0] set_hyst_o           ,
   output     [       4-1: 0] set_avg_en_o         ,
   output     [   4*18 -1: 0] set_filt_aa_o        ,
   output     [   4*25 -1: 0] set_filt_bb_o        ,
   output     [   4*25 -1: 0] set_filt_kk_o        ,
   output     [   4*25 -1: 0] set_filt_pp_o        ,

   output     [   4*DW -1: 0] set_calib_offset_o   ,
   output     [   4*16 -1: 0] set_calib_gain_o     ,

   output     [      4 -1: 0] set_filt_byp_o       ,
   output     [      20-1: 0] set_deb_len_o        ,
   output     [   4*32 -1: 0] set_axi_start_o      ,
   output     [   4*32 -1: 0] set_axi_stop_o       ,
   output     [   4*32 -1: 0] set_axi_dly_o        ,
   output     [       4-1: 0] set_axi_en_o


);

reg  [    4-1: 0] adc_arm_do    ;
reg  [    4-1: 0] adc_rst_do    ;
reg  [    4-1: 0] adc_trig_sw   ;
reg  [    4-1: 0] adc_we_keep   ;
reg  [    4-1: 0] trig_dis_clr  ;
reg  [    4-1: 0] indep_mode    ;


wire [    4-1: 0] axi_en_addr   ;
wire [    4-1: 0] axi_en_pulse  ;

wire [    4-1: 0] new_trg_src   ;
wire [    4-1: 0] set_dec1      ;
wire [    4-1: 0] filt_rstn     ;
wire [    4-1: 0] filt_coef_adr ;

reg  [ 4*DW-1: 0] set_tresh     ;
reg  [ 4*32-1: 0] set_dly       ;
reg  [ 4*17-1: 0] set_dec       ;
reg  [ 4*DW-1: 0] set_hyst      ;
reg  [    4-1: 0] set_avg_en    ;
wire [ 4*4 -1: 0] trg_src       ;


reg  [ 4*18-1: 0] set_filt_aa   ;
reg  [ 4*25-1: 0] set_filt_bb   ;
reg  [ 4*25-1: 0] set_filt_kk   ;
reg  [ 4*25-1: 0] set_filt_pp   ;
reg  [    4-1: 0] set_filt_byp  ;
// added to store calibration data
reg  [ 4*DW-1: 0]   set_calib_offset  ;
reg  [ 4*16-1: 0]   set_calib_gain  ;

reg  [   20-1: 0] set_deb_len   ;

reg  [ 4*32-1: 0] set_axi_start ;
reg  [ 4*32-1: 0] set_axi_stop  ;
reg  [ 4*32-1: 0] set_axi_dly   ;
reg  [    4-1: 0] set_axi_en    ;

wire              sys_en        ;

wire [   32-1: 0] adc_state_rd   ;
wire [   32-1: 0] trg_state_rd   ;

assign adc_state_rd = (CHN == 0) ? {adc_state_ext_i, adc_state_i[15:0]} : {adc_state_i[15:0], adc_state_ext_i};
assign trg_state_rd = (CHN == 0) ? {trg_state_ext_i, trg_state_i[15:0]} : {trg_state_i[15:0], trg_state_ext_i};

assign axi_en_addr[0]   = sys_addr[19: 0] == 20'h5C;
assign axi_en_addr[1]   = sys_addr[19: 0] == 20'h7C;
assign axi_en_addr[2]   = sys_addr[19: 0] == 20'h9C;
assign axi_en_addr[3]   = sys_addr[19: 0] == 20'hBC;

assign filt_coef_adr[0] = sys_addr[ 7: 4] ==  4'h3 ;
assign filt_coef_adr[1] = sys_addr[ 7: 4] ==  4'h4 ;
assign filt_coef_adr[2] = sys_addr[ 7: 4] ==  4'h3 ;
assign filt_coef_adr[3] = sys_addr[ 7: 4] ==  4'h3 ;

assign sys_en = sys_wen | sys_ren;


genvar GV;
generate
for(GV = 0 ; GV < N_CH ; GV = GV + 1) begin
wire [ 8-1: 0] sys_dats;

reg            filt_coef_wr;


assign sys_dats                 = ((CHN == 1) && (indep_mode[GV] == 1)) ? sys_wdata[(GV+3)*8-1:(GV+2)*8] : sys_wdata[(GV+1)*8-1:GV*8] ;
//assign sys_dats                 = sys_wdata[(GV+1)*8-1:GV*8];

assign axi_en_pulse[GV]         = sys_wen && axi_en_addr[GV] && sys_wdata[0];
assign new_trg_src[GV]          = (sys_addr[19:0] == 20'h4) && sys_wen && |sys_dats[3:0];
assign set_dec1[GV]             = (set_dec[(GV+1)*17-1:GV*17] == 17'h1);
assign filt_rstn[GV]            = (adc_rstn_i == 1'b1) && filt_coef_wr;
assign trg_src[(GV+1)*4-1:GV*4] = sys_dats[3:0];

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   filt_coef_wr <= 1'b1;
end else begin
   filt_coef_wr <= ~(sys_wen && filt_coef_adr[GV]);
end

always @(posedge adc_clk_i) begin
  if (adc_rstn_i == 1'b0) begin
    adc_arm_do[GV]   <= 1'b0 ;
    adc_rst_do[GV]   <= 1'b0 ;
    adc_trig_sw[GV]  <= 1'b0 ;
    adc_we_keep[GV]  <= 1'b0 ;
    trig_dis_clr[GV] <= 1'b0 ;
    indep_mode[GV]   <= 1'b0 ;
    set_avg_en[GV]   <= 1'b0 ;
  end else begin
    adc_arm_do[GV]   <= sys_wen && (sys_addr[19:0]==20'h0 ) && sys_dats[0] ; // SW ARM
    adc_rst_do[GV]   <= sys_wen && (sys_addr[19:0]==20'h0 ) && sys_dats[1] ; // reset
    adc_trig_sw[GV]  <= sys_wen && (sys_addr[19:0]==20'h4 ) && (sys_dats[3:0]==4'h1); // SW trigger
    trig_dis_clr[GV] <= sys_wen && (sys_addr[19:0]==20'h94) && (sys_dats[0]==1'b1);   // clear trigger protect/disable
    if (sys_wen) begin
      if (sys_addr[19:0]==20'h0  && |sys_dats)  adc_we_keep[GV]  <= sys_dats[3]   ; // ARM stays on after trigger
      if (sys_addr[19:0]==20'h0  && |sys_dats)  indep_mode[GV]   <= sys_dats[5]   ; // independent acq mode
      if (sys_addr[19:0]==20'h28             )  set_avg_en[GV]   <= sys_dats[0]   ; // averaging enable
    end
  end
end

end
endgenerate


wire [    4-1: 0] adc_arm_do_x    ;
wire [    4-1: 0] adc_rst_do_x    ;
wire [    4-1: 0] adc_trig_sw_x   ;
wire [    4-1: 0] adc_we_keep_x   ;
wire [    4-1: 0] trig_dis_clr_x  ;
wire [    4-1: 0] new_trg_src_x   ;
wire [ 4*4 -1: 0] trg_src_x       ;
wire [ 4*32-1: 0] set_dly_x       ;
wire [ 4*17-1: 0] set_dec_x       ;
wire [    4-1: 0] set_dec1_x      ;
wire [    4-1: 0] set_avg_en_x    ;


genvar GL;
generate
for(GL = 0 ; GL < N_CH ; GL = GL + 1) begin

if (GL == 0) begin
  assign adc_arm_do_x[GL]             = adc_arm_do[GL]             ;
  assign adc_rst_do_x[GL]             = adc_rst_do[GL]             ;
  assign adc_trig_sw_x[GL]            = adc_trig_sw[GL]            ;
  assign adc_we_keep_x[GL]            = adc_we_keep[GL]            ;
  assign trig_dis_clr_x[GL]           = trig_dis_clr[GL]           ;
  assign new_trg_src_x[GL]            = new_trg_src[GL]            ;
  assign trg_src_x[(GL+1)*4 -1:GL*4 ] = trg_src[(GL+1)*4-1:GL*4] ;
  assign set_dly_x[(GL+1)*32-1:GL*32] = set_dly[(GL+1)*32-1:GL*32] ;
  assign set_dec_x[(GL+1)*17-1:GL*17] = set_dec[(GL+1)*17-1:GL*17] ;
  assign set_dec1_x[GL]               = set_dec1[GL]               ;
  assign set_avg_en_x[GL]             = set_avg_en[GL]             ;
end else begin
  assign adc_arm_do_x[GL]             = indep_mode[GL] ? adc_arm_do[GL]             : adc_arm_do[0]   ;
  assign adc_rst_do_x[GL]             = indep_mode[GL] ? adc_rst_do[GL]             : adc_rst_do[0]   ;
  assign adc_trig_sw_x[GL]            = indep_mode[GL] ? adc_trig_sw[GL]            : adc_trig_sw[0]  ;
  assign adc_we_keep_x[GL]            = indep_mode[GL] ? adc_we_keep[GL]            : adc_we_keep[0]  ;
  assign trig_dis_clr_x[GL]           = indep_mode[GL] ? trig_dis_clr[GL]           : trig_dis_clr[0] ;
  assign new_trg_src_x[GL]            = indep_mode[GL] ? new_trg_src[GL]            : new_trg_src[0]  ;
  assign trg_src_x[(GL+1)*4 -1:GL*4 ] = indep_mode[GL] ? trg_src[(GL+1)*4-1:GL*4]   : trg_src[3:0]    ;
  assign set_dly_x[(GL+1)*32-1:GL*32] = indep_mode[GL] ? set_dly[(GL+1)*32-1:GL*32] : set_dly[32-1: 0];
  assign set_dec_x[(GL+1)*17-1:GL*17] = indep_mode[GL] ? set_dec[(GL+1)*17-1:GL*17] : set_dec[17-1: 0];
  assign set_dec1_x[GL]               = indep_mode[GL] ? set_dec1[GL]               : set_dec1[0]     ;
  assign set_avg_en_x[GL]             = indep_mode[GL] ? set_avg_en[GL]             : set_avg_en[0]   ;
end

end
endgenerate


always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
  set_tresh[DW*1-1:DW*0] <=  'd5000         ;
  set_tresh[DW*2-1:DW*1] <= -'d5000         ;
  set_tresh[DW*3-1:DW*2] <=  'd5000         ;
  set_tresh[DW*4-1:DW*3] <= -'d5000         ;

  set_dly                <= {4{32'd0}}      ;
  set_dec                <= {4{17'd1}}      ;
  set_hyst[DW*1-1:DW*0]  <= 'd20            ;
  set_hyst[DW*2-1:DW*1]  <= 'd20            ;
  set_hyst[DW*3-1:DW*2]  <= 'd20            ;
  set_hyst[DW*4-1:DW*3]  <= 'd20            ;

  set_filt_aa            <= {4{18'h0}}      ;
  set_filt_bb            <= {4{25'h0}}      ;
  set_filt_kk            <= {4{25'hFFFFFF}} ;
  set_filt_pp            <= {4{25'h0}}      ;
  set_filt_byp           <=  4'h0           ;

  set_calib_offset       <= {4{{DW{1'b0}}}}      ;
  set_calib_gain         <= {4{16'h8000}}   ;

  set_deb_len            <= {4{20'd62500}}  ;

  set_axi_start          <= {4{32'd0}}      ;
  set_axi_stop           <= {4{32'd0}}      ;
  set_axi_dly            <= {4{32'd0}}      ;
  set_axi_en             <=  4'h0           ;
end else begin
  if (sys_wen) begin
    if (sys_addr[19:0]==20'h08 )   set_tresh[DW*1-1:DW*0]     <= sys_wdata[DW-1:0] ;
    if (sys_addr[19:0]==20'h0C )   set_tresh[DW*2-1:DW*1]     <= sys_wdata[DW-1:0] ;
    if (sys_addr[19:0]==20'h10 )   set_dly[32*1-1:32*0]       <= sys_wdata[32-1:0] ;
    if (sys_addr[19:0]==20'h14 )   set_dec[17*1-1:17*0]       <= sys_wdata[17-1:0] ;
    if (sys_addr[19:0]==20'h20 )   set_hyst[DW*1-1:DW*0]      <= sys_wdata[DW-1:0] ;
    if (sys_addr[19:0]==20'h24 )   set_hyst[DW*2-1:DW*1]      <= sys_wdata[DW-1:0] ;

    if (sys_addr[19:0]==20'h30 )   set_filt_aa[18*1-1:18*0]   <= sys_wdata[18-1:0] ;
    if (sys_addr[19:0]==20'h34 )   set_filt_bb[25*1-1:25*0]   <= sys_wdata[25-1:0] ;
    if (sys_addr[19:0]==20'h38 )   set_filt_kk[25*1-1:25*0]   <= sys_wdata[25-1:0] ;
    if (sys_addr[19:0]==20'h3C )   set_filt_pp[25*1-1:25*0]   <= sys_wdata[25-1:0] ;
    if (sys_addr[19:0]==20'h40 )   set_filt_aa[18*2-1:18*1]   <= sys_wdata[18-1:0] ;
    if (sys_addr[19:0]==20'h44 )   set_filt_bb[25*2-1:25*1]   <= sys_wdata[25-1:0] ;
    if (sys_addr[19:0]==20'h48 )   set_filt_kk[25*2-1:25*1]   <= sys_wdata[25-1:0] ;
    if (sys_addr[19:0]==20'h4C )   set_filt_pp[25*2-1:25*1]   <= sys_wdata[25-1:0] ;

    if (sys_addr[19:0]==20'h50 )   set_axi_start[32*1-1:32*0] <= sys_wdata[32-1:0] ;
    if (sys_addr[19:0]==20'h54 )   set_axi_stop[32*1-1:32*0]  <= sys_wdata[32-1:0] ;
    if (sys_addr[19:0]==20'h58 )   set_axi_dly[32*1-1:32*0]   <= sys_wdata[32-1:0] ;
    if (sys_addr[19:0]==20'h5C )   set_axi_en[0]              <= sys_wdata[     0] ;

    if (sys_addr[19:0]==20'h70 )   set_axi_start[32*2-1:32*1] <= sys_wdata[32-1:0] ;
    if (sys_addr[19:0]==20'h74 )   set_axi_stop[32*2-1:32*1]  <= sys_wdata[32-1:0] ;
    if (sys_addr[19:0]==20'h78 )   set_axi_dly[32*2-1:32*1]   <= sys_wdata[32-1:0] ;
    if (sys_addr[19:0]==20'h7C )   set_axi_en[1]              <= sys_wdata[     0] ;

    if (sys_addr[19:0]==20'h90 )   set_deb_len                <= sys_wdata[20-1:0] ;
    // Offset 0x94 reserved for trigger unlock bit
    if (sys_addr[19:0]==20'h98 )   set_filt_byp               <= sys_wdata[ 4-1:0] ;

    if (sys_addr[19:0]==20'h110)   set_dly[32*2-1:32*1]       <= sys_wdata[32-1:0] ;
    if (sys_addr[19:0]==20'h114)   set_dec[17*2-1:17*1]       <= sys_wdata[17-1:0] ;    

    // data for calibration of for channel
      // ch 1
    if (sys_addr[19:0]==20'h200)   set_calib_offset[DW*1-1:DW*0]    <= sys_wdata[DW-1:0] ;
    if (sys_addr[19:0]==20'h204)   set_calib_gain[16*1-1:16*0]      <= sys_wdata[16-1:0] ;
      // ch 2
    if (sys_addr[19:0]==20'h208)   set_calib_offset[DW*2-1:DW*1]    <= sys_wdata[DW-1:0] ;
    if (sys_addr[19:0]==20'h20c)   set_calib_gain[16*2-1:16*1]      <= sys_wdata[16-1:0] ;
    // removed because for 4ADC channels are mirrored on main address
      //// ch 3
    //if (sys_addr[19:0]==20'h210)   set_calib_offset[16*3-1:16*2]    <= sys_wdata[16-1:0] ;
    //if (sys_addr[19:0]==20'h214)   set_calib_gain[16*3-1:16*2]      <= sys_wdata[16-1:0] ;
      ////ch 4
    //if (sys_addr[19:0]==20'h218)   set_calib_offset[16*4-1:16*3]    <= sys_wdata[16-1:0] ;
    //if (sys_addr[19:0]==20'h21c)   set_calib_gain[16*4-1:16*3]      <= sys_wdata[16-1:0] ;

    //if (sys_addr[19:0]==20'h230 )   set_filt_aa[18*3-1:18*0]   <= sys_wdata[18-1:0] ;
    //if (sys_addr[19:0]==20'h234 )   set_filt_bb[25*3-1:25*0]   <= sys_wdata[25-1:0] ;
    //if (sys_addr[19:0]==20'h238 )   set_filt_kk[25*3-1:25*0]   <= sys_wdata[25-1:0] ;
    //if (sys_addr[19:0]==20'h23C )   set_filt_pp[25*3-1:25*0]   <= sys_wdata[25-1:0] ;
    //if (sys_addr[19:0]==20'h240 )   set_filt_aa[18*4-1:18*3]   <= sys_wdata[18-1:0] ;
    //if (sys_addr[19:0]==20'h244 )   set_filt_bb[25*4-1:25*3]   <= sys_wdata[25-1:0] ;
    //if (sys_addr[19:0]==20'h248 )   set_filt_kk[25*4-1:25*3]   <= sys_wdata[25-1:0] ;
    //if (sys_addr[19:0]==20'h24C )   set_filt_pp[25*4-1:25*3]   <= sys_wdata[25-1:0] ;

   end
end



always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
  sys_err <= 1'b0 ;
  sys_ack <= 1'b0 ;
end else begin
  sys_err <= 1'b0 ;

  casez (sys_addr[19:0])
    20'h00000 : begin sys_ack <= sys_en;          sys_rdata <=                 adc_state_rd                     ; end
    20'h00004 : begin sys_ack <= sys_en;          sys_rdata <=                 trg_state_rd                     ; end 
    //20'h00000 : begin sys_ack <= sys_en;          sys_rdata <=                 adc_state_i                      ; end
    //20'h00004 : begin sys_ack <= sys_en;          sys_rdata <=                 trg_state_i                      ; end 

    20'h00008 : begin sys_ack <= sys_en;          sys_rdata <= {{32-DW{1'b0}}, set_tresh[DW*1-1:DW*0]}          ; end
    20'h0000C : begin sys_ack <= sys_en;          sys_rdata <= {{32-DW{1'b0}}, set_tresh[DW*2-1:DW*1]}          ; end
    20'h00010 : begin sys_ack <= sys_en;          sys_rdata <=                 set_dly[32*1-1:32*0]             ; end
    20'h00014 : begin sys_ack <= sys_en;          sys_rdata <= {{32-17{1'b0}}, set_dec[17*1-1:17*0]}            ; end

    20'h00018 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ{1'b0}}, adc_wp_cur_i[RSZ*1-1:RSZ*0]}    ; end
    20'h0001C : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ{1'b0}}, adc_wp_trig_i[RSZ*1-1:RSZ*0]}   ; end

    20'h00020 : begin sys_ack <= sys_en;          sys_rdata <= {{32-DW{1'b0}},  set_hyst[DW*1-1:DW*0]}          ; end
    20'h00024 : begin sys_ack <= sys_en;          sys_rdata <= {{32-DW{1'b0}},  set_hyst[DW*2-1:DW*1]}          ; end

    20'h00028 : begin sys_ack <= sys_en;          sys_rdata <= {{ 8- 1{1'b0}},  set_avg_en[3],
                                                                { 8- 1{1'b0}},  set_avg_en[2],
                                                                { 8- 1{1'b0}},  set_avg_en[1],
                                                                { 8- 1{1'b0}},  set_avg_en[0]}                  ; end

    20'h0002C : begin sys_ack <= sys_en;          sys_rdata <=                  adc_we_cnt_i[32*1-1:32*0]       ; end

    20'h00030 : begin sys_ack <= sys_en;          sys_rdata <= {{32-18{1'b0}},  set_filt_aa[18*1-1:18*0]}       ; end
    20'h00034 : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_bb[25*1-1:25*0]}       ; end
    20'h00038 : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_kk[25*1-1:25*0]}       ; end
    20'h0003C : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_pp[25*1-1:25*0]}       ; end
    20'h00040 : begin sys_ack <= sys_en;          sys_rdata <= {{32-18{1'b0}},  set_filt_aa[18*2-1:18*1]}       ; end
    20'h00044 : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_bb[25*2-1:25*1]}       ; end
    20'h00048 : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_kk[25*2-1:25*1]}       ; end
    20'h0004C : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_pp[25*2-1:25*1]}       ; end

    20'h00050 : begin sys_ack <= sys_en;          sys_rdata <=                  set_axi_start[32*1-1:32*0]      ; end
    20'h00054 : begin sys_ack <= sys_en;          sys_rdata <=                  set_axi_stop[32*1-1:32*0]       ; end
    20'h00058 : begin sys_ack <= sys_en;          sys_rdata <=                  set_axi_dly[32*1-1:32*0]        ; end
    20'h0005C : begin sys_ack <= sys_en;          sys_rdata <= {{32- 1{1'b0}},  set_axi_en[0]}                  ; end
    20'h00060 : begin sys_ack <= sys_en;          sys_rdata <=                  axi_wp_trig_i[32*1-1:32*0]      ; end
    20'h00064 : begin sys_ack <= sys_en;          sys_rdata <=                  axi_wp_cur_i[32*1-1:32*0]       ; end

    20'h00070 : begin sys_ack <= sys_en;          sys_rdata <=                  set_axi_start[32*2-1:32*1]      ; end
    20'h00074 : begin sys_ack <= sys_en;          sys_rdata <=                  set_axi_stop[32*2-1:32*1]       ; end
    20'h00078 : begin sys_ack <= sys_en;          sys_rdata <=                  set_axi_dly[32*2-1:32*1]        ; end
    20'h0007C : begin sys_ack <= sys_en;          sys_rdata <= {{32- 1{1'b0}},  set_axi_en[1]}                  ; end
    20'h00080 : begin sys_ack <= sys_en;          sys_rdata <=                  axi_wp_trig_i[32*2-1:32*1]      ; end
    20'h00084 : begin sys_ack <= sys_en;          sys_rdata <=                  axi_wp_cur_i[32*2-1:32*1]       ; end

    20'h00088 : begin sys_ack <= sys_en;          sys_rdata <= {8'h0,           axi_state_i[16-1: 8],
                                                                8'h0,           axi_state_i[ 8-1: 0]}           ; end

    20'h00090 : begin sys_ack <= sys_en;          sys_rdata <= {{32-20{1'b0}},  set_deb_len}                    ; end
    // Offset 0x94 reserved for trigger unlock bit
    20'h00098 : begin sys_ack <= sys_en;          sys_rdata <= {{32- 4{1'b0}},  set_filt_byp}                   ; end

    20'h00110 : begin sys_ack <= sys_en;          sys_rdata <=                  set_dly[32*2-1:32*1]            ; end
    20'h00114 : begin sys_ack <= sys_en;          sys_rdata <= {{32-17{1'b0}},  set_dec[17*2-1:17*1]}           ; end
    20'h00118 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ{1'b0}}, adc_wp_cur_i[RSZ*2-1:RSZ*1]}    ; end
    20'h0011C : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ{1'b0}}, adc_wp_trig_i[RSZ*2-1:RSZ*1]}   ; end
    20'h0012C : begin sys_ack <= sys_en;          sys_rdata <=                  adc_we_cnt_i[32*2-1:32*1]       ; end

    20'h00200 : begin sys_ack <= sys_en;          sys_rdata <= {{32-DW{1'b0}},  set_calib_offset[DW*1-1:DW*0]}  ; end
    20'h00204 : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},  set_calib_gain[16*1-1:16*0]}    ; end
    20'h00208 : begin sys_ack <= sys_en;          sys_rdata <= {{32-DW{1'b0}},  set_calib_offset[DW*2-1:DW*1]}  ; end
    20'h0020C : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},  set_calib_gain[16*2-1:16*1]}    ; end
    // removed because for 4ADC channels are mirrored on main address
    //20'h00210 : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},  set_calib_offset[16*3-1:16*2]}  ; end
    //20'h00214 : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},  set_calib_gain[16*3-1:16*2]}    ; end
    //20'h00218 : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},  set_calib_offset[16*4-1:16*3]}  ; end
    //20'h0021C : begin sys_ack <= sys_en;          sys_rdata <= {{32-16{1'b0}},  set_calib_gain[16*4-1:16*3]}    ; end

    //20'h00230 : begin sys_ack <= sys_en;          sys_rdata <= {{32-18{1'b0}},  set_filt_aa[18*3-1:18*2]}       ; end
    //20'h00234 : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_bb[25*3-1:25*2]}       ; end
    //20'h00238 : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_kk[25*3-1:25*2]}       ; end
    //20'h0023C : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_pp[25*3-1:25*2]}       ; end
    //20'h00240 : begin sys_ack <= sys_en;          sys_rdata <= {{32-18{1'b0}},  set_filt_aa[18*4-1:18*3]}       ; end
    //20'h00244 : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_bb[25*4-1:25*3]}       ; end
    //20'h00248 : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_kk[25*4-1:25*3]}       ; end
    //20'h0024C : begin sys_ack <= sys_en;          sys_rdata <= {{32-25{1'b0}},  set_filt_pp[25*4-1:25*3]}       ; end

    20'h1???? : begin sys_ack <= bram_ack_i[0];   sys_rdata <= {{32-DW{1'b0}},  bram_rd_dat_i[DW*1-1:DW*0]}     ; end
    20'h2???? : begin sys_ack <= bram_ack_i[1];   sys_rdata <= {{32-DW{1'b0}},  bram_rd_dat_i[DW*2-1:DW*1]}     ; end
    20'h3???? : begin sys_ack <= bram_ack_i[2];   sys_rdata <= {{32-DW{1'b0}},  bram_rd_dat_i[DW*3-1:DW*2]}     ; end
    20'h4???? : begin sys_ack <= bram_ack_i[3];   sys_rdata <= {{32-DW{1'b0}},  bram_rd_dat_i[DW*4-1:DW*3]}     ; end

    default   : begin sys_ack <= sys_en;          sys_rdata <=  32'h0                                           ; end
  endcase
end

assign adc_arm_do_o          = adc_arm_do_x    ;
assign adc_rst_do_o          = adc_rst_do_x    ;
assign adc_trig_sw_o         = adc_trig_sw_x   ;
assign adc_we_keep_o         = adc_we_keep_x   ;
assign trig_dis_clr_o        = trig_dis_clr_x  ;
assign indep_mode_o          = indep_mode      ;
assign axi_en_pulse_o        = axi_en_pulse    ;
assign new_trg_src_o         = new_trg_src_x   ;
assign trg_src_o             = trg_src_x       ;
assign set_dec1_o            = set_dec1_x      ;
assign filt_rstn_o           = filt_rstn       ;
assign set_tresh_o           = set_tresh       ;
assign set_dly_o             = set_dly_x       ;
assign set_dec_o             = set_dec_x       ;
assign set_hyst_o            = set_hyst        ;
assign set_avg_en_o          = set_avg_en_x    ;
assign set_filt_aa_o         = set_filt_aa     ;
assign set_filt_bb_o         = set_filt_bb     ;
assign set_filt_kk_o         = set_filt_kk     ;
assign set_filt_pp_o         = set_filt_pp     ;
assign set_filt_byp_o        = set_filt_byp    ;
assign set_deb_len_o         = set_deb_len     ;
assign set_axi_start_o       = set_axi_start   ;
assign set_axi_stop_o        = set_axi_stop    ;
assign set_axi_dly_o         = set_axi_dly     ;
assign set_axi_en_o          = set_axi_en      ;
assign set_calib_offset_o    = set_calib_offset;
assign set_calib_gain_o      = set_calib_gain  ;

endmodule
