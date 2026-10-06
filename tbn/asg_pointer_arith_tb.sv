`timescale 1ns/1ps

// Differential check for the fixed-point ASG pointer transformation.  The
// reference is the original wide arithmetic; the DUT-side equations mirror
// red_pitaya_asg_ch.  Besides single-cycle corner cases, each case advances a
// pointer through wraps so an error in carry/borrow changes all later samples.
module asg_pointer_arith_tb;
  localparam int RSZ = 14;
  localparam int PNT_LO = 32;
  localparam int PNT_HI = RSZ + 16;
  localparam int PNT_SIZE = PNT_HI + PNT_LO;

  logic [PNT_SIZE-1:0] pnt;
  logic [PNT_HI-1:0] step_hi, size_i, ofs_i;
  logic [PNT_LO-1:0] step_lo;
  logic wrap;
  int checks;

  function automatic [PNT_SIZE:0] pair_advance;
    input logic [PNT_SIZE-1:0] base;
    logic [PNT_SIZE:0] sum, sub;
    begin
      sum = {1'b0,base} + {1'b0,step_hi,step_lo};
      sub = sum - {1'b0,size_i,{PNT_LO{1'b0}}} - 1'b1;
      pair_advance[PNT_SIZE] = ~sub[PNT_SIZE];
      pair_advance[PNT_SIZE-1:0] = ~sub[PNT_SIZE]
                                           ? (wrap ? sub[PNT_SIZE-1:0]
                                                   : {ofs_i,{PNT_LO{1'b0}}})
                                           : sum[PNT_SIZE-1:0];
    end
  endfunction

  function automatic [2*(PNT_SIZE+1)-1:0] pair_direct;
    input logic [PNT_SIZE-1:0] base;
    logic [PNT_SIZE:0] sum1, sub1;
    logic [PNT_SIZE+1:0] sum2, modulus, span, tmp;
    logic [PNT_SIZE:0] sum2n, sub2n, sum2w, sub2w, sum2o, sub2o;
    logic wrap1, wrap2n, wrap2w, wrap2o, wrap2;
    logic [PNT_SIZE-1:0] pnt1, pnt2n, pnt2w, pnt2o, pnt2;
    begin
      sum1 = {1'b0,base} + {1'b0,step_hi,step_lo};
      sub1 = sum1 - {1'b0,size_i,{PNT_LO{1'b0}}} - 1'b1;
      wrap1 = ~sub1[PNT_SIZE];
      pnt1 = wrap1 ? (wrap ? sub1[PNT_SIZE-1:0] : {ofs_i,{PNT_LO{1'b0}}})
                   : sum1[PNT_SIZE-1:0];

      sum2 = {2'b0,base} + ({2'b0,step_hi,step_lo} << 1);
      modulus = {2'b0,size_i,{PNT_LO{1'b0}}} + 1'b1;
      span = 'd1 << PNT_SIZE;
      tmp = sum2 - (sum1[PNT_SIZE] ? span : '0);
      sum2n = tmp[PNT_SIZE:0];
      tmp = sum2 - (sum1[PNT_SIZE] ? span : '0) - modulus;
      sub2n = tmp[PNT_SIZE:0];
      wrap2n = ~sub2n[PNT_SIZE];
      pnt2n = wrap2n ? (wrap ? sub2n[PNT_SIZE-1:0] : {ofs_i,{PNT_LO{1'b0}}})
                     : sum2n[PNT_SIZE-1:0];

      tmp = sum2 - modulus;
      sum2w = tmp[PNT_SIZE:0];
      tmp = sum2 - (modulus << 1);
      sub2w = tmp[PNT_SIZE:0];
      wrap2w = ~sub2w[PNT_SIZE];
      pnt2w = wrap2w ? sub2w[PNT_SIZE-1:0] : sum2w[PNT_SIZE-1:0];

      sum2o = {1'b0,ofs_i,{PNT_LO{1'b0}}} + {1'b0,step_hi,step_lo};
      sub2o = sum2o - {1'b0,size_i,{PNT_LO{1'b0}}} - 1'b1;
      wrap2o = ~sub2o[PNT_SIZE];
      pnt2o = wrap2o ? {ofs_i,{PNT_LO{1'b0}}} : sum2o[PNT_SIZE-1:0];

      wrap2 = wrap1 ? (wrap ? wrap2w : wrap2o) : wrap2n;
      pnt2 = wrap1 ? (wrap ? pnt2w : pnt2o) : pnt2n;
      pair_direct = {{wrap2,pnt2},{wrap1,pnt1}};
    end
  endfunction

  task automatic check_one;
    logic [PNT_SIZE:0] ref_next, ref_sub, dut_1, dut_2;
    logic [2*(PNT_SIZE+1)-1:0] direct_pair;
    logic [PNT_SIZE-1:0] ref_1, ref_2;
    logic ref_wrap_1, ref_wrap_2;
    begin
      ref_next = {1'b0,pnt} + {1'b0,step_hi,step_lo};
      ref_sub  = ref_next - {1'b0,size_i,{PNT_LO{1'b0}}} - 1'b1;
      ref_wrap_1 = ~ref_sub[PNT_SIZE];
      ref_1 = ref_wrap_1 ? (wrap ? ref_sub[PNT_SIZE-1:0]
                                  : {ofs_i,{PNT_LO{1'b0}}})
                         : ref_next[PNT_SIZE-1:0];
      ref_next = {1'b0,ref_1} + {1'b0,step_hi,step_lo};
      ref_sub  = ref_next - {1'b0,size_i,{PNT_LO{1'b0}}} - 1'b1;
      ref_wrap_2 = ~ref_sub[PNT_SIZE];
      ref_2 = ref_wrap_2 ? (wrap ? ref_sub[PNT_SIZE-1:0]
                                  : {ofs_i,{PNT_LO{1'b0}}})
                         : ref_next[PNT_SIZE-1:0];

      direct_pair = pair_direct(pnt);
      dut_1 = direct_pair[0 +: PNT_SIZE+1];
      dut_2 = direct_pair[PNT_SIZE+1 +: PNT_SIZE+1];
      if (dut_1 !== {ref_wrap_1,ref_1} || dut_2 !== {ref_wrap_2,ref_2}) begin
        $error("pair mismatch pnt=%h step=%h_%h size=%h ref=%b/%h %b/%h dut=%h/%h",
               pnt, step_hi, step_lo, size_i, ref_wrap_1, ref_1,
               ref_wrap_2, ref_2, dut_1, dut_2);
        $fatal(1);
      end
      pnt = ref_2;
      checks += 2;
    end
  endtask

  task automatic run_sequence(input logic [PNT_LO-1:0] lo,
                              input logic [PNT_HI-1:0] hi,
                              input logic [PNT_HI-1:0] sz,
                              input logic [PNT_SIZE-1:0] start,
                              input logic do_wrap,
                              input int count);
    begin
      step_lo = lo; step_hi = hi; size_i = sz; pnt = start;
      ofs_i = '0; wrap = do_wrap;
      repeat (count) check_one();
    end
  endtask

  initial begin
    checks = 0;
    // Directed fractional zero, carry, borrow and wrap boundaries.
    run_sequence(32'h0000_0000, 30'd1, 30'd31, 62'd0, 1'b1, 100);
    run_sequence(32'h0000_0001, 30'd0, 30'd7, {30'd6,32'hffff_ffff}, 1'b1, 100);
    run_sequence(32'hffff_ffff, 30'd0, 30'd7, {30'd0,32'h0000_0001}, 1'b1, 100);
    run_sequence(32'h8000_0000, 30'd3, 30'd17, {30'd16,32'h8000_0000}, 1'b0, 100);
    run_sequence(32'hffff_ffff, {PNT_HI{1'b1}}, {PNT_HI{1'b1}}, {PNT_SIZE{1'b1}}, 1'b1, 100);

    repeat (2000) begin
      step_lo = {$urandom,$urandom};
      step_hi = {$urandom,$urandom};
      size_i  = {$urandom,$urandom};
      pnt     = {$urandom,$urandom};
      ofs_i   = {$urandom,$urandom};
      wrap    = $urandom;
      repeat (100) check_one();
    end
    $display("SUCCESS: %0d bit-exact pointer/wrap checks", checks);
    $finish;
  end
endmodule
