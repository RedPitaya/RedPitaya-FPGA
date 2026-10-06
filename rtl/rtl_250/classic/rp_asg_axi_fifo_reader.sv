/*
  FIFO reader and DAC output for ASG
  - Handles trigger, FIFO preload, decimation and output to DAC
*/

module rp_asg_axi_fifo_reader #(
  parameter int DW = 64,
  parameter int AW = 32,
  parameter int FIFO_PRELOAD_SIZE = 240,
  parameter int RD_LVL_W = 7
)(
  // DAC
  output logic [14-1:0]       dac_o,
  input  logic               dac_clk_i,
  input  logic               dac_rstn_i,
  // trigger
  input  logic               trig_i,

  // configuration
  input  logic               set_rst_i,
  input  logic               set_axi_en_i,
  input  logic [32-1:0]       set_axi_start_i,
  input  logic [32-1:0]       set_axi_stop_i,
  input  logic [32-1:0]       set_axi_dec_i,
  input  logic [16-1:0]       set_cyc_cnt_i,
  input  logic               repeat_i,
  output logic [20-1:0]       axi_state_o,
  output logic               axi_last_o,
  output logic               axi_last_pre_o,
  output logic               axi_first_o,

  // start pulse to request AXI read
  output logic               start_pulse_o,

  // FIFO read-side interface
  input  logic [DW-1:0]       dat_fifo_out,
  input  logic               dat_rd_valid,
  input  logic               dat_fifo_empty,
  input  logic [RD_LVL_W-1:0] dat_rd_fifo_lvl,
  output logic               dat_fifo_rd
);

//---------------------------------------------------------------------------------

localparam int NUM_SAMPS = DW/16;
localparam int BUF_WORDS = 2;
localparam int PRE_LAST_SINGLE = (NUM_SAMPS >= 3) ? (NUM_SAMPS-3) : 0;
localparam int PRELOAD_TIMER_W = (FIFO_PRELOAD_SIZE > 1) ? $clog2(FIFO_PRELOAD_SIZE + 1) : 1;
localparam logic [PRELOAD_TIMER_W-1:0] PRELOAD_LIMIT = FIFO_PRELOAD_SIZE;

typedef enum logic [2:0] {
  RD_IDLE,
  RD_PRELOAD,
  RD_COLD_START,
  RD_ACTIVE
} rd_state_t;

rd_state_t rd_state_q;
rd_state_t rd_state_d;

logic [AW-1:0] period_words;
logic [AW-1:0] words_left_q;
logic          last_pulse;
logic          last_pre_pulse;
logic [31:0]   dec_countdown_q;
logic [31:0]   dec_reload_q;
logic [31:0]   dec_safe;
logic          dec_step;
logic          words_last_q;
logic [15:0]   cycle_cnt_q;

logic [1:0]    sample_index;

logic [DW-1:0] buf_data [0:BUF_WORDS-1];
logic          buf_wr_ptr;
logic          buf_rd_ptr;
logic [1:0]    buf_count_q;
logic          rd_pending_q;

logic [PRELOAD_TIMER_W-1:0] preload_timer;
logic          preload_done;
logic          preload_done_q;
logic          trig_pending;
logic          trig_edge;
logic          trig_req;
logic          repeat_req;
logic          preload_req;
logic          fifo_active;
logic          fifo_ready;
logic          output_valid;
logic          start_cycle;
logic          restart_cycle;
logic          advance_cycle;
logic          cycle_reload;
// Marks the first valid DAC sample after each AXI cycle reload. The ASG
// repetition delay uses this to ignore the one-time FIFO preload latency.
logic          burst_first_pending_q;
logic          burst_first_sample;
logic          consume_word;
logic          cycle_done;
logic          stop_cycle;
logic          read_active;
logic [2:0]    avail_words;
logic          need_words;
logic          will_continue;
logic          rd_en_req;
logic          buf_full;
logic          buf_empty;
logic          buf_push;
logic          buf_pop;
logic [15:0]   sample_data;
logic [AW-1:0] axi_start_q;
logic [AW-1:0] axi_stop_q;
logic [31:0]   axi_dec_q;
logic [AW-1:0] axi_start_use;
logic [AW-1:0] axi_stop_use;

//---------------------------------------------------------------------------------
//
//  Trig sync

// trig_i is combinational in the ASG channel and carries the full read pointer
// comparison (a 62 bit carry chain) with it. Registering it before the edge
// detector keeps that chain out of the FSM, the decimation counter and the word
// counters, which start their own logic levels from here. Costs one dac clock
// before an AXI playback starts.
logic trig_q;
logic trig_r;

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    trig_q <= 1'b0;
    trig_r <= 1'b0;
  end else begin
    trig_q <= trig_i;
    trig_r <= trig_q;
  end
end

assign trig_edge = trig_q & ~trig_r;
assign repeat_req = repeat_i && set_axi_en_i;

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    trig_pending <= 1'b0;
  end else if (cycle_reload) begin
    trig_pending <= 1'b0;
  end else if (trig_edge && set_axi_en_i && (!repeat_req || rd_state_q == RD_IDLE)) begin
    trig_pending <= 1'b1;
  end
end

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    preload_req <= 1'b0;
  end else if (rd_state_q == RD_PRELOAD && rd_state_d == RD_COLD_START) begin
    preload_req <= 1'b0;
  end else if (trig_edge && !repeat_req && set_axi_en_i) begin
    preload_req <= 1'b1;
  end
end

assign trig_req = trig_pending | (trig_edge && set_axi_en_i);

//---------------------------------------------------------------------------------
//
//  FSM for reading from fifo

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    rd_state_q <= RD_IDLE;
  end else begin
    rd_state_q <= rd_state_d;
  end
end

always_comb begin : fsm_fifo_read
  rd_state_d = rd_state_q;

  unique case (rd_state_q)
    RD_IDLE: begin
      if (trig_pending) begin
        if (preload_done_q && !preload_req)
          rd_state_d = RD_COLD_START;
        else
          rd_state_d = RD_PRELOAD;
      end
    end

    RD_PRELOAD: begin
      // use a timer because the FIFO filling time is different for several channels.
      if (preload_done)
        rd_state_d = RD_COLD_START;
    end

    RD_COLD_START: begin
      if (!buf_empty)
        rd_state_d = RD_ACTIVE;
    end

    RD_ACTIVE: begin
      if (stop_cycle)
        rd_state_d = RD_IDLE;
    end

    default:
      rd_state_d = RD_IDLE;
  endcase
end

//---------------------------------------------------------------------------------
//
//  FIFO read interface

assign buf_full     = buf_count_q == 2'd2;
assign buf_empty    = buf_count_q == 2'd0;
assign read_active  = (rd_state_q == RD_COLD_START) || (rd_state_q == RD_ACTIVE);
assign avail_words  = buf_count_q + rd_pending_q;
assign need_words   = words_left_q > avail_words;
assign will_continue = (cycle_cnt_q == 16'h0) || (cycle_cnt_q > 16'h1) || repeat_req || trig_req;
assign rd_en_req    = read_active && !dat_fifo_empty && (avail_words < 3'd2) &&
                      (need_words || will_continue) &&
                      (!rd_pending_q || dat_rd_valid);

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    dat_fifo_rd <= 1'b0;
  end else begin
    dat_fifo_rd <= rd_en_req;
  end
end

assign buf_push = dat_rd_valid && !buf_full;
assign buf_pop  = consume_word && !buf_empty;

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    buf_count_q  <= 2'd0;
    buf_wr_ptr   <= 1'b0;
    buf_rd_ptr   <= 1'b0;
    rd_pending_q <= 1'b0;
  end else if (start_cycle) begin
    buf_count_q  <= 2'd0;
    buf_wr_ptr   <= 1'b0;
    buf_rd_ptr   <= 1'b0;
    rd_pending_q <= 1'b0;
  end else begin
    rd_pending_q <= (rd_pending_q & ~dat_rd_valid) | rd_en_req;

    if (buf_push) begin
      buf_data[buf_wr_ptr] <= dat_fifo_out;
      buf_wr_ptr <= buf_wr_ptr + 1'b1;
    end

    if (buf_pop)
      buf_rd_ptr <= buf_rd_ptr + 1'b1;

    case ({buf_push, buf_pop})
      2'b10: buf_count_q <= buf_count_q + 1'b1;
      2'b01: buf_count_q <= buf_count_q - 1'b1;
      default: buf_count_q <= buf_count_q;
    endcase
  end
end

//---------------------------------------------------------------------------------
//
//  period/cycle counters and last pulse

// NOTE: incoming stop address is (real_stop - 4) due to upstream pipeline,
// so compensate by +4 to compute inclusive word count
assign axi_start_use = start_cycle ? set_axi_start_i : axi_start_q;
assign axi_stop_use  = start_cycle ? set_axi_stop_i  : axi_stop_q;

// The word count is a 32 bit subtract, and computing it combinationally put
// that carry chain in the middle of the datapath, in front of the last pulse
// and of the word counter reload. It only depends on configuration, so it is
// held in a register, refreshed while the reader is idle and frozen for the
// duration of a playback - which is what latching axi_start_q/axi_stop_q at
// start_cycle already did for the running cycles.
always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i)
    period_words <= '0;
  else if (rd_state_q == RD_IDLE)
    period_words <= ((set_axi_stop_i + 4 - set_axi_start_i) >> 3) + 1;
end

assign start_cycle   = (rd_state_q == RD_IDLE) && (rd_state_d != RD_IDLE);
assign restart_cycle = cycle_done && (cycle_cnt_q == 16'h1) && (trig_req || repeat_req);
assign advance_cycle = cycle_done && ((cycle_cnt_q == 16'h0) || (cycle_cnt_q > 16'h1));
assign cycle_reload  = start_cycle || restart_cycle;

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    words_left_q <= '0;
    words_last_q <= 1'b0;
    cycle_cnt_q  <= '0;
  end else begin
    if (cycle_reload) begin
      words_left_q <= period_words;
      words_last_q <= period_words == {{(AW-1){1'b0}},1'b1};
      cycle_cnt_q  <= set_cyc_cnt_i;
    end else if (advance_cycle) begin
      words_left_q <= period_words;
      words_last_q <= period_words == {{(AW-1){1'b0}},1'b1};
      if (cycle_cnt_q > 16'h1)
        cycle_cnt_q <= cycle_cnt_q - 16'h1;
    end else if (consume_word) begin
      if (|words_left_q) begin
        words_left_q <= words_left_q - 1'b1;
        words_last_q <= words_left_q == {{(AW-2){1'b0}},2'b10};
      end
    end
  end
end

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    axi_start_q <= '0;
    axi_stop_q  <= '0;
    axi_dec_q   <= 32'h0;
    dec_reload_q <= 32'h0;
  end else if (start_cycle) begin
    axi_start_q <= set_axi_start_i;
    axi_stop_q  <= set_axi_stop_i;
    axi_dec_q   <= set_axi_dec_i;
    dec_reload_q <= (set_axi_dec_i == 0) ? 32'd0 : set_axi_dec_i - 32'd1;
  end
end

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    last_pulse <= 1'b0;
  end else begin
    last_pulse <= 1'b0;
    if (cycle_done)
      last_pulse <= 1'b1;
  end
end

assign axi_last_o = last_pulse;

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    last_pre_pulse <= 1'b0;
  end else begin
    last_pre_pulse <= 1'b0;
    if ((consume_word && (words_left_q == {{(AW-2){1'b0}},2'd2})) ||
        (output_valid && dec_step &&
         (period_words == {{(AW-1){1'b0}},1'b1}) &&
         (words_left_q == {{(AW-1){1'b0}},1'b1}) &&
         (sample_index == PRE_LAST_SINGLE)))
      last_pre_pulse <= 1'b1;
  end
end

assign axi_last_pre_o = last_pre_pulse;

//---------------------------------------------------------------------------------
//
//  decimation and sample index

// Retained as the normalized active setting for observability and verification.
assign dec_safe = (axi_dec_q == 0) ? 32'd1 : axi_dec_q;

// Count remaining clocks instead of comparing an increasing counter with the
// runtime decimation value. A zero detect now drives the sample advance path;
// the registered runtime value is used only when the counter reloads. Loading
// decimation-1 preserves the original phase, including the zero-as-one setting.
// The reader cannot produce a sample on start_cycle, so registering the reload
// there removes its 32-bit subtraction from the trigger-to-counter path without
// changing any observable counter phase.
assign dec_step = ~|dec_countdown_q;
assign fifo_active = rd_state_q != RD_IDLE;
assign fifo_ready  = rd_state_q == RD_ACTIVE;
assign output_valid = fifo_ready && !buf_empty;
assign consume_word = output_valid && dec_step && (sample_index == (NUM_SAMPS-1));
assign cycle_done  = consume_word && words_last_q;
assign stop_cycle  = cycle_done && (cycle_cnt_q == 16'h1) && !(trig_req || repeat_req);
assign burst_first_sample = burst_first_pending_q && output_valid;
assign axi_first_o = burst_first_sample;

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    burst_first_pending_q <= 1'b0;
  end else if (cycle_reload) begin
    burst_first_pending_q <= 1'b1;
  end else if (burst_first_sample) begin
    burst_first_pending_q <= 1'b0;
  end
end

// cycle_reload is deliberately absent here: it is the deepest signal in this
// module and it drove the reset of all 32 counter bits for no effect. On
// start_cycle the FSM is still leaving RD_IDLE, so output_valid is low and the
// counter is reloaded below anyway; on restart_cycle the cycle ended, which
// requires dec_step and therefore takes the reload branch as well.
always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    dec_countdown_q <= 32'h0;
  end else if (!output_valid || dec_step) begin
    dec_countdown_q <= dec_reload_q;
  end else begin
    dec_countdown_q <= dec_countdown_q - 32'd1;
  end
end

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    sample_index <= 'b00;
  end else if (cycle_reload) begin
    sample_index <= 'b00;
  end else if (!fifo_ready) begin
    sample_index <= 'b00;
  end else if (output_valid && dec_step) begin
    sample_index <= sample_index + 1'b1;
  end
end

assign sample_data = buf_data[buf_rd_ptr][sample_index*16 +: 16];

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    dac_o <= '0;
  end else if (output_valid) begin
    dac_o <= sample_data[14-1:0];
  end
end

//---------------------------------------------------------------------------------
//
//  preload timer

always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    preload_timer <= 0;
  end else begin
    if (rd_state_q == RD_PRELOAD)
      preload_timer <= preload_timer + 1;
    else if (rd_state_q == RD_IDLE)
      preload_timer <= 0;
  end
end

// remember that FIFO was preloaded at least once after reset
always_ff @(posedge dac_clk_i) begin
  if (!dac_rstn_i || set_rst_i) begin
    preload_done_q <= 1'b0;
  end else if (rd_state_q == RD_PRELOAD && rd_state_d == RD_COLD_START) begin
    preload_done_q <= 1'b1;
  end
end

assign preload_done  = preload_timer >= PRELOAD_LIMIT;
assign start_pulse_o = start_cycle && !preload_done_q;

//---------------------------------------------------------------------------------
//
// status output

assign axi_state_o  =  {1'b0,            // [19:19]
                        dat_rd_fifo_lvl, // [12:18]
                        5'b0,            // [7:11]
                        1'b0,            // [6:6]
                        dat_fifo_empty,  // [5:5]
                        1'b0,            // [4:4]
                        fifo_active,     // [3:3]
                        1'b0,            // [2:2]
                        fifo_ready,      // [1:1]
                        1'b0};           // [0:0]
endmodule
