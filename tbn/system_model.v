/*
* Copyright (c) 2016 Instrumentation Technologies, d.d.
* All Rights Reserved.
*
* $Id: $
*/

// synopsys translate_off
`timescale 1ns/1ps
// synopsys translate_on

//------------------------------------------------------------------------------
//

/*! \file
    \brief System model
*/
//! \brief

module system_model
#(
  parameter GP0_AW = 32,
  parameter GP0_DW = 32,
  parameter GP0_IW =  4,
  parameter GP0_SZ = GP0_DW/8,


  parameter HP0_AW = 32,
  parameter HP0_DW = 64,
  parameter HP0_IW =  4,
  parameter HP0_SZ = HP0_DW/8,

  parameter HP1_AW = 32,
  parameter HP1_DW = 64,
  parameter HP1_IW =  4,
  parameter HP1_SZ = HP1_DW/8,

  parameter HP2_AW = 32,
  parameter HP2_DW = 64,
  parameter HP2_IW =  4,
  parameter HP2_SZ = HP2_DW/8,

  parameter HP3_AW = 32,
  parameter HP3_DW = 64,
  parameter HP3_IW =  4,
  parameter HP3_SZ = HP3_DW/8
)
(
inout  [14:0] DDR_addr,
inout  [ 2:0] DDR_ba,
inout         DDR_cas_n,
inout         DDR_ck_n,
inout         DDR_ck_p,
inout         DDR_cke,
inout         DDR_cs_n,
inout  [ 3:0] DDR_dm,
inout  [31:0] DDR_dq,
inout  [ 3:0] DDR_dqs_n,
inout  [ 3:0] DDR_dqs_p,
inout         DDR_odt,
inout         DDR_ras_n,
inout         DDR_reset_n,
inout         DDR_we_n,
output        FCLK_CLK0,
output        FCLK_CLK1,
output        FCLK_CLK2,
output        FCLK_CLK3,
output        FCLK_RESET0_N,
output        FCLK_RESET1_N,
output        FCLK_RESET2_N,
output        FCLK_RESET3_N,
inout         FIXED_IO_ddr_vrn,
inout         FIXED_IO_ddr_vrp,
inout  [53:0] FIXED_IO_mio,
inout         FIXED_IO_ps_clk,
inout         FIXED_IO_ps_porb,
inout         FIXED_IO_ps_srstb,
input  [23:0] GPIO_tri_i,
output [23:0] GPIO_tri_o,
output [23:0] GPIO_tri_t,

input               M_AXI_GP0_ACLK,
output [GP0_AW-1:0] M_AXI_GP0_araddr,
output [     2-1:0] M_AXI_GP0_arburst,
output [     4-1:0] M_AXI_GP0_arcache,
output [GP0_IW-1:0] M_AXI_GP0_arid,
output [     4-1:0] M_AXI_GP0_arlen,
output [     2-1:0] M_AXI_GP0_arlock,
output [     3-1:0] M_AXI_GP0_arprot,
output [     4-1:0] M_AXI_GP0_arqos,
input               M_AXI_GP0_arready,
output [     3-1:0] M_AXI_GP0_arsize,
output              M_AXI_GP0_arvalid,
output [GP0_AW-1:0] M_AXI_GP0_awaddr,
output [     2-1:0] M_AXI_GP0_awburst,
output [     4-1:0] M_AXI_GP0_awcache,
output [GP0_IW-1:0] M_AXI_GP0_awid,
output [     4-1:0] M_AXI_GP0_awlen,
output [     2-1:0] M_AXI_GP0_awlock,
output [     3-1:0] M_AXI_GP0_awprot,
output [     4-1:0] M_AXI_GP0_awqos,
input               M_AXI_GP0_awready,
output [     3-1:0] M_AXI_GP0_awsize,
output              M_AXI_GP0_awvalid,
input  [GP0_IW-1:0] M_AXI_GP0_bid,
output              M_AXI_GP0_bready,
input  [     2-1:0] M_AXI_GP0_bresp,
input               M_AXI_GP0_bvalid,
input  [GP0_DW-1:0] M_AXI_GP0_rdata,
input  [GP0_IW-1:0] M_AXI_GP0_rid,
input               M_AXI_GP0_rlast,
output              M_AXI_GP0_rready,
input  [     2-1:0] M_AXI_GP0_rresp,
input               M_AXI_GP0_rvalid,
output [GP0_DW-1:0] M_AXI_GP0_wdata,
output [GP0_IW-1:0] M_AXI_GP0_wid,
output              M_AXI_GP0_wlast,
input               M_AXI_GP0_wready,
output [GP0_SZ-1:0] M_AXI_GP0_wstrb,
output              M_AXI_GP0_wvalid,

input         SPI0_io0_i,
output        SPI0_io0_o,
output        SPI0_io0_t,
input         SPI0_io1_i,
output        SPI0_io1_o,
output        SPI0_io1_t,
input         SPI0_sck_i,
output        SPI0_sck_o,
output        SPI0_sck_t,
output        SPI0_ss1_o,
output        SPI0_ss2_o,
input         SPI0_ss_i,
output        SPI0_ss_o,
output        SPI0_ss_t,

input         SPI1_io0_i,
output        SPI1_io0_o,
output        SPI1_io0_t,
input         SPI1_io1_i,
output        SPI1_io1_o,
output        SPI1_io1_t,
input         SPI1_sck_i,
output        SPI1_sck_o,
output        SPI1_sck_t,
output        SPI1_ss1_o,
output        SPI1_ss2_o,
input         SPI1_ss_i,
output        SPI1_ss_o,
output        SPI1_ss_t,

input               S_AXI_HP0_aclk,
input  [HP0_AW-1:0] S_AXI_HP0_araddr,
input  [     2-1:0] S_AXI_HP0_arburst,
input  [     4-1:0] S_AXI_HP0_arcache,
input  [HP0_IW-1:0] S_AXI_HP0_arid,
input  [     4-1:0] S_AXI_HP0_arlen,
input  [     2-1:0] S_AXI_HP0_arlock,
input  [     3-1:0] S_AXI_HP0_arprot,
input  [     4-1:0] S_AXI_HP0_arqos,
output              S_AXI_HP0_arready,
input  [     3-1:0] S_AXI_HP0_arsize,
input               S_AXI_HP0_arvalid,
input  [HP0_AW-1:0] S_AXI_HP0_awaddr,
input  [     2-1:0] S_AXI_HP0_awburst,
input  [     4-1:0] S_AXI_HP0_awcache,
input  [HP0_IW-1:0] S_AXI_HP0_awid,
input  [     4-1:0] S_AXI_HP0_awlen,
input  [     2-1:0] S_AXI_HP0_awlock,
input  [     3-1:0] S_AXI_HP0_awprot,
input  [     4-1:0] S_AXI_HP0_awqos,
output              S_AXI_HP0_awready,
input  [     3-1:0] S_AXI_HP0_awsize,
input               S_AXI_HP0_awvalid,
output [HP0_IW-1:0] S_AXI_HP0_bid,
input               S_AXI_HP0_bready,
output [     2-1:0] S_AXI_HP0_bresp,
output              S_AXI_HP0_bvalid,
output [HP0_DW-1:0] S_AXI_HP0_rdata,
output [HP0_IW-1:0] S_AXI_HP0_rid,
output              S_AXI_HP0_rlast,
input               S_AXI_HP0_rready,
output [     2-1:0] S_AXI_HP0_rresp,
output              S_AXI_HP0_rvalid,
input  [HP0_DW-1:0] S_AXI_HP0_wdata,
input  [HP0_IW-1:0] S_AXI_HP0_wid,
input               S_AXI_HP0_wlast,
output              S_AXI_HP0_wready,
input  [HP0_SZ-1:0] S_AXI_HP0_wstrb,
input               S_AXI_HP0_wvalid,

input               S_AXI_HP1_aclk,
input  [HP1_AW-1:0] S_AXI_HP1_araddr,
input  [     2-1:0] S_AXI_HP1_arburst,
input  [     4-1:0] S_AXI_HP1_arcache,
input  [HP1_IW-1:0] S_AXI_HP1_arid,
input  [     4-1:0] S_AXI_HP1_arlen,
input  [     2-1:0] S_AXI_HP1_arlock,
input  [     3-1:0] S_AXI_HP1_arprot,
input  [     4-1:0] S_AXI_HP1_arqos,
output              S_AXI_HP1_arready,
input  [     3-1:0] S_AXI_HP1_arsize,
input               S_AXI_HP1_arvalid,
input  [HP1_AW-1:0] S_AXI_HP1_awaddr,
input  [     2-1:0] S_AXI_HP1_awburst,
input  [     4-1:0] S_AXI_HP1_awcache,
input  [HP1_IW-1:0] S_AXI_HP1_awid,
input  [     4-1:0] S_AXI_HP1_awlen,
input  [     2-1:0] S_AXI_HP1_awlock,
input  [     3-1:0] S_AXI_HP1_awprot,
input  [     4-1:0] S_AXI_HP1_awqos,
output              S_AXI_HP1_awready,
input  [     3-1:0] S_AXI_HP1_awsize,
input               S_AXI_HP1_awvalid,
output [HP1_IW-1:0] S_AXI_HP1_bid,
input         S_AXI_HP1_bready,
output [     2-1:0] S_AXI_HP1_bresp,
output              S_AXI_HP1_bvalid,
output [HP1_DW-1:0] S_AXI_HP1_rdata,
output [HP1_IW-1:0] S_AXI_HP1_rid,
output              S_AXI_HP1_rlast,
input               S_AXI_HP1_rready,
output [     2-1:0] S_AXI_HP1_rresp,
output              S_AXI_HP1_rvalid,
input  [HP1_DW-1:0] S_AXI_HP1_wdata,
input  [HP1_IW-1:0] S_AXI_HP1_wid,
input               S_AXI_HP1_wlast,
output              S_AXI_HP1_wready,
input  [HP1_SZ-1:0] S_AXI_HP1_wstrb,
input               S_AXI_HP1_wvalid,

input               S_AXI_HP2_aclk,
input  [HP2_AW-1:0] S_AXI_HP2_araddr,
input  [     2-1:0] S_AXI_HP2_arburst,
input  [     4-1:0] S_AXI_HP2_arcache,
input  [HP2_IW-1:0] S_AXI_HP2_arid,
input  [     4-1:0] S_AXI_HP2_arlen,
input  [     2-1:0] S_AXI_HP2_arlock,
input  [     3-1:0] S_AXI_HP2_arprot,
input  [     4-1:0] S_AXI_HP2_arqos,
output              S_AXI_HP2_arready,
input  [     3-1:0] S_AXI_HP2_arsize,
input               S_AXI_HP2_arvalid,
input  [HP2_AW-1:0] S_AXI_HP2_awaddr,
input  [     2-1:0] S_AXI_HP2_awburst,
input  [     4-1:0] S_AXI_HP2_awcache,
input  [HP2_IW-1:0] S_AXI_HP2_awid,
input  [     4-1:0] S_AXI_HP2_awlen,
input  [     2-1:0] S_AXI_HP2_awlock,
input  [     3-1:0] S_AXI_HP2_awprot,
input  [     4-1:0] S_AXI_HP2_awqos,
output              S_AXI_HP2_awready,
input  [     3-1:0] S_AXI_HP2_awsize,
input               S_AXI_HP2_awvalid,
output [HP2_IW-1:0] S_AXI_HP2_bid,
input               S_AXI_HP2_bready,
output [     2-1:0] S_AXI_HP2_bresp,
output              S_AXI_HP2_bvalid,
output [HP2_DW-1:0] S_AXI_HP2_rdata,
output [HP2_IW-1:0] S_AXI_HP2_rid,
output              S_AXI_HP2_rlast,
input               S_AXI_HP2_rready,
output [     2-1:0] S_AXI_HP2_rresp,
output              S_AXI_HP2_rvalid,
input  [HP2_DW-1:0] S_AXI_HP2_wdata,
input  [HP2_IW-1:0] S_AXI_HP2_wid,
input               S_AXI_HP2_wlast,
output              S_AXI_HP2_wready,
input  [HP2_SZ-1:0] S_AXI_HP2_wstrb,
input               S_AXI_HP2_wvalid,

input               S_AXI_HP3_aclk,
input  [HP3_AW-1:0] S_AXI_HP3_araddr,
input  [     2-1:0] S_AXI_HP3_arburst,
input  [     4-1:0] S_AXI_HP3_arcache,
input  [HP3_IW-1:0] S_AXI_HP3_arid,
input  [     4-1:0] S_AXI_HP3_arlen,
input  [     2-1:0] S_AXI_HP3_arlock,
input  [     3-1:0] S_AXI_HP3_arprot,
input  [     4-1:0] S_AXI_HP3_arqos,
output              S_AXI_HP3_arready,
input  [     3-1:0] S_AXI_HP3_arsize,
input               S_AXI_HP3_arvalid,
input  [HP3_AW-1:0] S_AXI_HP3_awaddr,
input  [     2-1:0] S_AXI_HP3_awburst,
input  [     4-1:0] S_AXI_HP3_awcache,
input  [HP3_IW-1:0] S_AXI_HP3_awid,
input  [     4-1:0] S_AXI_HP3_awlen,
input  [     2-1:0] S_AXI_HP3_awlock,
input  [       2:0] S_AXI_HP3_awprot,
input  [     4-1:0] S_AXI_HP3_awqos,
output              S_AXI_HP3_awready,
input  [     3-1:0] S_AXI_HP3_awsize,
input               S_AXI_HP3_awvalid,
output [HP3_IW-1:0] S_AXI_HP3_bid,
input               S_AXI_HP3_bready,
output [     2-1:0] S_AXI_HP3_bresp,
output              S_AXI_HP3_bvalid,
output [HP3_DW-1:0] S_AXI_HP3_rdata,
output [HP3_IW-1:0] S_AXI_HP3_rid,
output              S_AXI_HP3_rlast,
input               S_AXI_HP3_rready,
output [     2-1:0] S_AXI_HP3_rresp,
output              S_AXI_HP3_rvalid,
input  [HP3_DW-1:0] S_AXI_HP3_wdata,
input  [HP3_IW-1:0] S_AXI_HP3_wid,
input               S_AXI_HP3_wlast,
output              S_AXI_HP3_wready,
input  [HP3_SZ-1:0] S_AXI_HP3_wstrb,
input               S_AXI_HP3_wvalid,

input         CAN0_rx,
output        CAN0_tx,

input         CAN1_rx,
output        CAN1_tx,

input         IRQ_LG,
input         IRQ_LA,
input         IRQ_GEN0,
input         IRQ_GEN1,
input         IRQ_SCP0,
input         IRQ_SCP1,
input  [15:0] IRQ_F2P,

input         Vaux0_v_n,
input         Vaux0_v_p,
input         Vaux1_v_n,
input         Vaux1_v_p,
input         Vaux8_v_n,
input         Vaux8_v_p,
input         Vaux9_v_n,
input         Vaux9_v_p,
input         Vp_Vn_v_n,
input         Vp_Vn_v_p  
);

`ifdef SIMULATION
//------------------------------------------------------------------------------
// open ports
assign DDR_addr = 15'hz;
assign DDR_ba = 3'hz;
assign DDR_cas_n = 1'hz;
assign DDR_ck_n = 1'hz;
assign DDR_ck_p = 1'hz;
assign DDR_cke = 1'hz;
assign DDR_cs_n = 1'hz;
assign DDR_dm = 4'hz;
assign DDR_dq = 32'hz;
assign DDR_dqs_n = 4'hz;
assign DDR_dqs_p = 4'hz;
assign DDR_odt = 1'hz;
assign DDR_ras_n = 1'hz;
assign DDR_reset_n = 1'hz;
assign DDR_we_n = 1'hz;
assign FIXED_IO_ddr_vrn = 1'hz;
assign FIXED_IO_ddr_vrp = 1'hz;
assign FIXED_IO_mio = 54'hz;
assign FIXED_IO_ps_clk = 1'hz;
assign FIXED_IO_ps_porb = 1'hz;
assign FIXED_IO_ps_srstb = 1'hz;

assign SPI0_io0_o = 1'b0 ;
assign SPI0_io0_t = 1'b0 ;
assign SPI0_io1_o = 1'b0 ;
assign SPI0_io1_t = 1'b0 ;
assign SPI0_sck_o  = 1'b0 ;
assign SPI0_sck_t  = 1'b0 ;
assign SPI0_ss_o  = 1'b0 ;
assign SPI0_ss_t  = 1'b0 ;
assign SPI0_ss1_o  = 1'b0 ;
assign SPI0_ss2_o  = 1'b0 ;

assign SPI1_io0_o = 1'b0 ;
assign SPI1_io0_t = 1'b0 ;
assign SPI1_io1_o = 1'b0 ;
assign SPI1_io1_t = 1'b0 ;
assign SPI1_sck_o  = 1'b0 ;
assign SPI1_sck_t  = 1'b0 ;
assign SPI1_ss_o  = 1'b0 ;
assign SPI1_ss_t  = 1'b0 ;
assign SPI1_ss1_o  = 1'b0 ;
assign SPI1_ss2_o  = 1'b0 ;


//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// System clocks
wire [4-1:0] fclk_clk ;


localparam FCLK0_PER =  8000;
localparam FCLK1_PER =  4000;
localparam FCLK2_PER = 20000;
localparam FCLK3_PER =  5000;
//localparam FCLK2_PER =  5000;
//localparam FCLK3_PER =  6000;

localparam FCLK0_JIT = 0;
localparam FCLK1_JIT = 0;
localparam FCLK2_JIT = 0;
localparam FCLK3_JIT = 0;

clk_gen #(
  .CLKA_PERIOD  ( FCLK0_PER ) , //125MHz
  .CLKA_JIT     ( FCLK0_JIT ) , 
  .CLKB_PERIOD  ( FCLK1_PER ) , //250Mhz
  .CLKB_JIT     ( FCLK1_JIT ) ,
  .CLKC_PERIOD  ( FCLK2_PER ) , //50Mhz
  .CLKC_JIT     ( FCLK2_JIT ) ,
  .CLKD_PERIOD  ( FCLK3_PER ) , //200Mhz
  .CLKD_JIT     ( FCLK3_JIT )
)
i_clgen_model
(
  .clka_o  (  fclk_clk[0]  ) ,
  .clkb_o  (  fclk_clk[1]  ) ,
  .clkc_o  (  fclk_clk[2]  ) ,
  .clkd_o  (  fclk_clk[3]  )
);

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
reg  [4-1:0] fclk_rstn ;

initial begin : FCLK0
  fclk_rstn[0] <= 1'b0 ;
  repeat (16) @(posedge fclk_clk[0]);
  fclk_rstn[0] <= 1'b1 ;
end

initial begin : FCLK1
  fclk_rstn[1] <= 1'b0 ;
  repeat (16) @(posedge fclk_clk[1]);
  fclk_rstn[1] <= 1'b1 ;
end

initial begin : FCLK2
  fclk_rstn[2] <= 1'b0 ;
  repeat (16) @(posedge fclk_clk[2]);
  fclk_rstn[2] <= 1'b1 ;
end

initial begin : FCLK3
  fclk_rstn[3] <= 1'b0 ;
  repeat (16) @(posedge fclk_clk[3]);
  fclk_rstn[3] <= 1'b1 ;
end

reg axi_rst;
initial begin : AXIRST
  axi_rst <= 1'b0 ;
  repeat (60) @(posedge fclk_clk[0]);
  axi_rst <= 1'b1 ;
end

reg CAN0_tx_r = 1'b0;
assign CAN0_tx = CAN0_tx_r;

reg CAN1_tx_r = 1'b0;
assign CAN1_tx = CAN1_tx_r;
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
assign FCLK_CLK0 = fclk_clk[0] ;
assign FCLK_CLK1 = fclk_clk[1] ;
assign FCLK_CLK2 = fclk_clk[2] ;
assign FCLK_CLK3 = fclk_clk[3] ;

assign FCLK_RESET0_N = fclk_rstn[0] ;
assign FCLK_RESET1_N = fclk_rstn[1] ;
assign FCLK_RESET2_N = fclk_rstn[2] ;
assign FCLK_RESET3_N = fclk_rstn[3] ;
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// AXI master model
axi_master_model 
#(
  .DW  (GP0_DW) ,
  .AW  (GP0_AW) ,
  .IW  (GP0_IW) 
)
i_m_axi_gp0
(
  // global signals
  .aclk_i      (  M_AXI_GP0_ACLK  ), // global clock
  .arstn_i     (  axi_rst     ), // global reset.NOTE:Model simulation only, Wait to latest rstn.

    // axi write address channel
  .awid_o     (  M_AXI_GP0_awid          ), // write address ID
  .awaddr_o   (  M_AXI_GP0_awaddr        ), // write address
  .awlen_o    (  M_AXI_GP0_awlen         ), // write burst length
  .awsize_o   (  M_AXI_GP0_awsize        ), // write burst size
  .awburst_o  (  M_AXI_GP0_awburst       ), // write burst type
  .awlock_o   (  M_AXI_GP0_awlock        ), // write lock type
  .awcache_o  (  M_AXI_GP0_awcache       ), // write cache type
  .awprot_o   (  M_AXI_GP0_awprot        ), // write protection type
  .awvalid_o  (  M_AXI_GP0_awvalid       ), // write address valid
  .awready_i  (  M_AXI_GP0_awready       ), // write ready
    
    // axi write data channel
  //.wid_o      (  M_AXI_GP0_wid           ), // write data ID
  .wdata_o    (  M_AXI_GP0_wdata         ), // write data
  .wstrb_o    (  M_AXI_GP0_wstrb         ), // write strobes
  .wlast_o    (  M_AXI_GP0_wlast         ), // write last
  .wvalid_o   (  M_AXI_GP0_wvalid        ), // write valid
  .wready_i   (  M_AXI_GP0_wready        ), // write ready
    
    // axi write response channel
  .bid_i      (  M_AXI_GP0_bid           ), // write response ID
  .bresp_i    (  M_AXI_GP0_bresp         ), // write response
  .bvalid_i   (  M_AXI_GP0_bvalid        ), // write response valid
  .bready_o   (  M_AXI_GP0_bready        ), // write response ready
    
    // axi read address channel
  .arid_o     (  M_AXI_GP0_arid          ), // read address ID
  .araddr_o   (  M_AXI_GP0_araddr        ), // read address
  .arlen_o    (  M_AXI_GP0_arlen         ), // read burst length
  .arsize_o   (  M_AXI_GP0_arsize        ), // read burst size
  .arburst_o  (  M_AXI_GP0_arburst       ), // read burst type
  .arlock_o   (  M_AXI_GP0_arlock        ), // read lock type
  .arcache_o  (  M_AXI_GP0_arcache       ), // read cache type
  .arprot_o   (  M_AXI_GP0_arprot        ), // read protection type
  .arvalid_o  (  M_AXI_GP0_arvalid       ), // read address valid
  .arready_i  (  M_AXI_GP0_arready       ), // read address ready
        
    // axi read data channel
  .rid_i      (  M_AXI_GP0_rid           ), // read response ID
  .rdata_i    (  M_AXI_GP0_rdata         ), // read data
  .rresp_i    (  M_AXI_GP0_rresp         ), // read response
  .rlast_i    (  M_AXI_GP0_rlast         ), // read last
  .rvalid_i   (  M_AXI_GP0_rvalid        ), // read response valid
  .rready_o   (  M_AXI_GP0_rready        )  // read response ready
);
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// AXI0 slave model
axi_slave_model
#(
  .AXI_DW  (HP0_DW) , // data width (8,16,...,1024)
  .AXI_AW  (HP0_AW) , // address width ()
  .AXI_ID  (  0   ) , // master ID
  .AXI_IW  (HP0_IW)   // master ID width   
)
i_s_axi_hp0
(
  // global signals
  .axi_clk_i      (  S_AXI_HP0_aclk  ), // global clock
  .axi_rstn_i     (  axi_rst     ), // global reset.NOTE:Model simulation only, Wait to latest rstn.
                
    // axi write address channel
  .axi_awid_i     (  S_AXI_HP0_awid         ), // write address ID
  .axi_awaddr_i   (  S_AXI_HP0_awaddr       ), // write address
  .axi_awlen_i    (  S_AXI_HP0_awlen        ), // write burst length
  .axi_awsize_i   (  S_AXI_HP0_awsize       ), // write burst size
  .axi_awburst_i  (  S_AXI_HP0_awburst      ), // write burst type
  .axi_awlock_i   (  S_AXI_HP0_awlock       ), // write lock type
  .axi_awcache_i  (  S_AXI_HP0_awcache      ), // write cache type
  .axi_awprot_i   (  S_AXI_HP0_awprot       ), // write protection type
  .axi_awvalid_i  (  S_AXI_HP0_awvalid      ), // write address valid
  .axi_awready_o  (  S_AXI_HP0_awready      ), // write ready

    // axi write data channel
  .axi_wid_i      (  S_AXI_HP0_wid          ), // write data ID
  .axi_wdata_i    (  S_AXI_HP0_wdata        ), // write data
  .axi_wstrb_i    (  S_AXI_HP0_wstrb        ), // write strobes
  .axi_wlast_i    (  S_AXI_HP0_wlast        ), // write last
  .axi_wvalid_i   (  S_AXI_HP0_wvalid       ), // write valid
  .axi_wready_o   (  S_AXI_HP0_wready       ), // write ready

    // axi write response channel
  .axi_bid_o      (  S_AXI_HP0_bid          ), // write response ID
  .axi_bresp_o    (  S_AXI_HP0_bresp        ), // write response
  .axi_bvalid_o   (  S_AXI_HP0_bvalid       ), // write response valid
  .axi_bready_i   (  S_AXI_HP0_bready       ), // write response ready

    // axi read address channel
  .axi_arid_i     (  S_AXI_HP0_arid         ), // read address ID
  .axi_araddr_i   (  S_AXI_HP0_araddr       ), // read address
  .axi_arlen_i    (  S_AXI_HP0_arlen        ), // read burst length
  .axi_arsize_i   (  S_AXI_HP0_arsize       ), // read burst size
  .axi_arburst_i  (  S_AXI_HP0_arburst      ), // read burst type
  .axi_arlock_i   (  S_AXI_HP0_arlock       ), // read lock type
  .axi_arcache_i  (  S_AXI_HP0_arcache      ), // read cache type
  .axi_arprot_i   (  S_AXI_HP0_arprot       ), // read protection type
  .axi_arvalid_i  (  S_AXI_HP0_arvalid      ), // read address valid
  .axi_arready_o  (  S_AXI_HP0_arready      ), // read address ready
    
    // axi read data channel
  .axi_rid_o      (  S_AXI_HP0_rid          ), // read response ID
  .axi_rdata_o    (  S_AXI_HP0_rdata        ), // read data
  .axi_rresp_o    (  S_AXI_HP0_rresp        ), // read response
  .axi_rlast_o    (  S_AXI_HP0_rlast        ), // read last
  .axi_rvalid_o   (  S_AXI_HP0_rvalid       ), // read response valid
  .axi_rready_i   (  S_AXI_HP0_rready       )  // read response ready
);
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// AXI1 slave model
axi_slave_model
#(
  .AXI_DW (HP1_DW) , // data width (8,16,...,1024)
  .AXI_AW (HP1_AW) , // address width ()
  .AXI_ID (   1  ) , // master ID
  .AXI_IW (HP1_IW)   // master ID width   
)
i_s_axi_hp1
(
  // global signals
  .axi_clk_i      (  S_AXI_HP1_aclk  ), // global clock
  .axi_rstn_i     (  axi_rst     ), // global reset.NOTE:Model simulation only, Wait to latest rstn.
                
    // axi write address channel
  .axi_awid_i     (  S_AXI_HP1_awid         ), // write address ID
  .axi_awaddr_i   (  S_AXI_HP1_awaddr       ), // write address
  .axi_awlen_i    (  S_AXI_HP1_awlen        ), // write burst length
  .axi_awsize_i   (  S_AXI_HP1_awsize       ), // write burst size
  .axi_awburst_i  (  S_AXI_HP1_awburst      ), // write burst type
  .axi_awlock_i   (  S_AXI_HP1_awlock       ), // write lock type
  .axi_awcache_i  (  S_AXI_HP1_awcache      ), // write cache type
  .axi_awprot_i   (  S_AXI_HP1_awprot       ), // write protection type
  .axi_awvalid_i  (  S_AXI_HP1_awvalid      ), // write address valid
  .axi_awready_o  (  S_AXI_HP1_awready      ), // write ready

    // axi write data channel
  .axi_wid_i      (  S_AXI_HP1_wid          ), // write data ID
  .axi_wdata_i    (  S_AXI_HP1_wdata        ), // write data
  .axi_wstrb_i    (  S_AXI_HP1_wstrb        ), // write strobes
  .axi_wlast_i    (  S_AXI_HP1_wlast        ), // write last
  .axi_wvalid_i   (  S_AXI_HP1_wvalid       ), // write valid
  .axi_wready_o   (  S_AXI_HP1_wready       ), // write ready

    // axi write response channel
  .axi_bid_o      (  S_AXI_HP1_bid          ), // write response ID
  .axi_bresp_o    (  S_AXI_HP1_bresp        ), // write response
  .axi_bvalid_o   (  S_AXI_HP1_bvalid       ), // write response valid
  .axi_bready_i   (  S_AXI_HP1_bready       ), // write response ready

    // axi read address channel
  .axi_arid_i     (  S_AXI_HP1_arid         ), // read address ID
  .axi_araddr_i   (  S_AXI_HP1_araddr       ), // read address
  .axi_arlen_i    (  S_AXI_HP1_arlen        ), // read burst length
  .axi_arsize_i   (  S_AXI_HP1_arsize       ), // read burst size
  .axi_arburst_i  (  S_AXI_HP1_arburst      ), // read burst type
  .axi_arlock_i   (  S_AXI_HP1_arlock       ), // read lock type
  .axi_arcache_i  (  S_AXI_HP1_arcache      ), // read cache type
  .axi_arprot_i   (  S_AXI_HP1_arprot       ), // read protection type
  .axi_arvalid_i  (  S_AXI_HP1_arvalid      ), // read address valid
  .axi_arready_o  (  S_AXI_HP1_arready      ), // read address ready
    
    // axi read data channel
  .axi_rid_o      (  S_AXI_HP1_rid          ), // read response ID
  .axi_rdata_o    (  S_AXI_HP1_rdata        ), // read data
  .axi_rresp_o    (  S_AXI_HP1_rresp        ), // read response
  .axi_rlast_o    (  S_AXI_HP1_rlast        ), // read last
  .axi_rvalid_o   (  S_AXI_HP1_rvalid       ), // read response valid
  .axi_rready_i   (  S_AXI_HP1_rready       )  // read response ready
);
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// AXI2 slave model
axi_slave_model
#(
  .AXI_DW  (HP2_DW) , // data width (8,16,...,1024)
  .AXI_AW  (HP2_AW) , // address width ()
  .AXI_ID  (  2   ) , // master ID
  .AXI_IW  (HP2_IW)   // master ID width   
)
i_s_axi_hp2
(
  // global signals
  .axi_clk_i      (  S_AXI_HP2_aclk  ), // global clock
  .axi_rstn_i     (  axi_rst     ), // global reset.NOTE:Model simulation only, Wait to latest rstn.
                
    // axi write address channel
  .axi_awid_i     (  S_AXI_HP2_awid         ), // write address ID
  .axi_awaddr_i   (  S_AXI_HP2_awaddr       ), // write address
  .axi_awlen_i    (  S_AXI_HP2_awlen        ), // write burst length
  .axi_awsize_i   (  S_AXI_HP2_awsize       ), // write burst size
  .axi_awburst_i  (  S_AXI_HP2_awburst      ), // write burst type
  .axi_awlock_i   (  S_AXI_HP2_awlock       ), // write lock type
  .axi_awcache_i  (  S_AXI_HP2_awcache      ), // write cache type
  .axi_awprot_i   (  S_AXI_HP2_awprot       ), // write protection type
  .axi_awvalid_i  (  S_AXI_HP2_awvalid      ), // write address valid
  .axi_awready_o  (  S_AXI_HP2_awready      ), // write ready

    // axi write data channel
  .axi_wid_i      (  S_AXI_HP2_wid          ), // write data ID
  .axi_wdata_i    (  S_AXI_HP2_wdata        ), // write data
  .axi_wstrb_i    (  S_AXI_HP2_wstrb        ), // write strobes
  .axi_wlast_i    (  S_AXI_HP2_wlast        ), // write last
  .axi_wvalid_i   (  S_AXI_HP2_wvalid       ), // write valid
  .axi_wready_o   (  S_AXI_HP2_wready       ), // write ready

    // axi write response channel
  .axi_bid_o      (  S_AXI_HP2_bid          ), // write response ID
  .axi_bresp_o    (  S_AXI_HP2_bresp        ), // write response
  .axi_bvalid_o   (  S_AXI_HP2_bvalid       ), // write response valid
  .axi_bready_i   (  S_AXI_HP2_bready       ), // write response ready

    // axi read address channel
  .axi_arid_i     (  S_AXI_HP2_arid         ), // read address ID
  .axi_araddr_i   (  S_AXI_HP2_araddr       ), // read address
  .axi_arlen_i    (  S_AXI_HP2_arlen        ), // read burst length
  .axi_arsize_i   (  S_AXI_HP2_arsize       ), // read burst size
  .axi_arburst_i  (  S_AXI_HP2_arburst      ), // read burst type
  .axi_arlock_i   (  S_AXI_HP2_arlock       ), // read lock type
  .axi_arcache_i  (  S_AXI_HP2_arcache      ), // read cache type
  .axi_arprot_i   (  S_AXI_HP2_arprot       ), // read protection type
  .axi_arvalid_i  (  S_AXI_HP2_arvalid      ), // read address valid
  .axi_arready_o  (  S_AXI_HP2_arready      ), // read address ready
    
    // axi read data channel
  .axi_rid_o      (  S_AXI_HP2_rid          ), // read response ID
  .axi_rdata_o    (  S_AXI_HP2_rdata        ), // read data
  .axi_rresp_o    (  S_AXI_HP2_rresp        ), // read response
  .axi_rlast_o    (  S_AXI_HP2_rlast        ), // read last
  .axi_rvalid_o   (  S_AXI_HP2_rvalid       ), // read response valid
  .axi_rready_i   (  S_AXI_HP2_rready       )  // read response ready
);
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// AXI3 slave model
axi_slave_model
#(
  .AXI_DW  (HP3_DW) , // data width (8,16,...,1024)
  .AXI_AW  (HP3_AW) , // address width ()
  .AXI_ID  (   3  ) , // master ID
  .AXI_IW  (HP3_IW)   // master ID width   
)
i_s_axi_hp3
(
  // global signals
  .axi_clk_i      (  S_AXI_HP3_aclk  ), // global clock
  .axi_rstn_i     (  axi_rst     ), // global reset.NOTE:Model simulation only, Wait to latest rstn.
                
    // axi write address channel
  .axi_awid_i     (  S_AXI_HP3_awid         ), // write address ID
  .axi_awaddr_i   (  S_AXI_HP3_awaddr       ), // write address
  .axi_awlen_i    (  S_AXI_HP3_awlen        ), // write burst length
  .axi_awsize_i   (  S_AXI_HP3_awsize       ), // write burst size
  .axi_awburst_i  (  S_AXI_HP3_awburst      ), // write burst type
  .axi_awlock_i   (  S_AXI_HP3_awlock       ), // write lock type
  .axi_awcache_i  (  S_AXI_HP3_awcache      ), // write cache type
  .axi_awprot_i   (  S_AXI_HP3_awprot       ), // write protection type
  .axi_awvalid_i  (  S_AXI_HP3_awvalid      ), // write address valid
  .axi_awready_o  (  S_AXI_HP3_awready      ), // write ready

    // axi write data channel
  .axi_wid_i      (  S_AXI_HP3_wid          ), // write data ID
  .axi_wdata_i    (  S_AXI_HP3_wdata        ), // write data
  .axi_wstrb_i    (  S_AXI_HP3_wstrb        ), // write strobes
  .axi_wlast_i    (  S_AXI_HP3_wlast        ), // write last
  .axi_wvalid_i   (  S_AXI_HP3_wvalid       ), // write valid
  .axi_wready_o   (  S_AXI_HP3_wready       ), // write ready

    // axi write response channel
  .axi_bid_o      (  S_AXI_HP3_bid          ), // write response ID
  .axi_bresp_o    (  S_AXI_HP3_bresp        ), // write response
  .axi_bvalid_o   (  S_AXI_HP3_bvalid       ), // write response valid
  .axi_bready_i   (  S_AXI_HP3_bready       ), // write response ready

    // axi read address channel
  .axi_arid_i     (  S_AXI_HP3_arid         ), // read address ID
  .axi_araddr_i   (  S_AXI_HP3_araddr       ), // read address
  .axi_arlen_i    (  S_AXI_HP3_arlen        ), // read burst length
  .axi_arsize_i   (  S_AXI_HP3_arsize       ), // read burst size
  .axi_arburst_i  (  S_AXI_HP3_arburst      ), // read burst type
  .axi_arlock_i   (  S_AXI_HP3_arlock       ), // read lock type
  .axi_arcache_i  (  S_AXI_HP3_arcache      ), // read cache type
  .axi_arprot_i   (  S_AXI_HP3_arprot       ), // read protection type
  .axi_arvalid_i  (  S_AXI_HP3_arvalid      ), // read address valid
  .axi_arready_o  (  S_AXI_HP3_arready      ), // read address ready
    
    // axi read data channel
  .axi_rid_o      (  S_AXI_HP3_rid          ), // read response ID
  .axi_rdata_o    (  S_AXI_HP3_rdata        ), // read data
  .axi_rresp_o    (  S_AXI_HP3_rresp        ), // read response
  .axi_rlast_o    (  S_AXI_HP3_rlast        ), // read last
  .axi_rvalid_o   (  S_AXI_HP3_rvalid       ), // read response valid
  .axi_rready_i   (  S_AXI_HP3_rready       )  // read response ready
);
//------------------------------------------------------------------------------
`endif
endmodule 
