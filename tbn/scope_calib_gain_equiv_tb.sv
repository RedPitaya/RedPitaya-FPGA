`timescale 1ns/1ps

// Bit-exact differential test for narrowing the Scope calibration multiplier.
// This is intentionally independent of the RTL module so expression width and
// signedness changes can be checked before integrating the replacement.
module scope_calib_gain_equiv_tb;
  logic signed [16:0] offset;
  logic        [15:0] gain;
  logic signed [61:0] old_result;
  logic signed [61:0] narrow_result;
  integer checks;

  function automatic signed [61:0] old_formula(
    input logic signed [16:0] offset_arg,
    input logic        [15:0] gain_arg
  );
    logic signed [31:0] old_offset_operand;
    logic signed [30:0] old_gain_operand;
    logic signed [62:0] old_product;
    begin
      old_offset_operand = {offset_arg, 15'b0};
      old_gain_operand   = {15'b0, gain_arg};
      old_product        = old_offset_operand * old_gain_operand;
      old_formula        = old_product >>> 30;
    end
  endfunction

  function automatic signed [61:0] narrow_formula(
    input logic signed [16:0] offset_arg,
    input logic        [15:0] gain_arg
  );
    logic signed [16:0] positive_gain;
    logic signed [33:0] narrow_product;
    begin
      positive_gain  = {1'b0, gain_arg};
      narrow_product = offset_arg * positive_gain;
      narrow_formula = narrow_product >>> 15;
    end
  endfunction

  task automatic check_one(
    input logic signed [16:0] offset_arg,
    input logic        [15:0] gain_arg
  );
    begin
      offset        = offset_arg;
      gain          = gain_arg;
      old_result    = old_formula(offset_arg, gain_arg);
      narrow_result = narrow_formula(offset_arg, gain_arg);
      #1;
      if (old_result !== narrow_result) begin
        $error("mismatch offset=%0d (0x%h) gain=%0d (0x%h) old=%0d narrow=%0d",
               offset_arg, offset_arg, gain_arg, gain_arg,
               old_result, narrow_result);
        $fatal(1);
      end
      checks = checks + 1;
    end
  endtask

  logic [15:0] directed_gains [0:8];
  integer offset_value;
  integer gain_index;
  integer random_index;
  integer random_seed;

  initial begin
    checks = 0;
    directed_gains[0] = 16'h0000;
    directed_gains[1] = 16'h0001;
    directed_gains[2] = 16'h0002;
    directed_gains[3] = 16'h3fff;
    directed_gains[4] = 16'h4000;
    directed_gains[5] = 16'h7fff;
    directed_gains[6] = 16'h8000;
    directed_gains[7] = 16'hfffe;
    directed_gains[8] = 16'hffff;

    // Exhaust every possible signed 17-bit offset for gains around the
    // zero, half-scale, sign-bit and maximum boundaries.
    for (gain_index = 0; gain_index < 9; gain_index = gain_index + 1)
      for (offset_value = -65536; offset_value <= 65535;
           offset_value = offset_value + 1)
        check_one(offset_value, directed_gains[gain_index]);

    // Reproducible pseudo-random coverage across both complete input ranges.
    random_seed = 32'h5c0a_2501;
    random_seed = $urandom(random_seed);
    for (random_index = 0; random_index < 250000;
         random_index = random_index + 1)
      check_one($urandom, $urandom);

    $display("SUCCESS: %0d bit-exact Scope gain calculations", checks);
    $finish;
  end
endmodule
