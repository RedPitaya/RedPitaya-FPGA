`timescale 1ns/1ps

// Standalone differential regression for the split ASG repetition-delay
// counter in rtl/rtl_250/classic/red_pitaya_asg_ch.sv.  The DUT below is a
// literal extraction of the counter equations; the reference deliberately
// uses one 32-bit register and independent priority/saturation logic.
module asg_delay_counter_split (
  input  logic        clk,
  input  logic        rstn,
  input  logic        set_rst,
  input  logic        pnt_wrap,
  input  logic        axi_en,
  input  logic        axi_first,
  input  logic        dac_trig_0,
  input  logic        dac_trig_1,
  input  logic        dac_rep,
  input  logic        rep_ld,
  input  logic        rep_dec,
  input  logic        rep_clr,
  input  logic [15:0] set_rnum,
  input  logic [31:0] set_rdly_m1,
  output logic [31:0] dly_cnt,
  output logic        dly_started,
  output logic        dly_nonzero,
  output logic [15:0] rep_cnt,
  output logic        rep_nonzero
);
  logic [15:0] dly_cnt_lo, dly_cnt_hi;
  wire dly_start_0 = axi_en ? axi_first : dac_trig_0;
  wire dly_start_1 = axi_en ? axi_first : dac_trig_1;
  wire dly_dec = dac_rep && dly_started && dly_nonzero;
  wire [15:0] dly_hold_lo = dly_dec ? dly_cnt_lo - 16'h1 : dly_cnt_lo;
  wire [15:0] dly_hold_hi = (dly_dec && ~|dly_cnt_lo)
                          ? dly_cnt_hi - 16'h1 : dly_cnt_hi;
  wire [15:0] lo_nxt_0 = dly_start_0 ? set_rdly_m1[15:0]  : dly_hold_lo;
  wire [15:0] lo_nxt_1 = dly_start_1 ? set_rdly_m1[15:0]  : dly_hold_lo;
  wire [15:0] hi_nxt_0 = dly_start_0 ? set_rdly_m1[31:16] : dly_hold_hi;
  wire [15:0] hi_nxt_1 = dly_start_1 ? set_rdly_m1[31:16] : dly_hold_hi;
  wire dly_terminal = (dly_cnt_hi == 16'h0) && (dly_cnt_lo == 16'h1);
  wire dly_nonzero_nxt_0 = dly_start_0 ? |set_rdly_m1
                                      : dly_dec ? !dly_terminal : dly_nonzero;
  wire dly_nonzero_nxt_1 = dly_start_1 ? |set_rdly_m1
                                      : dly_dec ? !dly_terminal : dly_nonzero;
  wire started_nxt_0 = dly_start_0 ? 1'b1
                                   : (dac_trig_0 ? 1'b0 : dly_started);
  wire started_nxt_1 = dly_start_1 ? 1'b1
                                   : (dac_trig_1 ? 1'b0 : dly_started);
  wire rep_dec_qualified = rep_dec && rep_nonzero;
  wire [15:0] rep_cnt_nxt_0 = rep_ld ? set_rnum
                             : (rep_dec_qualified && dac_trig_0) ? rep_cnt - 16'h1
                             : rep_clr ? 16'h0 : rep_cnt;
  wire [15:0] rep_cnt_nxt_1 = rep_ld ? set_rnum
                             : (rep_dec_qualified && dac_trig_1) ? rep_cnt - 16'h1
                             : rep_clr ? 16'h0 : rep_cnt;
  wire rep_nonzero_nxt_0 = rep_ld ? |set_rnum
                             : (rep_dec_qualified && dac_trig_0) ? (rep_cnt != 16'h1)
                             : rep_clr ? 1'b0 : rep_nonzero;
  wire rep_nonzero_nxt_1 = rep_ld ? |set_rnum
                             : (rep_dec_qualified && dac_trig_1) ? (rep_cnt != 16'h1)
                             : rep_clr ? 1'b0 : rep_nonzero;

  assign dly_cnt = {dly_cnt_hi, dly_cnt_lo};

  always_ff @(posedge clk) begin
    if (!rstn) begin
      dly_cnt_lo <= '0;
      dly_cnt_hi <= '0;
      dly_started <= 1'b0;
      dly_nonzero <= 1'b0;
      rep_cnt <= '0;
      rep_nonzero <= 1'b0;
    end else if (set_rst) begin
      dly_cnt_lo <= '0;
      dly_cnt_hi <= '0;
      dly_started <= 1'b0;
      dly_nonzero <= 1'b0;
      rep_cnt <= pnt_wrap ? rep_cnt_nxt_1 : rep_cnt_nxt_0;
      rep_nonzero <= pnt_wrap ? rep_nonzero_nxt_1 : rep_nonzero_nxt_0;
    end else begin
      dly_cnt_lo <= pnt_wrap ? lo_nxt_1 : lo_nxt_0;
      dly_cnt_hi <= pnt_wrap ? hi_nxt_1 : hi_nxt_0;
      dly_started <= pnt_wrap ? started_nxt_1 : started_nxt_0;
      dly_nonzero <= pnt_wrap ? dly_nonzero_nxt_1 : dly_nonzero_nxt_0;
      rep_cnt <= pnt_wrap ? rep_cnt_nxt_1 : rep_cnt_nxt_0;
      rep_nonzero <= pnt_wrap ? rep_nonzero_nxt_1 : rep_nonzero_nxt_0;
    end
  end
endmodule

module asg_delay_counter_tb;
  logic clk = 1'b0;
  always #2 clk = ~clk;

  logic rstn, set_rst, pnt_wrap, axi_en, axi_first;
  logic dac_trig_0, dac_trig_1, dac_rep;
  logic rep_ld, rep_dec, rep_clr;
  logic [15:0] set_rnum;
  logic [31:0] set_rdly_m1;
  wire [31:0] dut_cnt;
  wire dut_started;
  wire dut_dly_nonzero;
  wire [15:0] dut_rep_cnt;
  wire dut_rep_nonzero;
  logic [31:0] ref_cnt;
  logic ref_started;
  logic [15:0] ref_rep_cnt;
  int checks;

  asg_delay_counter_split dut(.*,
    .dly_cnt(dut_cnt), .dly_started(dut_started),
    .dly_nonzero(dut_dly_nonzero), .rep_cnt(dut_rep_cnt),
    .rep_nonzero(dut_rep_nonzero));

  wire selected_trig = pnt_wrap ? dac_trig_1 : dac_trig_0;
  wire selected_start = axi_en ? axi_first : selected_trig;

  // Monolithic specification: reset, then load/start, then saturating
  // decrement, then hold.  A non-AXI trigger without a start clears the
  // started flag; AXI first is the AXI load event.
  always_ff @(posedge clk) begin
    if (!rstn) begin
      ref_cnt <= 32'h0;
      ref_started <= 1'b0;
      ref_rep_cnt <= 16'h0;
    end else begin
      if (set_rst) begin
        ref_cnt <= 32'h0;
        ref_started <= 1'b0;
      end else if (selected_start) begin
        ref_cnt <= set_rdly_m1;
        ref_started <= 1'b1;
      end else begin
        if (dac_rep && ref_started && ref_cnt != 0)
          ref_cnt <= ref_cnt - 32'h1;
        if (selected_trig)
          ref_started <= 1'b0;
      end
      if (rep_ld)
        ref_rep_cnt <= set_rnum;
      else if (rep_dec && ref_rep_cnt != 0 && selected_trig)
        ref_rep_cnt <= ref_rep_cnt - 16'h1;
      else if (rep_clr)
        ref_rep_cnt <= 16'h0;
    end
  end

  task automatic tick;
    begin
      @(posedge clk); #1;
      checks++;
      if (dut_cnt !== ref_cnt || dut_started !== ref_started ||
          dut_rep_cnt !== ref_rep_cnt ||
          dut_dly_nonzero !== (dut_cnt != 0) ||
          dut_rep_nonzero !== (dut_rep_cnt != 0)) begin
        $error("check %0d dly=%08h/%08h started=%b/%b dly_nz=%b rep=%04h/%04h rep_nz=%b",
               checks, dut_cnt, ref_cnt, dut_started, ref_started,
               dut_dly_nonzero, dut_rep_cnt, ref_rep_cnt, dut_rep_nonzero);
        $fatal(1);
      end
    end
  endtask

  task automatic idle_inputs;
    begin
      set_rst = 0; pnt_wrap = 0; axi_en = 0; axi_first = 0;
      dac_trig_0 = 0; dac_trig_1 = 0; dac_rep = 0;
      rep_ld = 0; rep_dec = 0; rep_clr = 0;
      set_rnum = 0; set_rdly_m1 = 0;
    end
  endtask

  task automatic exercise_rep(input logic [15:0] value, input logic branch);
    begin
      idle_inputs(); pnt_wrap = branch; rep_ld = 1; set_rnum = value; tick();
      idle_inputs(); pnt_wrap = branch; rep_dec = 1;
      if (branch) dac_trig_1 = 1; else dac_trig_0 = 1;
      tick();
      idle_inputs(); pnt_wrap = branch; rep_clr = 1; tick();
    end
  endtask

  task automatic load_nonaxi(input logic [31:0] value, input logic branch);
    begin
      idle_inputs(); pnt_wrap = branch; dac_rep = 1;
      set_rdly_m1 = value;
      if (branch) dac_trig_1 = 1; else dac_trig_0 = 1;
      tick();
      idle_inputs();
    end
  endtask

  task automatic load_axi(input logic [31:0] value, input logic branch);
    begin
      idle_inputs(); axi_en = 1; axi_first = 1; pnt_wrap = branch;
      dac_rep = 1; set_rdly_m1 = value;
      // Opposite trigger values prove AXI first, not the wrap-selected trigger,
      // controls the load.
      dac_trig_0 = branch; dac_trig_1 = ~branch;
      tick();
      idle_inputs();
    end
  endtask

  task automatic decrement_to(input logic [31:0] expected);
    begin
      dac_rep = 1;
      tick();
      if (dut_cnt !== expected) $fatal(1, "expected directed value %08h", expected);
      dac_rep = 0;
    end
  endtask

  initial begin
    checks = 0;
    idle_inputs(); rstn = 0; repeat (2) tick(); rstn = 1;

    // Hold before start, then directed borrow boundaries in both carry-select
    // branches and both event modes.
    repeat (2) tick();
    load_nonaxi(32'h0000_0000, 0);
    load_nonaxi(32'h0000_0001, 1);
    load_axi(32'h0000_ffff, 0);
    load_axi(32'h0001_0000, 1);
    load_nonaxi(32'h0001_0001, 0);
    decrement_to(32'h0001_0000);
    decrement_to(32'h0000_ffff);
    load_nonaxi(32'h0001_0000, 1);
    decrement_to(32'h0000_ffff);
    load_axi(32'hffff_0000, 0);
    decrement_to(32'hfffe_ffff);
    load_axi(32'h0001_0001, 1);
    decrement_to(32'h0001_0000);

    // Saturation at zero and hold when repetition is inactive.
    load_nonaxi(32'h0000_0001, 0);
    decrement_to(32'h0000_0000);
    repeat (3) decrement_to(32'h0000_0000);
    load_nonaxi(32'h0001_0001, 0);
    repeat (2) tick();

    // Load beats an otherwise enabled decrement; synchronous reset beats load.
    dac_rep = 1; set_rdly_m1 = 32'hffff_0000; dac_trig_0 = 1; tick();
    if (dut_cnt !== 32'hffff_0000) $fatal(1, "load priority failed");
    set_rst = 1; set_rdly_m1 = 32'h0001_0001; tick();
    if (dut_cnt !== 0 || dut_started !== 0) $fatal(1, "reset priority failed");
    idle_inputs();

    // Repetition shadow flag: load/decrement/clear priorities and both
    // carry-select branches at zero/terminal/16-bit-boundary values.
    exercise_rep(16'h0000, 0);
    exercise_rep(16'h0001, 1);
    exercise_rep(16'hffff, 0);
    idle_inputs(); rep_ld = 1; rep_clr = 1; set_rnum = 16'h0001; tick();
    if (dut_rep_cnt !== 16'h0001) $fatal(1, "rep load priority failed");
    idle_inputs(); set_rst = 1; rep_ld = 1; set_rnum = 16'hffff; tick();
    if (dut_rep_cnt !== 16'hffff || dut_cnt !== 0)
      $fatal(1, "set_rst delay/rep priority mismatch");
    idle_inputs();

    // Random cycle-by-cycle differential coverage of branch selection, AXI vs
    // non-AXI starts, reset/load collisions, hold and decrement.
    repeat (20000) begin
      set_rst = ($urandom_range(0,63) == 0);
      pnt_wrap = $urandom;
      axi_en = $urandom;
      axi_first = ($urandom_range(0,15) == 0);
      dac_trig_0 = ($urandom_range(0,15) == 0);
      dac_trig_1 = ($urandom_range(0,15) == 0);
      dac_rep = $urandom;
      rep_ld = ($urandom_range(0,31) == 0);
      rep_dec = $urandom;
      rep_clr = ($urandom_range(0,31) == 0);
      set_rnum = $urandom;
      set_rdly_m1 = {$urandom, $urandom};
      tick();
    end

    $display("SUCCESS: %0d cycle/bit-exact split delay-counter checks", checks);
    $finish;
  end
endmodule
