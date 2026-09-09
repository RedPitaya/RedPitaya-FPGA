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
*
 *                /--------\      /--------\      /-----------\            /-----\
 *   ADC CHA ---> | CALIB1 | ---> | DFILT1 | ---> | AVG & DEC | ---------> | BUF | --->  SW
 *                \--------/      \--------/      \-----------/     |      \-----/
 *                                                                  ˇ         ^
 *                                                              /------\      |
 *   ext trigger ---------------------------------------------> | TRIG | -----+
 *                                                              \------/      |
 *                                                                  ^         ˇ
 *                /--------\      /--------\      /-----------\     |      /-----\
 *   ADC CHB ---> | CALIB1 | ---> | DFILT1 | ---> | AVG & DEC | ---------> | BUF | --->  SW
 *                \--------/      \--------/      \-----------/            \-----/ 
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
/* 
* May 2025 - Alen Luin
* added calibration at the input from adc
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
   output                    scope_irq_o    ,
   output     [N_CH   -1: 0] scope_irq_ch_o ,

   // System bus
   input      [     32-1: 0] sys_addr       ,  // bus saddress
   input      [     32-1: 0] sys_wdata      ,  // bus write data
   input                     sys_wen        ,  // bus write enable
   input                     sys_ren        ,  // bus read enable
   output     [     32-1: 0] sys_rdata      ,  // bus read data
   output                    sys_err        ,  // bus error indicator
   output                    sys_ack           // bus acknowledge signal
);

wire [    N_CH-1: 0] axi_clk           ;
wire [    N_CH-1: 0] axi_rstn          ;

wire [       4-1: 0] adc_arm_do        ;
wire [       4-1: 0] adc_arm_do_applied;
wire [       4-1: 0] adc_rst_do        ;
wire [       4-1: 0] adc_rst_do_applied;
wire [       4-1: 0] adc_trig_sw       ;
wire [       4-1: 0] adc_we_keep       ;
wire [       4-1: 0] trig_dis_clr      ;
wire [       4-1: 0] axi_en_pulse      ;
wire [       4-1: 0] new_trg_src       ;
wire [   4*5  -1: 0] trg_src           ;
wire [       4-1: 0] set_dec1          ;
wire [       4-1: 0] filt_rstn         ;
wire [   4*DW -1: 0] set_tresh         ;
wire [   4*32 -1: 0] set_adc_dly       ;
wire [   4*17 -1: 0] set_dec           ;
wire [   4*DW -1: 0] set_hyst          ;
wire [       4-1: 0] set_avg_en        ;
wire [       4-1: 0] set_hres_en         ;
wire [   4*18 -1: 0] set_filt_aa       ;
wire [   4*25 -1: 0] set_filt_bb       ;
wire [   4*25 -1: 0] set_filt_kk       ;
wire [   4*25 -1: 0] set_filt_pp       ;
wire [   4*DW -1: 0] set_calib_offset  ;
wire [   4*16 -1: 0] set_calib_gain    ;
wire [      4 -1: 0] set_filt_byp      ;
wire [      20-1: 0] set_deb_len       ;
wire [   4*32 -1: 0] set_axi_start     ;
wire [   4*32 -1: 0] set_axi_stop      ;
wire [   4*32 -1: 0] set_axi_dly       ;
wire [       4-1: 0] set_axi_en        ;
wire [       4-1: 0] indep_mode        ;
wire [       2-1: 0] irq_mask          ;
wire [       2-1: 0] irq_clr           ;
wire [       8-1: 0] split_irq_mask    ;
wire [       8-1: 0] split_irq_clr     ;

wire [   4*8  -1: 0] axi_state    ;
wire [   4*8  -1: 0] adc_state    ;
wire [   4*8  -1: 0] trg_state    ;
wire [       4-1: 0] adc_dly_do_ch;
wire [       2-1: 0] irq_evt      ;

wire [   4*RSZ-1: 0] adc_wp_cur   ;
wire [   4*RSZ-1: 0] adc_wp_trig  ;
wire [   4*32 -1: 0] adc_we_cnt   ;
wire [   4*32 -1: 0] axi_wp_cur   ;
wire [   4*32 -1: 0] axi_wp_trig  ;
wire [      64-1: 0] cfg_timestamp_init;
wire                 cfg_timestamp_init_we;
reg  [      64-1: 0] curr_timestamp;
reg  [   4*64 -1: 0] trig_timestamp;

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
wire [       4-1: 0] irq_evt_trig_ch;
wire [       4-1: 0] irq_evt_fill_ch;
wire [       8-1: 0] split_irq_evt;
wire [       8-1: 0] split_irq_auto_clr;

localparam [2:0] DEC_MODE_PASS = 3'd0;
localparam [2:0] DEC_MODE_SUM  = 3'd1;
localparam [2:0] DEC_MODE_SHR1 = 3'd2;
localparam [2:0] DEC_MODE_SHR2 = 3'd3;
localparam [2:0] DEC_MODE_SHR3 = 3'd4;
localparam [2:0] DEC_MODE_DIV  = 3'd5;

function [2:0] decode_dec_mode;
  input [16:0] dec;
  input        avg_en;
begin
  if (!avg_en)
    decode_dec_mode = DEC_MODE_PASS;
  else begin
    case (dec)
      17'd1:  decode_dec_mode = DEC_MODE_SUM;
      17'd2:  decode_dec_mode = DEC_MODE_SHR1;
      17'd4:  decode_dec_mode = DEC_MODE_SHR2;
      17'd8:  decode_dec_mode = DEC_MODE_SHR3;
      17'd16: decode_dec_mode = DEC_MODE_DIV;
      default:
        decode_dec_mode = (dec > 17'd16) ? DEC_MODE_DIV : DEC_MODE_PASS;
    endcase
  end
end
endfunction


wire [   4*RSZ-1: 0] adc_wp_act   ;
wire [    4*DW-1: 0] adc_bram_in  ;
wire [       4-1: 0] adc_we       ;
wire [       4-1: 0] adc_dv_del   ;
wire [       4-1: 0] adc_dv_del_p ;
reg  [       4-1: 0] adc_trig_d   ;
reg  [       4-1: 0] adc_dly_do_ch_d;
reg  [       2-1: 0] irq_sts      ;
reg  [       8-1: 0] split_irq_sts;

assign sys_en = sys_wen | sys_ren;

assign adc_state_o = adc_state[15:0];
assign axi_state_o = axi_state[15:0];
assign trg_state_o = trg_state[15:0];
assign irq_evt_trig_ch = adc_trig & ~adc_trig_d;
assign irq_evt_fill_ch = adc_dly_do_ch_d & ~adc_dly_do_ch;
assign irq_evt[0] = |(irq_evt_trig_ch & ~indep_mode);
assign irq_evt[1] = |(irq_evt_fill_ch & ~indep_mode);
assign split_irq_evt = {irq_evt_fill_ch & indep_mode, irq_evt_trig_ch & indep_mode};
assign split_irq_auto_clr = {(adc_rst_do_applied | adc_arm_do_applied),
                             (adc_rst_do_applied | adc_arm_do_applied)};

always @(posedge adc_clk_i[0]) begin
  if (adc_rstn_i[0] == 1'b0) begin
    adc_trig_d      <= 4'h0;
    adc_dly_do_ch_d <= 4'h0;
    irq_sts         <= 2'b0;
    split_irq_sts   <= 8'h0;
    curr_timestamp  <= 64'h0;
    trig_timestamp  <= {4{64'h0}};
  end else begin
    if (cfg_timestamp_init_we)
      curr_timestamp <= cfg_timestamp_init;
    else
      curr_timestamp <= curr_timestamp + 64'd1;

    if (irq_evt_trig_ch[0])
      trig_timestamp[63:0] <= curr_timestamp;
    if (irq_evt_trig_ch[1])
      trig_timestamp[127:64] <= curr_timestamp;
    if (irq_evt_trig_ch[2])
      trig_timestamp[191:128] <= curr_timestamp;
    if (irq_evt_trig_ch[3])
      trig_timestamp[255:192] <= curr_timestamp;

    adc_trig_d      <= adc_trig;
    adc_dly_do_ch_d <= adc_dly_do_ch;

    if (|adc_rst_do_applied || |adc_arm_do_applied)
      irq_sts <= 2'b0;
    else
      irq_sts <= (irq_sts & ~irq_clr) | irq_evt;

    split_irq_sts <= (split_irq_sts & ~split_irq_auto_clr & ~split_irq_clr) | split_irq_evt;
  end
end

genvar GV;
generate
for(GV = 0 ; GV < N_CH ; GV = GV + 1) begin
//wire [ DW-1: 0] adc_calib_in  ;
//wire [ 16-1: 0] adc_calib_in  ;
//wire [ 16-1: 0] adc_calib_out ;
wire [ DW-1: 0] adc_calib_in  ;
wire [ DW-1: 0] adc_calib_out ;
wire [ DW-1: 0] adc_filt_in  ;
wire [ DW-1: 0] adc_filtered ;

wire [ DW-1: 0] adc_dec_in   ;
wire [ DW-1: 0] adc_dly_in   ;
wire [ DW-1: 0] axi_ram_in   ;
wire            adc_dly_do   ;

wire            axi_dv_del;
wire            dec_val;

// Apply the selected decimator settings, ARM and RESET as one per-channel package.
// The compact mode removes the wide set_dec decode from the sample-data path.
reg  [16:0] dec_cfg_applied;
reg         dec1_cfg_applied;
reg         hres_cfg_applied;
reg         arm_applied;
reg         rst_applied;
reg  [ 2:0] dec_mode_applied;

always @(posedge adc_clk_i[GV])
if (adc_rstn_i[GV] == 1'b0) begin
  dec_cfg_applied  <= 17'd1;
  dec1_cfg_applied <= 1'b1;
  hres_cfg_applied <= 1'b0;
  arm_applied      <= 1'b0;
  rst_applied      <= 1'b0;
  dec_mode_applied <= DEC_MODE_PASS;
end else begin
  dec_cfg_applied  <= set_dec[(GV+1)*17-1:GV*17];
  dec1_cfg_applied <= set_dec1[GV];
  hres_cfg_applied <= set_hres_en[GV];
  arm_applied      <= adc_arm_do[GV];
  rst_applied      <= adc_rst_do[GV];
  dec_mode_applied <= decode_dec_mode(
                        set_dec[(GV+1)*17-1:GV*17],
                        set_avg_en[GV]);
end

assign adc_arm_do_applied[GV] = arm_applied;
assign adc_rst_do_applied[GV] = rst_applied;

//assign adc_calib_in  = adc_dat_i[(GV+1)*DW-1:GV*DW] ;
wire  adc_sign_a = adc_dat_i[(GV+1)*DW-1];
//assign adc_calib_in = {adc_dat_i[(GV+1)*DW-1:GV*DW], {(16-DW){adc_sign_a}}};
assign adc_calib_in  = adc_dat_i[(GV+1)*DW-1:GV*DW] ;

rp_scope_calib #(
    .DBITS(DW)
    )
    i_calib_ch(
  .adc_clk_i            ( adc_clk_i[GV] ),  // ADC clock
  .adc_rstn_i           ( adc_rstn_i[GV] ),  // ADC reset - active low

  .calib_dat_i          (adc_calib_in),
  .calib_din_tvalid_i   (1'b1),

  .calib_dat_o          (adc_calib_out),
  .calib_dout_tvalid_o  (),
  .cfg_calib_offset_i   ( set_calib_offset[(GV+1)*DW-1:GV*DW] ),
  .cfg_calib_gain_i     ( set_calib_gain[(GV+1)*16-1:GV*16] )   
);

//assign adc_filt_in = adc_calib_out[16-1:2];
assign adc_filt_in = adc_calib_out;

// The filtering block is not used; it was removed from the code because it does not work in the 16-bit extension mode (hires).
// red_pitaya_dfilt1 #(
//   .DW      (  DW )
//   ) i_dfilt1_ch (
//    // ADC
//   .adc_clk_i   ( adc_clk_i[GV] ),  // ADC clock
//   .adc_rstn_i  ( filt_rstn[GV] ),  // ADC reset - active low
//   // changes fixed only to 12 bit
//   .adc_dat_i   ( {adc_filt_in, 2'b00}   ),  // ADC raw data
//   .adc_dat_o   ( adc_filtered ),  // filtered data
//    // configuration
//   .cfg_aa_i    ( set_filt_aa[(GV+1)*18-1:GV*18] ),  // config AA coefficient
//   .cfg_bb_i    ( set_filt_bb[(GV+1)*25-1:GV*25] ),  // config BB coefficient
//   .cfg_kk_i    ( set_filt_kk[(GV+1)*25-1:GV*25] ),  // config KK coefficient
//   .cfg_pp_i    ( set_filt_pp[(GV+1)*25-1:GV*25] )   // config PP coefficient
// );

assign adc_filtered = adc_filt_in;
assign adc_dec_in = set_filt_byp[GV] ? adc_filt_in : adc_filtered;

rp_decim #(
  .DW      (  DW          )
) i_dec (
   // global signals
  .adc_clk_i    ( adc_clk_i[GV]  ),  // ADC clock
  .adc_rstn_i   ( adc_rstn_i[GV] ),  // ADC reset - active low

   // Connection to AXI master
  .dec_dat_i    ( adc_dec_in                 ),  // data in
  .set_dec_i    ( dec_cfg_applied  ),  // decimation
  .set_hres_en_i( hres_cfg_applied ),  // high-resolution precision enable
  .dec_mode_i   ( dec_mode_applied ),
  .adc_arm_do_i ( arm_applied      ),

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
  .set_trg_src_i ( trg_src[(GV+1)*5-1:GV*5]       ),
  .set_trg_new_i ( new_trg_src[GV]                ),

  .axidly_val_o  ( axi_dv_del                     ),
  .axidly_dat_o  ( axi_ram_in                     ), // delayed data to AXI

  .dly_valp_o    ( adc_dv_del_p[GV]               ),
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
  .adc_rst_do_i   ( rst_applied       ),
  .adc_dly_do_i   ( adc_dly_do       ),
  .trig_dis_clr_i ( trig_dis_clr[GV] ),

  .set_trg_src_i  ( trg_src[(GV+1)*5-1:GV*5] ),
  .set_trg_new_i  ( new_trg_src[GV]          ),
  .dly_valp_i     ( adc_dv_del_p[GV]         ),

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
  .set_dec1_i     ( dec1_cfg_applied                   ),
  .adc_rst_do_i   ( rst_applied                       ),
  .adc_we_keep_i  ( adc_we_keep[GV]                   ),
  .adc_arm_do_i   ( arm_applied                       ),
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

assign adc_dly_do_ch[GV] = adc_dly_do;

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
  .set_dec1_i       ( dec1_cfg_applied                   ),
  .adc_rst_do_i     ( rst_applied                       ),
  .adc_we_keep_i    ( adc_we_keep[GV]                   ),
  .adc_arm_do_i     ( arm_applied                       ),
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

assign adc_arm_do_applied[GM]              = 1'b0;
assign adc_rst_do_applied[GM]              = 1'b0;
assign adc_bram_in[(GM+1)*DW -1:GM*DW ] = {DW{1'b0}};
assign adc_dv_del[GM]                   =  1'b0;
assign adc_dv_del_p[GM]                 =  1'b0;


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
assign adc_dly_do_ch[GM]                =  1'b0;

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
  .adc_clk_i          ( adc_clk_i[0]    ),  // ADC clock
  .adc_rstn_i         ( adc_rstn_i[0]   ),  // ADC reset - active low

  // System bus
  .sys_addr           ( sys_addr        ),
  .sys_wdata          ( sys_wdata       ),
  .sys_wen            ( sys_wen         ),
  .sys_ren            ( sys_ren         ),
  .sys_rdata          ( sys_rdata       ),
  .sys_err            ( sys_err         ),
  .sys_ack            ( sys_ack         ),


  .adc_state_i        ( adc_state       ),
  .axi_state_i        ( axi_state       ),
  .trg_state_i        ( trg_state       ),
	  .irq_sts_i          ( irq_sts         ),
	  .split_irq_sts_i    ( split_irq_sts   ),

  .adc_state_ext_i    ( adc_state_i     ),
  .axi_state_ext_i    ( axi_state_i     ),
  .trg_state_ext_i    ( trg_state_i     ),

  .adc_wp_cur_i       ( adc_wp_cur      ),
  .adc_wp_trig_i      ( adc_wp_trig     ),
  .adc_we_cnt_i       ( adc_we_cnt      ),

  .axi_wp_cur_i       ( axi_wp_cur      ),
  .axi_wp_trig_i      ( axi_wp_trig     ),
  .curr_timestamp_i   ( curr_timestamp  ),
  .trig_timestamp_i   ( trig_timestamp  ),

  .bram_rd_dat_i      ( bram_rd_dat     ),
  .bram_ack_i         ( bram_ack        ),

  .adc_arm_do_o       ( adc_arm_do      ),
  .adc_rst_do_o       ( adc_rst_do      ),
  .adc_trig_sw_o      ( adc_trig_sw     ),
  .adc_we_keep_o      ( adc_we_keep     ),
  .trig_dis_clr_o     ( trig_dis_clr    ),
  .indep_mode_o       ( indep_mode      ),
  .axi_en_pulse_o     ( axi_en_pulse    ),
  .new_trg_src_o      ( new_trg_src     ),
  .trg_src_o          ( trg_src         ),
  .set_dec1_o         ( set_dec1        ),
  .filt_rstn_o        ( filt_rstn       ),
  .set_tresh_o        ( set_tresh       ),
  .set_dly_o          ( set_adc_dly     ),
  .set_dec_o          ( set_dec         ),
  .set_hyst_o         ( set_hyst        ),
  .set_avg_en_o       ( set_avg_en      ),
  .set_hres_en_o        ( set_hres_en       ),
  .set_filt_aa_o      ( set_filt_aa     ),
  .set_filt_bb_o      ( set_filt_bb     ),
  .set_filt_kk_o      ( set_filt_kk     ),
  .set_filt_pp_o      ( set_filt_pp     ),

  .set_calib_offset_o ( set_calib_offset),
  .set_calib_gain_o   ( set_calib_gain  ),

  .set_filt_byp_o     ( set_filt_byp    ),
  .set_deb_len_o      ( set_deb_len     ),
  .set_axi_start_o    ( set_axi_start   ),
  .set_axi_stop_o     ( set_axi_stop    ),
  .set_axi_dly_o      ( set_axi_dly     ),
  .set_axi_en_o       ( set_axi_en      ),
  .cfg_timestamp_init_o   ( cfg_timestamp_init    ),
  .cfg_timestamp_init_we_o( cfg_timestamp_init_we ),
  .irq_mask_o         ( irq_mask        ),
  .irq_clr_o          ( irq_clr         ),
  .split_irq_mask_o   ( split_irq_mask  ),
  .split_irq_clr_o    ( split_irq_clr   )
);

assign axi_clk    = adc_clk_i ;
assign axi_rstn   = adc_rstn_i;

assign axi_clk_o  = axi_clk ;
assign axi_rstn_o = axi_rstn;

assign trig_ch_o      = {adc_trig_n[1], adc_trig_p[1], adc_trig_n[0], adc_trig_p[0]};
assign daisy_trig_o   = adc_trig[0];
assign scope_irq_o    = |(irq_sts & irq_mask);

assign trig_ext_asg_o = {asg_trig_n, asg_trig_p, ext_trig_n, ext_trig_p};

generate
for (genvar GI = 0; GI < N_CH; GI = GI + 1) begin : gen_scope_irq_ch
  assign scope_irq_ch_o[GI] = indep_mode[GI] &
                              ((split_irq_sts[GI] & split_irq_mask[GI]) |
                               (split_irq_sts[GI+4] & split_irq_mask[GI+4]));
end
endgenerate

endmodule
