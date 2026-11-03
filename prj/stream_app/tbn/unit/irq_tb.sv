// The scope interrupt with two channels (rtl variant, stream clock = AXI clock): two rp_dma_s2mm
// wired as in rp_oscilloscope (buf_sel crossed, the interrupts ORed, one control register),
// in the continuous streaming mode. The software is modelled as oscWorker does it: it takes
// the current buffer when the status of CH1 says it is full, else it waits for the interrupt
// (1 s poll timeout on the board, a few buffers here), acknowledges it and asks the status
// again. A wait that ends in the timeout is a FAIL: on the board it is a stall of 1 s.
// CH2 gets its samples ahead of CH1 by `lead` samples: 0 (in step), a part of a buffer, or a
// whole buffer (the channels a buffer apart, as seen on the 250-12 after overflows); a negative
// lead puts CH2 behind CH1 (its port slower, as on the 250-12 under load).
// The software takes a buffer by the full flag of CH1 alone (all_full 0, the register before)
// or of all channels (all_full 1, rp_oscilloscope now). A buffer released before CH2 has written
// it is a FAIL: CH2 misses the release, finds that buffer full a round later, overflows and stays
// a buffer off. The runs with the flag of CH1 show the old register (info, not counted).
// The interrupt is set when a buffer of a channel gets full: on a buffer switch alone a channel
// whose next buffer was full (CH2 after its port stalled) filled its buffer without one, and the
// software waited for the 1 s timeout with every buffer full.
`timescale 1ns / 1ps

module irq_tb;

localparam BUF_BYTES = 2048;
localparam int BUF_SMP = BUF_BYTES / 2;
localparam DST1      = 32'h0001_0000;
localparam DST2      = 32'h0002_0000;

int unsigned DEC;
bit          port2_stalls = 0;  // the AXI port of CH2 stops now and then for a while (HP port load)
int unsigned errors = 0, runs = 0, apart = 0;

reg clk = 0;
always #4 clk = ~clk;
reg aresetn = 0;

reg  [63:0] ts = 64'd1000;
always @(posedge clk) ts <= ts + 64'd1;

// streams: a sample every DEC clocks; CH2 starts `lead` samples before CH1
bit          run_stream = 0;
int          lead = 0;
int unsigned dcnt = 0, n = 0;
reg  [15:0]  tdata = 0;
reg  [1:0]   tvalid = 0;
always @(posedge clk) begin
  tvalid <= 0;
  if (!run_stream) begin
    dcnt <= 0; n <= 0;
  end else begin
    if (dcnt >= DEC - 1) dcnt <= 0; else dcnt <= dcnt + 1;
    if (dcnt == 0) begin
      tdata  <= n[15:0];
      tvalid <= {int'(n) >= -lead, int'(n) >= lead};
      n      <= n + 1;
    end
  end
end

reg  [31:0] reg_wr_data = 0;
reg         reg_wr_we   = 0;
wire [31:0] sts [2];
wire [31:0] diags [2];
wire [1:0]  intr, sel;

genvar C;
generate
for (C = 0; C < 2; C++) begin : ch
  wire [31:0] awaddr;  wire [7:0] awlen;  wire awvalid;  reg awready = 0;
  wire        wlast;   wire wvalid;       reg wready  = 0;
  reg         bvalid = 0;  wire bready;
  int unsigned pend_aw = 0, pend_b = 0;
  bit          wbusy = 0;

  rp_dma_s2mm #(.AXI_ADDR_BITS(32), .AXI_DATA_BITS(64), .AXIS_DATA_BITS(16), .AXI_BURST_LEN(16)) dut (
    .m_axi_aclk (clk), .s_axis_aclk (clk), .aresetn (aresetn),
    .busy (), .intr (intr[C]), .mode (),
    .reg_wr_data (reg_wr_data), .reg_wr_we (reg_wr_we),
    .reg_ctrl (), .reg_sts (sts[C]), .reg_diags (diags[C]),
    .reg_dst_addr1 (DST1 + C * 32'h0010_0000), .reg_dst_addr2 (DST2 + C * 32'h0010_0000), .reg_buf_size (BUF_BYTES),
    .timestamp_counter (ts), .timestamp_init (64'd0), .timestamp_init_we (1'b0),
    .ctl_start_o (), .ctl_start_ext (1'b0), .use_8bit (1'b0),
    .buf1_timestamp (), .buf2_timestamp (),
    .s_axis_drop (1'b0), .s_axis_flush (1'b0), .s_axis_series (1'b0), .series_lost_o (), .series_drop_i (1'b0), .buf1_lost (), .buf2_lost (),
    .buf1_wait (), .buf2_wait (),
    .buf_sel_in (sel[1 - C]), .buf_sel_out (sel[C]),
    .m_axi_awaddr (awaddr), .m_axi_awlen (awlen), .m_axi_awsize (), .m_axi_awburst (),
    .m_axi_awprot (), .m_axi_awcache (), .m_axi_awvalid (awvalid), .m_axi_awready (awready),
    .m_axi_wdata (), .m_axi_wstrb (), .m_axi_wlast (wlast), .m_axi_wvalid (wvalid),
    .m_axi_wready (wready), .m_axi_bresp (2'b00), .m_axi_bvalid (bvalid), .m_axi_bready (bready),
    .s_axis_tdata (tdata), .s_axis_tvalid (tvalid[C]), .s_axis_tready (), .s_axis_tlast (1'b0));

  // AXI slave with random stalls, the data is not kept
  int unsigned stall = 0;
  always @(posedge clk) begin
    if (stall > 0) stall--;
    else if (C == 1 && port2_stalls && ($urandom % 3000) == 0) stall = 2000 + $urandom % 6000;
    awready <= ($urandom % 4) != 0 && stall == 0;
    if (awvalid && awready) pend_aw++;
    if (wvalid && wready) begin
      if (!wbusy) begin pend_aw--; wbusy = 1; end
      if (wlast) begin wbusy = 0; pend_b++; end
    end
    wready <= (($urandom % 3) != 0) && (wbusy || (pend_aw > 0)) && stall == 0;
    if (bvalid && bready) bvalid <= 0;
    else if (!bvalid && pend_b > 0) begin bvalid <= 1; pend_b--; end
  end
end
endgenerate

wire irq = |intr;

// what the software reads as the full flags of the buffers
bit  all_full = 0;
wire [1:0] sw_full = all_full ? (sts[0][1:0] & sts[1][1:0]) : sts[0][1:0];

// buffer switches and overflows (entries into WAIT_BUF_FULL) per channel
int unsigned sw_cnt[2], ovf_cnt[2];
reg [1:0] sel_d = 0;
reg [2:0] st_d [2];
always @(posedge clk) begin
  for (int c = 0; c < 2; c++) begin
    if (sel[c] != sel_d[c]) sw_cnt[c]++;
    if (diags[c][2:0] == 3'd5 && st_d[c] != 3'd5) ovf_cnt[c]++;
    st_d[c] <= diags[c][2:0];
  end
  sel_d <= sel;
end

`ifdef IRQ_TRACE
reg irq_d = 0;
reg [1:0] f0_d = 0, f1_d = 0;
always @(posedge clk) begin
  irq_d <= irq; f0_d <= sts[0][1:0]; f1_d <= sts[1][1:0];
  if ($time < 400000) begin
    if (irq && !irq_d) $display("%0t irq up", $time);
    if (sts[0][1:0] != f0_d) $display("%0t CH1 full %b", $time, sts[0][1:0]);
    if (sts[1][1:0] != f1_d) $display("%0t CH2 full %b", $time, sts[1][1:0]);
    for (int c = 0; c < 2; c++) if (diags[c][2:0] == 3'd5 && st_d[c] != 3'd5) $display("%0t CH%0d WAIT_BUF_FULL", $time, c + 1);
    if (reg_wr_we) $display("%0t write 0x%0h", $time, reg_wr_data);
  end
end
`endif

task automatic wr(input [31:0] v);
  @(posedge clk); reg_wr_data <= v; reg_wr_we <= 1;
  @(posedge clk); reg_wr_we <= 0;
endtask

task automatic run(input int unsigned dec, input int unsigned nbuf, input int lead_smp, input bit all, input int unsigned slow = 0,
                   input bit stalls = 0);
  int unsigned got = 0, timeouts = 0, wakes = 0, idle = 0, cur = 0, early = 0, bad;
  DEC = dec; lead = lead_smp; all_full = all; port2_stalls = stalls; runs++;
  sw_cnt = '{0, 0}; ovf_cnt = '{0, 0};
  aresetn = 0; run_stream = 0; repeat (20) @(posedge clk); aresetn = 1; repeat (20) @(posedge clk);
  wr(32'h0000_0200);  // streaming mode
  wr(32'h0000_0001);  // start
  repeat (500) @(posedge clk);
  run_stream = 1;
  while (got < nbuf && timeouts < 10) begin  // a run that stalls for good stops after 10 timeouts
    if (sw_full[cur]) begin
      // the buffer of both channels: some processing time, then the release
      repeat ($urandom % (BUF_SMP * dec / 2)) @(posedge clk);
      // sometimes too slow: the channels overflow (each on its own, by its port)
      if (($urandom % 100) < slow) repeat (BUF_SMP * dec * (2 + $urandom % 3)) @(posedge clk);
      if (!sts[1][cur]) early++;  // CH2 has not written it yet
      wr(cur == 0 ? 32'h0000_0004 : 32'h0000_0008);
      cur = 1 - cur;
      got++;
    end else begin
      int unsigned to = 0;
      while (!irq && to < 4 * BUF_SMP * dec) begin
        @(posedge clk);
        to++;
      end
      if (!irq) begin
        timeouts++;
        if (timeouts <= 3 && all)
          $display("FAIL lead %0d: no interrupt for %0d clocks after %0d buffers, waiting for buffer %0d: sts 0x%02h / 0x%02h, state %0d / %0d, sel %0d / %0d",
                   lead_smp, to, got, cur + 1, sts[0][7:0], sts[1][7:0], diags[0][2:0], diags[1][2:0], sel[0], sel[1]);
      end else begin
        wakes++;
        repeat (20) @(posedge clk);  // the wake-up latency
        wr(32'h0000_0002);           // interrupt ACK
        if (!sw_full[cur]) idle++;
      end
    end
  end
  repeat (50) @(posedge clk);
  // every wait ends in an interrupt, no buffer released before CH2 wrote it; with less than half
  // a buffer between their data and no stalls of one port the channels stay in step (as many
  // switches and overflows). KNOWN: a port that stops alone overflows its channel alone, the
  // channels drop different samples and their buffers no longer hold the same time.
  bad = timeouts + early;
  if (stalls) begin
    if (ovf_cnt[0] != ovf_cnt[1]) apart++;
  end else
    bad += ((sw_cnt[0] > sw_cnt[1] + 1 || sw_cnt[1] > sw_cnt[0] + 1) ? 1 : 0) +
           ((lead_smp < BUF_SMP / 2 && lead_smp > -BUF_SMP / 2 && ovf_cnt[0] != ovf_cnt[1]) ? 1 : 0);
  if (all) errors += bad;
  $display("%s decimation %0d, CH2 %0d samples ahead, %0d %% slow%s, status of %s: %0d buffers, %0d interrupts (%0d found the buffer not full), %0d timeouts, %0d released before CH2 wrote them, switches %0d / %0d, overflows %0d / %0d",
           !all ? "info " : bad ? "FAIL " : "ok   ", dec, lead_smp, slow, stalls ? ", CH2 port stalls" : "", all ? "all channels" : "CH1", got, wakes, idle, timeouts, early, sw_cnt[0], sw_cnt[1], ovf_cnt[0], ovf_cnt[1]);
  run_stream = 0;
  wr(32'h0000_0010);  // reset
endtask

initial begin
  for (int a = 0; a < 2; a++) begin
    run(4, 40, 0, a);                       // in step
    run(4, 40, BUF_SMP / 4, a);             // CH2 a quarter of a buffer ahead
    run(4, 40, BUF_SMP, a);                 // a buffer apart
    run(4, 40, -100, a);                    // CH2 behind by more than a burst
    run(4, 40, -256, a);                    // CH2 a quarter of a buffer behind
  end
  // a slow software: overflows, the channels may end up a buffer apart, and a buffer can get
  // full in a channel that cannot switch (its next buffer full): every wait must still end
  for (int l = 0; l < 3; l++)
    run(4, 60, l == 0 ? 0 : l == 1 ? -100 : 1024, 1, 30);
  // the port of CH2 stops for up to 8000 clocks: CH2 overflows alone
  run(4, 80, 0, 1, 0, 1);
  run(4, 80, 0, 1, 30, 1);
  if (apart) $display("KNOWN %0d runs with the CH2 port stalling: the channels overflow apart, their buffers hold different times", apart);
  if (errors == 0) $display("PASS irq_tb (%0d runs)", runs);
  else             $display("FAIL irq_tb: %0d errors", errors);
  $finish;
end

endmodule
