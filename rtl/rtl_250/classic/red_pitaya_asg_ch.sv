/**
 * $Id: red_pitaya_asg_ch.v 1271 2014-02-25 12:32:34Z matej.oblak $
 *
 * @brief Red Pitaya ASG submodule. Holds table and FSM for one channel.
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
 * Arbitrary signal generator takes data stored in buffer and sends them to DAC.
 *
 *
 *                /-----\         /--------\
 *   SW --------> | BUF | ------> | kx + o | ---> DAC DAT
 *          |     \-----/         \--------/
 *          |        ^
 *          |        |
 *          |     /-----\
 *          ----> |     |
 *                | FSM | ------> trigger notification
 *   trigger ---> |     |
 *                \-----/
 *
 *
 * Submodule for ASG which hold buffer data and control registers for one channel.
 * 
 */

module red_pitaya_asg_ch #(
   parameter RSZ = 14
)(
   // DAC
   output reg [ 14-1: 0] dac_o           ,  //!< dac data output
   input                 dac_clk_i       ,  //!< dac clock
   input                 dac_rstn_i      ,  //!< dac reset - active low
   // trigger
   input                 trig_sw_i       ,  //!< software trigger
   input                 trig_ext_i      ,  //!< external trigger
   input      [  3-1: 0] trig_src_i      ,  //!< trigger source selector
   output                trig_done_o     ,  //!< trigger event
   // buffer ctrl
   input                 sys_clk_i       ,  //!< system clock for buffer access
   input                 sys_rstn_i      ,  //!< system reset for configuration CDC
   input                 buf_we_i        ,  //!< buffer write enable
   input      [ 14-1: 0] buf_addr_i      ,  //!< buffer address
   input      [ 14-1: 0] buf_wdata_i     ,  //!< buffer write data
   output reg [ 14-1: 0] buf_rdata_o     ,  //!< buffer read data
   output reg [RSZ-1: 0] buf_rpnt_o      ,  //!< buffer current read pointer

   axi_sys_if.s          axi_sys         ,
   // configuration
   input     [RSZ+15: 0] set_size_i      ,  //!< set table data size
   input     [  32-1: 0] set_step_i      ,  //!< set pointer step
   input     [  32-1: 0] set_step_lo_i   ,  //!< set pointer step, low frequency
   output    [  32-1: 0] get_step_o      ,  //!< applied pointer step
   output    [  32-1: 0] get_step_lo_o   ,  //!< applied pointer step, low frequency
   input     [  32-1: 0] set_ofs_i       ,  //!< set reset offset
   input                 set_rst_i       ,  //!< set FSM to reset
   input                 set_rdly_mode_i ,  //!< sets the behavior of a constant signal before and after burst
   input                 set_wrap_i      ,  //!< set wrap enable
   input     [  14-1: 0] set_amp_i       ,  //!< set amplitude scale
   input     [  14-1: 0] set_dc_i        ,  //!< set output offset
   input     [  14-1: 0] set_first_i     ,  //!< set initial value before start
   input     [  14-1: 0] set_last_i      ,  //!< set final value in burst
   input     [  32-1: 0] set_last_len_i  ,  //!< set length of final value in burst in ADC counts -- not used
   input                 set_zero_i      ,  //!< set output to zero
   input     [  16-1: 0] set_ncyc_i      ,  //!< set number of cycle
   input     [  16-1: 0] set_rnum_i      ,  //!< set number of repetitions
   input     [  32-1: 0] set_rdly_i      ,  //!< set period between burst starts in DAC clock cycles
   input     [  20-1: 0] set_deb_len_i   ,  //!< set trigger debouncer
   input     [  32-1: 0] set_seed_i      ,  //!< initial value for LFSR
   input                 rand_en_i       ,  //!< enable random output
   input                 rand_init_i     ,  //!< initialize LFSR
   input                 set_rgate_i     ,  //!< set external gated repetition
   input                 set_axi_en_i    ,  //!< enable AXI buffer read
   input     [  32-1: 0] set_axi_start_i ,  //!< AXI start address
   input     [  32-1: 0] set_axi_stop_i  ,  //!< AXI stop address
   input     [  32-1: 0] set_axi_dec_i   ,  //!< AXI decimation
   output    [  20-1: 0] axi_state_o     ,  //!< AXI state
   output    [  32-1: 0] err_cnt_o       ,  //!< number of missed samples (unused)
   output    [  32-1: 0] transf_cnt_o       //!< number of successful AXI transfers (unused)
);

//---------------------------------------------------------------------------------
//
//  DAC buffer RAM

wire [14-1:0] lfsr_noise;
  rand_lfsr #(
    .DW ( 14 ) // output data width
  )
  i_rand
  (
    .clk_i   (  dac_clk_i  ), // clock
    .rstn_i  (  dac_rstn_i ), // reset
    .init_i  (  rand_init_i), // enable
    .seed_i  (  set_seed_i ), // init value
    .dat_o   (  lfsr_noise )  // data output noise
  );

localparam PNT_SIZE = RSZ+16+32;
typedef enum logic [1:0] {
    RDLY_MODE_CONST  = 2'b00,
    RDLY_MODE_COPY  = 2'b01
} rdly_mode_t;

reg   [  14-1: 0] dac_buf [0:(1<<RSZ)-1] ;
reg   [  14-1: 0] dac_rd    ;
wire  [  14-1: 0] dac_axi_rd;
reg   [  14-1: 0] dac_rdat  ;
reg                    dac_scale_bypass;

reg   [ RSZ-1: 0] dac_rp    ;
reg   [PNT_SIZE-1: 0] dac_pnt   ; // read pointer
reg   [PNT_SIZE-1: 0] dac_pnt_next; // second pointer in the active look-ahead pair
reg                    pnt_pair_phase;
reg                    pnt_pair_wrap;
reg   [          1: 0] pnt_pair_warm;
wire  [PNT_SIZE-1: 0] axi_pnt   ; // read pointer AXI
wire  [PNT_SIZE  : 0] dac_npnt  ; // next read pointer
wire  [PNT_SIZE  : 0] dac_npnt_sub ;
wire                  dac_npnt_sub_neg;
wire                  axi_dac_do;
reg  [   5-1: 0] axi_dac_do_sr ;
wire                  axi_last;
wire                  axi_last_pre;
wire                  axi_first;
reg              dac_do       ;
reg  [   5-1: 0] dac_do_sr    ;
reg              init_run     ;
wire             do_read      ;
wire             do_read_end  ;

assign axi_dac_do = axi_state_o[1];

reg   [  16-1: 0] cyc_cnt   ;
reg signed  [  28-1: 0] dac_mult  ;
reg signed  [  15-1: 0] dac_sum   ;

rdly_mode_t        rdly_mode;
reg   [  14-1: 0] set_last;
reg               set_last_from_buf;
reg   [   5-1: 0] lastval_sr;
reg   [   5-1: 0] zero_sr;

wire              not_burst;
wire  [   5-1: 0] out_sel;

assign not_burst = (&(~set_ncyc_i)) && (&(~set_rnum_i));

assign out_sel[0] = |dac_do_sr[4:1];
assign out_sel[1] = |axi_dac_do_sr[4:1];
assign out_sel[2] = (!init_run) && (|lastval_sr[1:0]) && (!do_read_end);
assign out_sel[3] = rand_en_i;
assign out_sel[4] = set_zero_i || |zero_sr;

// read
always @(posedge dac_clk_i)
begin
  buf_rpnt_o <= dac_pnt[PNT_SIZE-1:16+32];
  dac_rp     <= dac_pnt[PNT_SIZE-1:16+32];
  dac_rd     <= dac_buf[dac_rp] ;
  casez (out_sel)
    5'b00001: begin dac_rdat <= dac_rd;      dac_scale_bypass <= 1'b0;              end
    5'b0001?: begin dac_rdat <= dac_axi_rd;  dac_scale_bypass <= 1'b0;              end
    5'b001??: begin dac_rdat <= set_last;    dac_scale_bypass <= !set_last_from_buf; end
    5'b01???: begin dac_rdat <= lfsr_noise;  dac_scale_bypass <= 1'b0;              end
    5'b1????: begin dac_rdat <= 14'h0;       dac_scale_bypass <= 1'b0;              end
    default : begin dac_rdat <= set_first_i; dac_scale_bypass <= 1'b1;              end
  endcase
end

always @(posedge dac_clk_i) // shift regs are needed because of processing path delay
begin
   if (!dac_rstn_i || set_rst_i) begin
      dac_do_sr     <= 5'b0;
      axi_dac_do_sr <= 5'b0;
      lastval_sr    <= 5'b0;
      zero_sr       <= 5'b0;
   end else begin
      dac_do_sr     <= {dac_do_sr[3:0] , dac_do     };
      axi_dac_do_sr <= {axi_dac_do_sr[3:0], axi_dac_do };
      lastval_sr    <= {lastval_sr[3:0], ~do_read    };
      zero_sr       <= {zero_sr[3:0]   , set_zero_i };
   end
end

// write
always @(posedge sys_clk_i)
if (buf_we_i)  dac_buf[buf_addr_i] <= buf_wdata_i[14-1:0] ;

// read-back
always @(posedge sys_clk_i)
buf_rdata_o <= dac_buf[buf_addr_i] ;

// scale and offset
always @(posedge dac_clk_i)
begin
   dac_mult <= dac_scale_bypass ? ($signed({{14{dac_rdat[13]}}, dac_rdat}) <<< 13) :
                                  ($signed(dac_rdat) * $signed({1'b0,set_amp_i})) ;
   dac_sum  <= $signed(dac_mult[28-1:13]) + $signed({set_dc_i[13], set_dc_i}) ;
   dac_o    <= ^dac_sum[15-1:15-2] ? {dac_sum[15-1], {13{~dac_sum[15-1]}}} : dac_sum[13:0];
end

//---------------------------------------------------------------------------------
//
//  read pointer & state machine

reg              trig_in      ;
wire             ext_trig_p   ;
wire             ext_trig_n   ;

reg  [  16-1: 0] rep_cnt      ;
reg  [  16-1: 0] dly_cnt_lo   ;
reg  [  16-1: 0] dly_cnt_hi   ;
wire [  32-1: 0] dly_cnt = {dly_cnt_hi,dly_cnt_lo};
// Precompute the configuration-only decrement so it is not placed behind the
// late wrap/trigger decision in the delay counter load path.
reg  [  32-1: 0] set_rdly_m1  ;
// Set after the first real output sample so AXI preload time is not counted
// as part of the requested start-to-start burst period.
reg              dly_started  ;

reg  [  32-1: 0] set_step         ;
reg  [  32-1: 0] set_step_lo      ;
reg  [RSZ+16-1:0] set_size        ;
reg  [PNT_SIZE-1:0] set_offset    ;
reg                  set_wrap     ;
wire [  32-1: 0] set_step_cfg     ;
wire [  32-1: 0] set_step_lo_cfg  ;

reg              dac_rep      ;
wire             dac_trig     ;
reg              dac_trigr    ;
reg              buf_cycle_q  ;

wire             buf_cycle    ;
wire             dly_start    ;
wire             pnt_wrap     ;
wire             cycle_end_0  ;
wire             cycle_end_1  ;
wire             dac_trig_0   ;
wire             dac_trig_1   ;
wire             dly_start_0  ;
wire             dly_start_1  ;
(* keep = "true" *) wire [15:0] dly_cnt_lo_nxt_0;
(* keep = "true" *) wire [15:0] dly_cnt_lo_nxt_1;
(* keep = "true" *) wire [15:0] dly_cnt_hi_nxt_0;
(* keep = "true" *) wire [15:0] dly_cnt_hi_nxt_1;
(* keep = "true" *) wire        dly_started_nxt_0;
(* keep = "true" *) wire        dly_started_nxt_1;
(* keep = "true" *) wire [15:0] rep_cnt_nxt_0;
(* keep = "true" *) wire [15:0] rep_cnt_nxt_1;
(* keep = "true" *) wire [15:0] cyc_cnt_nxt_0;
(* keep = "true" *) wire [15:0] cyc_cnt_nxt_1;
(* keep = "true" *) wire        dac_do_nxt_0;
(* keep = "true" *) wire        dac_do_nxt_1;
(* keep = "true" *) wire        dac_rep_nxt_0;
(* keep = "true" *) wire        dac_rep_nxt_1;

assign do_read       = set_axi_en_i ? axi_dac_do  : dac_do;

assign do_read_end   = set_axi_en_i ? (set_axi_dec_i == 1 ? axi_last && cyc_cnt == 1 : axi_dac_do_sr[0] && !axi_dac_do) : 
                                    dac_do_sr[1:0] == 2'b10;
// Non-AXI cycle completion is consumed one clock after the pointer wraps. The
// old implementation reconstructed that delayed event by comparing the full
// previous and current 62-bit pointers. Capture the wrap decision directly;
// this preserves the cycle-counter timing while removing a second wide
// pointer feedback cone from its clock enable.
assign buf_cycle     = set_axi_en_i ? axi_last : buf_cycle_q;
// AXI starts producing samples only after FIFO preload; non-AXI starts on dac_trig.
assign dly_start     = set_axi_en_i ? axi_first   : dac_trig;

sync #(.DW(32)) i_set_step_sync (
  .sclk_i  ( sys_clk_i    ),
  .srstn_i ( sys_rstn_i   ),
  .dclk_i  ( dac_clk_i    ),
  .drstn_i ( dac_rstn_i   ),
  .src_i   ( set_step_i   ),
  .dst_o   ( set_step_cfg )
);

sync #(.DW(32)) i_set_step_lo_sync (
  .sclk_i  ( sys_clk_i       ),
  .srstn_i ( sys_rstn_i      ),
  .dclk_i  ( dac_clk_i       ),
  .drstn_i ( dac_rstn_i      ),
  .src_i   ( set_step_lo_i   ),
  .dst_o   ( set_step_lo_cfg )
);

always_ff @(posedge dac_clk_i) begin
   if (dac_rstn_i == 1'b0) begin
      rdly_mode <= RDLY_MODE_COPY;
   end

   if (set_rst_i) begin
      rdly_mode <= rdly_mode_t'(set_rdly_mode_i);
   end
end

reg [2-1:0] init_delay;

always_ff @(posedge dac_clk_i) begin
   if (!dac_rstn_i) begin
      init_run   <= 1'b1;
      set_last   <= 1'b0;
      set_last_from_buf <= 1'b0;
      init_delay <= 1'b0;
   end else begin
      if (set_rst_i) begin
          init_run   <= 1'b1;
          set_last_from_buf <= 1'b0;
          init_delay <= 1'b0;
      end else if (trig_in || init_delay != 1'b0) begin
          init_delay <= init_delay + 2'b1;
          set_last   <= set_last_i;
          set_last_from_buf <= 1'b0;
      end else if (rdly_mode == RDLY_MODE_COPY) begin
          if (lastval_sr == 1'b1) begin
             set_last <= dac_rd;
             set_last_from_buf <= 1'b1;
          end
      end

      if (init_delay == 2'b11) begin
         init_run   <= 1'b0;
         init_delay <= 1'b0;
      end 
   end
end

// state machine
always @(posedge dac_clk_i) begin
   if (dac_rstn_i == 1'b0) begin
      cyc_cnt      <= 16'h0 ;
      rep_cnt      <= 16'h0 ;
      dly_cnt_lo   <= 16'h0 ;
      dly_cnt_hi   <= 16'h0 ;
      dly_started  <=  1'b0 ;
      dac_do       <=  1'b0 ;
      dac_rep      <=  1'b0 ;
      trig_in      <=  1'b0 ;
      dac_trigr    <=  1'b0 ;
      buf_cycle_q  <=  1'b0 ;
      set_step     <= 32'h0 ; 
      set_step_lo  <= 32'h0 ;
      set_size        <= {(RSZ+16){1'b0}};
      set_offset      <= {PNT_SIZE{1'b0}};
      set_wrap        <= 1'b0;
      pnt_pair_warm   <= 2'b00;
   end
   else begin
      // A non-AXI start is delayed by two clocks.  This both flushes an old
      // look-ahead pair and gives the newly captured configuration an honest
      // 8 ns path to the seed pair.
      if (set_rst_i)
         pnt_pair_warm <= 2'b00;
      else if (trig_in && !do_read && !dac_rep && !set_axi_en_i)
         pnt_pair_warm <= 2'b01;
      else
         pnt_pair_warm <= {pnt_pair_warm[0],1'b0};

      // Compute both state variants before the late wrap decision and use the
      // wrap bit only for the final selection.
      if (set_rst_i) begin
         dly_cnt_lo <= 16'h0;
         dly_cnt_hi <= 16'h0;
         dly_started <= 1'b0;
      end else begin
         dly_cnt_lo  <= pnt_wrap ? dly_cnt_lo_nxt_1  : dly_cnt_lo_nxt_0;
         dly_cnt_hi  <= pnt_wrap ? dly_cnt_hi_nxt_1  : dly_cnt_hi_nxt_0;
         dly_started <= pnt_wrap ? dly_started_nxt_1 : dly_started_nxt_0;
      end

      rep_cnt <= pnt_wrap ? rep_cnt_nxt_1 : rep_cnt_nxt_0;

      dac_trigr <= dac_trig; // ignore trigger when count
      buf_cycle_q <= dac_do && ~dac_npnt_sub_neg;
      cyc_cnt <= pnt_wrap ? cyc_cnt_nxt_1 : cyc_cnt_nxt_0;

      // trigger arrived
      case (trig_src_i & {3{!set_rst_i}})
          3'd1 : trig_in <= trig_sw_i   ; // sw
          3'd2 : trig_in <= ext_trig_p  ; // external positive edge
          3'd3 : trig_in <= ext_trig_n  ; // external negative edge
       default : trig_in <= 1'b0        ;
      endcase

      if (trig_in && !do_read && !dac_rep) begin
        set_step    <= set_step_cfg;
        set_step_lo <= set_step_lo_cfg;
        set_size        <= set_size_i;
        set_offset      <= {set_ofs_i[RSZ+15:0],32'b0};
        set_wrap        <= set_wrap_i;
      end

      dac_do  <= pnt_wrap ? dac_do_nxt_1  : dac_do_nxt_0;
      dac_rep <= pnt_wrap ? dac_rep_nxt_1 : dac_rep_nxt_0;
   end
end

always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) set_rdly_m1 <= 32'h0;
else                    set_rdly_m1 <= (set_rdly_i > 32'h0) ? (set_rdly_i - 32'h1) : 32'h0;

wire rep_arm   = dac_rep && |rep_cnt && dly_started && (dly_cnt == 32'h0);
wire rep_idle  = (cyc_cnt == 16'h0) && ~dac_do && !buf_cycle;
wire cycle_end = set_axi_en_i ? axi_last : (~dac_npnt_sub_neg);
wire rep_end   = (cyc_cnt == 16'h1) && cycle_end;
wire cycle_end_pre = set_axi_en_i ? axi_last_pre : (~dac_npnt_sub_neg);
wire rep_end_pre   = (cyc_cnt == 16'h1) && cycle_end_pre;
wire pnt_pair_start = pnt_pair_warm[1];
wire trig_now     = (!dac_rep && (set_axi_en_i ? trig_in : pnt_pair_start))
                    || (rep_arm && rep_idle);
wire trig_on_wrap = rep_arm && (cyc_cnt == 16'h1);
wire dac_trig_axi = trig_now || (trig_on_wrap && cycle_end_pre);

assign dac_trig = trig_now || (trig_on_wrap && cycle_end);

////////////////////////////////////////////////////////////////////////////////
// State machine, carry select on the wrap decision.
////////////////////////////////////////////////////////////////////////////////

assign pnt_wrap    = ~dac_npnt_sub_neg;
assign cycle_end_0 = set_axi_en_i ? axi_last : 1'b0;
assign cycle_end_1 = set_axi_en_i ? axi_last : 1'b1;
assign dac_trig_0  = trig_now || (trig_on_wrap && cycle_end_0);
assign dac_trig_1  = trig_now || (trig_on_wrap && cycle_end_1);
assign dly_start_0 = set_axi_en_i ? axi_first : dac_trig_0;
assign dly_start_1 = set_axi_en_i ? axi_first : dac_trig_1;

wire        dly_dec     = dac_rep && dly_started && |dly_cnt;
wire [15:0] dly_hold_lo = dly_dec ? dly_cnt_lo - 16'h1 : dly_cnt_lo;
wire [15:0] dly_hold_hi = (dly_dec && ~|dly_cnt_lo)
                        ? dly_cnt_hi - 16'h1 : dly_cnt_hi;
wire        rep_ld    = trig_in && !do_read;
wire        rep_dec   = !set_rgate_i && |rep_cnt && dac_rep && !dac_trigr
                        && (set_rnum_i != 16'hffff);
wire        rep_clr   = set_rgate_i && ((!trig_ext_i && trig_src_i==3'd2)
                                     || ( trig_ext_i && trig_src_i==3'd3));
wire        cyc_dec   = !dac_trigr && |cyc_cnt && buf_cycle;
wire        do_clr    = set_rst_i;
wire        rep_end_c = set_rst_i || (rep_cnt==16'h0);

assign dly_cnt_lo_nxt_0 = dly_start_0 ? set_rdly_m1[15:0]  : dly_hold_lo;
assign dly_cnt_lo_nxt_1 = dly_start_1 ? set_rdly_m1[15:0]  : dly_hold_lo;
assign dly_cnt_hi_nxt_0 = dly_start_0 ? set_rdly_m1[31:16] : dly_hold_hi;
assign dly_cnt_hi_nxt_1 = dly_start_1 ? set_rdly_m1[31:16] : dly_hold_hi;
assign dly_started_nxt_0 = dly_start_0 ? 1'b1 : (dac_trig_0 ? 1'b0 : dly_started);
assign dly_started_nxt_1 = dly_start_1 ? 1'b1 : (dac_trig_1 ? 1'b0 : dly_started);

assign rep_cnt_nxt_0 = rep_ld                 ? set_rnum_i      :
                       (rep_dec && dac_trig_0) ? rep_cnt - 16'h1 :
                       rep_clr                ? 16'h0           : rep_cnt;
assign rep_cnt_nxt_1 = rep_ld                 ? set_rnum_i      :
                       (rep_dec && dac_trig_1) ? rep_cnt - 16'h1 :
                       rep_clr                ? 16'h0           : rep_cnt;

assign cyc_cnt_nxt_0 = dac_trig_0 ? set_ncyc_i : (cyc_dec ? cyc_cnt - 16'h1 : cyc_cnt);
assign cyc_cnt_nxt_1 = dac_trig_1 ? set_ncyc_i : (cyc_dec ? cyc_cnt - 16'h1 : cyc_cnt);

assign dac_do_nxt_0 = (dac_trig_0 && !set_rst_i && !set_axi_en_i) ? 1'b1 :
                      do_clr                                      ? 1'b0 : dac_do;
assign dac_do_nxt_1 = (dac_trig_1 && !set_rst_i && !set_axi_en_i) ? 1'b1 :
                      (do_clr || (cyc_cnt==16'h1))                ? 1'b0 : dac_do;

assign dac_rep_nxt_0 = (dac_trig_0 && !set_rst_i) ? 1'b1 :
                       rep_end_c                  ? 1'b0 : dac_rep;
assign dac_rep_nxt_1 = (dac_trig_1 && !set_rst_i) ? 1'b1 :
                       rep_end_c                  ? 1'b0 : dac_rep;

////////////////////////////////////////////////////////////////////////////////
// Two-sample pointer look-ahead.  dac_pnt and dac_pnt_next hold consecutive
// samples.  The second register is stable for two DAC clocks, so two further
// applications of F() have a real 8 ns budget.  One pointer is still consumed
// on every 250 MHz clock.
////////////////////////////////////////////////////////////////////////////////

wire [PNT_SIZE-1:0] pnt_step = {set_step[RSZ+15:0],set_step_lo};
wire [PNT_SIZE-1:0] pnt_reset_offset = {set_ofs_i[RSZ+15:0],32'b0};
wire [PNT_SIZE-1:0] pnt_pair_base = |pnt_pair_warm ? set_offset : dac_pnt_next;

// First transition.
(* keep = "true" *) wire [PNT_SIZE:0] pair_sum_1 =
   {1'b0,pnt_pair_base} + {1'b0,pnt_step};
(* keep = "true" *) wire [PNT_SIZE:0] pair_sub_1 =
   pair_sum_1 - {1'b0,set_size,32'b0} - 1'b1;
wire pair_wrap_1 = ~pair_sub_1[PNT_SIZE];
wire [PNT_SIZE-1:0] pair_pnt_1 = pair_wrap_1
   ? (set_wrap ? pair_sub_1[PNT_SIZE-1:0] : set_offset)
   : pair_sum_1[PNT_SIZE-1:0];

// Second transition candidates, derived directly from the original base.
// pair_sum_2 is B+2*S.  The no-first-wrap candidate subtracts 2^PNT_SIZE
// when the first raw sum overflowed the stored pointer width.
(* keep = "true" *) wire [PNT_SIZE+1:0] pair_sum_2 =
   {2'b0,pnt_pair_base} + ({2'b0,pnt_step} << 1);
wire [PNT_SIZE+1:0] pair_modulus = {1'b0,1'b0,set_size,32'b0} + 1'b1;
wire [PNT_SIZE+1:0] pair_pointer_span =
   {{(PNT_SIZE+1){1'b0}},1'b1} << PNT_SIZE;

(* keep = "true" *) wire [PNT_SIZE:0] pair_sum_2_nowrap =
   pair_sum_2 - (pair_sum_1[PNT_SIZE] ? pair_pointer_span : {PNT_SIZE+2{1'b0}});
(* keep = "true" *) wire [PNT_SIZE:0] pair_sub_2_nowrap =
   (pair_sum_2 - (pair_sum_1[PNT_SIZE] ? pair_pointer_span : {PNT_SIZE+2{1'b0}})
    - pair_modulus);
wire pair_wrap_2_nowrap = ~pair_sub_2_nowrap[PNT_SIZE];
wire [PNT_SIZE-1:0] pair_pnt_2_nowrap = pair_wrap_2_nowrap
   ? (set_wrap ? pair_sub_2_nowrap[PNT_SIZE-1:0] : set_offset)
   : pair_sum_2_nowrap[PNT_SIZE-1:0];

(* keep = "true" *) wire [PNT_SIZE:0] pair_sum_2_wrapped =
   pair_sum_2 - pair_modulus;
(* keep = "true" *) wire [PNT_SIZE:0] pair_sub_2_wrapped =
   pair_sum_2 - (pair_modulus << 1);
wire pair_wrap_2_wrapped = ~pair_sub_2_wrapped[PNT_SIZE];
wire [PNT_SIZE-1:0] pair_pnt_2_wrapped = pair_wrap_2_wrapped
   ? pair_sub_2_wrapped[PNT_SIZE-1:0] : pair_sum_2_wrapped[PNT_SIZE-1:0];

(* keep = "true" *) wire [PNT_SIZE:0] pair_sum_2_offset =
   {1'b0,set_offset} + {1'b0,pnt_step};
(* keep = "true" *) wire [PNT_SIZE:0] pair_sub_2_offset =
   pair_sum_2_offset - {1'b0,set_size,32'b0} - 1'b1;
wire pair_wrap_2_offset = ~pair_sub_2_offset[PNT_SIZE];
wire [PNT_SIZE-1:0] pair_pnt_2_offset = pair_wrap_2_offset
   ? set_offset : pair_sum_2_offset[PNT_SIZE-1:0];

wire pair_wrap_2 = pair_wrap_1
   ? (set_wrap ? pair_wrap_2_wrapped : pair_wrap_2_offset)
   : pair_wrap_2_nowrap;
wire [PNT_SIZE-1:0] pair_pnt_2 = pair_wrap_1
   ? (set_wrap ? pair_pnt_2_wrapped : pair_pnt_2_offset)
   : pair_pnt_2_nowrap;
(* keep = "true" *) wire [PNT_SIZE:0] pnt_pair_1 = {pair_wrap_1,pair_pnt_1};
(* keep = "true" *) wire [PNT_SIZE:0] pnt_pair_2 = {pair_wrap_2,pair_pnt_2};
wire pnt_wrap_now = pnt_pair_phase ? pnt_pair_1[PNT_SIZE] : pnt_pair_wrap;

// Keep the legacy signal names for the state machine.  The pair engine has
// already selected the wrapped/non-wrapped pointer; only the per-sample wrap
// decision is consumed here.
assign dac_npnt = {1'b0,pnt_pair_1[PNT_SIZE-1:0]};
assign dac_npnt_sub = {~pnt_wrap_now,pnt_pair_1[PNT_SIZE-1:0]};
assign dac_npnt_sub_neg = ~(dac_do && pnt_wrap_now);

// read pointer logic
always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) begin
   dac_pnt       <= {PNT_SIZE{1'b0}};
   dac_pnt_next  <= {PNT_SIZE{1'b0}};
   pnt_pair_phase <= 1'b0;
   pnt_pair_wrap  <= 1'b0;
end else begin
   if (set_rst_i) begin
      dac_pnt        <= pnt_reset_offset;
      dac_pnt_next   <= pnt_reset_offset;
      pnt_pair_phase <= 1'b0;
      pnt_pair_wrap  <= 1'b0;
   end else if (pnt_pair_start && !dac_do) begin
      // Configuration has been stable for two clocks while pnt_pair_warm was
      // shifting, so the first pair does not create a 4 ns seed path.
      dac_pnt        <= set_offset;
      dac_pnt_next   <= pnt_pair_1[PNT_SIZE-1:0];
      pnt_pair_phase <= 1'b0;
      pnt_pair_wrap  <= pnt_pair_1[PNT_SIZE];
   end
   else if (dac_do) begin
      if (pnt_pair_phase) begin
         dac_pnt        <= pnt_pair_1[PNT_SIZE-1:0];
         dac_pnt_next   <= pnt_pair_2[PNT_SIZE-1:0];
         pnt_pair_wrap  <= pnt_pair_2[PNT_SIZE];
         pnt_pair_phase <= 1'b0;
      end else begin
         dac_pnt        <= dac_pnt_next;
         pnt_pair_phase <= 1'b1;
      end
   end
end

assign trig_done_o = !dac_rep && trig_in;
assign get_step_o = set_step;
assign get_step_lo_o = set_step_lo;
assign err_cnt_o = 32'h0;
assign transf_cnt_o = 32'h0;

//---------------------------------------------------------------------------------
//
//  External trigger

reg  [  3-1: 0] ext_trig_in    ;
reg  [  2-1: 0] ext_trig_dp    ;
reg  [  2-1: 0] ext_trig_dn    ;
reg  [ 20-1: 0] ext_trig_debp  ;
reg  [ 20-1: 0] ext_trig_debn  ;

always @(posedge dac_clk_i) begin
   if (dac_rstn_i == 1'b0) begin
      ext_trig_in   <=  3'h0 ;
      ext_trig_dp   <=  2'h0 ;
      ext_trig_dn   <=  2'h0 ;
      ext_trig_debp <= 20'h0 ;
      ext_trig_debn <= 20'h0 ;
   end
   else begin
      //----------- External trigger
      // synchronize FFs
      ext_trig_in <= {ext_trig_in[1:0],trig_ext_i} ;

      // look for input changes
      if ((ext_trig_debp == 20'h0) && (ext_trig_in[1] && !ext_trig_in[2]))
         ext_trig_debp <= set_deb_len_i ; // default 0.5ms
      else if (ext_trig_debp != 20'h0)
         ext_trig_debp <= ext_trig_debp - 20'd1 ;

      if ((ext_trig_debn == 20'h0) && (!ext_trig_in[1] && ext_trig_in[2]))
         ext_trig_debn <= set_deb_len_i ; // default 0.5ms
      else if (ext_trig_debn != 20'h0)
         ext_trig_debn <= ext_trig_debn - 20'd1 ;

      // update output values
      ext_trig_dp[1] <= ext_trig_dp[0] ;
      if (ext_trig_debp == 20'h0)
         ext_trig_dp[0] <= ext_trig_in[1] ;

      ext_trig_dn[1] <= ext_trig_dn[0] ;
      if (ext_trig_debn == 20'h0)
         ext_trig_dn[0] <= ext_trig_in[1] ;
   end
end

assign ext_trig_p = (ext_trig_dp == 2'b01) ;
assign ext_trig_n = (ext_trig_dn == 2'b10) ;

rp_asg_axi #(
) inst_axi_dac 
(
  // DAC
  .dac_o           ( dac_axi_rd        ),
  .dac_clk_i       ( dac_clk_i         ),
  .dac_rstn_i      ( dac_rstn_i        ),
  .trig_i          ( dac_trig_axi      ),

  .axi_sys         ( axi_sys           ),      

  .set_rst_i       ( set_rst_i ),
  .set_axi_en_i    ( set_axi_en_i      ),
  .repeat_i        ( rep_arm           ),
  .set_axi_start_i ( set_axi_start_i   ),
  .set_axi_stop_i  ( set_axi_stop_i    ),
  .set_axi_dec_i   ( set_axi_dec_i     ),
  .set_cyc_cnt_i   ( set_ncyc_i        ),
  .axi_state_o     ( axi_state_o       ),
  .axi_last_o      ( axi_last          ),
  .axi_last_pre_o  ( axi_last_pre      ),
  .axi_first_o     ( axi_first         )
);

//---------------------------------------------------------------------------------
//
//  ILA debug (dac_clk_i domain)

// ila_1 i_ila_asg_ch (
//   .clk    (dac_clk_i),
//   .probe0 (trig_in),          // [1]
//   .probe1 (trig_sw_i),        // [1]
//   .probe2 (trig_ext_i),       // [1]
//   .probe3 (dac_trig),         // [1]
//   .probe4 (dac_do),           // [1]
//   .probe5 (dac_rep),          // [1]
//   .probe6 (buf_cycle),        // [1]
//   .probe7 (dac_pnt),          // [62]
//   .probe8 (set_step_i),       // [32]
//   .probe9 (set_step_lo_i),    // [32]
//   .probe10(set_size_i),       // [30]
//   .probe11(set_ofs_i),        // [32]
//   .probe12(axi_state_o),      // [20]
//   .probe13(axi_last),         // [1]
//   .probe14(axi_last_pre),     // [1]
//   .probe15(out_sel),          // [5]
//   .probe16(dac_o)             // [14]
// );

endmodule
