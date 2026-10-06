`timescale 1ns/1ps

module sync #(parameter DW = 1) (
  input sclk_i, input srstn_i, input dclk_i, input drstn_i,
  input [DW-1:0] src_i, output logic [DW-1:0] dst_o
);
  always_ff @(posedge dclk_i)
    if (!drstn_i) dst_o <= '0; else dst_o <= src_i;
endmodule

module rand_lfsr #(parameter DW = 14) (
  input clk_i, input rstn_i, input init_i,
  input [31:0] seed_i, output logic [DW-1:0] dat_o
);
  always_ff @(posedge clk_i)
    if (!rstn_i) dat_o <= '0; else dat_o <= dat_o + 1'b1;
endmodule

module rp_asg_axi (
  output logic [13:0] dac_o,
  input dac_clk_i, input dac_rstn_i, input trig_i,
  axi_sys_if.s axi_sys,
  input set_rst_i, input set_axi_en_i, input repeat_i,
  input [31:0] set_axi_start_i, input [31:0] set_axi_stop_i,
  input [31:0] set_axi_dec_i, input [15:0] set_cyc_cnt_i,
  output logic [19:0] axi_state_o,
  output logic axi_last_o, output logic axi_last_pre_o,
  output logic axi_first_o
);
  always_comb begin
    dac_o = '0; axi_state_o = '0; axi_last_o = 1'b0;
    axi_last_pre_o = 1'b0; axi_first_o = 1'b0;
  end
endmodule

module asg_pointer_pair_integration_tb;
  localparam int RSZ = 14;
  localparam int PNT_SIZE = RSZ + 16 + 32;

  logic dac_clk_i = 0, sys_clk_i = 0;
  logic dac_rstn_i = 0, sys_rstn_i = 0;
  logic [13:0] dac_o;
  logic trig_sw_i = 0, trig_ext_i = 0;
  logic [2:0] trig_src_i = 3'd1;
  logic trig_done_o;
  logic buf_we_i = 0;
  logic [13:0] buf_addr_i = 0, buf_wdata_i = 0;
  logic [13:0] buf_rdata_o, buf_rpnt_o;
  logic [29:0] set_size_i = 30'h3fff_ffff;
  logic [31:0] set_step_i = 32'h1, set_step_lo_i = 32'h1234;
  logic [31:0] get_step_o, get_step_lo_o, set_ofs_i = 32'h10000;
  logic set_rst_i = 0, set_rdly_mode_i = 0, set_wrap_i = 1;
  logic [13:0] set_amp_i = 14'h2000, set_dc_i = 0;
  logic [13:0] set_first_i = 0, set_last_i = 0;
  logic [31:0] set_last_len_i = 0;
  logic set_zero_i = 0;
  logic [15:0] set_ncyc_i = 16'hffff, set_rnum_i = 16'hffff;
  logic [31:0] set_rdly_i = 0;
  logic [19:0] set_deb_len_i = 0;
  logic [31:0] set_seed_i = 1;
  logic rand_en_i = 0, rand_init_i = 0, set_rgate_i = 0;
  logic set_axi_en_i = 0;
  logic [31:0] set_axi_start_i = 0, set_axi_stop_i = 0, set_axi_dec_i = 0;
  logic [19:0] axi_state_o;
  logic [31:0] err_cnt_o, transf_cnt_o;
  axi_sys_if axi_sys();

  always #2 dac_clk_i = ~dac_clk_i;
  always #4 sys_clk_i = ~sys_clk_i;

  red_pitaya_asg_ch #(.RSZ(RSZ)) dut (.*);

  function automatic [PNT_SIZE-1:0] advance_ref(input [PNT_SIZE-1:0] base);
    logic [PNT_SIZE:0] sum, sub;
    begin
      sum = {1'b0,base} + {1'b0,set_step_i[29:0],set_step_lo_i};
      sub = sum - {1'b0,set_size_i,32'b0} - 1'b1;
      advance_ref = sub[PNT_SIZE] ? sum[PNT_SIZE-1:0] :
                    set_wrap_i ? sub[PNT_SIZE-1:0] : {set_ofs_i[29:0],32'b0};
    end
  endfunction

  task automatic pulse_trigger;
    begin
      @(negedge dac_clk_i); trig_sw_i = 1'b1;
      @(negedge dac_clk_i); trig_sw_i = 1'b0;
    end
  endtask

  task automatic pulse_set_reset;
    begin
      @(negedge dac_clk_i); set_rst_i = 1'b1;
      repeat (2) @(negedge dac_clk_i);
      set_rst_i = 1'b0;
    end
  endtask

  initial begin
    logic [PNT_SIZE-1:0] expected;
    logic [PNT_SIZE-1:0] saved_pnt, saved_next, saved_offset;
    logic [31:0] saved_step, saved_step_lo;
    logic [29:0] saved_size;

    repeat (4) @(posedge dac_clk_i);
    dac_rstn_i = 1'b1; sys_rstn_i = 1'b1;
    pulse_set_reset();
    pulse_trigger();
    wait (dut.dac_do === 1'b1);
    #1;
    expected = {set_ofs_i[29:0],32'b0};
    if (dut.dac_pnt !== expected) $fatal(1, "bad first pointer");
    repeat (20) begin
      @(posedge dac_clk_i); #1;
      expected = advance_ref(expected);
      if (dut.dac_pnt !== expected)
        $fatal(1, "sequence mismatch expected=%h actual=%h", expected, dut.dac_pnt);
    end

    // Force a short one-cycle burst followed by a long inter-repeat delay.
    pulse_set_reset();
    set_ofs_i = 0; set_step_i = 1; set_step_lo_i = 0;
    set_size_i = 30'd2; set_ncyc_i = 1; set_rnum_i = 2;
    set_rdly_i = 1000; set_wrap_i = 1;
    pulse_set_reset();
    pulse_trigger();
    wait (dut.dac_rep && !dut.dac_do && dut.dly_started);
    #1;
    saved_pnt = dut.dac_pnt; saved_next = dut.dac_pnt_next;
    saved_step = dut.set_step; saved_step_lo = dut.set_step_lo;
    saved_size = dut.set_size; saved_offset = dut.set_offset;

    // A trigger ignored by the FSM during this pause must not reload the pair
    // or capture a new configuration behind the FSM's back.
    set_ofs_i = 32'h12345; set_step_i = 32'h55; set_step_lo_i = 32'haa55aa55;
    set_size_i = 30'h1234567;
    pulse_trigger();
    repeat (8) @(posedge dac_clk_i);
    #1;
    if (dut.pnt_pair_warm !== 0 || dut.dac_pnt !== saved_pnt ||
        dut.dac_pnt_next !== saved_next || dut.set_step !== saved_step ||
        dut.set_step_lo !== saved_step_lo || dut.set_size !== saved_size ||
        dut.set_offset !== saved_offset)
      $fatal(1, "ignored pause trigger changed pointer pair or configuration");

    $display("SUCCESS: pair sequencing and ignored inter-repeat trigger checks");
    $finish;
  end
endmodule
