// GPIO input: trigger mode, block mode, the 64 bit lost counter and the pattern trigger, self checking.
// The input is a sequence of runs: value j (P = j[7:0], N = j[15:8]) is held r(j) clocks,
// r(j) = 1 without RLE, 1 + j % 4 with RLE. The words in memory then tell exactly how many
// samples are missing between two buffers, which must equal the lost register of the
// second one. A software model acknowledges the buffers like uio_lib.
`timescale 1ns / 1ps
module gpio_in_tb;
typedef reg [8-1:0] DT;
localparam int WORDS = 256;           // 0x400 bytes per buffer
localparam logic [31:0] B1 = 32'h1000, B2 = 32'h4000;
logic clk = 0, rstn = 0;
always #4 clk = ~clk;

// ---- input runs
bit rle = 0;
function automatic int rlen(input int j); return rle ? 1 + j % 4 : 1; endfunction
int unsigned j = 0, c = 0;
always @(posedge clk) if (c + 1 >= rlen(j)) begin j <= j + 1; c <= 0; end else c <= c + 1;

axi4_stream_if #(.DN (2), .DT (DT)) sti (.ACLK (clk), .ARESETn (rstn));
assign sti.TDATA[0] = j[7:0];
assign sti.TDATA[1] = j[15:8];
assign sti.TVALID = 1'b1;
assign sti.TKEEP  = 2'b01;  // lane N not kept: the pattern trigger takes the lanes together
assign sti.TLAST  = 1'b0;

logic [31:0] reg_addr = 0, reg_wr_data = 0;
logic        reg_wr_we = 0;
logic [31:0] bsize = 32'(WORDS * 4), b1 = B1, b2 = B2;  // test 9 leaves them unset
logic        ctl_acq = 0, ctl_stp = 0, ctl_rst = 0;
logic        tmode = 0, trig = 0;
logic [15:0] epos = 0;
wire         latrg;
logic [15:0] nblk = 0;
wire  [31:0] awaddr;
wire  [63:0] wdata;
wire  [7:0]  awlen, wstrb;
wire         awvalid, wvalid, wlast, bready;
logic        awready = 1, wready = 1, bvalid = 0;
wire  [31:0] reg_sts, reg_ctrl;
wire  [63:0] lost1, lost2, wait1, wait2;
wire         armed, taken;

gpio_in_top #(.DN (2), .DT (DT), .TN (6), .M_AXI_GPIO_ADDR_BITS (32), .M_AXI_GPIO_DATA_BITS (64), .S_AXI_REG_ADDR_BITS (32), .CW (8)) dut (
  .clk(clk), .rst_n(rstn), .sti(sti), .irq_trg(), .dma_intr(),
  .cfg_dec(17'd0), .cfg_pol(16'd0), .cfg_cmp_msk(16'd0), .cfg_cmp_val(16'd0), .cfg_edg_pos(epos), .cfg_edg_neg(16'd0),
  .cfg_con(1'b1), .cfg_aut(1'b0), .cfg_pre(32'd0), .sts_pre(), .cfg_pst(32'd0), .sts_pst(),
  .sts_acq(), .cts_acq(), .sts_trg(), .cts_trg(), .cts_stp(), .cfg_rle(rle), .sts_cur(), .sts_lst(),
  .cfg_trg(6'd0), .ctl_trg(6'd0), .trg_out(latrg),
  .reg_wr_data(reg_wr_data), .reg_wr_we(reg_wr_we), .reg_addr(reg_addr), .reg_ctrl(reg_ctrl),
  .ctl_rst(ctl_rst), .ctl_acq(ctl_acq), .ctl_stp(ctl_stp), .reg_sts(reg_sts), .gpio_ctrl_reg(8'd0), .gpio_sts_reg(),
  .gpio_buf_size(bsize), .gpio_buf1_adr(b1), .gpio_buf2_adr(b2), .gpio_step(32'd1),
  .gpio_wp(), .dma_diags(),
  .cfg_trig_mode(tmode), .cfg_trig_blocks(nblk), .trig_i(trig), .sts_armed(armed), .sts_trig_taken(taken),
  .buf1_lost(lost1), .buf2_lost(lost2), .buf1_wait(wait1), .buf2_wait(wait2),
  .m_axi_gpio_awaddr(awaddr), .m_axi_gpio_awlen(awlen), .m_axi_gpio_awsize(), .m_axi_gpio_awburst(), .m_axi_gpio_awprot(), .m_axi_gpio_awcache(),
  .m_axi_gpio_awvalid(awvalid), .m_axi_gpio_awready(awready), .m_axi_gpio_wdata(wdata), .m_axi_gpio_wstrb(wstrb), .m_axi_gpio_wlast(wlast),
  .m_axi_gpio_wvalid(wvalid), .m_axi_gpio_wready(wready), .m_axi_gpio_bresp(2'b00), .m_axi_gpio_bvalid(bvalid), .m_axi_gpio_bready(bready));

// ---- memory
logic [31:0] mem [logic [31:0]];
logic [31:0] waddr; logic [31:0] awq[$];
int burstLeft = 0;
always @(posedge clk) begin
  if (awvalid && awready) awq.push_back(awaddr);
  if (wvalid && wready) begin
    if (burstLeft == 0) begin waddr = awq.pop_front(); burstLeft = 16; end
    mem[waddr] = wdata[31:0]; mem[waddr + 4] = wdata[63:32];
    waddr += 8; burstLeft--;
  end
  bvalid <= wvalid && wready && wlast;
end

// ---- test 9: the burst addresses of a run
bit collect = 0; logic [31:0] seenAw[$];
always @(posedge clk) if (collect && awvalid && awready) seenAw.push_back(awaddr);

// ---- the first word the gate takes after a start: reference of the first lost count
int unsigned startJ, startSamples; bit startSeen = 0;
always @(posedge clk) if (!startSeen && dut.gate.take) begin
  startSeen = 1; startJ = {dut.gate.s_tdata[23:16], dut.gate.s_tdata[7:0]}; startSamples = dut.gate.s_tdata[15:8] + 1;
end

int errors = 0;
task automatic fail(string s); errors++; $display("FAIL  %s (t=%0t)", s, $time); endtask
task automatic ok(string s); $display("ok    %s", s); endtask

task wr(input [31:0] a, input [31:0] d);
  @(negedge clk) begin reg_addr = a; reg_wr_data = d; reg_wr_we = 1; end
  @(negedge clk) reg_wr_we = 0;
endtask

task automatic pulse(ref logic s); @(negedge clk) s = 1; @(negedge clk) s = 0; endtask

// unwraps a 16 bit value against a reference
function automatic longint unwrap(input longint ref_, input logic [15:0] v);
  longint d = longint'(v) - (ref_ & 16'hFFFF);
  if (d < -32768) d += 65536;
  if (d > 32767) d -= 65536;
  return ref_ + d;
endfunction

// samples of the values a < j < b
function automatic longint gapSamples(input longint a, input longint b);
  longint s = 0;
  for (longint k = a + 1; k < b; k++) s += rlen(int'(k));
  return s;
endfunction

// ---- software model
int  nextBuf;          // 0: buffer 1, 1: buffer 2
longint lastJ;         // value of the last word read, -1 before the first buffer
int  buffers;

task automatic begin_run(input bit trigMode, input int n, input bit rleOn);
  tmode = trigMode; nblk = n; rle = rleOn;
  wr(32'h8C, 32'h21E);  // stream mode, reset, acknowledge both buffers
  pulse(ctl_acq);       // start event
  startSeen = 0;
  wr(32'h8C, 32'h1);    // start
  nextBuf = 0; lastJ = -1; buffers = 0;
endtask

task automatic end_run();
  pulse(ctl_stp);
  wr(32'h8C, 32'h10);   // reset
  repeat (200) @(negedge clk);
endtask

// waits for the next buffer, checks it against the previous one, acknowledges it after ackDelay
task automatic read_buffer(input int timeout, input int ackDelay, output bit got);
  int t = 0;
  got = 0;
  while (!(reg_sts[nextBuf]) && t < timeout) begin @(negedge clk); t++; end
  if (!reg_sts[nextBuf]) return;
  got = 1;
  begin
    logic [31:0] base = nextBuf ? B2 : B1;
    longint lost = nextBuf ? lost2 : lost1;
    longint wt   = nextBuf ? wait2 : wait1;
    longint first, prev, v, expGap;
    int badRun = 0, badSeq = 0;
    for (int w = 0; w < WORDS; w++) begin
      logic [31:0] x = mem.exists(base + 4 * w) ? mem[base + 4 * w] : 32'hDEADBEEF;
      v = unwrap(w == 0 ? (lastJ >= 0 ? lastJ : longint'(startJ)) : prev, {x[23:16], x[7:0]});
      if (x[15:8] != x[31:24]) badRun++;
      if (w == 0) first = v;
      else begin
        if (v != prev + 1) badSeq++;
        if (x[15:8] + 1 != rlen(int'(v))) badRun++;
      end
      prev = v;
    end
    // the first buffer without the trigger mode reports 0: the words dropped while the DMA
    // resets its FIFO after the start are not counted (as in the scope)
    expGap = lastJ >= 0 ? gapSamples(lastJ, first)
           : !tmode     ? 0
                        : (first == startJ ? 0 : startSamples + gapSamples(startJ, first));
    if (badSeq || badRun) fail($sformatf("buffer %0d: %0d sequence breaks, %0d wrong counts", buffers + 1, badSeq, badRun));
    if (lost != expGap) fail($sformatf("buffer %0d: lost register %0d, gap in the data %0d", buffers + 1, lost, expGap));
    else if (expGap != 0) ok($sformatf("buffer %0d: lost register %0d = gap in the data", buffers + 1, lost));
    // the trigger mode runs acknowledge in time: their whole gap is the wait; without it 0
    if (tmode ? (wt != lost) : (wt != 0)) fail($sformatf("buffer %0d: wait register %0d, lost %0d, trigger mode %0d", buffers + 1, wt, lost, tmode));
    lastJ = prev;
    buffers++;
  end
  repeat (ackDelay) @(negedge clk);
  wr(32'h8C, nextBuf ? 32'h8 : 32'h4);
  nextBuf ^= 1;
endtask

task automatic read_n(input int n, input int ackDelay, output int got);
  bit g;
  got = 0;
  for (int i = 0; i < n; i++) begin read_buffer(20 * WORDS * 4, ackDelay, g); if (!g) break; got++; end
endtask

initial begin
  int got, more;
  bit g;
  repeat (20) @(negedge clk);
  rstn = 1;
  repeat (200) @(negedge clk);  // FIFO reset busy

  // 1: no trigger mode, continuous, no loss
  begin_run(0, 0, 0);
  read_n(6, 50, got);
  if (got != 6) fail($sformatf("continuous: %0d of 6 buffers", got)); else ok("continuous: 6 buffers, continuous data");
  end_run();

  // 2: trigger mode, N = 2: nothing before the trigger, 2 buffers after it, armed again;
  //    the lost count of the first buffer is the wait from the start
  begin_run(1, 2, 0);
  repeat (700) @(negedge clk);
  if (!armed) fail("trigger mode: armed after the start");
  read_buffer(1000, 0, g);
  if (g) fail("trigger mode: a buffer before the trigger");
  pulse(trig);
  read_n(3, 50, got);
  if (got != 2) fail($sformatf("N = 2: %0d buffers (2)", got)); else ok("N = 2: 2 buffers");
  if (!armed) fail("N = 2: armed again after the series");
  repeat (500) @(negedge clk);
  pulse(trig);
  read_n(3, 50, got);
  if (got != 2) fail($sformatf("N = 2, second trigger: %0d buffers (2)", got)); else ok("N = 2, second series: 2 buffers");
  end_run();

  // 3: RLE, N = 3, a trigger in block 2 ends the series with block 5
  begin_run(1, 3, 1);
  repeat (300) @(negedge clk);
  pulse(trig);
  read_buffer(20 * WORDS * 4, 0, g);          // block 1 complete, block 2 being written
  repeat (WORDS) @(negedge clk);
  pulse(trig);
  read_n(6, 0, got);
  if (got + g != 5) fail($sformatf("RLE, N = 3, triggers in blocks 1 and 2: %0d buffers (5)", got + g));
  else ok("RLE, N = 3, triggers in blocks 1 and 2: 5 buffers, counts and lost exact");
  end_run();

  // 4: N = 0: continuous after the trigger
  begin_run(1, 0, 0);
  repeat (300) @(negedge clk);
  pulse(trig);
  read_n(5, 50, got);
  if (got != 5 || armed) fail($sformatf("N = 0: %0d buffers, armed %0d", got, armed)); else ok("N = 0: continuous after the trigger");
  end_run();

  // 5: no trigger mode, slow software: the DMA drops while the next buffer is not free
  begin_run(0, 0, 0);
  read_n(6, 3 * WORDS, got);
  if (got != 6) fail($sformatf("slow software: %0d of 6 buffers", got)); else ok("slow software: holes reported with the buffer after them");
  end_run();

  // 6: RLE and slow software
  begin_run(0, 0, 1);
  read_n(6, 6 * WORDS, got);
  if (got != 6) fail($sformatf("RLE, slow software: %0d of 6 buffers", got)); else ok("RLE, slow software: holes reported in samples");
  end_run();

  // 7: stop inside a series, start again: armed, nothing written
  begin_run(1, 4, 0);
  repeat (100) @(negedge clk);
  pulse(trig);
  read_buffer(20 * WORDS * 4, 0, g);
  end_run();
  begin_run(1, 4, 0);
  read_buffer(6 * WORDS, 0, g);
  if (g || !armed) fail("stop inside a series: armed and silent after the next start"); else ok("stop inside a series: armed and silent after the next start");
  end_run();

  // 8: pattern trigger: rising edges of P0 (every second clock) and of N0 (j bit 8, every 512 clocks)
  begin
    int n0 = 0, n1 = 0;
    rle = 0;
    epos = 16'h0001;
    repeat (20) @(negedge clk);
    repeat (1024) begin @(negedge clk); if (latrg) n0++; end
    epos = 16'h0100;
    repeat (20) @(negedge clk);
    repeat (1024) begin @(negedge clk); if (latrg) n1++; end
    epos = 0;
    if (n0 < 510 || n0 > 514 || n1 < 1 || n1 > 3) fail($sformatf("pattern trigger: P0 rising %0d (512), N0 rising %0d (2)", n0, n1));
    else ok($sformatf("pattern trigger: P0 rising %0d, N0 rising %0d in 1024 clocks", n0, n1));
  end

  // 9: buffers not set up (the register tests leave all ones, a fresh board zeros): every burst
  // goes to the start of a buffer, as with the modulo 2^32 end compare; a wrapped end address
  // let the DMA write on through the whole memory (rp30 rebooted, 2026-11-11)
  begin
    logic [31:0] cfg [3][3] = '{'{32'h0, 32'h0, 32'h0}, '{32'hFFFFFF80, 32'hFFFFFF80, 32'hFFFFFF}, '{32'h40, 32'h0, 32'h40}};
    for (int c = 0; c < 3; c++) begin
      int bad = 0;
      b1 = cfg[c][0]; b2 = cfg[c][1]; bsize = cfg[c][2];
      seenAw.delete(); collect = 1;
      begin_run(0, 0, 0);
      repeat (40 * 16) @(negedge clk);
      collect = 0;
      end_run();
      foreach (seenAw[i]) if (seenAw[i] != b1 && seenAw[i] != b2) bad++;
      if (seenAw.size() == 0 || bad) fail($sformatf("unset buffers %h/%h size %h: %0d of %0d bursts outside the buffer starts (first %h)",
                                                    b1, b2, bsize, bad, seenAw.size(), seenAw.size() ? seenAw[0] : 0));
      else ok($sformatf("unset buffers %h/%h size %h: %0d bursts, all at a buffer start", b1, b2, bsize, seenAw.size()));
    end
    b1 = B1; b2 = B2; bsize = 32'(WORDS * 4);
  end

  if (errors == 0) $display("PASS gpio_in_tb"); else $display("FAIL gpio_in_tb: %0d", errors);
  $finish;
end
endmodule
