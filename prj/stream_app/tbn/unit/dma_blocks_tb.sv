// rp_dma_s2mm in the block mode with one buffer per trigger (rtl variant, stream clock = AXI
// clock): a series is exactly one buffer long, then a pause of the same length while the
// acquisition waits for the next trigger (drop strobes, flush high, as osc_top drives them;
// osc_aquire raises tlast only at the end of a normal mode capture, never at a series end).
// Every sample carries its series number and its position in the series, so a buffer must
// start with position 0 and hold one series in order. A slow consumer acknowledges some
// buffers late: the DMA overflows at the start of a series and drops its first samples
// (an overflow: lost above wait).
// A buffer out of step with the series is a FAIL, also after an overflow: the DMA drops the
// rest of a series that lost data (SERIES_WAIT), so the next series starts the free buffer
// (before, the acquisition counted the series by the samples it sent and the DMA closed a
// buffer by the words it wrote, and the buffers stayed out of step for good).
// KNOWN: the full flag of a buffer comes up to a burst before its last word reaches the memory.
`timescale 1ns / 1ps

module dma_blocks_tb;

localparam BUF_BYTES = 2048;
localparam BUF_SMP   = BUF_BYTES / 2;  // samples of a buffer and of a series
localparam DST1      = 32'h0001_0000;
localparam DST2      = 32'h0002_0000;

int unsigned DEC;
int unsigned errors = 0, checks = 0, shifted = 0, early = 0;
longint      early_max = 0;

reg clk = 0;
always #4 clk = ~clk;
reg aresetn = 0;

reg  [63:0] ts = 64'd1000;
always @(posedge clk) ts <= ts + 64'd1;

// stream: one slot every DEC clocks; a period is a series (BUF_SMP samples) and a pause
// (BUF_SMP drop strobes). The sample is {series[5:0], position[9:0]}.
reg  [15:0] tdata  = 0;
reg         tvalid = 0;
reg         tlast  = 0;
reg         sdrop  = 0;
reg         flush  = 0;
bit         run_stream = 0;
int unsigned dcnt = 0, slot = 0, series = 0;
always @(posedge clk) begin
  tvalid <= 0;
  tlast  <= 0;
  sdrop  <= 0;
  if (!run_stream) begin
    dcnt <= 0; slot <= 0; series <= 0;
    flush <= 0;
  end else begin
    if (dcnt >= DEC - 1) dcnt <= 0; else dcnt <= dcnt + 1;
    if (dcnt == 0) begin
      if (slot < BUF_SMP) begin
        tvalid <= 1;
        tdata  <= {series[5:0], slot[9:0]};
      end else
        sdrop <= 1;
      if (slot == 2 * BUF_SMP - 1) begin
        slot   <= 0;
        series <= series + 1;
      end else
        slot <= slot + 1;
    end
    flush <= (slot >= BUF_SMP);  // armed: waiting for the next trigger
  end
end

reg  [31:0] reg_wr_data = 0;
reg         reg_wr_we   = 0;
wire [31:0] reg_sts, reg_ctrl, reg_diags;
wire [63:0] buf1_ts, buf2_ts, buf1_lost, buf2_lost, buf1_wait, buf2_wait;

wire [31:0] awaddr;  wire [7:0] awlen;  wire awvalid;  reg awready = 0;
wire [63:0] wdata;   wire wlast;        wire wvalid;   reg wready  = 0;
reg  [1:0]  bresp = 0; reg bvalid = 0;  wire bready;

rp_dma_s2mm #(.AXI_ADDR_BITS(32), .AXI_DATA_BITS(64), .AXIS_DATA_BITS(16), .AXI_BURST_LEN(16)) dut (
  .m_axi_aclk (clk), .s_axis_aclk (clk), .aresetn (aresetn),
  .busy (), .intr (), .mode (),
  .reg_wr_data (reg_wr_data), .reg_wr_we (reg_wr_we),
  .reg_ctrl (reg_ctrl), .reg_sts (reg_sts), .reg_diags (reg_diags),
  .reg_dst_addr1 (DST1), .reg_dst_addr2 (DST2), .reg_buf_size (BUF_BYTES),
  .timestamp_counter (ts), .timestamp_init (64'd0), .timestamp_init_we (1'b0),
  .ctl_start_o (), .ctl_start_ext (1'b0), .use_8bit (1'b0),
  .buf1_timestamp (buf1_ts), .buf2_timestamp (buf2_ts),
  .s_axis_drop (sdrop), .s_axis_flush (flush), .s_axis_series (1'b1), .buf1_lost (buf1_lost), .buf2_lost (buf2_lost),
  .buf1_wait (buf1_wait), .buf2_wait (buf2_wait),
  .buf_sel_in (1'b0), .buf_sel_out (),
  .m_axi_awaddr (awaddr), .m_axi_awlen (awlen), .m_axi_awsize (), .m_axi_awburst (),
  .m_axi_awprot (), .m_axi_awcache (), .m_axi_awvalid (awvalid), .m_axi_awready (awready),
  .m_axi_wdata (wdata), .m_axi_wstrb (), .m_axi_wlast (wlast), .m_axi_wvalid (wvalid),
  .m_axi_wready (wready), .m_axi_bresp (bresp), .m_axi_bvalid (bvalid), .m_axi_bready (bready),
  .s_axis_tdata (tdata), .s_axis_tvalid (tvalid), .s_axis_tready (), .s_axis_tlast (tlast));

// AXI slave with random stalls
logic [63:0] mem [int unsigned];
int unsigned aw_q [$];
int unsigned waddr;
longint unsigned last_wr[2] = '{0, 0};  // clock of the last word written into each buffer
bit          wbusy = 0;
int unsigned pend_b = 0;
always @(posedge clk) begin
  awready <= ($urandom % 4) != 0;
  if (awvalid && awready) aw_q.push_back(awaddr);
  if (wvalid && wready) begin
    if (!wbusy) begin
      waddr = aw_q.pop_front();
      wbusy = 1;
    end
    mem[waddr] = wdata;
    if (waddr == DST1 + BUF_BYTES - 8) last_wr[0] = $time / 8;
    if (waddr == DST2 + BUF_BYTES - 8) last_wr[1] = $time / 8;
    waddr += 8;
    if (wlast) begin
      wbusy = 0;
      pend_b++;
    end
  end
  wready <= (($urandom % 3) != 0) && (wbusy || (aw_q.size() > 0));
  if (bvalid && bready) bvalid <= 0;
  else if (!bvalid && pend_b > 0) begin bvalid <= 1; pend_b--; end
end

task automatic wr(input [31:0] v);
  @(posedge clk); reg_wr_data <= v; reg_wr_we <= 1;
  @(posedge clk); reg_wr_we <= 0;
endtask

function automatic [15:0] smp(input int unsigned addr, input int unsigned k);
  logic [63:0] w = mem[addr + (k / 4) * 8];
  return w[(k % 4) * 16 +: 16];
endfunction

// a buffer holds one series from its start: position 0 first, then in order, one series number
task automatic check_buf(input int unsigned addr, input [63:0] lost, input int idx, input bit after_hole);
  // after_hole: an overflow in this buffer or one before it
  logic [15:0] s0 = smp(addr, 0);
  int unsigned bad = 0, first_bad = 0;
  checks++;
  for (int k = 1; k < BUF_SMP; k++) begin
    logic [9:0] pos = s0[9:0] + k[9:0];
    if (smp(addr, k) !== {s0[15:10], pos}) begin
      if (bad == 0) first_bad = k;
      bad++;
    end
  end
  if (s0[9:0] != 0 || bad) begin
    errors++;
    if (after_hole)
      shifted++;
    if (errors <= 5) begin
      $display("FAIL buffer %0d: starts at position %0d of series %0d, %0d samples out of order (first at %0d), lost %0d%s",
               idx, s0[9:0], s0[15:10], bad, first_bad, lost, after_hole ? ", after an overflow" : "");
    end
  end
endtask

task automatic run(input int unsigned dec, input int unsigned nbuf, input int unsigned slow);
  int unsigned got = 0, holes = 0;
  bit hole_seen = 0;
  DEC = dec;
  $display("info  run: decimation %0d, %0d buffers, %0d %% late", dec, nbuf, slow);
  aresetn = 0; run_stream = 0; repeat (20) @(posedge clk); aresetn = 1; repeat (20) @(posedge clk);
  mem.delete();
  wr(32'h0000_0200);  // streaming mode
  wr(32'h0000_0001);  // start
  repeat (500) @(posedge clk);  // the first trigger comes after the start
  run_stream = 1;
  while (got < nbuf) begin
    for (int b = 0; b < 2 && got < nbuf; b++) begin
      begin
        int unsigned to = 0;
        while (!reg_sts[b]) begin
          @(posedge clk);
          if (++to > 40 * BUF_SMP * dec) begin
            errors++;
            $display("FAIL hang: no buffer %0d for %0d clocks after %0d buffers, sts 0x%02h diags 0x%08h (state %0d)",
                     b + 1, to, got, reg_sts[7:0], reg_diags, reg_diags[2:0]);
            $display("FAIL dma_blocks_tb: %0d errors in %0d buffers", errors, checks);
            $finish;
          end
        end
      end
      begin
        // the last burst may still be on its way: wait more than a burst of samples
        longint t_full = $time / 8;
        repeat (16 * 4 * dec + 200) @(posedge clk);
        if (longint'(last_wr[b]) > t_full) begin
          early++;
          if (longint'(last_wr[b]) - t_full > early_max) early_max = longint'(last_wr[b]) - t_full;
        end
      end
      // sometimes too slow: the other buffer is still full when the next series starts
      if (($urandom % 100) < slow) repeat (BUF_SMP * dec * (2 + $urandom % 3)) @(posedge clk);
      if ((b == 0 ? buf1_lost : buf2_lost) > (b == 0 ? buf1_wait : buf2_wait)) begin
        holes++;
        hole_seen = 1;
      end
      check_buf(b == 0 ? DST1 : DST2, b == 0 ? buf1_lost : buf2_lost, got, hole_seen);
      wr(b == 0 ? 32'h0000_0006 : 32'h0000_000A);  // buffer ACK + interrupt ACK
      got++;
    end
  end
  $display("ok    decimation %0d: %0d buffers, %0d with an overflow before them", dec, got, holes);
  run_stream = 0;
  wr(32'h0000_0010);  // reset
endtask

initial begin
  run(8, 20, 0);    // no overflow: every buffer is one series
  run(8, 40, 20);   // late ACKs: overflows at the start of a series
  if (shifted) $display("FAIL %0d of %0d buffers out of step with the series after an overflow", shifted, checks);
  if (early)   $display("KNOWN %0d of %0d buffers full up to %0d clocks before their last word is written", early, checks, early_max);
  if (errors == 0) $display("PASS dma_blocks_tb (%0d buffers checked)", checks);
  else             $display("FAIL dma_blocks_tb: %0d errors in %0d buffers", errors, checks);
  $finish;
end

endmodule
