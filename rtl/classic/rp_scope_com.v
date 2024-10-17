/**
 * $Id: red_pitaya_scope.v 965 2014-01-24 13:39:56Z matej.oblak $
 *
 * @brief Red Pitaya oscilloscope application, used for capturing ADC data
 *        into BRAMs, which can be later read by SW.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */

/**
 * GENERAL DESCRIPTION:
 *
 * This is simple data aquisition module, primerly used for scilloscope 
 * application. It consists from three main parts.
 *
 *
 *                /--------\      /-----------\            /-----\
 *   ADC CHA ---> | DFILT1 | ---> | AVG & DEC | ---------> | BUF | --->  SW
 *                \--------/      \-----------/     |      \-----/
 *                                                  ˇ         ^
 *                                              /------\      |
 *   ext trigger -----------------------------> | TRIG | -----+
 *                                              \------/      |
 *                                                  ^         ˇ
 *                /--------\      /-----------\     |      /-----\
 *   ADC CHB ---> | DFILT1 | ---> | AVG & DEC | ---------> | BUF | --->  SW
 *                \--------/      \-----------/            \-----/ 
 *
 *
 * Input data is optionaly averaged and decimated via average filter.
 *
 * Trigger section makes triggers from input ADC data or external digital 
 * signal. To make trigger from analog signal schmitt trigger is used, external
 * trigger goes first over debouncer, which is separate for pos. and neg. edge.
 *
 * Data capture buffer is realized with BRAM. Writing into ram is done with 
 * arm/trig logic. With adc_arm_do signal (SW) writing is enabled, this is active
 * until trigger arrives and adc_dly_cnt counts to zero. Value adc_wp_trig
 * serves as pointer which shows when trigger arrived. This is used to show
 * pre-trigger data.
 * 
 */

module rp_scope_com #(
  parameter CHN  = 0 ,
  parameter N_CH = 2 ,
  parameter DW   = 14,
  parameter RSZ  = 14  // RAM size 2^RSZ
)(
   // ADC
   input      [N_CH   -1: 0] adc_clk_i      ,  // ADC clock
   input      [N_CH   -1: 0] adc_rstn_i     ,  // ADC reset - active low
   input      [N_CH*DW-1: 0] adc_dat_i      ,  // ADC data CHA
   // trigger sources
   input                     trig_ext_i     ,  // external trigger
   input                     trig_asg_i     ,  // ASG trigger
   output     [      4-1: 0] trig_ch_o      ,  // output trigger to ADC for other 2 channels
   input      [      4-1: 0] trig_ch_i      ,  // input ADC trigger from other 2 channels
   output     [      4-1: 0] trig_ext_asg_o ,  // output External and ASG trigger to share between multiple scope modules
   input      [      4-1: 0] trig_ext_asg_i ,  // input External and ASG trigger 
   output                    daisy_trig_o   ,  // trigger for daisy chaining
   // axi master
   output     [N_CH   -1: 0] axi_clk_o      ,  // global clock
   output     [N_CH   -1: 0] axi_rstn_o     ,  // global reset
   output     [N_CH*32-1: 0] axi_waddr_o    ,  // system write address
   output     [N_CH*64-1: 0] axi_wdata_o    ,  // system write data
   output     [N_CH* 8-1: 0] axi_wsel_o     ,  // system write byte select
   output     [N_CH   -1: 0] axi_wvalid_o   ,  // system write data valid
   output     [N_CH* 4-1: 0] axi_wlen_o     ,  // system write burst length
   output     [N_CH   -1: 0] axi_wfixed_o   ,  // system write burst type (fixed / incremental)
   input      [N_CH   -1: 0] axi_werr_i     ,  // system write error
   input      [N_CH   -1: 0] axi_wrdy_i     ,  // system write ready
   output     [     16-1: 0] adc_state_o    ,
   input      [     16-1: 0] adc_state_i    ,
   output     [     16-1: 0] axi_state_o    ,
   input      [     16-1: 0] axi_state_i    ,
   output     [     16-1: 0] trg_state_o    ,
   input      [     16-1: 0] trg_state_i    ,

   // System bus
   input      [     32-1: 0] sys_addr       ,  // bus saddress
   input      [     32-1: 0] sys_wdata      ,  // bus write data
   input                     sys_wen        ,  // bus write enable
   input                     sys_ren        ,  // bus read enable
   output     [     32-1: 0] sys_rdata      ,  // bus read data
   output                    sys_err        ,  // bus error indicator
   output                    sys_ack           // bus acknowledge signal
);

wire [    N_CH-1: 0] axi_clk        ;
wire [    N_CH-1: 0] axi_rstn       ;

wire [       4-1: 0] adc_arm_do     ;
wire [       4-1: 0] adc_rst_do     ;
wire [       4-1: 0] adc_trig_sw    ;
wire [       4-1: 0] adc_we_keep    ;
wire [       4-1: 0] trig_dis_clr   ;
wire [       4-1: 0] axi_en_pulse   ;
wire [       4-1: 0] new_trg_src    ;
wire [   4*4  -1: 0] trg_src        ;
wire [       4-1: 0] set_dec1       ;
wire [       4-1: 0] filt_rstn      ;
wire [   4*DW -1: 0] set_tresh      ;
wire [   4*32 -1: 0] set_adc_dly    ;
wire [   4*17 -1: 0] set_dec        ;
wire [   4*DW -1: 0] set_hyst       ;
wire [       4-1: 0] set_avg_en     ;
wire [   4*18 -1: 0] set_filt_aa    ;
wire [   4*25 -1: 0] set_filt_bb    ;
wire [   4*25 -1: 0] set_filt_kk    ;
wire [   4*25 -1: 0] set_filt_pp    ;
wire [      20-1: 0] set_deb_len    ;
wire [   4*32 -1: 0] set_axi_start  ;
wire [   4*32 -1: 0] set_axi_stop   ;
wire [   4*32 -1: 0] set_axi_dly    ;
wire [       4-1: 0] set_axi_en     ;
wire [       4-1: 0] indep_mode     ;

wire [   4*8  -1: 0] axi_state    ;
wire [   4*8  -1: 0] adc_state    ;
wire [   4*8  -1: 0] trg_state    ;

wire [   4*RSZ-1: 0] adc_wp_cur   ;
wire [   4*RSZ-1: 0] adc_wp_trig  ;
wire [   4*32 -1: 0] adc_we_cnt   ;
wire [   4*32 -1: 0] axi_wp_cur   ;
wire [   4*32 -1: 0] axi_wp_trig  ;

wire [       4-1: 0] bram_ack     ;
wire [   4*DW -1: 0] bram_rd_dat  ;

wire [       4-1: 0] adc_trig_p   ;
wire [       4-1: 0] adc_trig_n   ;
wire                 ext_trig_p   ;
wire                 ext_trig_n   ;
wire                 asg_trig_p   ;
wire                 asg_trig_n   ;
wire [       4-1: 0] adc_trig     ;
wire [       4-1: 0] axi_trig     ;
wire                 sys_en       ;


wire [   4*RSZ-1: 0] adc_wp_act   ;
wire [    4*DW-1: 0] adc_bram_in  ;
wire [       4-1: 0] adc_we       ;
wire [       4-1: 0] adc_dv_del;

assign sys_en = sys_wen | sys_ren;

assign adc_state_o = adc_state[15:0];
assign axi_state_o = axi_state[15:0];
assign trg_state_o = trg_state[15:0];

genvar GV;
generate
for(GV = 0 ; GV < N_CH ; GV = GV + 1) begin
wire [ DW-1: 0] adc_filt_in  ;
wire [ DW-1: 0] adc_dec_in   ;
wire [ DW-1: 0] adc_dly_in   ;
wire [ DW-1: 0] axi_ram_in   ;
wire            adc_dly_do   ;

wire            axi_dv_del;
wire            dec_val;

assign adc_filt_in  = adc_dat_i[(GV+1)*DW-1:GV*DW] ;

red_pitaya_dfilt1 i_dfilt1_cha (
   // ADC
  .adc_clk_i   ( adc_clk_i[GV] ),  // ADC clock
  .adc_rstn_i  ( filt_rstn[GV] ),  // ADC reset - active low
  .adc_dat_i   ( adc_filt_in   ),  // ADC raw data
  .adc_dat_o   ( adc_dec_in    ),  // filtered data
   // configuration
  .cfg_aa_i    ( set_filt_aa[(GV+1)*18-1:GV*18] ),  // config AA coefficient
  .cfg_bb_i    ( set_filt_bb[(GV+1)*25-1:GV*25] ),  // config BB coefficient
  .cfg_kk_i    ( set_filt_kk[(GV+1)*25-1:GV*25] ),  // config KK coefficient
  .cfg_pp_i    ( set_filt_pp[(GV+1)*25-1:GV*25] )   // config PP coefficient
);


rp_decim #(
  .DW  (  DW    )
) i_dec (
   // global signals
  .adc_clk_i    ( adc_clk_i[GV]  ),  // ADC clock
  .adc_rstn_i   ( adc_rstn_i[GV] ),  // ADC reset - active low

   // Connection to AXI master
  .dec_dat_i    ( adc_dec_in                 ),  // data in
  .set_dec_i    ( set_dec[(GV+1)*17-1:GV*17] ),  // decimation
  .set_avg_en_i ( set_avg_en[GV]             ),  // averaging enable
  .adc_arm_do_i ( adc_arm_do[GV]             ),

  .dec_val_o    ( dec_val       ),
  .dec_dat_o    ( adc_dly_in    )   // decimated data out
);


rp_delay #(
  .DW  (  DW    )
) i_dly (
   // global signals
  .adc_clk_i     ( adc_clk_i[GV]                  ),  // ADC clock
  .adc_rstn_i    ( adc_rstn_i[GV]                 ),  // ADC reset - active low
  .axi_clk_i     ( axi_clk[GV]                    ),  // AXI clock
  .axi_rstn_i    ( axi_rstn[GV]                   ),  // AXI reset - active low

   // Connection to AXI master
  .dly_dat_i     ( adc_dly_in                     ),
  .dly_val_i     ( dec_val                        ),
  .set_trg_src_i ( trg_src[(GV+1)*4-1:GV*4]       ),
  .set_trg_new_i ( new_trg_src[GV]                ),

  .axidly_val_o  ( axi_dv_del                     ),
  .axidly_dat_o  ( axi_ram_in                     ), // delayed data to AXI

  .dly_val_o     ( adc_dv_del[GV]                 ),
  .dly_dat_o     ( adc_bram_in[(GV+1)*DW-1:GV*DW] )  // delayed data to BRAM
);

rp_adc_trig #(
  .DW  (  DW     )
) i_adc_trig (
   // global signals
  .adc_clk_i      ( adc_clk_i[GV]   ),  // ADC clock
  .adc_rstn_i     ( adc_rstn_i[GV]  ),  // ADC reset - active low

   // Connection to AXI master
  .adc_dat_i      ( adc_dly_in                      ),
  .adc_dv_i       ( dec_val                         ),
  .set_tresh_i    ( set_tresh[(GV+1)*DW-1:GV*DW]    ),
  .set_hyst_i     ( set_hyst[(GV+1)*DW-1:GV*DW]     ),

  .adc_trig_p_o   ( adc_trig_p[GV]                  ),
  .adc_trig_n_o   ( adc_trig_n[GV]                  )
);

rp_trig_src #(
  .CHN  (  CHN   )
) i_trig_src (
   // global signals
  .adc_clk_i      ( adc_clk_i[GV]   ),  // ADC clock
  .adc_rstn_i     ( adc_rstn_i[GV]  ),  // ADC reset - active low

   // Connection to AXI master
  .adc_rst_do_i   ( adc_rst_do[GV]   ),
  .adc_dly_do_i   ( adc_dly_do       ),
  .trig_dis_clr_i ( trig_dis_clr[GV] ),

  .set_trg_src_i  ( trg_src[(GV+1)*4-1:GV*4] ),
  .set_trg_new_i  ( new_trg_src[GV]          ),

  .adc_trig_sw_i  ( adc_trig_sw[GV]   ),
  .adc_trig_p_i   ( adc_trig_p        ),
  .adc_trig_n_i   ( adc_trig_n        ),
  .ext_trig_p_i   ( trig_ext_asg_i[0] ),
  .ext_trig_n_i   ( trig_ext_asg_i[1] ),
  .asg_trig_p_i   ( trig_ext_asg_i[2] ),
  .asg_trig_n_i   ( trig_ext_asg_i[3] ),
  .trig_ch_i      ( trig_ch_i         ),

  .trg_state_o    ( trg_state[(GV+1)*8-1:GV*8]),
  .adc_trig_o     ( adc_trig[GV]              )
);

rp_bram_sm #(
) i_bram_sm (
   // global signals
  .adc_clk_i      ( adc_clk_i[GV]   ),  // ADC clock
  .adc_rstn_i     ( adc_rstn_i[GV]  ),  // ADC reset - active low

   // Connection to AXI master
  .set_dly_i      ( set_adc_dly[(GV+1)*32 -1:GV*32 ]  ),
  .set_dec1_i     ( set_dec1[GV]                      ),
  .adc_rst_do_i   ( adc_rst_do[GV]                    ),
  .adc_we_keep_i  ( adc_we_keep[GV]                   ),
  .adc_arm_do_i   ( adc_arm_do[GV]                    ),
  .adc_trig_i     ( adc_trig[GV]                      ),
  .adc_dv_i       ( adc_dv_del[GV]                    ),
  .indep_mode_i   ( indep_mode[GV]                    ),
  .trig_dis_clr_i ( trig_dis_clr[GV]                  ),

  .adc_wp_o       ( adc_wp_act[(GV+1)*RSZ-1:GV*RSZ]   ),
  .adc_wp_cur_o   ( adc_wp_cur[(GV+1)*RSZ-1:GV*RSZ]   ),
  .adc_wp_trig_o  ( adc_wp_trig[(GV+1)*RSZ-1:GV*RSZ]  ),
  .adc_we_cnt_o   ( adc_we_cnt[(GV+1)*32-1:GV*32]     ),
  .adc_state_o    ( adc_state[(GV+1)*8-1:GV*8]        ),
  .adc_we_o       ( adc_we[GV]                        ),
  .adc_dly_do_o   ( adc_dly_do                        )
);

rp_acq_bram #(
  .DW  (  DW     ),
  .RSZ (  RSZ    )
) i_acq_bram (
   // global signals
  .adc_clk_i      ( adc_clk_i[GV]   ),  // ADC clock
  .adc_rstn_i     ( adc_rstn_i[GV]  ),  // ADC reset - active low

   // Connection to AXI master
  .bram_wp_i      ( adc_wp_act[(GV+1)*RSZ-1:GV*RSZ] ),
  .bram_dat_i     ( adc_bram_in[(GV+1)*DW-1:GV*DW]  ),
  .bram_val_i     ( adc_dv_del[GV]                  ),
  .bram_we_i      ( adc_we[GV]                      ),
  .bram_ack_i     ( sys_en                          ),

  .bram_rp_i      ( sys_addr[RSZ+1:2]               ),
  .bram_dat_o     ( bram_rd_dat[(GV+1)*DW-1:GV*DW]  ),
  .bram_ack_o     ( bram_ack[GV]                    )
);

rp_axi_sm #(
  .DW  (  DW    )
) i_axi_sm (
   // global signals
  .axi_clk_i        ( axi_clk[GV]                       ),
  .axi_rstn_i       ( axi_rstn[GV]                      ),
  .axi_waddr_o      ( axi_waddr_o[(GV+1)*32-1:GV*32]    ),
  .axi_wdata_o      ( axi_wdata_o[(GV+1)*64-1:GV*64]    ),
  .axi_wsel_o       ( axi_wsel_o[(GV+1)*8-1:GV*8]       ),
  .axi_wvalid_o     ( axi_wvalid_o[GV]                  ),
  .axi_wlen_o       ( axi_wlen_o[(GV+1)*4-1:GV*4]       ),
  .axi_wfixed_o     ( axi_wfixed_o[GV]                  ),
  .axi_werr_i       ( axi_werr_i[GV]                    ),
  .axi_wrdy_i       ( axi_wrdy_i[GV]                    ),

   // Connection to AXI master
  .axi_dat_i        ( axi_ram_in                        ),
  .axi_dv_i         ( axi_dv_del                        ),
  .set_dly_i        ( set_axi_dly[(GV+1)*32 -1:GV*32 ]  ),
  .set_dec1_i       ( set_dec1[GV]                      ),
  .adc_rst_do_i     ( adc_rst_do[GV]                    ),
  .adc_we_keep_i    ( adc_we_keep[GV]                   ),
  .adc_arm_do_i     ( adc_arm_do[GV]                    ),
  .adc_trig_i       ( adc_trig[GV]                      ),
  .indep_mode_i     ( indep_mode[GV]                    ),

  .axi_en_pulse_i   ( axi_en_pulse[GV]                  ),
  .set_axi_en_i     ( set_axi_en[GV]                    ),
  .set_axi_start_i  ( set_axi_start[(GV+1)*32-1:GV*32]  ),
  .set_axi_stop_i   ( set_axi_stop[(GV+1)*32-1:GV*32]   ),
  .axi_wp_trig_o    ( axi_wp_trig[(GV+1)*32-1:GV*32]    ),
  .axi_wp_cur_o     ( axi_wp_cur[(GV+1)*32-1:GV*32]     ),

  .axi_trig_o       ( axi_trig[GV]                      ),
  .axi_state_o      ( axi_state[(GV+1)*8-1:GV*8]        )
);
end
endgenerate

genvar GM;
generate
for(GM = N_CH ; GM < 4 ; GM = GM + 1) begin // pad out remaining channels

assign adc_bram_in[(GM+1)*DW -1:GM*DW ] = {DW{1'b0}};
assign adc_dv_del[GM]                   =  1'b0;


assign adc_state[(GM+1)*8  -1:GM*8  ]   =  8'h0;
assign axi_state[(GM+1)*8  -1:GM*8  ]   =  8'h0;
assign trg_state[(GM+1)*8  -1:GM*8  ]   =  8'h0;

assign adc_wp_act[(GM+1)*RSZ-1:GM*RSZ]  = {RSZ{1'b0}};
assign adc_wp_cur[(GM+1)*RSZ-1:GM*RSZ]  = {RSZ{1'b0}};
assign adc_wp_trig[(GM+1)*RSZ-1:GM*RSZ] = {RSZ{1'b0}};
assign adc_we_cnt[(GM+1)*32 -1:GM*32 ]  = 32'h0;

assign axi_wp_cur[(GM+1)*32 -1:GM*32 ]  = 32'h0;
assign axi_wp_trig[(GM+1)*32 -1:GM*32 ] = 32'h0;

assign bram_rd_dat[(GM+1)*DW -1:GM*DW ] = {DW{1'b0}};
assign bram_ack[GM]                     =  1'b0;
assign adc_trig_p[GM]                   =  1'b0;
assign adc_trig_n[GM]                   =  1'b0;
assign axi_trig[GM]                     =  1'b0;

assign adc_we[GM]                       =  1'b0;

end
endgenerate

rp_ext_trig #(
  .DW  (  DW     )
) i_ext_trig (
   // global signals
  .adc_clk_i      ( adc_clk_i[0]    ),  // ADC clock
  .adc_rstn_i     ( adc_rstn_i[0]   ),  // ADC reset - active low

   // Connection to AXI master
  .trig_asg_i     ( trig_asg_i      ),
  .trig_ext_i     ( trig_ext_i      ),
  .set_deb_len_i  ( set_deb_len     ),


  .ext_trig_p_o   ( ext_trig_p      ),
  .ext_trig_n_o   ( ext_trig_n      ),
  .asg_trig_p_o   ( asg_trig_p      ),
  .asg_trig_n_o   ( asg_trig_n      )
);

rp_scope_cfg #(
  .CHN (  CHN    ),
  .DW  (  DW     )
) i_cfg (
   // global signals
  .adc_clk_i        ( adc_clk_i[0]    ),  // ADC clock
  .adc_rstn_i       ( adc_rstn_i[0]   ),  // ADC reset - active low

  // System bus
  .sys_addr         ( sys_addr        ),
  .sys_wdata        ( sys_wdata       ),
  .sys_wen          ( sys_wen         ),
  .sys_ren          ( sys_ren         ),
  .sys_rdata        ( sys_rdata       ),
  .sys_err          ( sys_err         ),
  .sys_ack          ( sys_ack         ),


  .adc_state_i      ( adc_state       ),
  .axi_state_i      ( axi_state       ),
  .trg_state_i      ( trg_state       ),

  .adc_state_ext_i  ( adc_state_i     ),
  .axi_state_ext_i  ( axi_state_i     ),
  .trg_state_ext_i  ( trg_state_i     ),

  .adc_wp_cur_i     ( adc_wp_cur      ),
  .adc_wp_trig_i    ( adc_wp_trig     ),
  .adc_we_cnt_i     ( adc_we_cnt      ),

  .axi_wp_cur_i     ( axi_wp_cur      ),
  .axi_wp_trig_i    ( axi_wp_trig     ),

  .bram_rd_dat_i    ( bram_rd_dat     ),
  .bram_ack_i       ( bram_ack        ),

  .adc_arm_do_o     ( adc_arm_do      ),
  .adc_rst_do_o     ( adc_rst_do      ),
  .adc_trig_sw_o    ( adc_trig_sw     ),
  .adc_we_keep_o    ( adc_we_keep     ),
  .trig_dis_clr_o   ( trig_dis_clr    ),
  .indep_mode_o     ( indep_mode      ),
  .axi_en_pulse_o   ( axi_en_pulse    ),
  .new_trg_src_o    ( new_trg_src     ),
  .trg_src_o        ( trg_src         ),
  .set_dec1_o       ( set_dec1        ),
  .filt_rstn_o      ( filt_rstn       ),
  .set_tresh_o      ( set_tresh       ),
  .set_dly_o        ( set_adc_dly     ),
  .set_dec_o        ( set_dec         ),
  .set_hyst_o       ( set_hyst        ),
  .set_avg_en_o     ( set_avg_en      ),
  .set_filt_aa_o    ( set_filt_aa     ),
  .set_filt_bb_o    ( set_filt_bb     ),
  .set_filt_kk_o    ( set_filt_kk     ),
  .set_filt_pp_o    ( set_filt_pp     ),
  .set_deb_len_o    ( set_deb_len     ),
  .set_axi_start_o  ( set_axi_start   ),
  .set_axi_stop_o   ( set_axi_stop    ),
  .set_axi_dly_o    ( set_axi_dly     ),
  .set_axi_en_o     ( set_axi_en      )
);

assign axi_clk    = adc_clk_i ;
assign axi_rstn   = adc_rstn_i;

assign axi_clk_o  = axi_clk ;
assign axi_rstn_o = axi_rstn;

assign trig_ch_o      = {adc_trig_n[1], adc_trig_p[1], adc_trig_n[0], adc_trig_p[0]};
assign daisy_trig_o   = adc_trig[0];

assign trig_ext_asg_o = {asg_trig_n, asg_trig_p, ext_trig_n, ext_trig_p};

endmodule
