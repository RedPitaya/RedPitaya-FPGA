// rp_dma_s2mm buffer timestamps and lost counter (rtl variant, stream clock = AXI clock).
// Every sample is the low 16 bits of the timestamp counter at its input, so the first
// sample of a buffer in memory must equal the low bits of the buffer timestamp, and the
// lost counter of a buffer must equal the gap in the data before it.
// The AXI slave stalls at random and a slow consumer acknowledges the buffers late, so the
// DMA drops data, resets its FIFO and restarts in the middle of bursts. Breaks inside a
// buffer (the overflow handling of the DMA) are counted, not failed.
// Gaps imitate the block mode: drop strobes instead of samples, as while the acquisition
// waits for a trigger. They are counted as lost and also as wait: without an overflow the
// wait of a buffer is exactly the dropped slots between the last sample of the buffer before
// and its first one (the bench keeps their timestamps), without gaps it is 0.
`timescale 1ns / 1ps

module dma_ts_tb;

localparam BUF_BYTES = 4096;
localparam BUF_SMP   = BUF_BYTES / 2;
localparam DST1      = 32'h0001_0000;
localparam DST2      = 32'h0002_0000;

int unsigned DEC;
int unsigned GAPS;  // 0: no gaps, else a gap after about this many samples
int unsigned SLOW;
int unsigned errors = 0, checks = 0, breaks = 0;

reg clk = 0;
always #4 clk = ~clk;
reg aresetn = 0;

reg  [63:0] ts = 64'd1000;
always @(posedge clk) ts <= ts + 64'd1;

// stream: one sample every DEC clocks, the value is the timestamp at the input
reg  [15:0] tdata  = 0;
reg         tvalid = 0;
reg         sdrop  = 0;
int unsigned dcnt = 0, gap_left = 0, since_gap = 0;
longint unsigned drops[$];  // timestamps of the dropped slots, as a sample would carry them
always @(posedge clk) begin
  if (dcnt >= DEC - 1) dcnt <= 0; else dcnt <= dcnt + 1;
  tvalid <= (dcnt == 0) && (gap_left == 0);
  sdrop  <= (dcnt == 0) && (gap_left != 0);
  if ((dcnt == 0) && (gap_left != 0)) drops.push_back(ts + 64'd1);
  if (dcnt == 0) begin
    if (gap_left != 0)
      gap_left <= gap_left - 1;
    else if ((GAPS != 0) && (since_gap >= GAPS)) begin
      gap_left  <= 1 + $urandom % (3 * BUF_SMP);
      since_gap <= 0;
    end else
      since_gap <= since_gap + 1;
  end
  tdata  <= ts[15:0] + 16'd1;  // the timestamp seen by the DMA when tvalid is high
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
  .s_axis_drop (sdrop), .s_axis_flush (1'b0), .s_axis_series (1'b0), .series_lost_o (), .series_drop_i (1'b0), .buf1_lost (buf1_lost), .buf2_lost (buf2_lost),
  .buf1_wait (buf1_wait), .buf2_wait (buf2_wait),
  .buf_sel_in (1'b0), .buf_sel_out (),
  .m_axi_awaddr (awaddr), .m_axi_awlen (awlen), .m_axi_awsize (), .m_axi_awburst (),
  .m_axi_awprot (), .m_axi_awcache (), .m_axi_awvalid (awvalid), .m_axi_awready (awready),
  .m_axi_wdata (wdata), .m_axi_wstrb (), .m_axi_wlast (wlast), .m_axi_wvalid (wvalid),
  .m_axi_wready (wready), .m_axi_bresp (bresp), .m_axi_bvalid (bvalid), .m_axi_bready (bready),
  .s_axis_tdata (tdata), .s_axis_tvalid (tvalid), .s_axis_tready (), .s_axis_tlast (1'b0));

// AXI slave with random stalls
logic [63:0] mem [int unsigned];
int unsigned aw_q [$];
int unsigned waddr;
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
    waddr += 8;
    if (wlast) begin
      wbusy = 0;
      pend_b++;
    end
  end
  // a write beat only with its address accepted (W may come before AW on AXI)
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

logic [15:0] prev_last;  // last sample of the previous buffer

task automatic check_buf(input int unsigned addr, input [63:0] bts, input [63:0] lost, input [63:0] wt,
                         inout [63:0] prev_ts, inout bit have_prev, input int idx);
  int unsigned bad = 0;
  logic [15:0] dgap, lgap;
  checks++;
  // the wait is part of the lost count: the dropped slots between this buffer and the one before
  begin
    longint unsigned last = prev_ts + (BUF_SMP - 1) * DEC;  // last sample of the buffer before
    int unsigned exp_wait = 0;
    while (drops.size() && drops[0] < bts) begin
      if (have_prev && drops[0] > last) exp_wait++;
      void'(drops.pop_front());
    end
    if (wt > lost || (GAPS == 0 && wt != 0) || (have_prev && wt != exp_wait)) begin
      errors++;
      $display("FAIL buffer %0d: wait %0d, dropped slots %0d, lost %0d (gaps %0d)", idx, wt, exp_wait, lost, GAPS);
    end
  end
  // the data gives the true gap modulo 2^16: the lost counter and the timestamps against it
  if (have_prev) begin
    dgap = smp(addr, 0) - prev_last - 16'(DEC);
    lgap = 16'(lost * DEC);
    if (lgap != dgap) begin
      errors++;
      $display("FAIL buffer %0d: lost %0d samples, the data says %0d (modulo 2^16 / %0d)", idx, lost, $signed(dgap) / $signed(DEC), DEC);
    end
  end
  prev_last = smp(addr, BUF_SMP - 1);
  if (smp(addr, 0) !== bts[15:0]) begin
    errors++;
    $display("FAIL buffer %0d: first sample 0x%04h, timestamp 0x%016h", idx, smp(addr, 0), bts);
  end
  for (int k = 1; k < BUF_SMP; k++) begin
    logic [15:0] step = smp(addr, k) - smp(addr, k - 1);
    if (step != DEC[15:0]) begin
      bad++;
    end
  end
  if (bad) breaks++;
  // after a break inside the buffer its last sample says nothing about the next gap
  prev_ts = bts; have_prev = (bad == 0);
endtask

task automatic run(input int unsigned dec, input int unsigned nbuf, input int unsigned slow, input int unsigned gaps);
  logic [63:0] prev_ts; bit have_prev = 0;
  int unsigned got = 0, holes = 0, ovf = 0, wait_cl;
  DEC = dec;
  GAPS = gaps;
  SLOW = slow;
  aresetn = 0; repeat (20) @(posedge clk); aresetn = 1; repeat (20) @(posedge clk);
  mem.delete();
  drops.delete();
  wr(32'h0000_0200);  // streaming mode
  wr(32'h0000_0001);  // start
  while (got < nbuf) begin
    // the consumer: buffers are handed out in turn
    for (int b = 0; b < 2 && got < nbuf; b++) begin
      wait_cl = 0;
      while (!reg_sts[b]) begin @(posedge clk); wait_cl++; end
      // let the last burst reach the memory
      repeat (200) @(posedge clk);
      // sometimes too slow: the other buffer fills meanwhile and the DMA drops data
      if (($urandom % 100) < slow) repeat (BUF_SMP * dec * (1 + $urandom % 3)) @(posedge clk);
      // an overflowed buffer (written again before its ACK) is not checked and breaks the chain
      if (reg_sts[2 + b]) begin
        have_prev = 0;
        ovf++;
      end else if (b == 0) check_buf(DST1, buf1_ts, buf1_lost, buf1_wait, prev_ts, have_prev, got);
      else                 check_buf(DST2, buf2_ts, buf2_lost, buf2_wait, prev_ts, have_prev, got);
      if ((b == 0 ? buf1_lost : buf2_lost) != 0) holes++;
      wr(b == 0 ? 32'h0000_0006 : 32'h0000_000A);  // buffer ACK + interrupt ACK
      got++;
    end
  end
  $display("ok    decimation %0d%s: %0d buffers, %0d after a hole, %0d overflowed (not checked)", dec, gaps ? ", gaps" : "", got, holes, ovf);
  wr(32'h0000_0010);  // reset
endtask

initial begin
  run(1, 40, 30, 0);
  run(4, 30, 30, 0);
  run(64, 12, 40, 0);
  run(1, 40, 0, 3000);   // gaps, no overflow: wait = lost
  run(4, 30, 0, 2000);
  run(1, 40, 30, 3000);  // gaps and overflow: wait <= lost
  if (breaks) $display("KNOWN buffers with a break inside (DMA overflow handling): %0d of %0d", breaks, checks);
  if (errors == 0) $display("PASS dma_ts_tb (%0d buffers checked)", checks);
  else             $display("FAIL dma_ts_tb: %0d errors in %0d buffers", errors, checks);
  $finish;
end

endmodule
