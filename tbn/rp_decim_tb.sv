////////////////////////////////////////////////////////////////////////////////
// Module: RP decimator testbench
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module rp_decim_tb #(
  realtime TP = 8.0ns,  // 125MHz
  int unsigned DW = 16
);

// DUT I/O
logic                adc_clk_i;
logic                adc_rstn_i;
logic [DW-1:0]       dec_dat_i;
logic [17-1:0]       set_dec_i;
logic                set_avg_en_i;
logic                set_hres_en_i;
logic                adc_arm_do_i;
logic                dec_val_o;
logic [DW-1:0]       dec_dat_o;
logic signed [DW-1:0] dec_dat_o_valid_hold;
int unsigned          dec_valid_count;

int unsigned errors = 0;

//------------------------------------------------------------------------------
// clock/reset
//------------------------------------------------------------------------------

initial        adc_clk_i = 1'b0;
always #(TP/2) adc_clk_i = ~adc_clk_i;

// `dec_dat_o` is only meaningful when `dec_val_o` is high.
// Hold the last valid sample for easier waveform inspection.
always @(posedge adc_clk_i) begin
  if (!adc_rstn_i) begin
    dec_dat_o_valid_hold <= '0;
    dec_valid_count      <= '0;
  end else if (dec_val_o) begin
    dec_dat_o_valid_hold <= $signed(dec_dat_o);
    dec_valid_count      <= dec_valid_count + 1;
  end
end

task automatic reset_dut(
  input int unsigned dec,
  input bit avg_en,
  input bit hres_en
);
begin
  adc_rstn_i    <= 1'b0;
  dec_dat_i     <= '0;
  set_dec_i     <= dec[16:0];
  set_avg_en_i  <= avg_en;
  set_hres_en_i   <= hres_en;
  adc_arm_do_i  <= 1'b0;
  repeat (4) @(posedge adc_clk_i);
  adc_rstn_i <= 1'b1;
end
endtask

task automatic arm_once;
begin
  @(posedge adc_clk_i);
  adc_arm_do_i <= 1'b1;
  @(posedge adc_clk_i);
  adc_arm_do_i <= 1'b0;
end
endtask

//------------------------------------------------------------------------------
// helpers
//------------------------------------------------------------------------------

function automatic int signed to_sint_dw(input logic [DW-1:0] dat);
begin
  to_sint_dw = $signed(dat);
end
endfunction

function automatic int signed trunc_dw(input int signed dat);
  logic signed [DW-1:0] tmp;
begin
  tmp = dat;
  trunc_dw = tmp;
end
endfunction

function automatic int signed sample_pattern(input int unsigned idx);
  int signed base;
begin
  // Deterministic mixed-sign sequence (safe for DW=14)
  base = ((idx % 29) - 14) * 37 + ((idx % 7) - 3);
  sample_pattern = trunc_dw(base);
end
endfunction

function automatic int signed apply_hres_scale(
  input int signed dat,
  input bit hres_en
);
begin
  if (hres_en)  apply_hres_scale = trunc_dw(dat <<< 2);
  else          apply_hres_scale = trunc_dw(dat);
end
endfunction

function automatic logic [DW-1:0] sample_bits(input int unsigned idx);
  logic signed [DW-1:0] tmp;
begin
  tmp = sample_pattern(idx);
  sample_bits = tmp;
end
endfunction

function automatic int unsigned log2_pow2(input int unsigned v);
begin
  case (v)
    1: log2_pow2 = 0;
    2: log2_pow2 = 1;
    4: log2_pow2 = 2;
    8: log2_pow2 = 3;
    default: log2_pow2 = 0;
  endcase
end
endfunction

task automatic build_expected(
  input int unsigned dec,
  input bit avg_en,
  input bit hres_en,
  input int unsigned n_samples,
  output int signed expected[$]
);
  int unsigned i;
  int signed sum;
  int unsigned j;
  int unsigned sh;
begin
  expected = {};
  sh = log2_pow2(dec);

  if (dec == 0) begin
    // With dec=0, dec_valid is always asserted and pass-through path is used.
    for (i = 0; i < n_samples; i++) begin
      expected.push_back(apply_hres_scale(sample_pattern(i), hres_en));
    end
  end else if (!avg_en) begin
    for (i = dec; i < n_samples; i += dec) begin
      expected.push_back(apply_hres_scale(sample_pattern(i), hres_en));
    end
  end else begin
    case (dec)
      1: begin
        for (i = 1; i < n_samples; i++) begin
          expected.push_back(apply_hres_scale(sample_pattern(i-1), hres_en));
        end
      end
      2, 4, 8: begin
        for (i = dec; i < n_samples; i += dec) begin
          sum = 0;
          for (j = i - dec; j < i; j++) begin
            sum += apply_hres_scale(sample_pattern(j), hres_en);
          end
          expected.push_back(trunc_dw(sum >>> sh));
        end
      end
      3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15: begin
        // In RTL this range falls back to non-averaged decimation path.
        for (i = dec; i < n_samples; i += dec) begin
          expected.push_back(apply_hres_scale(sample_pattern(i), hres_en));
        end
      end
      default: begin
        // Divider path: sign is handled as abs(sum)/dec and restored.
        // This is equivalent to truncation towards zero.
        for (i = dec; i < n_samples; i += dec) begin
          sum = 0;
          for (j = i - dec; j < i; j++) begin
            sum += apply_hres_scale(sample_pattern(j), hres_en);
          end
          expected.push_back(trunc_dw(sum / $signed(dec)));
        end
      end
    endcase
  end
end
endtask

task automatic run_case(
  input string name,
  input int unsigned dec,
  input bit avg_en,
  input bit hres_en,
  input int unsigned n_samples
);
  int signed expected[$];
  int signed got[$];
  int unsigned i;
  int unsigned wait_cycles;
  int unsigned errors_before;
begin
  $display("CASE START: %s (dec=%0d avg=%0d hres=%0d samples=%0d)", name, dec, avg_en, hres_en, n_samples);
  errors_before = errors;

  reset_dut(dec, avg_en, hres_en);

  build_expected(dec, avg_en, hres_en, n_samples, expected);

  // Feed deterministic samples.
  for (i = 0; i < n_samples; i++) begin
    @(negedge adc_clk_i);
    dec_dat_i <= sample_bits(i);
    @(posedge adc_clk_i);
    #1ps;
    if (dec_val_o) begin
      got.push_back(to_sint_dw(dec_dat_o));
      if (got.size() > expected.size()) begin
        $display("  ERROR: extra output at i=%0d value=%0d", i, to_sint_dw(dec_dat_o));
        errors++;
      end
    end
  end

  // Allow divider and pipeline latency to flush.
  wait_cycles = 300;
  i = 0;
  while ((i < wait_cycles) && (got.size() < expected.size())) begin
    @(negedge adc_clk_i);
    dec_dat_i <= '0;
    @(posedge adc_clk_i);
    #1ps;
    if (dec_val_o && (got.size() < expected.size())) begin
      got.push_back(to_sint_dw(dec_dat_o));
    end
    i++;
  end

  if (got.size() != expected.size()) begin
    $display("  ERROR: size mismatch exp=%0d got=%0d", expected.size(), got.size());
    errors++;
  end

  for (i = 0; i < got.size() && i < expected.size(); i++) begin
    if (got[i] !== expected[i]) begin
      $display("  ERROR: idx=%0d exp=%0d got=%0d", i, expected[i], got[i]);
      errors++;
    end
  end

  if (errors == errors_before) begin
    $display("CASE PASS: %s", name);
  end else begin
    $display("CASE DONE WITH ERRORS: %s", name);
  end
end
endtask

// Change the complete decimator setting together with ARM, as rp_scope_com
// does at its registered configuration boundary.  This specifically checks
// that the first completed window after ARM contains only samples acquired
// with the new setting.
task automatic run_rearm_case(
  input string name,
  input int unsigned dec,
  input bit avg_en,
  input bit hres_en
);
  int signed sum;
  int signed expected;
  int signed got;
  int unsigned i;
  int unsigned valid_count;
  int unsigned errors_before;
begin
  $display("CASE START: %s", name);
  errors_before = errors;
  reset_dut(8, 1'b0, 1'b0);

  // Move the old decimator away from its reset state before applying the new
  // package.  If old and new settings are mixed, this makes the error visible.
  for (i = 0; i < 5; i++) begin
    @(negedge adc_clk_i);
    dec_dat_i <= sample_bits(80 + i);
  end

  sum = 0;
  @(negedge adc_clk_i);
  set_dec_i     <= dec[16:0];
  set_avg_en_i  <= avg_en;
  set_hres_en_i <= hres_en;
  adc_arm_do_i  <= 1'b1;
  dec_dat_i     <= sample_bits(0);
  sum += apply_hres_scale(sample_pattern(0), hres_en);
  @(posedge adc_clk_i);
  #1ps;

  @(negedge adc_clk_i);
  adc_arm_do_i <= 1'b0;

  valid_count = 0;
  got = 0;
  for (i = 1; i <= dec; i++) begin
    dec_dat_i <= sample_bits(i);
    @(posedge adc_clk_i);
    #1ps;
    if (i < dec)
      sum += apply_hres_scale(sample_pattern(i), hres_en);
    if (dec_val_o) begin
      valid_count++;
      got = to_sint_dw(dec_dat_o);
    end
    if (i != dec)
      @(negedge adc_clk_i);
  end

  if (avg_en) begin
    case (dec)
      1:       expected = apply_hres_scale(sample_pattern(0), hres_en);
      2, 4, 8: expected = trunc_dw(sum >>> log2_pow2(dec));
      default: expected = apply_hres_scale(sample_pattern(dec), hres_en);
    endcase
  end else begin
    expected = apply_hres_scale(sample_pattern(dec), hres_en);
  end

  if (valid_count != 1) begin
    $display("  ERROR: expected one valid after ARM, got %0d", valid_count);
    errors++;
  end else if (got !== expected) begin
    $display("  ERROR: first post-ARM sample exp=%0d got=%0d", expected, got);
    errors++;
  end

  if (errors == errors_before)
    $display("CASE PASS: %s", name);
  else
    $display("CASE DONE WITH ERRORS: %s", name);
end
endtask

//------------------------------------------------------------------------------
// test sequence
//------------------------------------------------------------------------------

initial begin
  run_case("avg_off_dec0",            0, 1'b0, 1'b0, 128);
  run_case("avg_off_dec1",            1, 1'b0, 1'b0, 128);
  run_case("avg_off_dec2",            2, 1'b0, 1'b0, 128);
  run_case("avg_off_dec3",            3, 1'b0, 1'b0, 128);
  run_case("avg_off_dec4",            4, 1'b0, 1'b0, 128);
  run_case("avg_off_dec5",            5, 1'b0, 1'b0, 128);
  run_case("avg_off_dec8",            8, 1'b0, 1'b0, 128);
  run_case("avg_on_dec1",             1, 1'b1, 1'b0, 128);
  run_case("avg_on_dec2",             2, 1'b1, 1'b0, 128);
  run_case("avg_on_dec4",             4, 1'b1, 1'b0, 128);
  run_case("avg_on_dec8",             8, 1'b1, 1'b0, 128);
  run_case("avg_on_dec3_fallback",    3, 1'b1, 1'b0, 128);
  run_case("avg_on_dec17_divider",   17, 1'b1, 1'b0, 256);
  run_case("avg_on_dec64_divider",   64, 1'b1, 1'b0, 512);

  // high-resolution precision enabled
  run_case("hres_on_avg_off_dec1",      1, 1'b0, 1'b1, 128);
  run_case("hres_on_avg_off_dec4",      4, 1'b0, 1'b1, 128);
  run_case("hres_on_avg_on_dec2",       2, 1'b1, 1'b1, 128);
  run_case("hres_on_avg_on_dec8",       8, 1'b1, 1'b1, 128);
  run_case("hres_on_avg_on_dec3_fallback", 3, 1'b1, 1'b1, 128);
  run_case("hres_on_avg_on_dec64_divider", 64, 1'b1, 1'b1, 512);

  run_rearm_case("atomic_rearm_dec4_avg_hres", 4, 1'b1, 1'b1);
  run_rearm_case("atomic_rearm_dec3_passthrough", 3, 1'b0, 1'b0);

  if (errors == 0)  $display("SUCCESS: rp_decim_tb");
  else              $display("FAILURE: rp_decim_tb errors=%0d", errors);

  $finish();
end

//------------------------------------------------------------------------------
// DUT instance
//------------------------------------------------------------------------------

rp_decim #(
  .DW (DW)
) dut (
  .adc_clk_i    (adc_clk_i   ),
  .adc_rstn_i   (adc_rstn_i  ),
  .dec_dat_i    (dec_dat_i   ),
  .set_dec_i    (set_dec_i   ),
  .set_avg_en_i (set_avg_en_i),
  .set_hres_en_i  (set_hres_en_i ),
  .adc_arm_do_i (adc_arm_do_i),
  .dec_val_o    (dec_val_o   ),
  .dec_dat_o    (dec_dat_o   )
);

//------------------------------------------------------------------------------
// waveforms
//------------------------------------------------------------------------------

initial begin
  $dumpfile("rp_decim_tb.vcd");
  $dumpvars(0, rp_decim_tb);
end

endmodule: rp_decim_tb
