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
  localparam int INT_LO = PNT_HI / 2;
  localparam int INT_HI = PNT_HI - INT_LO;

  logic [PNT_SIZE-1:0] pnt;
  logic [PNT_HI-1:0] step_hi, size_i, ofs_i;
  logic [PNT_LO-1:0] step_lo;
  logic wrap;
  int checks;

  task automatic check_one;
    logic [PNT_SIZE:0] ref_next, ref_sub;
    logic [PNT_LO:0] frac_sum;
    logic [PNT_LO-1:0] frac_sub_lo;
    logic frac_carry, frac_zero;
    logic [1:0] frac_k;
    logic [INT_LO-1:0] pnt_i_l, stp_i_l, siz_i_l;
    logic [INT_HI-1:0] pnt_i_h, stp_i_h, siz_i_h;
    logic [INT_LO+1:0] isub_l_m1, isub_l_z, isub_l_p1, isub_l;
    logic [1:0] int_j;
    logic [INT_HI:0] isub_h_m1, isub_h_z, isub_h_p1, isub_h;
    logic [PNT_HI:0] int_sum_c0, int_sum_c1, int_sum, int_sub;
    logic [PNT_SIZE:0] new_next, new_sub;
    logic [PNT_SIZE-1:0] ref_pnt_after, new_pnt_after;
    begin
      ref_next = {1'b0,pnt} + {1'b0,step_hi,step_lo};
      ref_sub  = ref_next - {1'b0,size_i,{PNT_LO{1'b0}}} - 1'b1;

      frac_sum = {1'b0,pnt[PNT_LO-1:0]} + {1'b0,step_lo};
      frac_sub_lo = pnt[PNT_LO-1:0] + (step_lo - 1'b1);
      frac_carry = frac_sum[PNT_LO];
      frac_zero = (pnt[PNT_LO-1:0] == -step_lo);
      frac_k = frac_carry ? (frac_zero ? 2'b00 : 2'b01) :
                            frac_zero ? 2'b11 : 2'b00;

      int_sum_c0 = {1'b0,pnt[PNT_SIZE-1:PNT_LO]} + {1'b0,step_hi};
      int_sum_c1 = int_sum_c0 + 1'b1;
      int_sum = frac_carry ? int_sum_c1 : int_sum_c0;

      pnt_i_l = pnt[PNT_LO +: INT_LO];
      pnt_i_h = pnt[PNT_LO+INT_LO +: INT_HI];
      stp_i_l = step_hi[0 +: INT_LO];
      stp_i_h = step_hi[INT_LO +: INT_HI];
      siz_i_l = size_i[0 +: INT_LO];
      siz_i_h = size_i[INT_LO +: INT_HI];
      isub_l_m1 = {2'b0,pnt_i_l} + {2'b0,stp_i_l} - {2'b0,siz_i_l} - 1'b1;
      isub_l_z  = {2'b0,pnt_i_l} + {2'b0,stp_i_l} - {2'b0,siz_i_l};
      isub_l_p1 = {2'b0,pnt_i_l} + {2'b0,stp_i_l} - {2'b0,siz_i_l} + 1'b1;
      isub_l = frac_k[1] ? isub_l_m1 : frac_k[0] ? isub_l_p1 : isub_l_z;
      int_j = isub_l[INT_LO+1:INT_LO];
      isub_h_m1 = {1'b0,pnt_i_h} + {1'b0,stp_i_h} - {1'b0,siz_i_h} - 1'b1;
      isub_h_z  = {1'b0,pnt_i_h} + {1'b0,stp_i_h} - {1'b0,siz_i_h};
      isub_h_p1 = {1'b0,pnt_i_h} + {1'b0,stp_i_h} - {1'b0,siz_i_h} + 1'b1;
      isub_h = int_j[1] ? isub_h_m1 : int_j[0] ? isub_h_p1 : isub_h_z;
      int_sub = {isub_h,isub_l[INT_LO-1:0]};
      new_next = {int_sum,frac_sum[PNT_LO-1:0]};
      new_sub = {int_sub,frac_sub_lo};

      ref_pnt_after = ref_sub[PNT_SIZE] ? ref_next[PNT_SIZE-1:0] :
                      wrap ? ref_sub[PNT_SIZE-1:0] : {ofs_i,{PNT_LO{1'b0}}};
      new_pnt_after = new_sub[PNT_SIZE] ? new_next[PNT_SIZE-1:0] :
                      wrap ? new_sub[PNT_SIZE-1:0] : {ofs_i,{PNT_LO{1'b0}}};
      if (new_next !== ref_next || new_sub !== ref_sub || new_pnt_after !== ref_pnt_after) begin
        $error("mismatch pnt=%h step=%h_%h size=%h ref=%h/%h/%h new=%h/%h/%h",
               pnt, step_hi, step_lo, size_i, ref_next, ref_sub, ref_pnt_after,
               new_next, new_sub, new_pnt_after);
        $fatal(1);
      end
      pnt = ref_pnt_after;
      checks++;
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
