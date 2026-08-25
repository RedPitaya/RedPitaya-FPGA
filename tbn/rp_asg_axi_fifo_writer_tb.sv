`timescale 1ns/1ps

// Behavioural model of the generated CDC FIFO used only to deliver the
// writer's configuration request.  The DUT itself is the production RTL.
module sync_fifo (
  input  logic         wr_clk, rd_clk, rst,
  input  logic [127:0] din,
  input  logic         wr_en, rd_en,
  output logic         full,
  output logic [127:0] dout,
  output logic         empty, valid, wr_rst_busy, rd_rst_busy
);
  logic [127:0] data_q;
  logic wr_toggle_q;
  logic rd_toggle_q;

  assign full = 1'b0;
  assign empty = wr_toggle_q == rd_toggle_q;
  assign wr_rst_busy = rst;
  assign rd_rst_busy = rst;

  always_ff @(posedge wr_clk or posedge rst) begin
    if (rst) begin
      data_q <= '0;
      wr_toggle_q <= 1'b0;
    end else if (wr_en) begin
      data_q <= din;
      wr_toggle_q <= ~wr_toggle_q;
    end
  end

  always_ff @(posedge rd_clk or posedge rst) begin
    if (rst) begin
      dout <= '0;
      valid <= 1'b0;
      rd_toggle_q <= 1'b0;
    end else begin
      valid <= rd_en && (wr_toggle_q != rd_toggle_q);
      if (rd_en && (wr_toggle_q != rd_toggle_q)) begin
        dout <= data_q;
        rd_toggle_q <= wr_toggle_q;
      end
    end
  end
endmodule

module rp_asg_axi_fifo_writer_tb;
  localparam int AW = 32;
  localparam int DW = 64;
  localparam int MAX_REQ = 256;

  logic axi_clk = 1'b0;
  logic dac_clk = 1'b0;
  logic axi_rstn = 1'b0;
  logic dac_rstn = 1'b0;
  logic start_pulse = 1'b0;
  logic set_rst = 1'b0;
  logic [AW-1:0] set_start = '0;
  logic [AW-1:0] set_stop = '0;
  logic [DW-1:0] fifo_data;
  logic fifo_wr;
  logic fifo_full = 1'b0;
  logic [6:0] fifo_level = '0;
  logic fifo_rst_busy = 1'b0;
  logic fifo_reset;

  logic ready_enable = 1'b1;
  logic response_enable = 1'b1;
  integer errors = 0;
  integer accepted_count = 0;
  integer returned_count = 0;
  logic [AW-1:0] accepted_addr [0:MAX_REQ-1];
  integer accepted_beats [0:MAX_REQ-1];
  logic [AW-1:0] rsp_addr [0:MAX_REQ-1];
  integer rsp_beats [0:MAX_REQ-1];
  integer rsp_head = 0;
  integer rsp_tail = 0;
  integer rsp_index = 0;
  integer restart_req_index = 0;
  logic rsp_active = 1'b0;
  logic hold_valid = 1'b0;
  logic [AW-1:0] hold_addr = '0;
  logic [3:0] hold_len = '0;

  always #4 axi_clk = ~axi_clk;
  always #5 dac_clk = ~dac_clk;

  axi_sys_if #(.AW(AW), .DW(DW), .LW(4)) axi (.clk(axi_clk), .rstn(axi_rstn));

  rp_asg_axi_fifo_writer #(
    .DW(DW), .AW(AW), .LW(4), .AXI_BURST_LEN(16),
    .DATA_REQUEST_LEVEL(112), .WR_LVL_W(7), .MAX_OUTSTANDING_BURSTS(8)
  ) dut (
    .dac_clk_i(dac_clk), .dac_rstn_i(dac_rstn),
    .start_pulse_i(start_pulse), .set_rst_i(set_rst),
    .set_axi_start_i(set_start), .set_axi_stop_i(set_stop),
    .axi_sys(axi), .dat_fifo_idata(fifo_data), .dat_fifo_wr(fifo_wr),
    .dat_fifo_full(fifo_full), .dat_wr_fifo_lvl(fifo_level),
    .dat_fifo_rst_busy(fifo_rst_busy), .axi_fifo_reset(fifo_reset)
  );

  assign axi.werr = 1'b0;
  assign axi.wrdy = 1'b0;
  assign axi.rerr = 1'b0;
  assign axi.rardy = ready_enable;

  // Ordered AXI read responder. Data encodes the byte address of each beat.
  always @(posedge axi_clk) begin
    if (!axi_rstn) begin
      axi.rrdym <= 1'b0;
      axi.rlast <= 1'b0;
      axi.rdata <= '0;
      rsp_head <= 0;
      rsp_tail <= 0;
      rsp_index <= 0;
      rsp_active <= 1'b0;
      accepted_count <= 0;
      returned_count <= 0;
    end else begin
      if (axi.ARtransfer) begin
        accepted_addr[accepted_count] <= axi.raddr;
        accepted_beats[accepted_count] <= axi.rlen + 1;
        accepted_count <= accepted_count + 1;
        rsp_addr[rsp_tail] <= axi.raddr;
        rsp_beats[rsp_tail] <= axi.rlen + 1;
        rsp_tail <= rsp_tail + 1;
      end

      if (!rsp_active && (rsp_head < rsp_tail)) begin
        rsp_active <= 1'b1;
        rsp_index <= 0;
      end

      axi.rrdym <= response_enable && rsp_active;
      if (response_enable && rsp_active) begin
        axi.rdata <= {{(DW-AW){1'b0}}, rsp_addr[rsp_head] + rsp_index*8};
        axi.rlast <= rsp_index == rsp_beats[rsp_head]-1;
      end else begin
        axi.rlast <= 1'b0;
      end

      if (axi.Rtransfer) begin
        returned_count <= returned_count + 1;
        if (rsp_index == rsp_beats[rsp_head]-1) begin
          rsp_active <= 1'b0;
          rsp_head <= rsp_head + 1;
          rsp_index <= 0;
        end else begin
          rsp_index <= rsp_index + 1;
        end
      end
    end
  end

  // AXI requires the address request to remain stable while stalled.
  always @(posedge axi_clk) begin
    if (!axi_rstn || !axi.rvalid) begin
      hold_valid <= 1'b0;
    end else if (!hold_valid) begin
      hold_valid <= 1'b1;
      hold_addr <= axi.raddr;
      hold_len <= axi.rlen;
    end else if (!axi.rardy && ((axi.raddr !== hold_addr) || (axi.rlen !== hold_len))) begin
      $error("AR payload changed under backpressure");
      errors <= errors + 1;
    end
  end

  task automatic reset_dut;
    begin
      axi_rstn = 1'b0;
      dac_rstn = 1'b0;
      set_rst = 1'b0;
      start_pulse = 1'b0;
      fifo_full = 1'b0;
      fifo_level = '0;
      ready_enable = 1'b1;
      response_enable = 1'b1;
      repeat (5) @(posedge axi_clk);
      axi_rstn = 1'b1;
      dac_rstn = 1'b1;
      repeat (5) @(posedge axi_clk);
    end
  endtask

  task automatic launch(input logic [AW-1:0] base, input integer words);
    begin
      set_start = base;
      set_stop = base + (words-1)*8;
      @(posedge dac_clk);
      start_pulse = 1'b1;
      @(posedge dac_clk);
      start_pulse = 1'b0;
    end
  endtask

  task automatic wait_requests(input integer count);
    integer timeout;
    begin
      timeout = 0;
      while ((accepted_count < count) && timeout < 2000) begin
        @(posedge axi_clk);
        timeout = timeout + 1;
      end
      if (accepted_count < count) begin
        $error("timeout waiting for %0d requests, got %0d", count, accepted_count);
        errors = errors + 1;
      end
    end
  endtask

  task automatic check_request(input integer idx, input logic [AW-1:0] addr, input integer beats);
    begin
      if ((accepted_addr[idx] !== addr) || (accepted_beats[idx] != beats)) begin
        $error("request %0d got addr=%08x beats=%0d, expected addr=%08x beats=%0d",
               idx, accepted_addr[idx], accepted_beats[idx], addr, beats);
        errors = errors + 1;
      end
    end
  endtask

  task automatic test_period(input integer words);
    logic [AW-1:0] base;
    integer requests_per_period;
    begin
      reset_dut();
      base = 32'h1000 + words*32'h100;
      requests_per_period = (words+15)/16;
      launch(base, words);
      wait_requests(2*requests_per_period);
      if (words <= 16) begin
        check_request(0, base, words);
        check_request(1, base, words);
      end else begin
        check_request(0, base, 16);
        check_request(1, base+128, words-16);
        check_request(2, base, 16);
        check_request(3, base+128, words-16);
      end
      $display("period %0d words passed", words);
    end
  endtask

  initial begin
    test_period(1);
    test_period(2);
    test_period(15);
    test_period(16);
    test_period(17);

    // Delayed ARREADY must preserve the complete request.
    reset_dut();
    ready_enable = 1'b0;
    launch(32'h8000, 17);
    repeat (12) @(posedge axi_clk);
    ready_enable = 1'b1;
    wait_requests(2);
    check_request(0, 32'h8000, 16);
    check_request(1, 32'h8080, 1);

    // FIFO full must backpressure R without losing or writing a beat.
    fifo_full = 1'b1;
    repeat (12) @(posedge axi_clk);
    if (fifo_wr) begin
      $error("FIFO write asserted while full");
      errors = errors + 1;
    end
    fifo_full = 1'b0;
    repeat (20) @(posedge axi_clk);

    // Restart while reads are outstanding: old responses are drained, not
    // written, and the next request starts from the new configuration.
    reset_dut();
    response_enable = 1'b0;
    launch(32'h9000, 32);
    wait_requests(2);
    set_rst = 1'b1;
    repeat (4) @(posedge axi_clk);
    set_rst = 1'b0;
    response_enable = 1'b1;
    repeat (80) @(posedge axi_clk);
    if (fifo_wr) begin
      $error("stale data written during restart flush");
      errors = errors + 1;
    end
    restart_req_index = accepted_count;
    launch(32'ha000, 2);
    wait_requests(restart_req_index + 1);
    check_request(restart_req_index, 32'ha000, 2);

    repeat (20) @(posedge axi_clk);
    if (errors == 0)
      $display("PASS: rp_asg_axi_fifo_writer regression");
    else
      $fatal(1, "FAIL: %0d errors", errors);
    $finish;
  end
endmodule
