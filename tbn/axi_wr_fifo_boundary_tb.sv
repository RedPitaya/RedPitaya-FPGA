`timescale 1ns/1ps
module axi_wr_fifo_boundary_tb;
  localparam int AW=32, FW=8;
  logic [AW:0] next_address; logic [AW-1:0] stop_address;
  logic [FW:0] fill_lvl; logic fifo_flush;
  logic [8:0] old_next_end;
  logic [AW:0] old_next_stop, address_distance;
  logic [AW+1:0] old_boundary_condition;
  logic [2:0] old_cross, new_cross;
  logic [3:0] old_len, new_len;
  int checks;

  function automatic logic [3:0] burst_len(
    input logic [2:0] boundary, input logic [FW:0] fill,
    input logic flush, input logic [3:0] next_word,
    input logic [3:0] stop_word);
    if (boundary[1:0] || fill[FW:4]) begin
      if (fill[FW:4] && !boundary[1:0]) burst_len=4'hf;
      else if (boundary[2]) burst_len=4'hf-next_word;
      else burst_len=stop_word-next_word;
    end else if (flush) burst_len=fill[3:0]-1'b1;
    else burst_len=fill[3:0];
  endfunction

  always_comb begin
    // Exact copies of the original RTL expressions.
    old_next_end=next_address[10:3]+{3'b0,fill_lvl};
    old_next_stop={1'b0,stop_address[AW-1:3]}-next_address[AW:3]
                 -{{(AW-FW+1){1'b0}},fill_lvl};
    old_boundary_condition={1'b0,next_address[AW:3]}
                 +{{(AW-FW+1){1'b0}},fill_lvl}
                 -{1'b0,stop_address[AW-1:3]};
    old_cross={old_boundary_condition[AW+1],old_next_end[8],old_next_stop[AW]};

    // Candidate decomposition: fill_lvl is absent from the wide subtract.
    address_distance={1'b0,stop_address[AW-1:3]}-next_address[AW:3];
    new_cross[0]=address_distance[AW]
      || ({{(AW-FW){1'b0}},fill_lvl}>address_distance);
    new_cross[1]=({1'b0,next_address[10:3]}+fill_lvl)>=9'h100;
    // Strict '<' preserves the equality behavior of the old borrow bit.
    new_cross[2]=!address_distance[AW]
      && ({{(AW-FW){1'b0}},fill_lvl}<address_distance);
    old_len=burst_len(old_cross,fill_lvl,fifo_flush,
                      next_address[6:3],stop_address[6:3]);
    new_len=burst_len(new_cross,fill_lvl,fifo_flush,
                      next_address[6:3],stop_address[6:3]);
  end

  task automatic check_case(input logic [AW:0] next_addr,
    input logic [AW-1:0] stop_addr, input logic [FW:0] fill,
    input logic flush, input string label);
    next_address=next_addr; stop_address=stop_addr;
    fill_lvl=fill; fifo_flush=flush; #1; checks++;
    if (old_cross!==new_cross || old_len!==new_len) begin
      $error("%s next=%h stop=%h fill=%0d flush=%0b cross=%b/%b len=%0d/%0d",
        label,next_addr,stop_addr,fill,flush,old_cross,new_cross,old_len,new_len);
      $fatal(1);
    end
  endtask

  initial begin
    checks=0;
    // Actual Scope parameters are AW=32, FW=8 (fill_lvl is 0..256).
    // For each important fill level, test stop distance equality and +/-1.
    begin : directed_stop_distances
      int levels[10] = '{0,1,15,16,31,32,63,127,255,256};
      for (int i=0;i<10;i++) begin
        check_case('h1000,'h1000+((levels[i]-1)<<3),levels[i],0,"stop distance fill-1");
        check_case('h1000,'h1000+( levels[i]   <<3),levels[i],0,"stop distance equality");
        check_case('h1000,'h1000+((levels[i]+1)<<3),levels[i],0,"stop distance fill+1");
      end
    end
    check_case('h0200,'h0800,7,1,"partial flush");
    check_case('h0ff8,'h2000,1,0,"exact 4k boundary");
    check_case('h0ff0,'h2000,3,0,"cross 4k boundary");
    check_case('h0800,'h2000,256,0,"fill level 256");
    check_case('h2008,'h2000,1,0,"already past stop");
    // Exhaust every fill value and low 4k position close to the stop transition.
    // 512 is the 4k boundary expressed in 64-bit words.
    for (int n=0;n<512;n++) for (int d=-4;d<=4;d++)
      for (int f=0;f<=256;f++) check_case(n<<3,(n+f+d)<<3,f,f<16,"low exhaustive");
    for (int i=0;i<50000;i++) check_case({$urandom,1'b0},$urandom&32'hfffffff8,
      $urandom_range(256,0),$urandom_range(1,0),"random high");
    $display("PASS: %0d boundary and burst-length equivalence checks",checks);
    $finish;
  end
endmodule
