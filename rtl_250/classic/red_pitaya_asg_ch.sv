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
   input                 sys_clk_i       ,  //!< 
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
   input     [  32-1: 0] set_ofs_i       ,  //!< set reset offset
   input                 set_rst_i       ,  //!< set FSM to reset
   input                 set_rdly_mode_i      ,  //!< sets the behavior of a constant signal before and after burst
   input                 set_wrap_i      ,  //!< set wrap enable
   input     [  14-1: 0] set_amp_i       ,  //!< set amplitude scale
   input     [  14-1: 0] set_dc_i        ,  //!< set output offset
   input     [  14-1: 0] set_first_i     ,  //!< set initial value before start
   input     [  14-1: 0] set_last_i      ,  //!< set final value in burst
   input     [  32-1: 0] set_last_len_i  ,  //!< set length of final value in burst in ADC counts -- not used
   input                 set_zero_i      ,  //!< set output to zero
   input     [  16-1: 0] set_ncyc_i      ,  //!< set number of cycle
   input     [  16-1: 0] set_rnum_i      ,  //!< set number of repetitions
   input     [  32-1: 0] set_rdly_i      ,  //!< set delay between repetitions
   input     [  20-1: 0] set_deb_len_i   ,  //!< set trigger debouncer
   input     [  32-1: 0] set_seed_i      ,  //!< initial value for LFSR
   input                 rand_en_i       ,  //!< enable random output
   input                 rand_init_i     ,  //!< initialize LFSR
   input                 set_rgate_i     ,  //!< set external gated repetition
   input                 set_axi_en_i    ,  //!< enable AXI buffer read
   input     [  32-1: 0] set_axi_start_i ,  //!< AXI start address
   input     [  32-1: 0] set_axi_stop_i  ,  //!< AXI stop address
   input     [  32-1: 0] set_axi_dec_i   ,  //!< AXI decimation
   output    [  16-1: 0] axi_state_o     ,  //!< AXI state
   output    [  32-1: 0] err_cnt_o       ,  //!< number of missed samples
   output    [  32-1: 0] transf_cnt_o       //!< number of successful AXI transfers
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

reg   [ RSZ-1: 0] dac_rp    ;
reg   [PNT_SIZE-1: 0] dac_pnt   ; // read pointer
reg   [PNT_SIZE-1: 0] dac_pntp  ; // previous read pointer
wire  [PNT_SIZE-1: 0] axi_pnt   ; // read pointer AXI
reg   [PNT_SIZE-1: 0] axi_pntp  ; // previous read pointer AXI
wire  [PNT_SIZE  : 0] dac_npnt  ; // next read pointer
wire  [PNT_SIZE  : 0] dac_npnt_sub ;
wire                  dac_npnt_sub_neg;

reg   [  15-1: 0] set_amp_r ;
reg   [  28-1: 0] dac_mult  ;
reg   [  15-1: 0] dac_msr   ;
wire                  axi_dac_do;
wire                  axi_init;
reg  [   5-1: 0] axi_dac_do_sr ;
wire                  axi_last;
reg              dac_do       ;
reg  [   5-1: 0] dac_do_sr    ;

assign axi_dac_do = axi_state_o[1];
assign axi_init   = axi_state_o[3];

reg   [  16-1: 0] cyc_cnt   ;
reg signed  [  28-1: 0] dac_mult  ;
reg signed  [  15-1: 0] dac_sum   ;

rdly_mode_t        rdly_mode;
reg   [  14-1: 0] set_last;
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
    5'b00001: dac_rdat <= dac_rd;
    5'b0001?: dac_rdat <= dac_axi_rd;
    5'b001??: dac_rdat <= set_last;
    5'b01???: dac_rdat <= lfsr_noise;
    5'b1????: dac_rdat <= 14'h0;
    default : dac_rdat <= set_first_i;
  endcase
end

always @(posedge dac_clk_i) // shift regs are needed because of processing path delay
begin
   dac_do_sr     <= {dac_do_sr[3:0] , dac_do     };
   axi_dac_do_sr <= {axi_dac_do_sr[3:0], axi_dac_do };
   lastval_sr    <= {lastval_sr[3:0], ~do_read    };
   zero_sr       <= {zero_sr[3:0]   , set_zero_i };
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
   set_amp_r <= {1'b0,set_amp_i} ;

   dac_mult <= $signed(dac_rdat) * $signed(set_amp_r) ;
   dac_msr  <= dac_mult[28-1:13] ;
   dac_sum  <= $signed(dac_msr) + $signed(set_dc_i) ;
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
reg  [   8-1: 0] dly_tick     ;
reg              init_run     ;

reg              dac_rep      ;
wire             dac_trig     ;
reg              dac_trigr    ;

wire             do_read      ;
wire             do_read_start;
wire             do_read_end  ;
wire             buf_cycle    ;

assign do_read       = set_axi_en_i ? axi_dac_do  : dac_do;
assign do_read_start = set_axi_en_i ? axi_init    : dac_do;

assign do_read_end   = set_axi_en_i ? (set_axi_dec_i == 1 ? axi_last && cyc_cnt == 1 : axi_dac_do_sr[0] && !axi_dac_do) : 
                                    dac_do_sr[1:0] == 2'b10;
assign buf_cycle     = set_axi_en_i ? axi_last    : ({1'b0,dac_pntp} > {1'b0,dac_pnt});

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
      init_delay <= 1'b0;
   end else begin
      if (set_rst_i) begin
          init_run   <= 1'b1;
          init_delay <= 1'b0;
      end else if (trig_in || init_delay != 1'b0) begin
          init_delay <= init_delay + 2'b1;
          set_last   <= set_last_i;
      end else if (rdly_mode == RDLY_MODE_COPY) begin
          if (lastval_sr == 1'b1) begin
             set_last <= dac_rd;
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
      cyc_cnt   <= 16'h0 ;
      rep_cnt   <= 16'h0 ;
      dly_cnt   <= 32'h0 ;
      dly_tick  <=  8'h0 ;
      dac_do    <=  1'b0 ;
      dac_rep   <=  1'b0 ;
      trig_in   <=  1'b0 ;
      dac_pntp  <= {PNT_SIZE{1'b0}} ;
      dac_trigr <=  1'b0 ;
   end
   else begin
      // make 1us tick
      if (do_read || (dly_tick == 8'd124))
         dly_tick <= 8'h0 ;
      else
         dly_tick <= dly_tick + 8'h1 ;

      // delay between repetitions 
      if (set_rst_i || do_read_start)
         dly_cnt <= set_rdly_i ;
      else if (|dly_cnt && (dly_tick == 8'd124)) begin// last value counter takes precedent
         if(dly_cnt > 'h1 || (dly_cnt == 'h1))
            dly_cnt <= dly_cnt - 32'h1 ;
      end

      // repetitions counter
      if (trig_in && !do_read)
         rep_cnt <= set_rnum_i;
      else if (!set_rgate_i && (|rep_cnt && dac_rep && (dac_trig && !dac_trigr)) && (set_rnum_i != 16'hffff)) // only substract at the end of a cycle; 16'hffff is infinite pulses
         rep_cnt <= rep_cnt - 16'h1 ;
      else if (set_rgate_i && ((!trig_ext_i && trig_src_i==3'd2) || (trig_ext_i && trig_src_i==3'd3)))
         rep_cnt <= 16'h0 ;

      // count number of table read cycles
      dac_pntp  <= dac_pnt;
      axi_pntp  <= axi_pnt;
      dac_trigr <= dac_trig; // ignore trigger when count
      if (dac_trig)
         cyc_cnt <= set_ncyc_i ;
      else if (!dac_trigr && |cyc_cnt && buf_cycle)
         cyc_cnt <= cyc_cnt - 16'h1 ;

      // trigger arrived
      case (trig_src_i & {3{!set_rst_i}})
          3'd1 : trig_in <= trig_sw_i   ; // sw
          3'd2 : trig_in <= ext_trig_p  ; // external positive edge
          3'd3 : trig_in <= ext_trig_n  ; // external negative edge
       default : trig_in <= 1'b0        ;
      endcase

      // in cycle mode
      if (dac_trig && !set_rst_i && !set_axi_en_i)
         dac_do <= 1'b1 ;
      else if (set_rst_i || ((cyc_cnt==16'h1) && ~dac_npnt_sub_neg) )
         dac_do <= 1'b0 ;

      // in repetition mode
      if (dac_trig && !set_rst_i)
         dac_rep <= 1'b1 ;
      else if (set_rst_i || (rep_cnt==16'h0))
         dac_rep <= 1'b0 ;
   end
end

assign dac_trig = (!dac_rep && trig_in) || (dac_rep && |rep_cnt && (dly_cnt == 32'h0) && (cyc_cnt == 16'h0) && ~dac_do && !buf_cycle) ;


reg [PNT_SIZE: 0] dac_pnt_rem  ; // final step over size
// dac_npnt_sub = dac_npnt - size - 1  ==  dac_pnt + step - size - 1
assign dac_npnt_sub = {1'b0,dac_pnt} + dac_pnt_rem ;   // dac_npnt - {1'b0,set_size_i} - 1;
assign dac_npnt_sub_neg = dac_npnt_sub[PNT_SIZE];

// read pointer logic
always @(posedge dac_clk_i)
if (dac_rstn_i == 1'b0) begin
   dac_pnt  <= {PNT_SIZE{1'b0}};
end else begin
   dac_pnt_rem <= {1'b0,set_step_i[RSZ+15:0],set_step_lo_i} - {1'b0,set_size_i,32'h0} - 1 ;
   if (set_rst_i || (dac_trig && !dac_do)) // manual reset or start
      dac_pnt <= {set_ofs_i[RSZ+15:0],32'h0};
   else if (dac_do) begin
      if (~dac_npnt_sub_neg)  dac_pnt <= set_wrap_i ? dac_npnt_sub : {set_ofs_i[RSZ+15:0],32'h0}; // wrap or go to start
      else                    dac_pnt <= dac_npnt[PNT_SIZE-1:0]; // normal increase
   end
end

assign dac_npnt = dac_do ? dac_pnt + {set_step_i[RSZ+15:0],set_step_lo_i} : dac_pnt;
assign trig_done_o = !dac_rep && trig_in;

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
  .trig_i          ( dac_trig          ),

  .axi_sys         ( axi_sys           ),      

  .set_rst_i       ( set_rst_i         ),
  .set_axi_en_i    ( set_axi_en_i      ),
  .set_axi_start_i ( set_axi_start_i   ),
  .set_axi_stop_i  ( set_axi_stop_i    ),
  .set_axi_dec_i   ( set_axi_dec_i     ),
  .set_cyc_cnt_i   ( set_ncyc_i        ),
  .cyc_cnt_i       ( cyc_cnt           ),
  .axi_state_o     ( axi_state_o       ),
  .axi_last_o      ( axi_last          ),
  .err_cnt_o       ( err_cnt_o         ),
  .transf_cnt_o    ( transf_cnt_o      )
);
endmodule
