// GPIO output stream from memory, self checking: every 32 bit word {P, N, 0, count} is
// played for count+1 clocks with RLE (count 0..3 here, count 0 included), for one clock without.
// The value of a word is its address / 4, so the sequence and the run lengths are known.
// Continuous streaming: a driver hands the slots again on their free flags (0x98 bits 7/8): the
// output plays without a gap. The wait counter (0x38) counts the clocks the output waited for a
// buffer: none while the driver keeps up, every clock while it does not, kept after the stop.
`timescale 1ns / 1ps
module gpio_out_tb;
parameter int WE_CLOCKS = 2;
logic clk = 0, rstn = 0;
always #4 clk = ~clk;
axi4_stream_if #(.DN (1), .DT (reg [16-1:0])) sto (.ACLK (clk), .ARESETn (rstn));
assign sto.TREADY = 1'b1;

logic [31:0] reg_addr = 0, reg_wr_data = 0;
logic        reg_wr_we = 0, ctl_rst = 0, rle = 0, tmode = 0, trig = 0;
wire         armed;
logic [7:0]  ctrl8 = 0;     // rp_gpio keeps the last write of 0x90 in an 8 bit register
wire  [31:0] reg_ctrl, reg_sts, rp;
wire  [63:0] out_wait;
wire  [31:0] araddr; wire [3:0] arlen; wire arvalid, rready;
logic        arready = 1, rvalid = 0, rlast = 0;
logic [63:0] rdata = 0;

gpio_out_top #(.DN (1), .GPIO_BITS (8), .M_AXI_GPIO_ADDR_BITS (32), .M_AXI_GPIO_DATA_BITS (64), .S_AXI_REG_ADDR_BITS (32),
               .CTRL_ADDR ('h90), .STS_ADDR ('h98), .CW (8)) dut (
  .clk(clk), .rst_n(rstn), .sto(sto), .cfg_pol(16'd0), .cfg_rle(rle), .cfg_trig_mode(tmode), .trig_i(trig), .sts_armed(armed),
  .reg_wr_data(reg_wr_data), .reg_wr_we(reg_wr_we), .reg_addr(reg_addr), .reg_ctrl(reg_ctrl), .ctl_rst(ctl_rst), .reg_sts(reg_sts),
  .gpio_ctrl_reg(ctrl8), .gpio_step(32'h100), .gpio_buf_size(32'h10000), .gpio_buf1_adr(32'h3000), .gpio_buf2_adr(32'h20000), .gpio_wp(rp), .out_wait(out_wait),
  .m_axi_gpio_arid_o(), .m_axi_gpio_araddr_o(araddr), .m_axi_gpio_arlen_o(arlen), .m_axi_gpio_arsize_o(), .m_axi_gpio_arburst_o(),
  .m_axi_gpio_arlock_o(), .m_axi_gpio_arcache_o(), .m_axi_gpio_arprot_o(), .m_axi_gpio_arvalid_o(arvalid), .m_axi_gpio_arready_i(arready),
  .m_axi_gpio_rid_i(4'd0), .m_axi_gpio_rdata_i(rdata), .m_axi_gpio_rresp_i(2'd0), .m_axi_gpio_rlast_i(rlast), .m_axi_gpio_rvalid_i(rvalid),
  .m_axi_gpio_rready_o(rready));

function automatic [31:0] word(input [31:0] a);  // {P, N} = a / 4, count = (a / 4) % 4
  word = {16'(a >> 2), 8'h00, 8'((a >> 2) % 4)};
endfunction

// memory: address requests queue up, bursts are returned in order
int left = 0; logic [31:0] addr; logic [35:0] arq[$];
always @(posedge clk) begin
  if (arvalid && arready) arq.push_back({arlen, araddr});
  if (rvalid && rready) begin left--; addr = addr + 8; end
  if (left == 0 && arq.size() > 0) begin addr = arq[0][31:0]; left = arq[0][35:32] + 1; void'(arq.pop_front()); end
  rvalid <= (left > 0);
  rlast  <= (left == 1);
  rdata  <= {word(addr + 4), word(addr)};
end

// checker: run length of every value, the sequence (value + 1 or a buffer change), gaps
int samples = 0, values = 0, badRun = 0, jumps = 0, gaps = 0, errors = 0;
logic [15:0] cur; int run = 0; bit started = 0, active = 0;
int ovf = 0, maxOut = 0;
always @(posedge clk) begin
  if (dut.U_dma_mm2s.fifo_wr_we && dut.U_dma_mm2s.fifo_full && !dut.U_dma_mm2s.fifo_reset) begin ovf++; if (ovf <= 3) $display("  %0t FIFO overflow, wr count %0d", $time, dut.U_dma_mm2s.fifo_wr_cnt); end
  if (arq.size() > maxOut) maxOut = arq.size();
end
always @(posedge clk) if (active) begin
  if (sto.TVALID) begin
    samples++;
    if (started && sto.TDATA[0] == cur) run++;
    else begin
      if (started) begin
        if (run != (rle ? cur % 4 + 1 : 1)) begin badRun++; if (badRun <= 5) $display("  value 0x%04X played %0d clocks (%0d)", cur, run, rle ? cur % 4 + 1 : 1); end
        if (sto.TDATA[0] != 16'(cur + 1)) begin jumps++; if (jumps <= 5) $display("  jump 0x%04X -> 0x%04X", cur, sto.TDATA[0]); end
      end
      values++; started = 1; cur = sto.TDATA[0]; run = 1;
    end
  end else if (started) gaps++;
end

task wr(input [31:0] a, input [31:0] d);
  @(negedge clk) begin reg_addr = a; reg_wr_data = d; reg_wr_we = 1; if (a == 32'h90) ctrl8 = d[7:0]; end
  repeat (WE_CLOCKS - 1) @(negedge clk);  // the write pulse of the 62.5 MHz register bus seen at 125 MHz
  @(negedge clk) reg_wr_we = 0;
endtask

task run_case(input bit r, input int clocks);
  rle = r;
  wr(32'h90, 32'h22);   // reset, streaming mode
  samples = 0; values = 0; badRun = 0; jumps = 0; gaps = 0; started = 0; active = 1;
  wr(32'h90, 32'h1);    // start: buffer 1 plays
  wr(32'h90, 32'h80);   // buffer 2 ready (the ready flags are cleared while stopped)
  repeat (clocks) @(negedge clk);
  active = 0;
  $display("RLE %0d: %0d samples, %0d values, %0d wrong run lengths, %0d jumps, %0d gaps, %0d FIFO overflows, %0d bursts queued at most", r, samples, values, badRun, jumps, gaps, ovf, maxOut);
  // buffer 1 holds 0x10000 / 4 values: one change to buffer 2 at most in this time
  if (values < 1000 || badRun > 0 || jumps > 1 || gaps > 0) errors++;
  wr(32'h90, 32'h2);    // stop: the output ends at once (no FIFO leftovers)
  repeat (8) @(negedge clk);
  samples = 0; active = 1; started = 0;
  repeat (100) @(negedge clk);
  active = 0;
  if (samples > 0) begin errors++; $display("  %0d samples after the stop", samples); end
endtask

// the driver: the slots in turn, each once its free flag is up
int handed = 0;
task refill(input int clocks);
  int next = 0;  // buffer 1 plays first, buffer 2 is ready: buffer 1 is the next to hand again
  repeat (clocks) begin
    @(negedge clk);
    if (reg_sts[7 + next]) begin wr(32'h90, next ? 32'h80 : 32'h40); handed++; next ^= 1; end
  end
endtask

initial begin
  repeat (20) @(negedge clk);
  rstn = 1;
  repeat (200) @(negedge clk);
  run_case(1, 30000);
  run_case(0, 30000);
  // continuous, without RLE a buffer of 0x4000 words plays in 0x4000 clocks
  rle = 0;
  wr(32'h90, 32'h22);
  samples = 0; values = 0; badRun = 0; jumps = 0; gaps = 0; started = 0; handed = 0; active = 1;
  wr(32'h90, 32'h1);
  wr(32'h90, 32'h80);
  refill(150000);
  active = 0;
  $display("refill: %0d buffers handed again, %0d samples, %0d wrong run lengths, %0d buffer changes, %0d gaps", handed, samples, badRun, jumps, gaps);
  if (handed < 6 || badRun > 0 || gaps > 0 || jumps > handed + 2) errors++;
  $display("refill: output wait %0d clocks (0)", out_wait);
  if (out_wait != 0) errors++;
  wr(32'h90, 32'h2);
  repeat (8) @(negedge clk);
  // no refill: after its two buffers the output waits, every clock counted; then refilled, it
  // plays on and the count stops; the stop keeps it
  begin
    longint w1, w2, w3, w4;
    wr(32'h90, 32'h22);
    wr(32'h90, 32'h1);
    wr(32'h90, 32'h80);
    repeat (40000) @(negedge clk);  // the two buffers take 0x8000 clocks
    w1 = out_wait;
    repeat (10000) @(negedge clk);
    w2 = out_wait;
    refill(40000);
    w3 = out_wait;
    repeat (8) @(negedge clk);
    wr(32'h90, 32'h2);
    repeat (8) @(negedge clk);
    w4 = out_wait;
    $display("wait: %0d clocks waited by 40000 clocks, %0d more in 10000 clocks, %0d after a refill of 40000 clocks, %0d after the stop", w1, w2 - w1, w3 - w2, w4);
    // after a wait the DMA starts again (FIFO reset and fill): some 600 clocks more
    if (w1 == 0 || w2 - w1 != 10000 || w3 - w2 > 1000 || w4 != w3) errors++;
  end
  // trigger mode: armed once the FIFO is full, silent until the trigger edge, then plays
  tmode = 1; rle = 1;
  wr(32'h90, 32'h22);
  samples = 0; started = 0; values = 0; badRun = 0; jumps = 0; gaps = 0; active = 1;
  wr(32'h90, 32'h1);
  repeat (3000) @(negedge clk);
  if (!armed || samples != 0) begin errors++; $display("  trigger mode: armed %0d, %0d samples before the trigger", armed, samples); end
  trig = 1;
  repeat (5000) @(negedge clk);
  trig = 0;
  active = 0;
  $display("trigger mode: %0d samples after the trigger, %0d wrong run lengths, armed %0d", samples, badRun, armed);
  if (samples < 4000 || badRun > 0 || armed) errors++;
  wr(32'h90, 32'h2);
  tmode = 0;
  if (errors == 0) $display("PASS gpio_out_tb"); else $display("FAIL gpio_out_tb");
  $finish;
end
endmodule
