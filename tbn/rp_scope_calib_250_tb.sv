`timescale 1ns / 1ps

module rp_scope_calib_250_tb;
  localparam integer DBITS = 16;
  localparam integer LATENCY = 7;

  reg                       clk = 1'b0;
  reg                       rstn = 1'b0;
  reg  signed [DBITS-1:0]   dat_i = '0;
  reg                       valid_i = 1'b0;
  reg  signed [DBITS-1:0]   offset_i = 16'sd1000;
  reg  signed [15:0]        gain_i = 16'sd16384;
  wire signed [DBITS-1:0]   dat_o;
  wire                      valid_o;

  integer cycle = 0;
  integer errors = 0;
  integer sample;
  reg signed [DBITS-1:0] expected [0:LATENCY];

  always #2 clk = ~clk;

  rp_scope_calib #(.DBITS(DBITS)) dut (
    .adc_clk_i(clk),
    .adc_rstn_i(rstn),
    .calib_dat_i(dat_i),
    .calib_din_tvalid_i(valid_i),
    .calib_dat_o(dat_o),
    .calib_dout_tvalid_o(valid_o),
    .cfg_calib_offset_i(offset_i),
    .cfg_calib_gain_i(gain_i)
  );

  function automatic signed [DBITS-1:0] reference_calib;
    input signed [DBITS-1:0] value;
    integer offset_value;
    integer saturated;
    integer gained;
    begin
      offset_value = value - $signed(offset_i);
      if (offset_value > 32767)
        saturated = 32767;
      else if (offset_value < -32768)
        saturated = -32768;
      else
        saturated = offset_value;

      gained = (saturated * $signed(gain_i)) >>> 15;
      if (gained > 32767)
        reference_calib = 16'sh7fff;
      else if (gained < -32768)
        reference_calib = 16'sh8000;
      else
        reference_calib = gained;
    end
  endfunction

  integer i;
  always @(posedge clk) begin
    if (!rstn) begin
      cycle <= 0;
      for (i = 0; i <= LATENCY; i = i + 1)
        expected[i] <= '0;
    end else begin
      expected[0] <= reference_calib(dat_i);
      for (i = 1; i <= LATENCY; i = i + 1)
        expected[i] <= expected[i-1];

      if (cycle >= 10 && dat_o !== expected[LATENCY-1]) begin
        $display("ERROR cycle=%0d got=%0d expected=%0d", cycle, dat_o,
                 expected[LATENCY-1]);
        errors <= errors + 1;
      end
      cycle <= cycle + 1;
    end
  end

  initial begin
    repeat (4) @(negedge clk);
    rstn = 1'b1;
    valid_i = 1'b1;

    // Allow the registered configuration to fill before checking samples.
    repeat (8) @(negedge clk);
    for (integer stimulus = 0; stimulus < 80; stimulus = stimulus + 1) begin
      sample = ((stimulus * 7919) & 16'hffff) - 32768;
      dat_i = sample;
      @(negedge clk);
    end
    repeat (LATENCY + 2) @(negedge clk);

    if (errors == 0)
      $display("SUCCESS: scope calibration samples preserved with pipelined limiter");
    else
      $fatal(1, "FAILED: %0d mismatches", errors);
    $finish;
  end
endmodule
