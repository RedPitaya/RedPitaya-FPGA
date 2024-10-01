// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.1 (lin64) Build 2902540 Wed May 27 19:54:35 MDT 2020
// Date        : Tue Oct  1 14:35:22 2024
// Host        : devmachine running 64-bit Ubuntu 24.04 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/juretrnovec/RPdev/RP30/redpitaya-fpga/redpitaya-fpga/ip/asg_dat_fifo/asg_dat_fifo_stub.v
// Design      : asg_dat_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_5,Vivado 2020.1" *)
module asg_dat_fifo(rst, wr_clk, rd_clk, din, wr_en, rd_en, dout, full, 
  empty, rd_data_count, wr_rst_busy, rd_rst_busy)
/* synthesis syn_black_box black_box_pad_pin="rst,wr_clk,rd_clk,din[95:0],wr_en,rd_en,dout[95:0],full,empty,rd_data_count[7:0],wr_rst_busy,rd_rst_busy" */;
  input rst;
  input wr_clk;
  input rd_clk;
  input [95:0]din;
  input wr_en;
  input rd_en;
  output [95:0]dout;
  output full;
  output empty;
  output [7:0]rd_data_count;
  output wr_rst_busy;
  output rd_rst_busy;
endmodule
