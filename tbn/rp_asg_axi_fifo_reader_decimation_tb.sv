`timescale 1ns/1ps

module rp_asg_axi_fifo_reader_decimation_tb;
  localparam int DW = 64;

  logic clk = 1'b0;
  logic rstn = 1'b0;
  logic set_rst = 1'b0;
  logic trig = 1'b0;
  logic axi_en = 1'b1;
  logic [31:0] axi_start = 32'h100;
  logic [31:0] axi_stop = 32'hfc;
  logic [31:0] axi_dec = 32'd1;
  logic [15:0] cyc_cnt = 16'd1;
  logic repeat_en = 1'b0;
  logic [63:0] fifo_data = 64'h0004_0003_0002_0001;
  logic fifo_valid = 1'b0;
  logic fifo_empty = 1'b0;
  logic [6:0] fifo_level = 7'd16;
  logic fifo_rd;
  logic [13:0] dac;
  logic [19:0] axi_state;
  logic axi_last;
  logic axi_last_pre;
  logic axi_first;
  logic start_pulse;

  int errors = 0;
  int last_count = 0;
  logic [31:0] ref_cnt;
  logic ref_last;
  logic ref_lt;

  always #2 clk = ~clk;

  rp_asg_axi_fifo_reader #(
    .DW(DW),
    .AW(32),
    .FIFO_PRELOAD_SIZE(1),
    .RD_LVL_W(7)
  ) dut (
    .dac_o(dac),
    .dac_clk_i(clk),
    .dac_rstn_i(rstn),
    .trig_i(trig),
    .set_rst_i(set_rst),
    .set_axi_en_i(axi_en),
    .set_axi_start_i(axi_start),
    .set_axi_stop_i(axi_stop),
    .set_axi_dec_i(axi_dec),
    .set_cyc_cnt_i(cyc_cnt),
    .repeat_i(repeat_en),
    .axi_state_o(axi_state),
    .axi_last_o(axi_last),
    .axi_last_pre_o(axi_last_pre),
    .axi_first_o(axi_first),
    .start_pulse_o(start_pulse),
    .dat_fifo_out(fifo_data),
    .dat_rd_valid(fifo_valid),
    .dat_fifo_empty(fifo_empty),
    .dat_rd_fifo_lvl(fifo_level),
    .dat_fifo_rd(fifo_rd)
  );

  // One-cycle-latency FIFO response. Only the FIFO itself is modeled; the
  // reader, buffering, state machine, counters and outputs are the real DUT.
  always_ff @(posedge clk) begin
    fifo_valid <= fifo_rd && !fifo_empty;
    if (fifo_rd && !fifo_empty)
      fifo_data <= {fifo_data[47:0], fifo_data[63:48] + 16'd4};
  end

  always @(posedge clk) begin
    if (!rstn || set_rst) begin
      ref_cnt = 32'd1;
      ref_last = 1'b1;
      ref_lt = 1'b0;
    end else if (dut.output_valid) begin
      if (ref_lt) begin
        ref_cnt = ref_cnt + 32'd1;
        ref_last = (ref_cnt == dut.dec_safe);
        ref_lt = (ref_cnt < dut.dec_safe);
      end else begin
        ref_cnt = 32'd1;
        ref_last = (dut.dec_safe == 32'd1);
        ref_lt = (32'd1 < dut.dec_safe);
      end
    end else begin
      ref_cnt = 32'd1;
      ref_last = (dut.dec_safe == 32'd1);
      ref_lt = (32'd1 < dut.dec_safe);
    end

    #1;
    if (rstn && !set_rst && dut.dec_step !== ref_last) begin
      $error("dec_step mismatch: dec=%0d valid=%0b expected=%0b got=%0b",
             dut.dec_safe, dut.output_valid, ref_last, dut.dec_step);
      errors++;
    end
    if (axi_last)
      last_count++;
  end

  task automatic reset_dut;
    begin
      rstn = 1'b0;
      trig = 1'b0;
      repeat_en = 1'b0;
      fifo_empty = 1'b0;
      repeat (3) @(posedge clk);
      rstn = 1'b1;
      repeat (3) @(posedge clk);
    end
  endtask

  task automatic trigger_once;
    begin
      @(negedge clk);
      trig = 1'b1;
      @(negedge clk);
      trig = 1'b0;
    end
  endtask

  task automatic run_single_word(input logic [31:0] decimation);
    int timeout;
    begin
      reset_dut();
      axi_dec = decimation;
      axi_stop = axi_start - 32'd4;
      cyc_cnt = 16'd1;
      repeat (2) @(posedge clk);
      trigger_once();
      timeout = 0;
      while (!axi_last && timeout < 300) begin
        @(posedge clk);
        timeout++;
      end
      if (!axi_last) begin
        $error("timeout for decimation %0d", decimation);
        errors++;
      end
    end
  endtask

  initial begin
    run_single_word(32'd0);
    run_single_word(32'd1);
    run_single_word(32'd2);
    run_single_word(32'd7);

    // The active burst must keep its start-time setting despite live changes.
    reset_dut();
    axi_dec = 32'd5;
    axi_stop = axi_start + 32'd116; // sixteen FIFO words
    cyc_cnt = 16'd0;
    repeat (2) @(posedge clk);
    trigger_once();
    wait (dut.output_valid);
    axi_dec = 32'd2;
    repeat (12) @(posedge clk);
    if (dut.axi_dec_q != 32'd5) begin
      $error("decimation configuration changed during playback");
      errors++;
    end

    // Starve a longer burst until all prefetched data drains. The legacy
    // phase model above checks that invalid clocks continuously reset phase.
    fifo_empty = 1'b1;
    wait (!dut.output_valid);
    repeat (8) @(posedge clk);
    fifo_empty = 1'b0;
    wait (dut.output_valid);
    repeat (8) @(posedge clk);

    // A large runtime setting is checked without waiting billions of clocks.
    reset_dut();
    axi_dec = 32'h8000_0001;
    repeat (2) @(posedge clk);
    trigger_once();
    wait (dut.output_valid);
    #1;
    if (dut.dec_countdown_q != 32'h8000_0000) begin
      $error("large decimation reload mismatch: %h", dut.dec_countdown_q);
      errors++;
    end
    @(posedge clk);
    #1;
    if (dut.dec_countdown_q != 32'h7fff_ffff) begin
      $error("large decimation first decrement mismatch: %h", dut.dec_countdown_q);
      errors++;
    end

    // Repeat/restart must retain cadence across multiple one-word cycles.
    reset_dut();
    axi_dec = 32'd3;
    repeat_en = 1'b1;
    axi_stop = axi_start - 32'd4;
    last_count = 0;
    repeat (2) @(posedge clk);
    trigger_once();
    wait (last_count >= 3);
    repeat_en = 1'b0;
    repeat (20) @(posedge clk);

    if (errors == 0)
      $display("PASS: AXI FIFO reader decimation sequencing");
    else
      $fatal(1, "FAIL: %0d errors", errors);
    $finish;
  end

  initial begin
    #200000;
    $fatal(1, "global timeout");
  end
endmodule
