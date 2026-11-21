// rp_dma_mm2s (DAC DMA, rtl variant): the normal mode repeats buffer 1 in the FPGA, endless
// (loop count 0) or a given number of times, and then puts out 0; the streaming mode still swaps
// the two buffers re-armed by software. Every sample in memory is numbered, so a held sample, a
// skipped or an extra one breaks the expected sequence at the output.
// The AXI slave stalls the address and the data at random. Self checking: prints PASS or FAIL.
`timescale 1ns / 1ps

module dac_loop_tb;

localparam BUF1 = 32'h0001_0000;
localparam BUF2 = 32'h0003_0000;
localparam TAG1 = 16'h1000;  // sample i of buffer 1 is TAG1 + i
localparam TAG2 = 16'h6000;

// control and status bits of one channel
localparam C_START = 8'h01, C_RESET = 8'h02, C_NORM = 8'h10, C_STREAM = 8'h20, C_BUF1 = 8'h40, C_BUF2 = 8'h80;
localparam S_BUF1_FREE = 7, S_BUF2_FREE = 8, S_LOOP_DONE = 9;

int unsigned errors = 0;

reg aclk = 0, sclk = 0;
always #4 aclk = ~aclk;
initial begin #1.3; forever #4 sclk = ~sclk; end
reg rstn = 0;

reg  [7:0]  ctrl = 0;
reg         ctrl_val = 0;
reg  [31:0] buf_size = 0, loop_cnt = 0;
reg         trig_mode = 0, trig_pulse = 0, dma_trig = 0;
wire [31:0] sts, played;
wire [15:0] dout;
wire        dvalid;
wire        pstart;

wire [31:0] araddr; wire [7:0] arlen; wire arvalid; reg arready = 0;
reg  [63:0] rdata = 0; reg rlast = 0, rvalid = 0; wire rready;

rp_dma_mm2s #(.AXI_ADDR_BITS(32), .AXI_DATA_BITS(64), .AXIS_DATA_BITS(16), .AXI_BURST_LEN(16)) dut (
  .m_axi_aclk (aclk), .s_axis_aclk (sclk), .axi_rstn (rstn), .adc_rstn (rstn),
  .busy (), .intr (), .mode (), .ctrl_val (ctrl_val), .reg_sts (sts),
  .dac_step (32'h1_0000), .dac_buf_size (buf_size), .dac_buf1_adr (BUF1), .dac_buf2_adr (BUF2),
  .dac_rp (), .dac_trig (dma_trig), .dac_ctrl_reg (ctrl), .loop_cnt (loop_cnt), .loop_played (played),
  .dac_rdata_o (dout), .dac_rvalid_o (dvalid), .diag_reg (), .diag_reg2 (),
  .set_8bit_i (1'b0), .trigger_mode_i (trig_mode), .trigger_pulse_i (trig_pulse), .armed_o (), .play_start_o (pstart),
  .m_axi_arid_o (), .m_axi_araddr_o (araddr), .m_axi_arlen_o (arlen), .m_axi_arsize_o (),
  .m_axi_arburst_o (), .m_axi_arlock_o (), .m_axi_arcache_o (), .m_axi_arprot_o (),
  .m_axi_arvalid_o (arvalid), .m_axi_arready_i (arready), .m_axi_arqos_o (),
  .m_axi_rid_i (4'h0), .m_axi_rdata_i (rdata), .m_axi_rresp_i (2'b00), .m_axi_rlast_i (rlast),
  .m_axi_rvalid_i (rvalid), .m_axi_rready_o (rready));

// memory: 64-bit words, little endian 16-bit samples
bit [63:0] mem [int unsigned];
task automatic fill(int unsigned base, int unsigned n, bit [15:0] tag);
  for (int unsigned i = 0; i < n; i += 4)
    mem[(base >> 3) + i / 4] = {tag + 16'(i + 3), tag + 16'(i + 2), tag + 16'(i + 1), tag + 16'(i)};
endtask

// AXI read slave: one burst at a time, random stalls on the address and between the beats
int unsigned STALL = 30;     // % of clocks without a beat
int unsigned AR_DELAY = 0;   // clocks before a read address is accepted, besides the random ones
// The stalls come from this process alone, seeded by +seed=N: the same stalls whatever other
// processes the design has (a new register in the DUT changed them through the default seeding).
int unsigned SEED = 1;
initial void'($value$plusargs("seed=%d", SEED));
bit seeded = 0;
always begin
  if (!seeded) begin process::self().srandom(SEED); seeded = 1; end
  @(posedge aclk);
  if (arvalid) begin
    int unsigned a, n;
    repeat ($urandom % 4 + AR_DELAY) @(posedge aclk);
    arready <= 1; a = araddr; n = arlen + 1;
    @(posedge aclk); arready <= 0;
    repeat (2 + $urandom % 6) @(posedge aclk);
    for (int unsigned b = 0; b < n; b++) begin
      while ($urandom % 100 < STALL) begin rvalid <= 0; @(posedge aclk); end
      rvalid <= 1; rlast <= b == n - 1;
      rdata <= mem.exists((a >> 3) + b) ? mem[(a >> 3) + b] : 64'hDEAD_DEAD_DEAD_DEAD;
      do @(posedge aclk); while (!rready);
    end
    rvalid <= 0; rlast <= 0;
  end
end

// AXI rule: a read address stays valid and unchanged until it is accepted
int unsigned axi_errors = 0;
reg          ar_wait = 0;
reg  [31:0]  ar_addr = 0;
always @(posedge aclk) begin
  if (ar_wait && (!arvalid || araddr != ar_addr)) axi_errors++;
  ar_wait <= arvalid && !arready;
  ar_addr <= araddr;
end

// output samples, as the DAC takes them
bit [15:0] out[$];
bit        out_v[$];
bit        out_p[$];  // play_start_o: the trigger output of the channel (dac_top trig_op)
bit        rec = 0;
always @(posedge sclk) if (rec) begin out.push_back(dout); out_v.push_back(dvalid); out_p.push_back(pstart); end

task automatic write_ctrl(bit [7:0] v);
  @(posedge aclk); ctrl <= v; ctrl_val <= 1;
  @(posedge aclk); ctrl_val <= 0;
  repeat (2) @(posedge aclk);
endtask

task automatic check(bit ok, string what);
  if (!ok) begin errors++; $display("FAIL  %s (t=%0t)", what, $time); end
  else $display("ok    %s", what);
endtask

// play_start_o pulses recorded, and the first one
function automatic int pulses();
  int c = 0;
  for (int i = 0; i < out_p.size(); i++) c += out_p[i];
  return c;
endfunction

function automatic int first_pulse();
  for (int i = 0; i < out_p.size(); i++) if (out_p[i]) return i;
  return -1;
endfunction

// one play_start_o pulse for the whole playback, as the output turns valid (the DAC starts):
// later swaps, refills after an empty FIFO and further triggers give no pulse. The first sample of
// the buffer `f` follows the valid zeros the output starts with.
task automatic check_start(int f, string what);
  int p = first_pulse();
  int v = -1;
  for (int i = 0; i < out_v.size(); i++) if (out_v[i]) begin v = i; break; end
  check(pulses() == 1 && p >= 0 && v >= p && v - p <= 2 && f >= v,
        $sformatf("%s: one start pulse, %0d clock(s) before the output turns valid (%0d pulses, sample 0 after %0d valid zeros)",
                  what, v - p, pulses(), f - v));
endtask

// first valid sample of the buffer at the output
// before sample i: only zeros (the output before the playback starts)
function automatic bit zeros_before(int i);
  for (int k = 0; k < i; k++) if (out[k] != 0) return 0;
  return 1;
endfunction

// any sample of buffer 1 put out
function automatic bit played_out();
  for (int i = 0; i < out.size(); i++) if (out_v[i] && out[i] >= TAG1 && out[i] < TAG2) return 1;
  return 0;
endfunction

function automatic int first_of(bit [15:0] tag);
  for (int i = 0; i < out.size(); i++) if (out_v[i] && out[i] == tag) return i;
  return -1;
endfunction

// count samples from i on that follow the repeated buffer (n samples); stops at the first break
function automatic int run_len(int i, int n, bit [15:0] tag);
  int k;
  bit [15:0] e;
  for (k = 0; i + k < out.size(); k++) begin
    e = tag + k % n;
    if (!out_v[i + k] || out[i + k] != e) break;
  end
  return k;
endfunction

// normal mode: reset, buffer 1, count, start
task automatic start_loop(int unsigned n, int unsigned count);
  write_ctrl(C_RESET | C_NORM);
  buf_size = n * 2; loop_cnt = count;
  write_ctrl(C_BUF1);
  out.delete(); out_v.delete(); out_p.delete(); rec = 1;
  write_ctrl(C_START);
endtask

task automatic wait_samples(int unsigned n);
  repeat (n) @(posedge sclk);
endtask

task automatic endless(int unsigned n, int unsigned reps);
  int f, l;
  start_loop(n, 0);
  wait_samples(reps * n + 3000);
  f = first_of(TAG1);
  l = f < 0 ? 0 : run_len(f, n, TAG1);
  check(f >= 0 && l >= reps * n, $sformatf("endless, %0d samples: %0d repeats seamless (%0d samples in a row)", n, reps, l));
  check(f >= 0 && zeros_before(f), $sformatf("endless, %0d samples: the playback starts with sample 0", n));
  check(played >= reps, $sformatf("endless, %0d samples: %0d repeats read", n, played));
  check(!sts[S_LOOP_DONE], "endless: not done");
  check_start(f, $sformatf("endless, %0d samples", n));
  write_ctrl(C_RESET);
  repeat (200) @(posedge aclk);
  rec = 0;
  check(!dvalid && dout == 0, "endless: reset stops the output, 0");
endtask

task automatic finite(int unsigned n, int unsigned count);
  int f, l, h, z;
  bit [15:0] last;
  start_loop(n, count);
  repeat (4) @(posedge aclk);
  check(!sts[S_LOOP_DONE], $sformatf("%0d x %0d: the start clears done", count, n));
  fork
    begin wait (sts[S_LOOP_DONE]); end
    begin wait_samples(count * n * 4 + 20000); end
  join_any
  disable fork;
  repeat (100) @(posedge sclk);
  rec = 0;
  f = first_of(TAG1);
  l = f < 0 ? 0 : run_len(f, n, TAG1);
  check(f >= 0 && l == count * n, $sformatf("%0d x %0d samples: exactly %0d in a row (%0d)", count, n, count * n, l));
  check(f >= 0 && zeros_before(f), $sformatf("%0d x %0d: the playback starts with sample 0", count, n));
  h = 0;
  last = TAG1 + n - 1;
  while (f >= 0 && f + l + h < out.size() && out_v[f + l + h] && out[f + l + h] == last) h++;
  z = f + l + h;
  check(h < 64, $sformatf("%0d x %0d: the last sample held %0d clocks before the stop", count, n, h));
  check(z < out.size() && out[z] == 0 && !out_v[z], $sformatf("%0d x %0d: then the output is 0", count, n));
  for (int i = z; i < out.size(); i++) if (out[i] != 0 || out_v[i]) begin
    check(0, $sformatf("%0d x %0d: output stays 0 (sample %0d is %h)", count, n, i - z, out[i])); break;
  end
  check(sts[S_LOOP_DONE], $sformatf("%0d x %0d: done in the status", count, n));
  check(played == count, $sformatf("%0d x %0d: %0d repeats read", count, n, played));
  check_start(f, $sformatf("%0d x %0d", count, n));
endtask

// trigger mode with the normal mode: armed and quiet until the first trigger, which starts the
// repeats; later triggers (the playback one and the DMA one that swaps buffers in the streaming
// mode) change nothing until the stop or the end of the repeats
task automatic triggered(int unsigned n, int unsigned count);
  int f, l;
  string what = count ? $sformatf("%0d x %0d", count, n) : $sformatf("endless %0d", n);
  trig_mode = 1;
  start_loop(n, count);
  repeat (3000) @(posedge sclk);
  check(out.size() > 0 && first_of(TAG1) < 0 && !played_out(), $sformatf("triggered %s: nothing played before the trigger", what));
  check(pulses() == 0, $sformatf("triggered %s: no start pulse while armed", what));
  @(posedge sclk) trig_pulse <= 1;
  @(posedge sclk) trig_pulse <= 0;
  // more triggers of both kinds while playing
  for (int k = 0; k < 8; k++) begin
    repeat (n / 2 + 37) @(posedge sclk);
    if (k % 2) begin @(posedge sclk) trig_pulse <= 1; @(posedge sclk) trig_pulse <= 0; end
    else begin  // the DMA trigger is a level (dac_top ctl_trg): held over several bursts
      @(posedge aclk) dma_trig <= 1;
      repeat (200) @(posedge aclk);
      dma_trig <= 0;
    end
  end
  if (count) begin
    fork
      wait (sts[S_LOOP_DONE]);
      wait_samples(count * n * 4 + 20000);
    join_any
    disable fork;
  end else
    wait_samples(6 * n);
  repeat (100) @(posedge sclk);
  rec = 0;
  f = first_of(TAG1);
  l = f < 0 ? 0 : run_len(f, n, TAG1);
  check_start(f, $sformatf("triggered %s, 8 more triggers", what));
  if (count) begin
    check(f >= 0 && l == count * n, $sformatf("triggered %s: exactly %0d in a row despite 8 more triggers (%0d)", what, count * n, l));
    check(sts[S_LOOP_DONE] && played == count, $sformatf("triggered %s: done, %0d repeats read", what, played));
  end else begin
    check(f >= 0 && l >= 6 * n, $sformatf("triggered %s: seamless despite 8 more triggers (%0d samples in a row)", what, l));
    write_ctrl(C_RESET);
    repeat (200) @(posedge aclk);
  end
  trig_mode = 0;
endtask

// streaming mode, software swapping the buffers as CGenerator::setDataAddress does. The buffer
// armed last holds `last` samples (the end of a file): the size register is written when it is
// armed, while the other buffer is being read, and must not cut that one short. It stays so (as
// in software) or, with `rewrite`, is written again right after: the armed buffer keeps its size.
task automatic streaming(int unsigned n, int unsigned swaps, int unsigned last = 0, bit rewrite = 0);
  int f, k, idx, ok, total, b, i;
  if (last == 0) last = n;
  write_ctrl(C_RESET | C_STREAM);
  buf_size = n * 2;
  write_ctrl(C_BUF1);
  write_ctrl(C_BUF2);
  out.delete(); out_v.delete(); out_p.delete(); rec = 1;
  write_ctrl(C_START);
  idx = 0;
  for (int s = 0; s < swaps; s++) begin
    wait (sts[idx ? S_BUF2_FREE : S_BUF1_FREE]);
    if (s == swaps - 1) buf_size = last * 2;
    write_ctrl(idx ? C_BUF2 : C_BUF1);
    if (rewrite) buf_size = n * 2;
    idx = !idx;
    repeat (20) @(posedge aclk);
  end
  wait_samples(2 * n + 2000);
  rec = 0;
  // buffer 1, buffer 2, buffer 1, ... with no break, the last one `last` samples long. Arming in
  // IDLE is dropped: buffer 1 is read from the start anyway, the first swap re-arms it, so the
  // buffers played are the `swaps` armed ones.
  total = (swaps - 1) * n + last;
  f = first_of(TAG1); k = 0; ok = f >= 0;
  while (ok && f + k < out.size() && k < total) begin
    bit [15:0] e;
    b = k / n; i = k % n;
    e = ((b % 2) ? TAG2 : TAG1) + i;
    if (!out_v[f + k] || out[f + k] != e) ok = 0; else k++;
  end
  check(ok && k == total, $sformatf("streaming, %0d samples: %0d buffers alternate seamlessly, the last one %0d samples (%0d of %0d)",
                                    n, swaps, last, k, total));
  if (last < n)
    check(f >= 0 && (f + total >= out.size() || out[f + total] != (((swaps - 1) % 2) ? TAG2 : TAG1) + last),
          "streaming: nothing past the end of the short last buffer");
  check(!sts[S_LOOP_DONE], "streaming: no loop done");
  check_start(f, $sformatf("streaming, %0d buffers", swaps));
  write_ctrl(C_RESET);
endtask

// reset while a read address waits to be accepted: the DMA must keep it and take the data
task automatic reset_in_request();
  int unsigned axi_errors_was = axi_errors;
  start_loop(1024, 0);
  AR_DELAY = 40;
  repeat (2000) @(posedge aclk);
  wait (arvalid && !arready);
  @(posedge aclk); ctrl <= C_RESET; ctrl_val <= 1;
  @(posedge aclk); ctrl_val <= 0;
  repeat (400) @(posedge aclk);
  AR_DELAY = 0;
  rec = 0;
  check(axi_errors == axi_errors_was, "reset during a read request: the address held until accepted");
  check(!dvalid, "reset during a read request: idle after the burst");
endtask

initial begin
  fill(BUF1, 4096, TAG1);
  fill(BUF2, 4096, TAG2);
  repeat (20) @(posedge aclk);
  rstn = 1;
  repeat (20) @(posedge aclk);

  endless(1024, 8);
  endless(64, 40);  // one burst
  finite(1024, 3);
  finite(1024, 1);
  finite(64, 5);
  finite(512, 2);   // again after a finished one
  // A slow AXI: repeats stay seamless once playing. The playback starts with what the FIFO holds
  // (as in the streaming mode), so the start needs reads faster than the DAC: not checked here.
  STALL = 60;
  endless(256, 20);
  STALL = 30;
  finite(256, 4);
  triggered(1024, 3);
  triggered(512, 0);
  reset_in_request();
  finite(256, 2);   // works after it
  streaming(1024, 6);
  streaming(1024, 5, 256);     // a short last buffer (the end of a file)
  streaming(512, 4, 64);       // one burst
  streaming(1024, 5, 256, 1);  // the size register written again after arming
  endless(512, 6);  // the normal mode after the streaming one

  check(axi_errors == 0, $sformatf("AXI read address held until accepted (%0d violations)", axi_errors));
  if (errors == 0) $display("PASS  dac_loop_tb");
  else $display("FAIL  dac_loop_tb: %0d errors", errors);
  $finish;
end


initial begin
  #20ms;
  $display("FAIL  dac_loop_tb: timeout");
  $finish;
end

endmodule
