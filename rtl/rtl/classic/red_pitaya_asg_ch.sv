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

`ifdef Z20_G2
`define RP_ASG_TIMING_PIPELINE
`endif
`ifdef Z20_LL
`define RP_ASG_TIMING_PIPELINE
`define RP_ASG_TRIG_SELECT
`endif

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
   output    [  32-1: 0] get_step_o      ,  //!< get pointer step
   output    [  32-1: 0] get_step_lo_o   ,  //!< get pointer step, low frequency
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
   output    [  20-1: 0] axi_state_o        //!< AXI state
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
typedef enum logic [0:0] {
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
always @(posedge dac_clk_i)
if (buf_we_i)  dac_buf[buf_addr_i] <= buf_wdata_i[14-1:0] ;

// read-back
always @(posedge dac_clk_i)
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
reg  [  32-1: 0] dly_cnt      ;
// Zero flags for the two counters, kept out of rep_arm and so out of the
// dac_trig decode.  Updated one cycle ahead: "about to be zero" is "currently
// one".  Bit exact copies of |rep_cnt and (dly_cnt != 0).
reg              rep_nonzero  ;
reg              dly_nonzero  ;
// (set_rdly_i - 1) is a 32 bit subtract on a configuration value. Computed in
// the load path it sat behind dac_trig, which already arrives at the end of the
// read pointer comparison, so the two carry chains ended up in series. It takes
// effect one cycle after the register is written.
reg  [  32-1: 0] set_rdly_m1  ;
// Set after the first real output sample so AXI preload time is not counted
// as part of the requested start-to-start burst period.
reg              dly_started  ;
reg              init_run     ;

reg  [  32-1: 0] set_step      ;  
reg  [  32-1: 0] set_step_lo      ;  
// Derived fractional-step values are configuration data as well.  Keeping
// them in registers avoids putting a negate/decrement in the sample path.
reg  [  32-1: 0] set_step_lo_m1 ;
reg  [  32-1: 0] set_step_lo_neg;
`ifdef RP_ASG_TIMING_PIPELINE
reg  [RSZ+16-1:0] set_size;
`endif


reg              dac_rep      ;
wire             dac_trig     ;
reg              dac_trigr    ;
reg              buf_cycle_q  ;

wire             do_read      ;
wire             do_read_end  ;
wire             buf_cycle    ;
wire             dly_start    ;
`ifdef RP_ASG_TRIG_SELECT
// The wrap decision and the two values it can give to the signals derived from
// it.  Assigned next to trig_now / dac_trig, used by the state machine below.
wire             pnt_wrap     ;
wire             cycle_end_0  ;
wire             cycle_end_1  ;
wire             dac_trig_0   ;
wire             dac_trig_1   ;
wire             dly_start_0  ;
wire             dly_start_1  ;
// Next state variants, one per value of the wrap decision.  `keep` holds them
// apart, see the comment next to their assignments.
(* keep = "true" *) wire [  32-1: 0] dly_cnt_nxt_0     ;
(* keep = "true" *) wire [  32-1: 0] dly_cnt_nxt_1     ;
wire                              dly_nonzero_nxt_0 ;
wire                              dly_nonzero_nxt_1 ;
(* keep = "true" *) wire             dly_started_nxt_0 ;
(* keep = "true" *) wire             dly_started_nxt_1 ;
(* keep = "true" *) wire [  16-1: 0] rep_cnt_nxt_0     ;
(* keep = "true" *) wire [  16-1: 0] rep_cnt_nxt_1     ;
wire                              rep_nonzero_nxt_0 ;
wire                              rep_nonzero_nxt_1 ;
(* keep = "true" *) wire [  16-1: 0] cyc_cnt_nxt_0     ;
(* keep = "true" *) wire [  16-1: 0] cyc_cnt_nxt_1     ;
(* keep = "true" *) wire             dac_do_nxt_0      ;
(* keep = "true" *) wire             dac_do_nxt_1      ;
(* keep = "true" *) wire             dac_rep_nxt_0     ;
(* keep = "true" *) wire             dac_rep_nxt_1     ;
`endif

assign do_read       = set_axi_en_i ? axi_dac_do  : dac_do;

assign do_read_end   = set_axi_en_i ? (set_axi_dec_i == 1 ? axi_last && cyc_cnt == 1 : axi_dac_do_sr[0] && !axi_dac_do) : 
                                    dac_do_sr[1:0] == 2'b10;
// Non-AXI cycle completion is consumed one clock after the pointer wraps.  The
// old implementation reconstructed that delayed event by comparing the full
// previous and current 62-bit pointers.  Capture the wrap decision directly;
// this preserves the cycle-counter timing while removing a second wide
// pointer feedback cone from its clock enable.
assign buf_cycle     = set_axi_en_i ? axi_last : buf_cycle_q;
// AXI starts producing samples only after FIFO preload; non-AXI starts on dac_trig.
assign dly_start     = set_axi_en_i ? axi_first   : dac_trig;

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
      dly_cnt      <= 32'h0 ;
      rep_nonzero  <=  1'b0 ;
      dly_nonzero  <=  1'b0 ;
      dly_started  <=  1'b0 ;
      dac_do       <=  1'b0 ;
      dac_rep      <=  1'b0 ;
      trig_in      <=  1'b0 ;
      dac_trigr    <=  1'b0 ;
      buf_cycle_q  <=  1'b0 ;
      set_step     <= 32'h0 ; 
      set_step_lo  <= 32'h0 ;
      set_step_lo_m1  <= 32'hffff_ffff;
      set_step_lo_neg <= 32'h0;
`ifdef RP_ASG_TIMING_PIPELINE
      set_size     <= {(RSZ+16){1'b0}};
`endif
   end
   else begin
      // Count the requested start-to-start burst period from the first output sample.
`ifdef RP_ASG_TRIG_SELECT
      // Both next state variants are built from registers only, the wrap
      // decision selects between them.  See the comment at their definition.
      if (set_rst_i) begin
         dly_cnt <= 32'h0;
         dly_nonzero <= 1'b0;
         dly_started <= 1'b0;
      end else begin
         dly_cnt     <= pnt_wrap ? dly_cnt_nxt_1     : dly_cnt_nxt_0     ;
         dly_nonzero <= pnt_wrap ? dly_nonzero_nxt_1 : dly_nonzero_nxt_0 ;
         dly_started <= pnt_wrap ? dly_started_nxt_1 : dly_started_nxt_0 ;
      end

      // repetitions counter
      rep_cnt     <= pnt_wrap ? rep_cnt_nxt_1     : rep_cnt_nxt_0     ;
      rep_nonzero <= pnt_wrap ? rep_nonzero_nxt_1 : rep_nonzero_nxt_0 ;

      // count number of table read cycles
      dac_trigr <= dac_trig; // ignore trigger when count
      buf_cycle_q <= dac_do && ~dac_npnt_sub_neg;

      cyc_cnt <= pnt_wrap ? cyc_cnt_nxt_1 : cyc_cnt_nxt_0 ;
`else
      if (set_rst_i) begin
         dly_cnt <= 32'h0;
         dly_nonzero <= 1'b0;
         dly_started <= 1'b0;
      end else begin
         if (dly_start) begin
            dly_cnt <= set_rdly_m1;
            dly_nonzero <= |set_rdly_m1;
         end
         else if (dac_rep && dly_started && dly_nonzero) begin
            dly_cnt <= dly_cnt - 32'h1;
            dly_nonzero <= (dly_cnt != 32'h1);
         end

         if (dly_start)
            dly_started <= 1'b1;
         else if (dac_trig)
            dly_started <= 1'b0;
      end

      // repetitions counter
      if (trig_in && !do_read) begin
         rep_cnt <= set_rnum_i;
         rep_nonzero <= |set_rnum_i;
      end
      else if (!set_rgate_i && (rep_nonzero && dac_rep && (dac_trig && !dac_trigr)) && (set_rnum_i != 16'hffff)) begin // only substract at the end of a cycle; 16'hffff is infinite pulses
         rep_cnt <= rep_cnt - 16'h1 ;
         rep_nonzero <= (rep_cnt != 16'h1);
      end
      else if (set_rgate_i && ((!trig_ext_i && trig_src_i==3'd2) || (trig_ext_i && trig_src_i==3'd3))) begin
         rep_cnt <= 16'h0 ;
         rep_nonzero <= 1'b0;
      end

      // count number of table read cycles
      dac_trigr <= dac_trig; // ignore trigger when count
      buf_cycle_q <= dac_do && ~dac_npnt_sub_neg;

      if (dac_trig)
         cyc_cnt <= set_ncyc_i ;
      else if (!dac_trigr && |cyc_cnt && buf_cycle)
         cyc_cnt <= cyc_cnt - 16'h1 ;
`endif

      // trigger arrived
      case (trig_src_i & {3{!set_rst_i}})
          3'd1 : trig_in <= trig_sw_i   ; // sw
          3'd2 : trig_in <= ext_trig_p  ; // external positive edge
          3'd3 : trig_in <= ext_trig_n  ; // external negative edge
       default : trig_in <= 1'b0        ;
      endcase

      if (trig_in) begin
        set_step <= set_step_i;
        set_step_lo <= set_step_lo_i;
        set_step_lo_m1  <= set_step_lo_i - 32'h1;
        set_step_lo_neg <= -set_step_lo_i;
`ifdef RP_ASG_TIMING_PIPELINE
        set_size <= set_size_i;
`endif
      end

`ifdef RP_ASG_TRIG_SELECT
      // in cycle mode
      dac_do  <= pnt_wrap ? dac_do_nxt_1  : dac_do_nxt_0  ;

      // in repetition mode
      dac_rep <= pnt_wrap ? dac_rep_nxt_1 : dac_rep_nxt_0 ;
`else
      // in cycle mode
      if (dac_trig && !set_rst_i && !set_axi_en_i)
         dac_do <= 1'b1 ;
      else if (set_rst_i || ((cyc_cnt==16'h1) && ~dac_npnt_sub_neg) )
         dac_do <= 1'b0 ;

      // in repetition mode
      if (dac_trig && !set_rst_i)
         dac_rep <= 1'b1 ;
      else if (set_rst_i || !rep_nonzero)
         dac_rep <= 1'b0 ;
`endif
   end
end

always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) set_rdly_m1 <= 32'h0;
else                    set_rdly_m1 <= (set_rdly_i > 32'h0) ? (set_rdly_i - 32'h1) : 32'h0;

wire rep_arm   = dac_rep && rep_nonzero && dly_started && !dly_nonzero;
wire rep_idle  = (cyc_cnt == 16'h0) && ~dac_do && !buf_cycle;
wire cycle_end = set_axi_en_i ? axi_last : (~dac_npnt_sub_neg);
wire rep_end   = (cyc_cnt == 16'h1) && cycle_end;
wire cycle_end_pre = set_axi_en_i ? axi_last_pre : (~dac_npnt_sub_neg);
wire rep_end_pre   = (cyc_cnt == 16'h1) && cycle_end_pre;

// Same expression as before, factored so that everything except the end of
// cycle test is one term:
//   E1 | (E2 & (E3 | (E4 & end))) == (E1 | E2&E3) | (E2&E4 & end)
// dac_npnt_sub_neg is the slowest signal in this module (it ends a 62 bit carry
// chain), and it reaches the pointer, the delay and the repetition counters
// through this expression. Written this way it has a single term left to pass.
wire trig_now     = (!dac_rep && trig_in) || (rep_arm && rep_idle);
wire trig_on_wrap = rep_arm && (cyc_cnt == 16'h1);

wire dac_trig_axi  = trig_now || (trig_on_wrap && cycle_end_pre);

assign dac_trig = trig_now || (trig_on_wrap && cycle_end);

`ifdef RP_ASG_TRIG_SELECT
////////////////////////////////////////////////////////////////////////////////
// State machine, carry select on the wrap decision.
//
// dac_npnt_sub_neg ends the 62 bit pointer comparison and is the last signal to
// settle in this module.  Through cycle_end and dac_trig it reached the delay,
// the repetition and the cycle counter over two logic levels: one for dac_trig
// itself, a net with more than thirty loads, and a second one for every
// counter's own load / decrement multiplexer.
//
// Everything in those multiplexers except the wrap test is a function of
// registers only, so both next state variants are computed in advance and the
// wrap decision selects between them - the same rewrite as for the pointer
// arithmetic below.  Each variant is the original expression with the wrap bit
// substituted by a constant, so the selected value is bit identical and every
// register still changes in exactly the same clock cycle.
//
// `keep` holds the variants apart; without it they are folded back into one
// cone with dac_trig in front of it and the transformation is undone.
////////////////////////////////////////////////////////////////////////////////

assign pnt_wrap    = ~dac_npnt_sub_neg;
assign cycle_end_0 = set_axi_en_i ? axi_last  : 1'b0;
assign cycle_end_1 = set_axi_en_i ? axi_last  : 1'b1;
assign dac_trig_0  = trig_now || (trig_on_wrap && cycle_end_0);
assign dac_trig_1  = trig_now || (trig_on_wrap && cycle_end_1);
assign dly_start_0 = set_axi_en_i ? axi_first : dac_trig_0;
assign dly_start_1 = set_axi_en_i ? axi_first : dac_trig_1;

// Terms shared by both variants: everything that does not depend on the wrap
// decision, i.e. only registers and configuration.
wire             dly_dec   = dac_rep && dly_started && dly_nonzero;
wire [  32-1: 0] dly_hold  = dly_dec ? dly_cnt - 32'h1 : dly_cnt;
wire             dly_terminal = (dly_cnt == 32'h1);
wire             rep_ld    = trig_in && !do_read;
wire             rep_dec   = !set_rgate_i && rep_nonzero && dac_rep && !dac_trigr
                             && (set_rnum_i != 16'hffff); // 16'hffff is infinite pulses
wire             rep_clr   = set_rgate_i && ((!trig_ext_i && trig_src_i==3'd2)
                                          || ( trig_ext_i && trig_src_i==3'd3));
wire             cyc_dec   = !dac_trigr && |cyc_cnt && buf_cycle;
wire             do_clr    = set_rst_i;                  // wrap term added per variant
wire             rep_end_c = set_rst_i || !rep_nonzero;

// The two next state variants.  Each pair differs only in which value of the
// wrap decision was substituted, so the selected result is the original
// expression.
assign dly_cnt_nxt_0     = dly_start_0 ? set_rdly_m1 : dly_hold;
assign dly_cnt_nxt_1     = dly_start_1 ? set_rdly_m1 : dly_hold;

assign dly_nonzero_nxt_0 = dly_start_0 ? |set_rdly_m1
                                       : dly_dec ? !dly_terminal : dly_nonzero;
assign dly_nonzero_nxt_1 = dly_start_1 ? |set_rdly_m1
                                       : dly_dec ? !dly_terminal : dly_nonzero;

assign dly_started_nxt_0 = dly_start_0 ? 1'b1 : (dac_trig_0 ? 1'b0 : dly_started);
assign dly_started_nxt_1 = dly_start_1 ? 1'b1 : (dac_trig_1 ? 1'b0 : dly_started);

assign rep_cnt_nxt_0     = rep_ld                 ? set_rnum_i      :
                           (rep_dec && dac_trig_0) ? rep_cnt - 16'h1 :
                           rep_clr                ? 16'h0           : rep_cnt;
assign rep_cnt_nxt_1     = rep_ld                 ? set_rnum_i      :
                           (rep_dec && dac_trig_1) ? rep_cnt - 16'h1 :
                           rep_clr                ? 16'h0           : rep_cnt;

assign rep_nonzero_nxt_0 = rep_ld                  ? |set_rnum_i        :
                           (rep_dec && dac_trig_0) ? (rep_cnt != 16'h1) :
                           rep_clr                 ? 1'b0               : rep_nonzero;
assign rep_nonzero_nxt_1 = rep_ld                  ? |set_rnum_i        :
                           (rep_dec && dac_trig_1) ? (rep_cnt != 16'h1) :
                           rep_clr                 ? 1'b0               : rep_nonzero;

assign cyc_cnt_nxt_0     = dac_trig_0 ? set_ncyc_i : (cyc_dec ? cyc_cnt - 16'h1 : cyc_cnt);
assign cyc_cnt_nxt_1     = dac_trig_1 ? set_ncyc_i : (cyc_dec ? cyc_cnt - 16'h1 : cyc_cnt);

// dac_do is cleared by the end of the last cycle, which is the wrap decision
// itself: 1'b0 in variant 0, 1'b1 in variant 1.
assign dac_do_nxt_0      = (dac_trig_0 && !set_rst_i && !set_axi_en_i) ? 1'b1 :
                           do_clr                                     ? 1'b0 : dac_do;
assign dac_do_nxt_1      = (dac_trig_1 && !set_rst_i && !set_axi_en_i) ? 1'b1 :
                           (do_clr || (cyc_cnt==16'h1))               ? 1'b0 : dac_do;

assign dac_rep_nxt_0     = (dac_trig_0 && !set_rst_i) ? 1'b1 : (rep_end_c ? 1'b0 : dac_rep);
assign dac_rep_nxt_1     = (dac_trig_1 && !set_rst_i) ? 1'b1 : (rep_end_c ? 1'b0 : dac_rep);
`endif

////////////////////////////////////////////////////////////////////////////////
// Read pointer arithmetic, carry select across the fixed point boundary.
//
// The pointer is 62 bits: 30 integer bits of table address and 32 fractional
// bits of phase. Written plainly, (dac_pnt + step) and then (- size - 1) form
// one 63 bit carry chain, and its last bit - the borrow, dac_npnt_sub_neg -
// decides whether the pointer wraps, so it feeds the clock enable of dac_pnt
// itself and of the counters beside it. That closed loop, 16 carry blocks plus
// the decode, is what does not fit in 8 ns.
//
// Splitting at bit 32 makes the two halves independent. The fraction produces
// only a carry into the integer half, and that carry can take three values
// once the -1 of the subtraction is included, so the integer half is computed
// for all of them in parallel and selected afterwards:
//
//   k = carry(fraction sum) - borrow(fraction sum - 1)   in {-1, 0, +1}
//
// Depth becomes one 34 bit chain (or one 31 bit chain, whichever is slower)
// plus a multiplexer, instead of two chains in series. The result is bit exact,
// including the borrow bit, because addition modulo 2**31 in the integer half
// is exactly what the wide subtraction does to those bits.
//
// `keep` holds the variants apart; without it the tool folds them back into a
// single chain and the split is undone.
////////////////////////////////////////////////////////////////////////////////

localparam PNT_LO = 32;                   // fractional bits
localparam PNT_HI = PNT_SIZE - PNT_LO;    // integer bits (table address)

wire [PNT_LO-1:0] pnt_lo = dac_pnt[PNT_LO-1:0];
wire [PNT_HI-1:0] pnt_hi = dac_pnt[PNT_SIZE-1:PNT_LO];
// dac_pnt already has an explicit dac_do enable below.  Do not put dac_do in
// front of every arithmetic operand as well: that adds the run-state decode to
// both carry-select cones and makes dac_do the critical feedback source.  The
// arithmetic is don't-care while the pointer is held.
wire [PNT_LO-1:0] stp_lo = set_step_lo;
wire [PNT_HI-1:0] stp_hi = set_step[PNT_HI-1:0];

// Fractional sum.  The low part of (sum - 1) is computed independently using
// the registered (step - 1), while its signed carry into the integer part is
// derived without a second 34-bit carry chain:
//   sum == 0             -> -1
//   sum > 2**PNT_LO      -> +1
//   otherwise            ->  0
// A zero low result is detected as pnt_lo == -step.  The exact value
// 2**PNT_LO has both carry and a zero low result, and contributes zero.
(* keep = "true" *) wire [PNT_LO  :0] frac_sum = {1'b0,pnt_lo} + {1'b0,stp_lo};
wire [PNT_LO-1:0] stp_lo_m1  = set_step_lo_m1;
wire [PNT_LO-1:0] stp_lo_neg = set_step_lo_neg;
(* keep = "true" *) wire [PNT_LO-1:0] frac_sub_lo = pnt_lo + stp_lo_m1;
wire              frac_carry = frac_sum[PNT_LO];
wire              frac_zero  = (pnt_lo == stp_lo_neg);
wire  [      1:0] frac_k     = frac_carry ? (frac_zero ? 2'b00 : 2'b01) :
                                frac_zero  ? 2'b11 : 2'b00;

// integer half, one variant per possible carry from the fraction
(* keep = "true" *) wire [PNT_HI:0] int_sum_c0 = {1'b0,pnt_hi} + {1'b0,stp_hi};
(* keep = "true" *) wire [PNT_HI:0] int_sum_c1 = {1'b0,pnt_hi} + {1'b0,stp_hi} + 1'b1;
wire [PNT_HI:0] int_sum = frac_carry ? int_sum_c1 : int_sum_c0;

// The subtraction is the half that decides the wrap, so it is split once more,
// by the same rule: its low part passes a carry of -1, 0 or +1 to its high
// part, and the high part is computed for all three in advance. Total carry
// length is unchanged (three chains of 31 bits become three of 17 and three of
// 16), only the depth halves. sum needs no second split: it feeds the pointer
// data input, which has a whole cycle, not the enables.
localparam INT_LO = PNT_HI/2;
localparam INT_HI = PNT_HI - INT_LO;

wire [INT_LO-1:0] pnt_i_l = pnt_hi     [INT_LO-1:0];
wire [INT_HI-1:0] pnt_i_h = pnt_hi     [PNT_HI-1:INT_LO];
wire [INT_LO-1:0] stp_i_l = stp_hi     [INT_LO-1:0];
wire [INT_HI-1:0] stp_i_h = stp_hi     [PNT_HI-1:INT_LO];
`ifdef RP_ASG_TIMING_PIPELINE
wire [INT_LO-1:0] siz_i_l = set_size [INT_LO-1:0];
wire [INT_HI-1:0] siz_i_h = set_size [PNT_HI-1:INT_LO];
`else
wire [INT_LO-1:0] siz_i_l = set_size_i [INT_LO-1:0];
wire [INT_HI-1:0] siz_i_h = set_size_i [PNT_HI-1:INT_LO];
`endif

(* keep = "true" *) wire [INT_LO+1:0] isub_l_m1 = {2'b0,pnt_i_l} + {2'b0,stp_i_l}
                                                - {2'b0,siz_i_l} - 1'b1;
(* keep = "true" *) wire [INT_LO+1:0] isub_l_z  = {2'b0,pnt_i_l} + {2'b0,stp_i_l}
                                                - {2'b0,siz_i_l};
(* keep = "true" *) wire [INT_LO+1:0] isub_l_p1 = {2'b0,pnt_i_l} + {2'b0,stp_i_l}
                                                - {2'b0,siz_i_l} + 1'b1;

wire [INT_LO+1:0] isub_l = frac_k[1] ? isub_l_m1 :
                           frac_k[0] ? isub_l_p1 : isub_l_z;
wire [       1:0] int_j  = isub_l[INT_LO+1:INT_LO];   // 2'b11 = -1, 2'b01 = +1

(* keep = "true" *) wire [INT_HI:0] isub_h_m1 = {1'b0,pnt_i_h} + {1'b0,stp_i_h}
                                              - {1'b0,siz_i_h} - 1'b1;
(* keep = "true" *) wire [INT_HI:0] isub_h_z  = {1'b0,pnt_i_h} + {1'b0,stp_i_h}
                                              - {1'b0,siz_i_h};
(* keep = "true" *) wire [INT_HI:0] isub_h_p1 = {1'b0,pnt_i_h} + {1'b0,stp_i_h}
                                              - {1'b0,siz_i_h} + 1'b1;

wire [INT_HI:0] isub_h = int_j[1] ? isub_h_m1 :
                         int_j[0] ? isub_h_p1 : isub_h_z;

wire [PNT_HI:0] int_sub = {isub_h, isub_l[INT_LO-1:0]};

assign dac_npnt         = {int_sum, frac_sum[PNT_LO-1:0]};
assign dac_npnt_sub     = {int_sub, frac_sub_lo};
assign dac_npnt_sub_neg = dac_npnt_sub[PNT_SIZE];

// read pointer logic
always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) begin
   dac_pnt  <= {PNT_SIZE{1'b0}};
end else begin
`ifdef RP_ASG_TIMING_PIPELINE
   // A trigger generated by the current wrap is only an FSM event: while
   // dac_do is active the pointer already performs that wrap below.  Feeding
   // it back into the start branch is redundant, but makes the wide boundary
   // arithmetic part of the pointer's own R/CE cone.  Only an idle trigger
   // needs to load the configured start offset.
   if (set_rst_i || (trig_now && !dac_do))
`else
   if (set_rst_i || (dac_trig && !dac_do)) // manual reset or start
`endif
      dac_pnt <= {set_ofs_i[RSZ+15:0],32'h0};
   else if (dac_do) begin
      if (~dac_npnt_sub_neg)  dac_pnt <= set_wrap_i ? dac_npnt_sub : {set_ofs_i[RSZ+15:0],32'h0};
      else                    dac_pnt <= dac_npnt[PNT_SIZE-1:0];
   end
end

// dac_npnt / dac_npnt_sub are built above, split at the fixed point boundary.
assign trig_done_o = !dac_rep && trig_in;
// output frequency on trigger
assign get_step_o = set_step;
assign get_step_lo_o = set_step_lo;

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

endmodule

`ifdef RP_ASG_TIMING_PIPELINE
`undef RP_ASG_TIMING_PIPELINE
`endif
`ifdef RP_ASG_TRIG_SELECT
`undef RP_ASG_TRIG_SELECT
`endif
