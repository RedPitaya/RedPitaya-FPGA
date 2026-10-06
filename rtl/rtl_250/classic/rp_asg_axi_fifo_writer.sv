/*
  AXI -> FIFO writer for ASG
  - Receives start/stop requests in DAC clock domain
  - Keeps the FIFO filled with multiple outstanding AXI read bursts
  - Wraps only on the last accepted beat and flushes stale data on restart
*/

module rp_asg_axi_fifo_writer #(
  parameter int DW = 64,
  parameter int AW = 32,
  parameter int LW = 4,
  parameter int AXI_BURST_LEN = 16,
  parameter int DATA_REQUEST_LEVEL = 128-16,
  parameter int WR_LVL_W = 7,
  parameter int MAX_OUTSTANDING_BURSTS = 8
)(
  input  logic               dac_clk_i,
  input  logic               dac_rstn_i,
  input  logic               start_pulse_i,
  input  logic               set_rst_i,
  input  logic [AW-1:0]      set_axi_start_i,
  input  logic [AW-1:0]      set_axi_stop_i,
  axi_sys_if.s               axi_sys,

  // FIFO write-side interface
  output logic [DW-1:0]      dat_fifo_idata,
  output logic               dat_fifo_wr,
  input  logic               dat_fifo_full,
  input  logic [WR_LVL_W-1:0] dat_wr_fifo_lvl,
  input  logic               dat_fifo_rst_busy,
  output logic               axi_fifo_reset
);

//---------------------------------------------------------------------------------

localparam int DWB = DW/8;
localparam int AXI_ADDR_SHIFT = $clog2(DWB);
localparam logic [2:0] AXI_RSIZE = 3'h3; // 8 bytes per beat for 64-bit data
localparam int REQ_W = 128;
localparam int ISSUE_BEAT_W = (AXI_BURST_LEN > 1) ? $clog2(AXI_BURST_LEN + 1) : 1;
localparam int OUTSTANDING_BEATS_MAX = MAX_OUTSTANDING_BURSTS * AXI_BURST_LEN;
localparam int OUT_BEAT_W = (OUTSTANDING_BEATS_MAX > 1) ? $clog2(OUTSTANDING_BEATS_MAX + 1) : 1;
localparam int OUT_BURST_W = (MAX_OUTSTANDING_BURSTS > 1) ? $clog2(MAX_OUTSTANDING_BURSTS + 1) : 1;
localparam int EXPECT_LVL_W = (((1 << WR_LVL_W) + OUTSTANDING_BEATS_MAX) > 1) ?
                              $clog2((1 << WR_LVL_W) + OUTSTANDING_BEATS_MAX + 1) : 1;

typedef enum logic [1:0] {
  WR_IDLE,
  WR_INIT,
  WR_RUN,
  WR_FLUSH
} wr_state_t;

wr_state_t wr_state_q;
wr_state_t wr_state_d;

logic [AW-1:0] start_addr_q;
logic [AW-1:0] stop_addr_q;
logic [AW-1:0] issue_addr_q;
logic [AW-1:0] req_next_addr_q;
logic [AW-1:0] req_next_words_q;
logic [AW-1:0] stream_addr_q;
logic [AW-1:0] current_beat_addr_q;
logic [1:0]    init_cnt_q;
logic [AW-1:0] stop_addr_eff_q;
logic [AW-1:0] words_diff_q;
logic [AW-1:0] period_words_q;
logic          addr_range_valid_q;

logic [ISSUE_BEAT_W-1:0] issue_beats_c;
logic [ISSUE_BEAT_W-1:0] req_beats_q;
logic [LW-1:0] issue_len_c;
logic [AW-1:0] issue_words_left_q;
logic [AW-1:0] issue_addr_next_c;
logic [AW-1:0] issue_words_next_c;
logic [AW-1:0] stream_words_left_q;

logic [OUT_BEAT_W-1:0]  outstanding_beats_q;
logic [OUT_BURST_W-1:0] outstanding_bursts_q;
logic [EXPECT_LVL_W-1:0] expected_fifo_lvl;

logic fsm_reset_sync;
logic ar_accept;
logic beat_accept;
logic prefetch_issue;
logic wrap_pulse_q;
logic first_beat_new_period_q;

//---------------------------------------------------------------------------------
//
//  addr cfg sync for axi

logic             req_valid;
logic             req_empty;
logic [REQ_W-1:0] req_payload;
logic [REQ_W-1:0] req_fifo_out;
logic [REQ_W-1:0] req_data_q;
logic [AW-1:0]    req_start_addr;
logic [AW-1:0]    req_stop_addr;

wire req_pop = (wr_state_q == WR_IDLE) && !req_empty && !fsm_reset_sync;

assign req_payload = {{(REQ_W-2*AW){1'b0}}, set_axi_start_i, set_axi_stop_i};

sync_fifo inst_sync_fifo
(
  .wr_clk         (dac_clk_i         ),
  .rd_clk         (axi_sys.clk       ),
  .rst            (!dac_rstn_i || set_rst_i),
  .din            (req_payload       ),
  .wr_en          (start_pulse_i     ),
  .full           (                  ),
  .dout           (req_fifo_out      ),
  .rd_en          (req_pop           ),
  .empty          (req_empty         ),
  .valid          (req_valid         ),
  .wr_rst_busy    (                  ),
  .rd_rst_busy    (                  )
);

assign req_start_addr      = req_data_q[1*AW +: AW];
assign req_stop_addr       = req_data_q[0*AW +: AW];

always_ff @(posedge axi_sys.clk) begin
  if (!axi_sys.rstn) begin
    req_data_q <= '0;
  end else if (req_valid) begin
    req_data_q <= req_fifo_out;
  end
end

//---------------------------------------------------------------------------------
//
//  FSM reset sync

(* ASYNC_REG = "TRUE" *) logic fsm_reset_ff1;
(* ASYNC_REG = "TRUE" *) logic fsm_reset_ff2;

always_ff @(posedge axi_sys.clk) begin
  if (!axi_sys.rstn) begin
    fsm_reset_ff1 <= 1'b0;
    fsm_reset_ff2 <= 1'b0;
  end else begin
    fsm_reset_ff1 <= set_rst_i;
    fsm_reset_ff2 <= fsm_reset_ff1;
  end
end

assign fsm_reset_sync = fsm_reset_ff2;

//---------------------------------------------------------------------------------
//
//  FSM

always_ff @(posedge axi_sys.clk) begin
  if (!axi_sys.rstn)
    wr_state_q <= WR_IDLE;
  else
    wr_state_q <= wr_state_d;
end

always_ff @(posedge axi_sys.clk) begin
  if (!axi_sys.rstn)
    init_cnt_q <= '0;
  else if (wr_state_q != WR_INIT)
    init_cnt_q <= '0;
  else if (init_cnt_q != 2'd3)
    init_cnt_q <= init_cnt_q + 1'b1;
end

always_comb begin : fsm_axi_read
  wr_state_d = wr_state_q;

  unique case (wr_state_q)
    WR_IDLE: begin
      if (req_valid)
        wr_state_d = WR_INIT;
    end

    WR_INIT: begin
      if (fsm_reset_sync)
        wr_state_d = WR_FLUSH;
      else if (!dat_fifo_rst_busy && (init_cnt_q == 2'd3))
        wr_state_d = WR_RUN;
    end

    WR_RUN: begin
      if (fsm_reset_sync)
        wr_state_d = WR_FLUSH;
    end

    WR_FLUSH: begin
      if (outstanding_beats_q == {OUT_BEAT_W{1'b0}})
        wr_state_d = WR_IDLE;
    end

    default: begin
      wr_state_d = WR_IDLE;
    end
  endcase
end

//---------------------------------------------------------------------------------
//
//  Request generation

// Compute the period once at startup.  Each arithmetic operation has its own
// cycle; combining all three produced a 5.87 ns path in the 250 MHz domain.
always_ff @(posedge axi_sys.clk) begin
  if (!axi_sys.rstn) begin
    stop_addr_eff_q   <= '0;
    words_diff_q      <= '0;
    period_words_q    <= '0;
    addr_range_valid_q <= 1'b0;
  end else begin
    stop_addr_eff_q    <= req_stop_addr + AW'(32'd4);
    words_diff_q       <= stop_addr_eff_q - req_start_addr;
    addr_range_valid_q <= req_start_addr <= stop_addr_eff_q;
    period_words_q     <= addr_range_valid_q
                        ? (words_diff_q >> AXI_ADDR_SHIFT) + 1'b1
                        : '0;
  end
end

always_comb begin

  if (issue_words_left_q > AXI_BURST_LEN)
    issue_beats_c = ISSUE_BEAT_W'(AXI_BURST_LEN);
  else
    issue_beats_c = issue_words_left_q[ISSUE_BEAT_W-1:0];

  issue_len_c = issue_beats_c - 1'b1;

  if (issue_words_left_q <= AXI_BURST_LEN) begin
    issue_addr_next_c = start_addr_q;
    issue_words_next_c = period_words_q;
  end else begin
    issue_addr_next_c = issue_addr_q + AW'(AXI_BURST_LEN * DWB);
    issue_words_next_c = issue_words_left_q - AW'(AXI_BURST_LEN);
  end
end

always_comb begin
  expected_fifo_lvl = EXPECT_LVL_W'(dat_wr_fifo_lvl) + EXPECT_LVL_W'(outstanding_beats_q);
end

assign prefetch_issue = (wr_state_q == WR_RUN) &&
                        !fsm_reset_sync &&
                        !axi_sys.rvalid &&
                        (issue_words_left_q != {AW{1'b0}}) &&
                        (outstanding_bursts_q < MAX_OUTSTANDING_BURSTS) &&
                        (expected_fifo_lvl <= DATA_REQUEST_LEVEL);

assign ar_accept   = axi_sys.ARtransfer;
assign beat_accept = axi_sys.Rtransfer;

always_ff @(posedge axi_sys.clk) begin
  if (!axi_sys.rstn) begin
    start_addr_q     <= '0;
    stop_addr_q      <= '0;
    issue_addr_q     <= '0;
    req_next_addr_q  <= '0;
    req_next_words_q <= '0;
    issue_words_left_q <= '0;
    req_beats_q      <= '0;
    axi_sys.raddr    <= '0;
    axi_sys.rlen     <= '0;
    axi_sys.rvalid   <= 1'b0;
  end else begin
    if (wr_state_q == WR_INIT) begin
      start_addr_q    <= req_start_addr;
      stop_addr_q     <= req_stop_addr;
      issue_addr_q    <= req_start_addr;
      req_next_addr_q <= req_start_addr;
      req_next_words_q <= period_words_q;
      issue_words_left_q <= period_words_q;
      req_beats_q     <= '0;
      axi_sys.raddr   <= req_start_addr;
      axi_sys.rlen    <= '0;
      axi_sys.rvalid  <= 1'b0;
    end else if (wr_state_d == WR_FLUSH) begin
      axi_sys.rvalid <= 1'b0;
    end else begin
      if (ar_accept) begin
        axi_sys.rvalid <= 1'b0;
        issue_addr_q   <= req_next_addr_q;
        issue_words_left_q <= req_next_words_q;
      end else if (prefetch_issue) begin
        axi_sys.raddr   <= issue_addr_q;
        axi_sys.rlen    <= issue_len_c;
        axi_sys.rvalid  <= 1'b1;
        req_beats_q     <= issue_beats_c;
        req_next_addr_q <= issue_addr_next_c;
        req_next_words_q <= issue_words_next_c;
      end
    end
  end
end

//---------------------------------------------------------------------------------
//
//  Outstanding trackers

always_ff @(posedge axi_sys.clk) begin
  if (!axi_sys.rstn) begin
    outstanding_beats_q  <= '0;
    outstanding_bursts_q <= '0;
  end else if (wr_state_q == WR_INIT) begin
    outstanding_beats_q  <= '0;
    outstanding_bursts_q <= '0;
  end else begin
    unique case ({ar_accept, beat_accept})
      2'b10: outstanding_beats_q <= outstanding_beats_q + OUT_BEAT_W'(req_beats_q);
      2'b01: outstanding_beats_q <= outstanding_beats_q - OUT_BEAT_W'(1);
      2'b11: outstanding_beats_q <= outstanding_beats_q + OUT_BEAT_W'(req_beats_q) - OUT_BEAT_W'(1);
      default: outstanding_beats_q <= outstanding_beats_q;
    endcase

    unique case ({ar_accept, beat_accept && axi_sys.rlast})
      2'b10: outstanding_bursts_q <= outstanding_bursts_q + OUT_BURST_W'(1);
      2'b01: outstanding_bursts_q <= outstanding_bursts_q - OUT_BURST_W'(1);
      2'b11: outstanding_bursts_q <= outstanding_bursts_q;
      default: outstanding_bursts_q <= outstanding_bursts_q;
    endcase
  end
end

//---------------------------------------------------------------------------------
//
//  Actual accepted data stream tracking

always_ff @(posedge axi_sys.clk) begin
  if (!axi_sys.rstn) begin
    stream_addr_q             <= '0;
    stream_words_left_q       <= '0;
    current_beat_addr_q       <= '0;
    wrap_pulse_q              <= 1'b0;
    first_beat_new_period_q   <= 1'b0;
  end else begin
    wrap_pulse_q            <= 1'b0;
    first_beat_new_period_q <= 1'b0;

    if (wr_state_q == WR_INIT) begin
      stream_addr_q       <= req_start_addr;
      stream_words_left_q <= period_words_q;
      current_beat_addr_q <= req_start_addr;
    end else if ((wr_state_q == WR_RUN) && beat_accept) begin
      current_beat_addr_q     <= stream_addr_q;
      first_beat_new_period_q <= stream_addr_q == start_addr_q;

      if (stream_words_left_q == AW'(1)) begin
        wrap_pulse_q <= 1'b1;
        stream_addr_q <= start_addr_q;
        stream_words_left_q <= period_words_q;
      end else begin
        stream_addr_q <= stream_addr_q + DWB;
        stream_words_left_q <= stream_words_left_q - AW'(1);
      end
    end
  end
end

//---------------------------------------------------------------------------------
//
//  AXI interface

assign axi_sys.rfixed = 1'b0;
assign axi_sys.rsize  = AXI_RSIZE;
assign axi_sys.rsel   = {DW/8{1'b1}};
assign axi_sys.rrdys  = (wr_state_q == WR_RUN) ? !dat_fifo_full : 1'b1;

assign dat_fifo_idata = axi_sys.rdata;
assign dat_fifo_wr    = beat_accept && (wr_state_q == WR_RUN);
assign axi_fifo_reset = wr_state_q == WR_IDLE;

//---------------------------------------------------------------------------------
//
//  AXI-clock diagnostics for ILA hookup

logic restart_flush_active;
(* mark_debug = "true" *) logic                dbg_arvalid;
(* mark_debug = "true" *) logic                dbg_arready;
(* mark_debug = "true" *) logic [AW-1:0]       dbg_araddr;
(* mark_debug = "true" *) logic [LW-1:0]       dbg_arlen;
(* mark_debug = "true" *) logic                dbg_rvalid;
(* mark_debug = "true" *) logic                dbg_rready;
(* mark_debug = "true" *) logic                dbg_rlast;
(* mark_debug = "true" *) logic [OUT_BURST_W-1:0] dbg_outstanding_bursts;
(* mark_debug = "true" *) logic [OUT_BEAT_W-1:0]  dbg_outstanding_beats;
(* mark_debug = "true" *) logic [EXPECT_LVL_W-1:0] dbg_expected_fifo_lvl;
(* mark_debug = "true" *) logic [WR_LVL_W-1:0] dbg_dat_wr_fifo_lvl;
(* mark_debug = "true" *) logic [AW-1:0]       dbg_writer_addr;
(* mark_debug = "true" *) logic                dbg_wrap;
(* mark_debug = "true" *) logic                dbg_restart_flush_active;
(* mark_debug = "true" *) logic                dbg_first_beat_new_period;

assign restart_flush_active = wr_state_q == WR_FLUSH;
assign dbg_arvalid               = axi_sys.rvalid;
assign dbg_arready               = axi_sys.rardy;
assign dbg_araddr                = axi_sys.raddr;
assign dbg_arlen                 = axi_sys.rlen;
assign dbg_rvalid                = axi_sys.rrdym;
assign dbg_rready                = axi_sys.rrdys;
assign dbg_rlast                 = axi_sys.rlast;
assign dbg_outstanding_bursts    = outstanding_bursts_q;
assign dbg_outstanding_beats     = outstanding_beats_q;
assign dbg_expected_fifo_lvl     = expected_fifo_lvl;
assign dbg_dat_wr_fifo_lvl       = dat_wr_fifo_lvl;
assign dbg_writer_addr           = current_beat_addr_q;
assign dbg_wrap                  = wrap_pulse_q;
assign dbg_restart_flush_active  = restart_flush_active;
assign dbg_first_beat_new_period = first_beat_new_period_q;

// Suggested probes:
//   axi_sys.rvalid / axi_sys.rardy / axi_sys.raddr / axi_sys.rlen
//   axi_sys.rrdym / axi_sys.rrdys / axi_sys.rlast
//   outstanding_bursts_q / outstanding_beats_q
//   dat_wr_fifo_lvl
//   current_beat_addr_q / wrap_pulse_q
//   restart_flush_active / first_beat_new_period_q

endmodule
