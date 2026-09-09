`timescale 1ns/1ps

// Standalone differential regression for the ASG counter zero flags in
// rtl/rtl/classic/red_pitaya_asg_ch.sv.  REF keeps the original |rep_cnt and
// (dly_cnt == 0) reductions, DUT uses rep_nonzero / dly_nonzero.  Both are
// extractions of the plain (non RP_ASG_TRIG_SELECT) state machine, which is
// what Z10 compiles, with the rep_arm -> dac_trig -> counters loop closed.
//
// Run from the repository root:
//   xvlog -sv tbn/asg_zero_flag_tb.sv
//   xelab -debug typical --timescale 1ns/1ps asg_zero_flag_tb -s sim
//   xsim sim -runall

// Reference: the state machine as it was before the port.
module asg_sm_ref (
  input  logic        clk,
  input  logic        rstn,
  input  logic        set_rst,
  input  logic        trig_in,
  input  logic        set_rgate,
  input  logic        trig_ext,
  input  logic [ 2:0] trig_src,
  input  logic [15:0] set_rnum,
  input  logic [15:0] set_ncyc,
  input  logic [31:0] set_rdly_m1,
  input  logic        axi_en,
  input  logic        axi_first,
  input  logic        axi_last,
  input  logic        axi_dac_do,
  input  logic        npnt_sub_neg,
  output logic [15:0] rep_cnt,
  output logic [31:0] dly_cnt,
  output logic        dly_started,
  output logic [15:0] cyc_cnt,
  output logic        dac_do,
  output logic        dac_rep
);
  logic dac_trigr, buf_cycle_q;

  wire do_read    = axi_en ? axi_dac_do : dac_do;
  wire buf_cycle  = axi_en ? axi_last   : buf_cycle_q;

  wire rep_arm    = dac_rep && |rep_cnt && dly_started && (dly_cnt == 32'h0);
  wire rep_idle   = (cyc_cnt == 16'h0) && ~dac_do && !buf_cycle;
  wire cycle_end  = axi_en ? axi_last : (~npnt_sub_neg);
  wire trig_now     = (!dac_rep && trig_in) || (rep_arm && rep_idle);
  wire trig_on_wrap = rep_arm && (cyc_cnt == 16'h1);
  wire dac_trig     = trig_now || (trig_on_wrap && cycle_end);
  wire dly_start    = axi_en ? axi_first : dac_trig;

  always @(posedge clk) begin
    if (!rstn) begin
      cyc_cnt <= 16'h0; rep_cnt <= 16'h0; dly_cnt <= 32'h0;
      dly_started <= 1'b0; dac_do <= 1'b0; dac_rep <= 1'b0;
      dac_trigr <= 1'b0; buf_cycle_q <= 1'b0;
    end else begin
      if (set_rst) begin
         dly_cnt <= 32'h0;
         dly_started <= 1'b0;
      end else begin
         if (dly_start)
            dly_cnt <= set_rdly_m1;
         else if (dac_rep && dly_started && |dly_cnt)
            dly_cnt <= dly_cnt - 32'h1;

         if (dly_start)
            dly_started <= 1'b1;
         else if (dac_trig)
            dly_started <= 1'b0;
      end

      if (trig_in && !do_read)
         rep_cnt <= set_rnum;
      else if (!set_rgate && (|rep_cnt && dac_rep && (dac_trig && !dac_trigr)) && (set_rnum != 16'hffff))
         rep_cnt <= rep_cnt - 16'h1;
      else if (set_rgate && ((!trig_ext && trig_src==3'd2) || (trig_ext && trig_src==3'd3)))
         rep_cnt <= 16'h0;

      dac_trigr   <= dac_trig;
      buf_cycle_q <= dac_do && ~npnt_sub_neg;

      if (dac_trig)
         cyc_cnt <= set_ncyc;
      else if (!dac_trigr && |cyc_cnt && buf_cycle)
         cyc_cnt <= cyc_cnt - 16'h1;

      if (dac_trig && !set_rst && !axi_en)
         dac_do <= 1'b1;
      else if (set_rst || ((cyc_cnt==16'h1) && ~npnt_sub_neg))
         dac_do <= 1'b0;

      if (dac_trig && !set_rst)
         dac_rep <= 1'b1;
      else if (set_rst || (rep_cnt==16'h0))
         dac_rep <= 1'b0;
    end
  end
endmodule

// DUT: the state machine as it is after the port.
module asg_sm_dut (
  input  logic        clk,
  input  logic        rstn,
  input  logic        set_rst,
  input  logic        trig_in,
  input  logic        set_rgate,
  input  logic        trig_ext,
  input  logic [ 2:0] trig_src,
  input  logic [15:0] set_rnum,
  input  logic [15:0] set_ncyc,
  input  logic [31:0] set_rdly_m1,
  input  logic        axi_en,
  input  logic        axi_first,
  input  logic        axi_last,
  input  logic        axi_dac_do,
  input  logic        npnt_sub_neg,
  output logic [15:0] rep_cnt,
  output logic [31:0] dly_cnt,
  output logic        dly_started,
  output logic [15:0] cyc_cnt,
  output logic        dac_do,
  output logic        dac_rep,
  output logic        rep_nonzero,
  output logic        dly_nonzero
);
  logic dac_trigr, buf_cycle_q;

  wire do_read    = axi_en ? axi_dac_do : dac_do;
  wire buf_cycle  = axi_en ? axi_last   : buf_cycle_q;

  wire rep_arm    = dac_rep && rep_nonzero && dly_started && !dly_nonzero;
  wire rep_idle   = (cyc_cnt == 16'h0) && ~dac_do && !buf_cycle;
  wire cycle_end  = axi_en ? axi_last : (~npnt_sub_neg);
  wire trig_now     = (!dac_rep && trig_in) || (rep_arm && rep_idle);
  wire trig_on_wrap = rep_arm && (cyc_cnt == 16'h1);
  wire dac_trig     = trig_now || (trig_on_wrap && cycle_end);
  wire dly_start    = axi_en ? axi_first : dac_trig;

  always @(posedge clk) begin
    if (!rstn) begin
      cyc_cnt <= 16'h0; rep_cnt <= 16'h0; dly_cnt <= 32'h0;
      rep_nonzero <= 1'b0; dly_nonzero <= 1'b0;
      dly_started <= 1'b0; dac_do <= 1'b0; dac_rep <= 1'b0;
      dac_trigr <= 1'b0; buf_cycle_q <= 1'b0;
    end else begin
      if (set_rst) begin
         dly_cnt <= 32'h0;
         dly_nonzero <= 1'b0;
         dly_started <= 1'b0;
      end else begin
         if (dly_start) begin
            dly_cnt <= set_rdly_m1;
            dly_nonzero <= |set_rdly_m1;
         end
         else if (dac_rep && dly_started && dly_nonzero) begin
            dly_cnt <= dly_cnt - 32'h1;
            dly_nonzero <= (dly_cnt != 32'h1);
         end

         if (dly_start)
            dly_started <= 1'b1;
         else if (dac_trig)
            dly_started <= 1'b0;
      end

      if (trig_in && !do_read) begin
         rep_cnt <= set_rnum;
         rep_nonzero <= |set_rnum;
      end
      else if (!set_rgate && (rep_nonzero && dac_rep && (dac_trig && !dac_trigr)) && (set_rnum != 16'hffff)) begin
         rep_cnt <= rep_cnt - 16'h1;
         rep_nonzero <= (rep_cnt != 16'h1);
      end
      else if (set_rgate && ((!trig_ext && trig_src==3'd2) || (trig_ext && trig_src==3'd3))) begin
         rep_cnt <= 16'h0;
         rep_nonzero <= 1'b0;
      end

      dac_trigr   <= dac_trig;
      buf_cycle_q <= dac_do && ~npnt_sub_neg;

      if (dac_trig)
         cyc_cnt <= set_ncyc;
      else if (!dac_trigr && |cyc_cnt && buf_cycle)
         cyc_cnt <= cyc_cnt - 16'h1;

      if (dac_trig && !set_rst && !axi_en)
         dac_do <= 1'b1;
      else if (set_rst || ((cyc_cnt==16'h1) && ~npnt_sub_neg))
         dac_do <= 1'b0;

      if (dac_trig && !set_rst)
         dac_rep <= 1'b1;
      else if (set_rst || !rep_nonzero)
         dac_rep <= 1'b0;
    end
  end
endmodule

////////////////////////////////////////////////////////////////////////////////
module asg_zero_flag_tb;
  logic clk = 0;
  always #4 clk = ~clk;               // 125 MHz

  logic        rstn, set_rst, trig_in, set_rgate, trig_ext;
  logic [ 2:0] trig_src;
  logic [15:0] set_rnum, set_ncyc;
  logic [31:0] set_rdly_m1;
  logic        axi_en, axi_first, axi_last, axi_dac_do, npnt_sub_neg;

  logic [15:0] r_rep, d_rep, r_cyc, d_cyc;
  logic [31:0] r_dly, d_dly;
  logic        r_sta, d_sta, r_do, d_do, r_rp, d_rp, d_repnz, d_dlynz;

  asg_sm_ref ref_i (.clk, .rstn, .set_rst, .trig_in, .set_rgate, .trig_ext,
    .trig_src, .set_rnum, .set_ncyc, .set_rdly_m1, .axi_en, .axi_first,
    .axi_last, .axi_dac_do, .npnt_sub_neg,
    .rep_cnt(r_rep), .dly_cnt(r_dly), .dly_started(r_sta), .cyc_cnt(r_cyc),
    .dac_do(r_do), .dac_rep(r_rp));

  asg_sm_dut dut_i (.clk, .rstn, .set_rst, .trig_in, .set_rgate, .trig_ext,
    .trig_src, .set_rnum, .set_ncyc, .set_rdly_m1, .axi_en, .axi_first,
    .axi_last, .axi_dac_do, .npnt_sub_neg,
    .rep_cnt(d_rep), .dly_cnt(d_dly), .dly_started(d_sta), .cyc_cnt(d_cyc),
    .dac_do(d_do), .dac_rep(d_rp),
    .rep_nonzero(d_repnz), .dly_nonzero(d_dlynz));

  int errors = 0;
  int checks = 0;

  task automatic check(string tag);
    checks++;
    if (r_rep !== d_rep) begin
      errors++; $display("MISMATCH %s @%0t rep_cnt ref=%h dut=%h", tag, $time, r_rep, d_rep);
    end
    if (r_dly !== d_dly) begin
      errors++; $display("MISMATCH %s @%0t dly_cnt ref=%h dut=%h", tag, $time, r_dly, d_dly);
    end
    if (r_sta !== d_sta) begin
      errors++; $display("MISMATCH %s @%0t dly_started ref=%b dut=%b", tag, $time, r_sta, d_sta);
    end
    if (r_cyc !== d_cyc) begin
      errors++; $display("MISMATCH %s @%0t cyc_cnt ref=%h dut=%h", tag, $time, r_cyc, d_cyc);
    end
    if (r_do  !== d_do ) begin
      errors++; $display("MISMATCH %s @%0t dac_do ref=%b dut=%b", tag, $time, r_do, d_do);
    end
    if (r_rp  !== d_rp ) begin
      errors++; $display("MISMATCH %s @%0t dac_rep ref=%b dut=%b", tag, $time, r_rp, d_rp);
    end
    if (d_repnz !== (|d_rep)) begin
      errors++; $display("FLAG    %s @%0t rep_nonzero=%b but rep_cnt=%h", tag, $time, d_repnz, d_rep);
    end
    if (d_dlynz !== (d_dly != 32'h0)) begin
      errors++; $display("FLAG    %s @%0t dly_nonzero=%b but dly_cnt=%h", tag, $time, d_dlynz, d_dly);
    end
    if (errors > 20) begin
      $display("too many errors, stopping"); $display("FAILURE"); $finish;
    end
  endtask

  task automatic idle_inputs();
    set_rst = 0; trig_in = 0; set_rgate = 0; trig_ext = 0; trig_src = 3'd1;
    set_rnum = 16'h0; set_ncyc = 16'h1; set_rdly_m1 = 32'h0;
    axi_en = 0; axi_first = 0; axi_last = 0; axi_dac_do = 0; npnt_sub_neg = 1;
  endtask

  // One directed burst: rnum repetitions of ncyc cycles with a delay of rdly.
  task automatic burst(int rnum, int ncyc, int rdly, string tag);
    rstn = 0; idle_inputs(); @(posedge clk); @(posedge clk);
    rstn = 1; @(posedge clk); check(tag);
    set_rnum    = rnum[15:0];
    set_ncyc    = ncyc[15:0];
    set_rdly_m1 = (rdly > 0) ? rdly - 1 : 0;
    trig_in = 1; @(posedge clk); check(tag);
    trig_in = 0;
    // run long enough for every repetition to complete
    for (int i = 0; i < (rnum + 2) * (ncyc + rdly + 6) + 60; i++) begin
      npnt_sub_neg = ((i % 3) != 2);
      @(posedge clk);
      check(tag);
    end
  endtask

  initial begin
    idle_inputs();
    rstn = 0;
    repeat (4) @(posedge clk);
    rstn = 1;

    // --- directed: the boundaries the flags encode -----------------------
    burst(0,  1, 0, "rnum=0");        // load a zero count
    burst(1,  1, 0, "rnum=1");        // single repetition, no delay
    burst(1,  1, 1, "rdly=1");        // delay reaches its terminal value
    burst(2,  1, 1, "rnum=2 rdly=1");
    burst(3,  2, 3, "rnum=3 rdly=3");
    burst(5,  3, 2, "rnum=5 rdly=2");

    // gate mode clears the counter from a nonzero value
    rstn = 0; idle_inputs(); @(posedge clk); rstn = 1; @(posedge clk);
    set_rnum = 16'h7; trig_in = 1; @(posedge clk); check("gate");
    trig_in = 0; @(posedge clk); check("gate");
    set_rgate = 1; trig_src = 3'd2; trig_ext = 0;
    repeat (8) begin @(posedge clk); check("gate"); end
    set_rgate = 0;

    // infinite repetitions: 16'hffff must never decrement
    rstn = 0; idle_inputs(); @(posedge clk); rstn = 1; @(posedge clk);
    set_rnum = 16'hffff; set_ncyc = 16'h1; trig_in = 1;
    @(posedge clk); check("inf"); trig_in = 0;
    for (int i = 0; i < 200; i++) begin
      npnt_sub_neg = ((i % 3) != 2); @(posedge clk); check("inf");
    end

    // --- random: same stimulus into both models --------------------------
    for (int seed = 0; seed < 40; seed++) begin
      rstn = 0; idle_inputs();
      @(posedge clk); @(posedge clk);
      rstn = 1;
      for (int i = 0; i < 400; i++) begin
          if ($urandom_range(0, 15) == 0) set_rnum    = $urandom_range(0, 6);
        if ($urandom_range(0, 15) == 0) set_rnum    = 16'hffff;
        if ($urandom_range(0, 15) == 0) set_ncyc    = $urandom_range(0, 4);
        if ($urandom_range(0, 15) == 0) set_rdly_m1 = $urandom_range(0, 5);
        trig_in      = ($urandom_range(0, 9) == 0);
        set_rst      = ($urandom_range(0,39) == 0);
        set_rgate    = ($urandom_range(0,19) == 0);
        trig_ext     = $urandom_range(0, 1);
        trig_src     = $urandom_range(1, 3);
        axi_en       = ($urandom_range(0, 3) == 0);
        axi_first    = ($urandom_range(0, 7) == 0);
        axi_last     = ($urandom_range(0, 5) == 0);
        axi_dac_do   = $urandom_range(0, 1);
        npnt_sub_neg = ($urandom_range(0, 3) != 0);
        @(posedge clk);
        check($sformatf("rand seed=%0d", seed));
      end
    end

    $display("checks: %0d, errors: %0d", checks, errors);
    if (errors == 0) $display("SUCCESS");
    else             $display("FAILURE");
    $finish;
  end
endmodule
