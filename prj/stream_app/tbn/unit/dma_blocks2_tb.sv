// Two rp_dma_s2mm in the block mode with one buffer per trigger, wired as in rp_oscilloscope
// (rtl variant, stream clock = AXI clock): a series is exactly one buffer long, then a pause of
// the same length (drop strobes, flush high). Both channels get the same samples, {series[5:0],
// position[9:0]}. The software takes a buffer when it is full in both channels (0x54) and
// releases it in both. The AXI port of CH2 stops now and then for a long time (the HP port
// load of the 250-12): its FIFO overflows while CH1 writes on; in the last runs both ports stop.
// A write outside the two buffers is a FAIL.
// Every buffer must hold one series from its start, and the buffers of one index the same
// series in both channels: channels a buffer apart (one dropped a series the other wrote) or a
// buffer out of step with the series is a FAIL.
`timescale 1ns / 1ps

module dma_blocks2_tb;

localparam BUF_BYTES = 2048;
localparam int BUF_SMP = BUF_BYTES / 2;
localparam DST1      = 32'h0001_0000;
localparam DST2      = 32'h0002_0000;
localparam CH_OFS    = 32'h0010_0000;

int unsigned DEC;
int unsigned errors = 0, checks = 0, apart = 0, shifted = 0;
bit          port2_stalls = 0, port1_stalls = 0;
int unsigned flush_early = 0;  // the arm (flush) rises this many clocks before the last sample of a series

reg clk = 0;
always #4 clk = ~clk;
reg aresetn = 0;

reg  [63:0] ts = 64'd1000;
always @(posedge clk) ts <= ts + 64'd1;

reg  [15:0] tdata  = 0;
reg         tvalid = 0;
reg         sdrop  = 0;
reg         flush  = 0;
bit         run_stream = 0;
int unsigned dcnt = 0, slot = 0, series = 0;
always @(posedge clk) begin
  tvalid <= 0;
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
    // the arm can come a few clocks before the last sample reaches the DMA (registers on the way)
    flush <= (slot >= BUF_SMP) || (flush_early > 0 && slot == BUF_SMP - 1 && dcnt + flush_early >= DEC);
  end
end

reg  [31:0] reg_wr_data = 0;
reg         reg_wr_we   = 0;
wire [31:0] sts [2];
wire [31:0] diags [2];
wire [63:0] lost [2][2];
wire [63:0] waitc [2][2];
wire [1:0]  sel;
wire [1:0]  ser_lost;  // ORed into the series drop of both, as rp_oscilloscope does
wire [1:0]  sw_full = sts[0][1:0] & sts[1][1:0];

logic [63:0] mem [2][int unsigned];

genvar C;
generate
for (C = 0; C < 2; C++) begin : ch
  wire [31:0] awaddr;  wire [7:0] awlen;  wire awvalid;  reg awready = 0;
  wire [63:0] wdata;   wire wlast;        wire wvalid;   reg wready  = 0;
  reg         bvalid = 0;  wire bready;
  int unsigned aw_q [$];
  int unsigned waddr, pend_b = 0, stall = 0;
  bit          wbusy = 0;

  rp_dma_s2mm #(.AXI_ADDR_BITS(32), .AXI_DATA_BITS(64), .AXIS_DATA_BITS(16), .AXI_BURST_LEN(16)) dut (
    .m_axi_aclk (clk), .s_axis_aclk (clk), .aresetn (aresetn),
    .busy (), .intr (), .mode (),
    .reg_wr_data (reg_wr_data), .reg_wr_we (reg_wr_we),
    .reg_ctrl (), .reg_sts (sts[C]), .reg_diags (diags[C]),
    .reg_dst_addr1 (DST1 + C * CH_OFS), .reg_dst_addr2 (DST2 + C * CH_OFS), .reg_buf_size (BUF_BYTES),
    .timestamp_counter (ts), .timestamp_init (64'd0), .timestamp_init_we (1'b0),
    .ctl_start_o (), .ctl_start_ext (1'b0), .use_8bit (1'b0),
    .buf1_timestamp (), .buf2_timestamp (),
    .s_axis_drop (sdrop), .s_axis_flush (flush), .s_axis_series (1'b1),
    .series_lost_o (ser_lost[C]), .series_drop_i (|ser_lost),
    .buf1_lost (lost[C][0]), .buf2_lost (lost[C][1]), .buf1_wait (waitc[C][0]), .buf2_wait (waitc[C][1]),
    .buf_sel_in (sel[1 - C]), .buf_sel_out (sel[C]),
    .m_axi_awaddr (awaddr), .m_axi_awlen (awlen), .m_axi_awsize (), .m_axi_awburst (),
    .m_axi_awprot (), .m_axi_awcache (), .m_axi_awvalid (awvalid), .m_axi_awready (awready),
    .m_axi_wdata (wdata), .m_axi_wstrb (), .m_axi_wlast (wlast), .m_axi_wvalid (wvalid),
    .m_axi_wready (wready), .m_axi_bresp (2'b00), .m_axi_bvalid (bvalid), .m_axi_bready (bready),
    .s_axis_tdata (tdata), .s_axis_tvalid (tvalid), .s_axis_tready (), .s_axis_tlast (1'b0));

  // AXI slave with random stalls; the port of CH2 stops for up to 20000 clocks now and then
  always @(posedge clk) begin
    if (stall > 0) stall--;
    else if (((C == 1 && port2_stalls) || (C == 0 && port1_stalls)) && ($urandom % 30000) == 0) begin
      stall = 4000 + $urandom % 16000;
`ifdef BLK_TRACE
      $display("%0t CH%0d port stalls for %0d clocks", $time, C + 1, stall);
`endif
    end
    awready <= ($urandom % 4) != 0 && stall == 0;
    if (awvalid && awready) aw_q.push_back(awaddr);
    if (wvalid && wready) begin
      if (!wbusy) begin
        if (aw_q.size() == 0) begin errors++; $display("FAIL CH%0d: data before its address", C + 1); end
        waddr = aw_q.pop_front();
        wbusy = 1;
      end
      if (!((waddr >= DST1 + C * CH_OFS && waddr < DST1 + C * CH_OFS + BUF_BYTES) ||
            (waddr >= DST2 + C * CH_OFS && waddr < DST2 + C * CH_OFS + BUF_BYTES)))
        begin errors++; if (errors <= 6) $display("FAIL CH%0d: write outside the buffers at 0x%h", C + 1, waddr); end
      mem[C][waddr] = wdata;
      waddr += 8;
      if (wlast) begin
        wbusy = 0;
        pend_b++;
      end
    end
    wready <= (($urandom % 3) != 0) && (wbusy || (aw_q.size() > 0)) && stall == 0;
    if (bvalid && bready) bvalid <= 0;
    else if (!bvalid && pend_b > 0) begin bvalid <= 1; pend_b--; end
  end
end
endgenerate

`ifdef BLK_TRACE
bit trace_on = 0;
reg trace_flush_d = 0;
reg [2:0] st_d [2];
reg [1:0] f_d [2];
reg [1:0] drop_d [2];
always @(posedge clk) if (trace_on) begin
  for (int c = 0; c < 2; c++) begin
    if (diags[c][2:0] != st_d[c]) $display("%0t CH%0d state %0d", $time, c + 1, diags[c][2:0]);
    if (sts[c][1:0] != f_d[c]) $display("%0t CH%0d full %b", $time, c + 1, sts[c][1:0]);
    st_d[c] <= diags[c][2:0]; f_d[c] <= sts[c][1:0];
  end
  if (ch[1].stall == 1) $display("%0t CH2 port runs again", $time);
  if ({ch[0].dut.drop_ser, ch[1].dut.drop_ser} != {drop_d[0][0], drop_d[1][0]})
    $display("%0t drop_ser %b%b busy %b%b", $time, ch[0].dut.drop_ser, ch[1].dut.drop_ser, ch[0].dut.drop_busy, ch[1].dut.drop_busy);
  drop_d[0][0] <= ch[0].dut.drop_ser; drop_d[1][0] <= ch[1].dut.drop_ser;
  for (int c = 0; c < 2; c++) begin
    if (c == 0 && ch[0].dut.U_dma_s2mm_ctrl.rew_we) $display("%0t CH1 rewind %0d words", $time, ch[0].dut.U_dma_s2mm_ctrl.rew_drop);
    if (c == 1 && ch[1].dut.U_dma_s2mm_ctrl.rew_we) $display("%0t CH2 rewind %0d words", $time, ch[1].dut.U_dma_s2mm_ctrl.rew_drop);
  end
  if (ch[1].awvalid && ch[1].awready && (ch[1].awaddr[10:0] == 0)) $display("%0t CH2 request at buffer start 0x%h", $time, ch[1].awaddr);
  if (ch[0].awvalid && ch[0].awready && (ch[0].awaddr[10:0] == 0)) $display("%0t CH1 request at buffer start 0x%h", $time, ch[0].awaddr);
  if (flush && !trace_flush_d) $display("%0t series end (armed), series %0d", $time, series);
  trace_flush_d <= flush;
end
`endif

task automatic wr(input [31:0] v);
  @(posedge clk); reg_wr_data <= v; reg_wr_we <= 1;
  @(posedge clk); reg_wr_we <= 0;
endtask

function automatic [15:0] smp(input int c, input int unsigned addr, input int unsigned k);
  logic [63:0] w = mem[c][addr + (k / 4) * 8];
  return w[(k % 4) * 16 +: 16];
endfunction

// where a buffer leaves one series in order: "pos k: value" of the first wrong sample
function automatic string first_bad(input int c, input int unsigned addr);
  logic [15:0] s0 = smp(c, addr, 0);
  for (int k = 1; k < BUF_SMP; k++) begin
    logic [9:0] pos = s0[9:0] + k[9:0];
    if (smp(c, addr, k) !== {s0[15:10], pos})
      return $sformatf("starts %0d.%0d, sample %0d is %0d.%0d", s0[15:10], s0[9:0], k, smp(c, addr, k) >> 10, smp(c, addr, k) & 10'h3ff);
  end
  return $sformatf("starts %0d.%0d, in order", s0[15:10], s0[9:0]);
endfunction

// the series a buffer holds from its start, -1 when it does not hold one series in order
function automatic int buf_series(input int c, input int unsigned addr);
  logic [15:0] s0 = smp(c, addr, 0);
  if (s0[9:0] != 0) return -1;
  for (int k = 1; k < BUF_SMP; k++) begin
    logic [9:0] pos = k[9:0];
    if (smp(c, addr, k) !== {s0[15:10], pos}) return -1;
  end
  return s0[15:10];
endfunction

task automatic run(input int unsigned dec, input int unsigned nbuf, input int unsigned slow, input bit stalls, input bit stalls1 = 0,
                   input int unsigned early = 0);
  int unsigned got = 0, ovf[2] = '{0, 0};
  DEC = dec; port2_stalls = stalls; port1_stalls = stalls1; flush_early = early;
  aresetn = 0; run_stream = 0; repeat (20) @(posedge clk); aresetn = 1; repeat (20) @(posedge clk);
  mem[0].delete(); mem[1].delete();
  wr(32'h0000_0200);  // streaming mode
  wr(32'h0000_0001);  // start
  repeat (500) @(posedge clk);
  run_stream = 1;
  while (got < nbuf) begin
    for (int b = 0; b < 2 && got < nbuf; b++) begin
      int unsigned to = 0;
      int s [2];
      while (!sw_full[b]) begin
        @(posedge clk);
        if (++to > 80 * BUF_SMP * dec) begin
          errors++;
          $display("FAIL hang: no buffer %0d in both channels after %0d buffers, sts 0x%02h / 0x%02h, state %0d / %0d",
                   b + 1, got, sts[0][7:0], sts[1][7:0], diags[0][2:0], diags[1][2:0]);
          for (int c = 0; c < 2; c++)
            $display("info    CH%0d: drop_ser %b ack %b busy %b, pend %b rew %b wait %0d, req FIFO empty %b, data FIFO %0d words, req_addr 0x%h buf 0x%h, next_buf_full %b, series_on %b",
                     c + 1, c ? ch[1].dut.drop_ser : ch[0].dut.drop_ser, c ? ch[1].dut.drop_ack : ch[0].dut.drop_ack,
                     c ? ch[1].dut.drop_busy : ch[0].dut.drop_busy,
                     c ? ch[1].dut.U_dma_s2mm_ctrl.drop_pend : ch[0].dut.U_dma_s2mm_ctrl.drop_pend,
                     c ? ch[1].dut.U_dma_s2mm_ctrl.drop_rew : ch[0].dut.U_dma_s2mm_ctrl.drop_rew,
                     c ? ch[1].dut.U_dma_s2mm_ctrl.drop_wait : ch[0].dut.U_dma_s2mm_ctrl.drop_wait,
                     c ? ch[1].dut.U_dma_s2mm_ctrl.fifo_empty : ch[0].dut.U_dma_s2mm_ctrl.fifo_empty,
                     c ? ch[1].dut.fifo_rd_cnt : ch[0].dut.fifo_rd_cnt,
                     c ? ch[1].dut.U_dma_s2mm_ctrl.req_addr : ch[0].dut.U_dma_s2mm_ctrl.req_addr,
                     c ? ch[1].dut.U_dma_s2mm_ctrl.req_buf_addr : ch[0].dut.U_dma_s2mm_ctrl.req_buf_addr,
                     c ? ch[1].dut.U_dma_s2mm_ctrl.next_buf_full : ch[0].dut.U_dma_s2mm_ctrl.next_buf_full,
                     c ? ch[1].dut.U_dma_s2mm_ctrl.series_on : ch[0].dut.U_dma_s2mm_ctrl.series_on);
          $display("FAIL dma_blocks2_tb: %0d errors in %0d buffers", errors, checks);
          $finish;
        end
      end
      repeat (16 * 4 * dec + 200) @(posedge clk);
      if (($urandom % 100) < slow) repeat (BUF_SMP * dec * (2 + $urandom % 3)) @(posedge clk);
      for (int c = 0; c < 2; c++) begin
        s[c] = buf_series(c, (b == 0 ? DST1 : DST2) + c * CH_OFS);
        if (lost[c][b] > waitc[c][b]) ovf[c]++;
      end
      checks++;
      if (s[0] < 0 || s[1] < 0) begin
        errors++;
        shifted++;
        if (errors <= 6)
          $display("FAIL buffer %0d: not one series from its start: CH1 %0d, CH2 %0d (lost %0d / %0d)", got, s[0], s[1], lost[0][b], lost[1][b]);
        if (errors <= 6)
          $display("info    CH1 %s; CH2 %s", first_bad(0, (b == 0 ? DST1 : DST2)), first_bad(1, (b == 0 ? DST1 : DST2) + CH_OFS));
      end else if (s[0] != s[1]) begin
        errors++;
        apart++;
        if (errors <= 6)
          $display("FAIL buffer %0d: CH1 holds series %0d, CH2 series %0d (lost %0d / %0d)", got, s[0], s[1], lost[0][b], lost[1][b]);
      end
      wr(b == 0 ? 32'h0000_0006 : 32'h0000_000A);  // buffer ACK + interrupt ACK
      got++;
    end
  end
  $display("ok    decimation %0d, %0d %% slow%s%s%s: %0d buffers, overflows before them %0d / %0d",
           dec, slow, early ? ", arm early" : "", stalls ? ", CH2 port stalls" : "", stalls1 ? ", CH1 port stalls" : "", got, ovf[0], ovf[1]);
  run_stream = 0;
  wr(32'h0000_0010);  // reset
endtask

initial begin
  run(8, 20, 0, 0);    // no overflow
  run(8, 40, 20, 0);   // a slow software: both channels overflow
`ifdef BLK_TRACE
  trace_on = 1;
`endif
  run(8, 60, 0, 1);    // the CH2 port stalls: CH2 overflows alone
  run(8, 60, 20, 1);
  run(8, 120, 30, 1, 1);  // both ports stall, a slow software: the waits for a free buffer and the drops mix
  run(4, 120, 30, 1, 1);
  // the arm a few clocks before the last sample (the 250-12 at decimation 32): a drop that ended
  // before the last word let a request through without its data, the stream stopped
  run(8, 80, 30, 0, 0, 2);
  run(8, 80, 30, 1, 1, 2);
  if (apart)   $display("FAIL %0d of %0d buffers with another series in CH1 and CH2", apart, checks);
  if (shifted) $display("FAIL %0d of %0d buffers out of step with the series", shifted, checks);
  if (errors == 0) $display("PASS dma_blocks2_tb (%0d buffers checked)", checks);
  else             $display("FAIL dma_blocks2_tb: %0d errors in %0d buffers", errors, checks);
  $finish;
end

endmodule
