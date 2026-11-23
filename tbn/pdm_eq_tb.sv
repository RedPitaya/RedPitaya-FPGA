// pdm of now against the pdm before the timing change (pdm_ref, tbn/pdm_ref.sv): the same pulse density in
// steady state for every value, the output 0 in reset, a value change followed within a period
`timescale 1ns / 1ps
module pdm_eq_tb;
  localparam int DWC = 8, CHN = 4;
  logic clk = 0, rstn = 0;
  always #2 clk = ~clk;
  logic [CHN-1:0][DWC-1:0] dat;
  logic [CHN-1:0] o_new, o_old;
  logic rdy_new, rdy_old;
  pdm     #(.DWC(DWC), .CHN(CHN)) dn (.clk(clk), .rstn(rstn), .cke(1'b1), .ena(1'b1), .rng(8'd255), .str_dat(dat), .str_vld(1'b1), .str_rdy(rdy_new), .pdm(o_new));
  pdm_ref #(.DWC(DWC), .CHN(CHN)) dref (.clk(clk), .rstn(rstn), .cke(1'b1), .ena(1'b1), .rng(8'd255), .str_dat(dat), .str_vld(1'b1), .str_rdy(rdy_old), .pdm(o_old));

  int errors = 0;
  int ones_new[CHN], ones_old[CHN], mism[CHN];
  // the old output SHIFT clocks later: the new one takes the data a clock later (ld), and with
  // sub_q decides a clock later still
  localparam int SHIFT = 2;
  logic [CHN-1:0] o_chain [0:SHIFT];
  logic [CHN-1:0] o_old_d;
  always_comb o_chain[0] = o_old;
  for (genvar k = 1; k <= SHIFT; k++) begin: g_shift
    always_ff @(posedge clk) o_chain[k] <= o_chain[k-1];
  end
  assign o_old_d = o_chain[SHIFT];
  task automatic count(int cycles);
    for (int c = 0; c < CHN; c++) begin ones_new[c] = 0; ones_old[c] = 0; mism[c] = 0; end
    repeat (cycles) begin
      @(posedge clk);
      for (int c = 0; c < CHN; c++) begin
        ones_new[c] += o_new[c]; ones_old[c] += o_old[c];
        if (o_new[c] !== o_old_d[c]) mism[c]++;
      end
    end
  endtask

  initial begin
    dat = '0;
    repeat (6) @(posedge clk);
    // the output is 0 in reset (after the reset reached it)
    for (int i = 0; i < 8; i++) begin
      @(posedge clk);
      if (i > 2 && (o_new !== '0)) begin errors++; $display("FAIL output not 0 in reset"); end
    end
    rstn = 1;
    // from a reset, every 5th value and the ends, a different value a channel: the new stream is
    // the old one SHIFT clocks later, bit for bit
    for (int v = 0; v < 256; v += (v < 8 || v > 247) ? 1 : 5) begin
      rstn = 0;
      for (int c = 0; c < CHN; c++) dat[c] = 8'(v + c * 37);
      repeat (6) @(posedge clk);
      rstn = 1;
      repeat (3 * 256) @(posedge clk);       // settle
      count(8 * 256);                         // 8 periods
      for (int c = 0; c < CHN; c++)
        if (mism[c] != 0) begin
          errors++;
          $display("FAIL value %0d ch %0d: %0d cycles differ from the old stream SHIFT clocks later (ones new %0d old %0d)", 8'(v + c * 37), c, mism[c], ones_new[c], ones_old[c]);
        end
    end
    // a value change is followed with the same density: the ones of 8 periods, 0..2 apart (the window edge)
    begin
      int worst = 0;
      for (int v = 0; v < 256; v += 7) begin
        for (int c = 0; c < CHN; c++) dat[c] = 8'(v * 3 + c * 61);
        repeat (3 * 256) @(posedge clk);
        count(8 * 256);
        for (int c = 0; c < CHN; c++) begin
          int d = ones_new[c] - ones_old[c];
          if (d < 0) d = -d;
          if (d > worst) worst = d;
        end
      end
      $display("value changes: the worst difference of the ones in 8 periods: %0d", worst);
      if (worst > 2) begin errors++; $display("FAIL changes differ by %0d", worst); end
    end
    // value changes at random times: the ones of a window stay within 2 of the old
    begin
      int worst = 0;
      for (int k = 0; k < 40; k++) begin
        for (int c = 0; c < CHN; c++) dat[c] = 8'($urandom);
        repeat (1 + $urandom_range(0, 600)) @(posedge clk);
        count(3 * 256);
        for (int c = 0; c < CHN; c++) begin
          int d = ones_new[c] - ones_old[c];
          if (d < 0) d = -d;
          if (d > worst) worst = d;
        end
      end
      $display("random changes: the worst difference of the ones in 3 periods: %0d", worst);
      if (worst > 4) begin errors++; $display("FAIL changes differ by %0d", worst); end
    end
    if (errors == 0) $display("SUCCESS pdm_eq_tb"); else $display("FAILURE pdm_eq_tb: %0d errors", errors);
    $finish;
  end
endmodule
