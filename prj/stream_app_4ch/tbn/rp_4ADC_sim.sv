//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
//Date        : Thu Oct 17 12:18:07 2019
//Host        : Jon-PC running 64-bit major release  (build 9200)
//Command     : generate_target system_wrapper.bd
//Design      : system_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module rp_4ADC_sim
   (DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,

    M_AXI_OSC0_araddr,
    M_AXI_OSC0_arburst,
    M_AXI_OSC0_arcache,
    M_AXI_OSC0_arid,
    M_AXI_OSC0_arlen,
    M_AXI_OSC0_arlock,
    M_AXI_OSC0_arprot,
    M_AXI_OSC0_arqos,
    M_AXI_OSC0_arready,
    M_AXI_OSC0_arsize,
    M_AXI_OSC0_arvalid,
    M_AXI_OSC0_awaddr,
    M_AXI_OSC0_awburst,
    M_AXI_OSC0_awcache,
    M_AXI_OSC0_awid,
    M_AXI_OSC0_awlen,
    M_AXI_OSC0_awlock,
    M_AXI_OSC0_awprot,
    M_AXI_OSC0_awqos,
    M_AXI_OSC0_awready,
    M_AXI_OSC0_awsize,
    M_AXI_OSC0_awvalid,
    M_AXI_OSC0_bid,
    M_AXI_OSC0_bready,
    M_AXI_OSC0_bresp,
    M_AXI_OSC0_bvalid,
    M_AXI_OSC0_rdata,
    M_AXI_OSC0_rid,
    M_AXI_OSC0_rlast,
    M_AXI_OSC0_rready,
    M_AXI_OSC0_rresp,
    M_AXI_OSC0_rvalid,
    M_AXI_OSC0_wdata,
    M_AXI_OSC0_wid,
    M_AXI_OSC0_wlast,
    M_AXI_OSC0_wready,
    M_AXI_OSC0_wstrb,
    M_AXI_OSC0_wvalid,

    M_AXI_OSC1_araddr,
    M_AXI_OSC1_arburst,
    M_AXI_OSC1_arcache,
    M_AXI_OSC1_arid,
    M_AXI_OSC1_arlen,
    M_AXI_OSC1_arlock,
    M_AXI_OSC1_arprot,
    M_AXI_OSC1_arqos,
    M_AXI_OSC1_arready,
    M_AXI_OSC1_arsize,
    M_AXI_OSC1_arvalid,
    M_AXI_OSC1_awaddr,
    M_AXI_OSC1_awburst,
    M_AXI_OSC1_awcache,
    M_AXI_OSC1_awid,
    M_AXI_OSC1_awlen,
    M_AXI_OSC1_awlock,
    M_AXI_OSC1_awprot,
    M_AXI_OSC1_awqos,
    M_AXI_OSC1_awready,
    M_AXI_OSC1_awsize,
    M_AXI_OSC1_awvalid,
    M_AXI_OSC1_bid,
    M_AXI_OSC1_bready,
    M_AXI_OSC1_bresp,
    M_AXI_OSC1_bvalid,
    M_AXI_OSC1_rdata,
    M_AXI_OSC1_rid,
    M_AXI_OSC1_rlast,
    M_AXI_OSC1_rready,
    M_AXI_OSC1_rresp,
    M_AXI_OSC1_rvalid,
    M_AXI_OSC1_wdata,
    M_AXI_OSC1_wid,
    M_AXI_OSC1_wlast,
    M_AXI_OSC1_wready,
    M_AXI_OSC1_wstrb,
    M_AXI_OSC1_wvalid,

    S_AXI_REG_araddr,
    S_AXI_REG_arburst,
    S_AXI_REG_arcache,
    S_AXI_REG_arid,
    S_AXI_REG_arlen,
    S_AXI_REG_arlock,
    S_AXI_REG_arprot,
    S_AXI_REG_arqos,
    S_AXI_REG_arready,
    S_AXI_REG_arsize,
    S_AXI_REG_arvalid,
    S_AXI_REG_awaddr,
    S_AXI_REG_awburst,
    S_AXI_REG_awcache,
    S_AXI_REG_awid,
    S_AXI_REG_awlen,
    S_AXI_REG_awlock,
    S_AXI_REG_awprot,
    S_AXI_REG_awqos,
    S_AXI_REG_awready,
    S_AXI_REG_awsize,
    S_AXI_REG_awvalid,
    S_AXI_REG_bid,
    S_AXI_REG_bready,
    S_AXI_REG_bresp,
    S_AXI_REG_bvalid,
    S_AXI_REG_rdata,
    S_AXI_REG_rid,
    S_AXI_REG_rlast,
    S_AXI_REG_rready,
    S_AXI_REG_rresp,
    S_AXI_REG_rvalid,
    S_AXI_REG_wdata,
    S_AXI_REG_wid,
    S_AXI_REG_wlast,
    S_AXI_REG_wready,
    S_AXI_REG_wstrb,
    S_AXI_REG_wvalid,

    clkout_625,
    clk_out125_0,
    clk_out125_1,

    rstn_out_0,
    rstn_out_1,

    rst_in,

    daisy_p_o,
    daisy_n_o,
    daisy_p_i,
    daisy_n_i,

    gpio_p_o,
    gpio_n_o,
    gpio_p_i,
    gpio_n_i,

    adc_clk_i,
    adc_clk_o,
    //adc_clk_p,
    adc_dat_i,
    adc_data_ch1,
    adc_data_ch2,
    adc_data_ch3,
    adc_data_ch4);

  inout [14:0]DDR_addr;
  inout [2:0]DDR_ba;
  inout DDR_cas_n;
  inout DDR_ck_n;
  inout DDR_ck_p;
  inout DDR_cke;
  inout DDR_cs_n;
  inout [3:0]DDR_dm;
  inout [31:0]DDR_dq;
  inout [3:0]DDR_dqs_n;
  inout [3:0]DDR_dqs_p;
  inout DDR_odt;
  inout DDR_ras_n;
  inout DDR_reset_n;
  inout DDR_we_n;
  inout FIXED_IO_ddr_vrn;
  inout FIXED_IO_ddr_vrp;
  inout [53:0]FIXED_IO_mio;
  inout FIXED_IO_ps_clk;
  inout FIXED_IO_ps_porb;
  inout FIXED_IO_ps_srstb;

  output [31:0]M_AXI_OSC0_araddr;
  output [1:0]M_AXI_OSC0_arburst;
  output [3:0]M_AXI_OSC0_arcache;
  output [4:0]M_AXI_OSC0_arid;
  output [3:0]M_AXI_OSC0_arlen;
  output [1:0]M_AXI_OSC0_arlock;
  output [2:0]M_AXI_OSC0_arprot;
  output [3:0]M_AXI_OSC0_arqos;
  input M_AXI_OSC0_arready;
  output [2:0]M_AXI_OSC0_arsize;
  output M_AXI_OSC0_arvalid;
  output [31:0]M_AXI_OSC0_awaddr;
  output [1:0]M_AXI_OSC0_awburst;
  output [3:0]M_AXI_OSC0_awcache;
  output [0:0]M_AXI_OSC0_awid;
  output [3:0]M_AXI_OSC0_awlen;
  output [1:0]M_AXI_OSC0_awlock;
  output [2:0]M_AXI_OSC0_awprot;
  output [3:0]M_AXI_OSC0_awqos;
  input M_AXI_OSC0_awready;
  output [2:0]M_AXI_OSC0_awsize;
  output M_AXI_OSC0_awvalid;
  input [0:0]M_AXI_OSC0_bid;
  output M_AXI_OSC0_bready;
  input [1:0]M_AXI_OSC0_bresp;
  input M_AXI_OSC0_bvalid;
  input [63:0]M_AXI_OSC0_rdata;
  input [4:0]M_AXI_OSC0_rid;
  input M_AXI_OSC0_rlast;
  output M_AXI_OSC0_rready;
  input [1:0]M_AXI_OSC0_rresp;
  input M_AXI_OSC0_rvalid;
  output [31:0]M_AXI_OSC0_wdata;
  output [0:0]M_AXI_OSC0_wid;
  output M_AXI_OSC0_wlast;
  input M_AXI_OSC0_wready;
  output [7:0]M_AXI_OSC0_wstrb;
  output M_AXI_OSC0_wvalid;

  output [31:0]M_AXI_OSC1_araddr;
  output [1:0]M_AXI_OSC1_arburst;
  output [3:0]M_AXI_OSC1_arcache;
  output [4:0]M_AXI_OSC1_arid;
  output [3:0]M_AXI_OSC1_arlen;
  output [1:0]M_AXI_OSC1_arlock;
  output [2:0]M_AXI_OSC1_arprot;
  output [3:0]M_AXI_OSC1_arqos;
  input M_AXI_OSC1_arready;
  output [2:0]M_AXI_OSC1_arsize;
  output M_AXI_OSC1_arvalid;
  output [31:0]M_AXI_OSC1_awaddr;
  output [1:0]M_AXI_OSC1_awburst;
  output [3:0]M_AXI_OSC1_awcache;
  output [0:0]M_AXI_OSC1_awid;
  output [3:0]M_AXI_OSC1_awlen;
  output [1:0]M_AXI_OSC1_awlock;
  output [2:0]M_AXI_OSC1_awprot;
  output [3:0]M_AXI_OSC1_awqos;
  input M_AXI_OSC1_awready;
  output [2:0]M_AXI_OSC1_awsize;
  output M_AXI_OSC1_awvalid;
  input [0:0]M_AXI_OSC1_bid;
  output M_AXI_OSC1_bready;
  input [1:0]M_AXI_OSC1_bresp;
  input M_AXI_OSC1_bvalid;
  input [63:0]M_AXI_OSC1_rdata;
  input [4:0]M_AXI_OSC1_rid;
  input M_AXI_OSC1_rlast;
  output M_AXI_OSC1_rready;
  input [1:0]M_AXI_OSC1_rresp;
  input M_AXI_OSC1_rvalid;
  output [31:0]M_AXI_OSC1_wdata;
  output [0:0]M_AXI_OSC1_wid;
  output M_AXI_OSC1_wlast;
  input M_AXI_OSC1_wready;
  output [7:0]M_AXI_OSC1_wstrb;
  output M_AXI_OSC1_wvalid;

  input [31:0]S_AXI_REG_araddr;
  input [1:0]S_AXI_REG_arburst;
  input [3:0]S_AXI_REG_arcache;
  input [11:0]S_AXI_REG_arid;
  input [3:0]S_AXI_REG_arlen;
  input [1:0]S_AXI_REG_arlock;
  input [2:0]S_AXI_REG_arprot;
  input [3:0]S_AXI_REG_arqos;
  output S_AXI_REG_arready;
  input [2:0]S_AXI_REG_arsize;
  input S_AXI_REG_arvalid;
  input [31:0]S_AXI_REG_awaddr;
  input [1:0]S_AXI_REG_awburst;
  input [3:0]S_AXI_REG_awcache;
  input [11:0]S_AXI_REG_awid;
  input [3:0]S_AXI_REG_awlen;
  input [1:0]S_AXI_REG_awlock;
  input [2:0]S_AXI_REG_awprot;
  input [3:0]S_AXI_REG_awqos;
  output S_AXI_REG_awready;
  input [2:0]S_AXI_REG_awsize;
  input S_AXI_REG_awvalid;
  output [11:0]S_AXI_REG_bid;
  input S_AXI_REG_bready;
  output [1:0]S_AXI_REG_bresp;
  output S_AXI_REG_bvalid;
  output [31:0]S_AXI_REG_rdata;
  output [11:0]S_AXI_REG_rid;
  output S_AXI_REG_rlast;
  input S_AXI_REG_rready;
  output [1:0]S_AXI_REG_rresp;
  output S_AXI_REG_rvalid;
  input [31:0]S_AXI_REG_wdata;
  input [11:0]S_AXI_REG_wid;
  input S_AXI_REG_wlast;
  output S_AXI_REG_wready;
  input [3:0]S_AXI_REG_wstrb;
  input S_AXI_REG_wvalid;

  output clkout_625;
  output clk_out125_0;
  output clk_out125_1;
  // SATA connector
  output [ 2-1:0] daisy_p_o  ;  // line 1 is clock capable
  output [ 2-1:0] daisy_n_o  ;
  input  [ 2-1:0] daisy_p_i  ;  // line 1 is clock capable
  input  [ 2-1:0] daisy_n_i  ;

  output [ 8-1:0] gpio_p_o  ;
  output [ 8-1:0] gpio_n_o  ;
  input  [ 8-1:0] gpio_p_i  ;
  input  [ 8-1:0] gpio_n_i  ;

  output rstn_out_0;
  output rstn_out_1;

  input  rst_in;

  input  [ 2-1:0] [ 2-1:0] adc_clk_i;
  input  [ 4-1:0] [ 7-1:0] adc_dat_i;

  output [ 2-1:0] adc_clk_o;
  //input adc_clk_p;
  input [15:0]adc_data_ch1;
  input [15:0]adc_data_ch2;
  input [15:0]adc_data_ch3;
  input [15:0]adc_data_ch4;

  wire [14:0]DDR_addr;
  wire [2:0]DDR_ba;
  wire DDR_cas_n;
  wire DDR_ck_n;
  wire DDR_ck_p;
  wire DDR_cke;
  wire DDR_cs_n;
  wire [3:0]DDR_dm;
  wire [31:0]DDR_dq;
  wire [3:0]DDR_dqs_n;
  wire [3:0]DDR_dqs_p;
  wire DDR_odt;
  wire DDR_ras_n;
  wire DDR_reset_n;
  wire DDR_we_n;
  wire FIXED_IO_ddr_vrn;
  wire FIXED_IO_ddr_vrp;
  wire [53:0]FIXED_IO_mio;
  wire FIXED_IO_ps_clk;
  wire FIXED_IO_ps_porb;
  wire FIXED_IO_ps_srstb;

  wire [31:0]M_AXI_OSC0_araddr;
  wire [1:0]M_AXI_OSC0_arburst;
  wire [3:0]M_AXI_OSC0_arcache;
  wire [4:0]M_AXI_OSC0_arid;
  wire [3:0]M_AXI_OSC0_arlen;
  wire [1:0]M_AXI_OSC0_arlock;
  wire [2:0]M_AXI_OSC0_arprot;
  wire [3:0]M_AXI_OSC0_arqos;
  wire M_AXI_OSC0_arready;
  wire [2:0]M_AXI_OSC0_arsize;
  wire M_AXI_OSC0_arvalid;
  wire [31:0]M_AXI_OSC0_awaddr;
  wire [1:0]M_AXI_OSC0_awburst;
  wire [3:0]M_AXI_OSC0_awcache;
  wire [0:0]M_AXI_OSC0_awid;
  wire [3:0]M_AXI_OSC0_awlen;
  wire [1:0]M_AXI_OSC0_awlock;
  wire [2:0]M_AXI_OSC0_awprot;
  wire [3:0]M_AXI_OSC0_awqos;
  wire M_AXI_OSC0_awready;
  wire [2:0]M_AXI_OSC0_awsize;
  wire M_AXI_OSC0_awvalid;
  wire [0:0]M_AXI_OSC0_bid;
  wire M_AXI_OSC0_bready;
  wire [1:0]M_AXI_OSC0_bresp;
  wire M_AXI_OSC0_bvalid;
  wire [63:0]M_AXI_OSC0_rdata;
  wire [4:0]M_AXI_OSC0_rid;
  wire M_AXI_OSC0_rlast;
  wire M_AXI_OSC0_rready;
  wire [1:0]M_AXI_OSC0_rresp;
  wire M_AXI_OSC0_rvalid;
  wire [63:0]M_AXI_OSC0_wdata;
  wire [0:0]M_AXI_OSC0_wid;
  wire M_AXI_OSC0_wlast;
  wire M_AXI_OSC0_wready;
  wire [7:0]M_AXI_OSC0_wstrb;
  wire M_AXI_OSC0_wvalid;

  wire [31:0]M_AXI_OSC1_araddr;
  wire [1:0]M_AXI_OSC1_arburst;
  wire [3:0]M_AXI_OSC1_arcache;
  wire [4:0]M_AXI_OSC1_arid;
  wire [3:0]M_AXI_OSC1_arlen;
  wire [1:0]M_AXI_OSC1_arlock;
  wire [2:0]M_AXI_OSC1_arprot;
  wire [3:0]M_AXI_OSC1_arqos;
  wire M_AXI_OSC1_arready;
  wire [2:0]M_AXI_OSC1_arsize;
  wire M_AXI_OSC1_arvalid;
  wire [31:0]M_AXI_OSC1_awaddr;
  wire [1:0]M_AXI_OSC1_awburst;
  wire [3:0]M_AXI_OSC1_awcache;
  wire [0:0]M_AXI_OSC1_bid;
  wire M_AXI_OSC1_bready;
  wire [1:0]M_AXI_OSC1_bresp;
  wire M_AXI_OSC1_bvalid;
  wire [63:0]M_AXI_OSC1_rdata;
  wire [4:0]M_AXI_OSC1_rid;
  wire M_AXI_OSC1_rlast;
  wire M_AXI_OSC1_rready;
  wire [1:0]M_AXI_OSC1_rresp;
  wire M_AXI_OSC1_rvalid;
  wire [63:0]M_AXI_OSC1_wdata;
  wire [0:0]M_AXI_OSC1_wid;
  wire M_AXI_OSC1_wlast;
  wire M_AXI_OSC1_wready;
  wire [7:0]M_AXI_OSC1_wstrb;
  wire M_AXI_OSC1_wvalid;

  wire [31:0]S_AXI_REG_araddr;
  wire [1:0]S_AXI_REG_arburst;
  wire [3:0]S_AXI_REG_arcache;
  wire [11:0]S_AXI_REG_arid;
  wire [3:0]S_AXI_REG_arlen;
  wire [1:0]S_AXI_REG_arlock;
  wire [2:0]S_AXI_REG_arprot;
  wire [3:0]S_AXI_REG_arqos;
  wire S_AXI_REG_arready;
  wire [2:0]S_AXI_REG_arsize;
  wire S_AXI_REG_arvalid;
  wire [31:0]S_AXI_REG_awaddr;
  wire [1:0]S_AXI_REG_awburst;
  wire [3:0]S_AXI_REG_awcache;
  wire [11:0]S_AXI_REG_awid;
  wire [3:0]S_AXI_REG_awlen;
  wire [1:0]S_AXI_REG_awlock;
  wire [2:0]S_AXI_REG_awprot;
  wire [3:0]S_AXI_REG_awqos;
  wire S_AXI_REG_awready;
  wire [2:0]S_AXI_REG_awsize;
  wire S_AXI_REG_awvalid;
  wire [11:0]S_AXI_REG_bid;
  wire S_AXI_REG_bready;
  wire [1:0]S_AXI_REG_bresp;
  wire S_AXI_REG_bvalid;
  wire [31:0]S_AXI_REG_rdata;
  wire [11:0]S_AXI_REG_rid;
  wire S_AXI_REG_rlast;
  wire S_AXI_REG_rready;
  wire [1:0]S_AXI_REG_rresp;
  wire S_AXI_REG_rvalid;
  wire [31:0]S_AXI_REG_wdata;
  wire [11:0]S_AXI_REG_wid;
  wire S_AXI_REG_wlast;
  wire S_AXI_REG_wready;
  wire [3:0]S_AXI_REG_wstrb;
  wire S_AXI_REG_wvalid;

  wire [ 8-1:0] gpio_p_o  ;
  wire [ 8-1:0] gpio_n_o  ;
  wire  [ 8-1:0] gpio_p_i  ;
  wire  [ 8-1:0] gpio_n_i  ;

  wire clkout_625;
  wire clk_out125_0;
  wire clk_out125_1;
  wire rstn_out_0;
  wire rstn_out_1;
  wire rstn_saxi;
  wire [ 4-1:0] [ 7-1:0] adc_dat_i;
  wire rst_in;

// PLL signals
logic [  2-1: 0]      adc_clk_in;
logic                 trig_out;

logic                 rstn_125_0, rstn_125_1;
logic [  2-1: 0]      pll_locked;
logic                 adc_10mhz;
logic                 spi_done; // ADC setup finished
wire external_trig;
wire trig_ext;

// fast serial signals
logic                 ser_clk ;
// PWM clock and reset
logic                 pwm_clk ;
logic                 pwm_rstn;

logic                 clksel;
logic [4-1:0] fclk ;
logic [4-1:0] frstn;
assign frstn = {4{rstn_out_0}};

//logic [4-1:0] fclk_clk ;
//logic [4-1:0] fclk_rstn;
//SPI CS
logic                 spi_cs;
assign spi_csa_o    = spi_cs; // only writes, no reads
assign spi_csb_o    = spi_cs;

// ADC clock/reset
//logic       clk_125_0 , clk_125_1 ;
//logic       adc_rstn_01, adc_rstn_23;

// stream bus type
localparam type SBA_T = logic signed [14-1:0];
localparam MNA = 4;
localparam DWE = 8;
localparam IDW = 12;
localparam AW  = 32;

SBA_T [MNA-1:0]          adc_dat, adc_dat_r;

// configuration
logic                    digital_loop;

  wire  [ 2-1:0] [ 2-1:0] adc_clk_i;
  wire  [ 2-1:0] adc_clk_o;
  //wire adc_clk_p;
  wire [15:0]adc_data_ch1;
  wire [15:0]adc_data_ch2;
  wire [15:0]adc_data_ch3;
  wire [15:0]adc_data_ch4;

////////////////////////////////////////////////////////////////////////////////
// PLL (clock and reset)
////////////////////////////////////////////////////////////////////////////////


// system bus
//sys_bus_if   ps_sys      (.clk (clk_125_0), .rstn (rstn_125_0));
//sys_bus_if   sys [8-1:0] (.clk (clk_125_0), .rstn (rstn_125_0));
//sys_bus_if   sys_adc_23  (.clk (clk_125_1), .rstn (rstn_125_1));
////////////////////////////////////////////////////////////////////////////////
// PLL (clock and reset)
////////////////////////////////////////////////////////////////////////////////

// diferential clock input
IBUFDS i_clk_01 (.I (adc_clk_i[0][1]), .IB (adc_clk_i[0][0]), .O (adc_clk_in[0]));  // differential clock input
IBUFDS i_clk_23 (.I (adc_clk_i[1][1]), .IB (adc_clk_i[1][0]), .O (adc_clk_in[1]));  // differential clock input

red_pitaya_pll_4adc pll_01 (
  // inputs
  .clk         (adc_clk_in[0]),  // clock
  .rstn        (spi_done  ),  // reset - active low
  // output clocks
  .clk_10mhz   (pll_adc_10mhz ),  // ADC divided to 10MHz
  .clk_ser     (pll_ser_clk   ),  // fast serial clock
  .clk_pdm     (pll_pwm_clk   ),  // PWM clock
  // status outputs
  .pll_locked  (pll_locked[0])
);
BUFG bufg_adc_10MHz  (.O (adc_10mhz ), .I (pll_adc_10mhz ));

/*
red_pitaya_pll_4adc pll_23 (
  // inputs
  .clk         (adc_clk_in[1]),  // clock
  .rstn        (spi_done  ),  // reset - active low
  // output clocks
  .clk_adc     (pll_adc_clk[1]),  // ADC clock
  // status outputs
  .pll_locked  (pll_locked[1])
);


BUFG bufg_clk_125_0 (.O (clk_125_0), .I (pll_adc_clk[0]));
BUFG bufg_clk_125_1 (.O (clk_125_1), .I (pll_adc_clk[1]));
BUFG bufg_ser_clk    (.O (ser_clk   ), .I (pll_ser_clk   ));
BUFG bufg_pwm_clk    (.O (pwm_clk   ), .I (pll_pwm_clk   ));
*/
logic [32-1:0] locked_pll_cnt, locked_pll_cnt_r, locked_pll_cnt_r2 ;
always @(posedge fclk[0]) begin
  if (~frstn[0])
    locked_pll_cnt <= 'h0;
  else if (~pll_locked)
    locked_pll_cnt <= locked_pll_cnt + 'h1;
end

always @(posedge clk_out125_0) begin
  locked_pll_cnt_r  <= locked_pll_cnt;
  locked_pll_cnt_r2 <= locked_pll_cnt_r;
end

wire [2-1:0] adc_clks;
assign adc_clks={clk_out125_1, clk_out125_0};
/*
// ADC reset (active low)
always @(posedge clk_125_0)
adc_rstn_01 <=  frstn[0] & spi_done & pll_locked[0];

always @(posedge clk_125_1)
adc_rstn_23 <=  frstn[0] & spi_done & pll_locked[1];
*/
// PWM reset (active low)
//always @(posedge pwm_clk)
//pwm_rstn <=  frstn[0] & spi_done & pll_locked[0];

axi4_if #(.DW (32), .AW (AW), .IW (IDW), .LW (4)) axi_gp (.ACLK (fclk[2]), .ARESETn (rstn_saxi));
sys_bus_if   ps_sys      (.clk (fclk[2]), .rstn (rstn_saxi));

axi4_slave #(
  .DW (32),
  .AW (AW),
  .IW (IDW)
) axi_slave_gp0 (
  // AXI bus
  .axi       (axi_gp),
  // system read/write channel
  .bus       (ps_sys)
);

reg [32-1:0] led_cnt;
reg          clk_rec_blnk='h0;

always @(posedge clk_out125_0) //shows FPGA is loaded and has a clock
begin
  if (~rstn_out_0) begin
    led_cnt <= 32'h0;
    clk_rec_blnk <= 'h0;
  end else begin 
    if (led_cnt < 32'd62500000)
      led_cnt <= led_cnt + 'h1;
    else begin
      led_cnt <= 32'h0;
      clk_rec_blnk <= ~clk_rec_blnk;
    end
  end
end

reg [32-1:0] led_cnt2;
reg          clk_rec_blnk2='h0;
always @(posedge clk_out125_0) //shows FPGA is loaded and has a clock
begin
  if (~rstn_125_0) begin
    led_cnt2 <= 32'h0;
    clk_rec_blnk2 <= 'h0;
  end else begin 
    if (led_cnt2 < 32'd62500000)
      led_cnt2 <= led_cnt2 + 'h1;
    else begin
      led_cnt2 <= 32'h0;
      clk_rec_blnk2 <= ~clk_rec_blnk2;
    end
  end
end

reg [32-1:0] val_cnt;
always @(posedge fclk[2]) //shows FPGA is loaded and has a clock
begin
  if (~frstn[2]) begin
    val_cnt <= 32'h0;
  end else begin 
    if (axi_gp.RVALID) begin
      val_cnt <= val_cnt + 'h1;
    end
  end
end

assign led_o = {5'h0,clk_rec_blnk2,~rstn_125_0,clk_rec_blnk};
wire adc_clk_out = clk_out125_0;

reg [10-1:0] daisy_cnt      =  'h0;
reg          daisy_slave    = 1'b0;

always @(posedge clk_out125_0) begin // if there is a clock present on the daisy chain connector, the board will be treated as a slave
  if (~rstn_125_0) begin
    daisy_cnt     <= 'h0;
    daisy_slave <= 1'b0;
  end else begin 
    daisy_cnt <= daisy_cnt + 'h1;
    if (&daisy_cnt)
      daisy_slave <= 1'b1;
  end
end

assign clkout_625=fclk[2];
////////////////////////////////////////////////////////////////////////////////
// ADC IO
////////////////////////////////////////////////////////////////////////////////

// DDR inputs
// falling edge: odd bits    rising edge: even bits   
// 0: CH1 falling edge data  1: CH1 rising edge data
// 2: CH2 falling edge data  3: CH2 rising edge data
// 4: CH3 falling edge data  5: CH3 rising edge data
// 6: CH4 falling edge data  7: CH4 rising edge data

// delay input ADC signals
logic [4*7-1:0] idly_rst ;
logic [4*7-1:0] idly_ce  ;
logic [4*7-1:0] idly_inc ;
logic [4*7-1:0] [5-1:0] idly_cnt ;
logic [4-1:0] [14-1:0] adc_dat_raw;
logic [4-1:0] [7-1:0] adc_dat_dly_diag;

//(* IODELAY_GROUP = "adc_inputs" *) // Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
IDELAYCTRL i_idelayctrl (
  .RDY(idly_rdy),   // 1-bit output: Ready output
  .REFCLK(fclk[3]), // 1-bit input: Reference clock input
  .RST(!frstn[3])   // 1-bit input: Active high reset input
);

genvar GV;
genvar GVC;
genvar GVD;

generate
for (GVC = 0; GVC < 4; GVC = GVC + 1) begin : channels
  for (GV = 0; GV < 7; GV = GV + 1) begin : adc_decode
    logic          adc_dat_idly;
    logic [ 2-1:0] adc_dat_ddr;

assign adc_dat_dly_diag[GVC][GV]=adc_dat_idly;

   //(* IODELAY_GROUP = "adc_inputs" *)
   IDELAYE2 #(
      .DELAY_SRC("IDATAIN"),           // Delay input (IDATAIN, DATAIN)
      .HIGH_PERFORMANCE_MODE("TRUE"),  // Reduced jitter ("TRUE"), Reduced power ("FALSE")
      .IDELAY_TYPE("VARIABLE"),        // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
      .IDELAY_VALUE(4),                // Input delay tap setting (0-31)
      .PIPE_SEL("FALSE"),              // Select pipelined mode, FALSE, TRUE
      .REFCLK_FREQUENCY(200.0),        // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
      .SIGNAL_PATTERN("DATA")          // DATA, CLOCK input signal
   )
   i_dly (
      .CNTVALUEOUT  ( idly_cnt[GV+GVC*7]    ),  // 5-bit output: Counter value output
      .DATAOUT      ( adc_dat_idly          ),  // 1-bit output: Delayed data output
      .C            ( adc_clk_in[GVC/2]     ),  // 1-bit input: Clock input
      .CE           ( idly_ce[GV+GVC*7]     ),  // 1-bit input: Active high enable increment/decrement input
      .CINVCTRL     ( 1'b0                  ),  // 1-bit input: Dynamic clock inversion input
      .CNTVALUEIN   ( 5'h0                  ),  // 5-bit input: Counter value input
      .DATAIN       ( 1'b0                  ),  // 1-bit input: Internal delay data input
      .IDATAIN      ( adc_dat_i[GVC][GV]    ),  // 1-bit input: Data input from the I/O
      .INC          ( idly_inc[GV+GVC*7]    ),  // 1-bit input: Increment / Decrement tap delay input
      .LD           ( idly_rst[GV+GVC*7]    ),  // 1-bit input: Load IDELAY_VALUE input
      .LDPIPEEN     ( 1'b0                  ),  // 1-bit input: Enable PIPELINE register to load data input
      .REGRST       ( 1'b0                  )   // 1-bit input: Active-high reset tap-delay input
   );
  
    IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) iddr_adc_dat_0 (.D(adc_dat_idly), .Q1({adc_dat_ddr[1]}), .Q2({adc_dat_ddr[0]}), .C(adc_clks[GVC/2]), .CE(1'b1), .R(1'b0), .S(1'b0));
    assign adc_dat_raw[GVC][2*GV  ] = adc_dat_ddr[0];
    assign adc_dat_raw[GVC][2*GV+1] = adc_dat_ddr[1];
  end 
end
endgenerate

always @(posedge clk_out125_0) begin
  adc_dat_r[0] <= {adc_dat_raw[0][14-1], ~adc_dat_raw[0][14-2:0]};
  adc_dat_r[1] <= {adc_dat_raw[1][14-1], ~adc_dat_raw[1][14-2:0]};

  adc_dat  [0] <= adc_dat_r[0];
  adc_dat  [1] <= adc_dat_r[1];
end

always @(posedge clk_out125_0) begin

  adc_dat_r[2] <= {adc_dat_raw[2][14-1], ~adc_dat_raw[2][14-2:0]};
  adc_dat_r[3] <= {adc_dat_raw[3][14-1], ~adc_dat_raw[3][14-2:0]};

  adc_dat  [2] <= adc_dat_r[2];
  adc_dat  [3] <= adc_dat_r[3];
end

////////////////////////////////////////////////////////////////////////////////
//  House Keeping
////////////////////////////////////////////////////////////////////////////////

logic [DWE-1: 0] exp_p_in , exp_n_in ;
logic [DWE-1: 0] exp_p_out, exp_n_out;
logic [DWE-1: 0] exp_p_dir, exp_n_dir;

red_pitaya_hk_4adc #(.DWE(DWE)) i_hk (
  // system signals
  .clk_i           (fclk[2] ),  // clock
  .rstn_i          (rstn_saxi),  // reset - active low
  .fclk_i          (fclk[0] ),  // clock
  .frstn_i         (frstn[0]),  // reset - active low
  .spi_done_o      (spi_done),  // PLL reset
  // LED
  //.led_o           (led_o       ),  // LED output
  // idelay control
  .idly_rst_o      (idly_rst    ),
  .idly_ce_o       (idly_ce     ),
  .idly_inc_o      (idly_inc    ),
  .idly_cnt_i      ({idly_cnt[21],idly_cnt[14],idly_cnt[7],idly_cnt[0]}),

  .spi_cs_o        (spi_cs     ),
  .spi_clk_o       (spi_clk_o  ),
  .spi_mosi_o      (spi_mosi_o ),

  // global configuration
  .digital_loop    (digital_loop),
  .pll_sys_i       (adc_10mhz   ),    // system clock
  .pll_ref_i       (adc_10mhz   ),    // reference clock
  .pll_hi_o        (pll_hi_o    ),    // PLL high
  .pll_lo_o        (pll_lo_o    ),    // PLL low
  .diag_i          (locked_pll_cnt_r2),

  // Expansion connector
  .exp_p_dat_i     (exp_p_in ),  // input data
  .exp_p_dat_o     (exp_p_out),  // output data
  .exp_p_dir_o     (exp_p_dir),  // 1-output enable
  .exp_n_dat_i     (exp_n_in ),
  .exp_n_dat_o     (exp_n_out),
  .exp_n_dir_o     (exp_n_dir),
   // System bus
  .sys_addr        (ps_sys.addr ),
  .sys_wdata       (ps_sys.wdata),
  .sys_wen         (ps_sys.wen  ),
  .sys_ren         (ps_sys.ren  ),
  .sys_rdata       (ps_sys.rdata),
  .sys_err         (ps_sys.err  ),
  .sys_ack         (ps_sys.ack  )
);


  system_wrapper system_wrapper_i
       (
        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        // FCLKs
        .FCLK_CLK0         (fclk[0]      ),
        .FCLK_CLK1         (fclk[1]      ),
        .FCLK_CLK2         (fclk[2]      ),
        .FCLK_CLK3         (fclk[3]      ),
        /*.FCLK_RESET0_N     (frstn[0]     ),
        .FCLK_RESET1_N     (frstn[1]     ),
        .FCLK_RESET2_N     (frstn[2]     ),
        .FCLK_RESET3_N     (frstn[3]     ),*/

        .M_AXI_OSC0_awaddr(M_AXI_OSC0_awaddr),
        .M_AXI_OSC0_awburst(M_AXI_OSC0_awburst),
        .M_AXI_OSC0_awcache(M_AXI_OSC0_awcache),
        .M_AXI_OSC0_awid(M_AXI_OSC0_awid),
        .M_AXI_OSC0_awlen(M_AXI_OSC0_awlen),
        .M_AXI_OSC0_awlock(M_AXI_OSC0_awlock),
        .M_AXI_OSC0_awprot(M_AXI_OSC0_awprot),
        .M_AXI_OSC0_awqos(M_AXI_OSC0_awqos),
        .M_AXI_OSC0_awready(M_AXI_OSC0_awready),
        .M_AXI_OSC0_awsize(M_AXI_OSC0_awsize),
        .M_AXI_OSC0_awvalid(M_AXI_OSC0_awvalid),
        .M_AXI_OSC0_bid(M_AXI_OSC0_bid),
        .M_AXI_OSC0_bready(M_AXI_OSC0_bready),
        .M_AXI_OSC0_bresp(M_AXI_OSC0_bresp),
        .M_AXI_OSC0_bvalid(M_AXI_OSC0_bvalid), 

        .M_AXI_OSC0_wdata(M_AXI_OSC0_wdata),
        .M_AXI_OSC0_wid(M_AXI_OSC0_wid),
        .M_AXI_OSC0_wlast(M_AXI_OSC0_wlast),
        .M_AXI_OSC0_wready(M_AXI_OSC0_wready),
        .M_AXI_OSC0_wstrb(M_AXI_OSC0_wstrb),
        .M_AXI_OSC0_wvalid(M_AXI_OSC0_wvalid),

        .M_AXI_OSC1_awaddr(M_AXI_OSC1_awaddr),
        .M_AXI_OSC1_awburst(M_AXI_OSC1_awburst),
        .M_AXI_OSC1_awcache(M_AXI_OSC1_awcache),
        .M_AXI_OSC1_awid(M_AXI_OSC1_awid),
        .M_AXI_OSC1_awlen(M_AXI_OSC1_awlen),
        .M_AXI_OSC1_awlock(M_AXI_OSC1_awlock),
        .M_AXI_OSC1_awprot(M_AXI_OSC1_awprot),
        .M_AXI_OSC1_awqos(M_AXI_OSC1_awqos),
        .M_AXI_OSC1_awready(M_AXI_OSC1_awready),
        .M_AXI_OSC1_awsize(M_AXI_OSC1_awsize),
        .M_AXI_OSC1_awvalid(M_AXI_OSC1_awvalid),
        .M_AXI_OSC1_bid(M_AXI_OSC1_bid),
        .M_AXI_OSC1_bready(M_AXI_OSC1_bready),
        .M_AXI_OSC1_bresp(M_AXI_OSC1_bresp),
        .M_AXI_OSC1_bvalid(M_AXI_OSC1_bvalid), 

        .M_AXI_OSC1_wdata(M_AXI_OSC1_wdata),
        .M_AXI_OSC1_wid(M_AXI_OSC1_wid),
        .M_AXI_OSC1_wlast(M_AXI_OSC1_wlast),
        .M_AXI_OSC1_wready(M_AXI_OSC1_wready),
        .M_AXI_OSC1_wstrb(M_AXI_OSC1_wstrb),
        .M_AXI_OSC1_wvalid(M_AXI_OSC1_wvalid),

        .S_AXI_REG_araddr(S_AXI_REG_araddr),
        .S_AXI_REG_arburst(S_AXI_REG_arburst),
        .S_AXI_REG_arcache(S_AXI_REG_arcache),
        .S_AXI_REG_arid(S_AXI_REG_arid),
        .S_AXI_REG_arlen(S_AXI_REG_arlen),
        .S_AXI_REG_arlock(S_AXI_REG_arlock),
        .S_AXI_REG_arprot(S_AXI_REG_arprot),
        .S_AXI_REG_arqos(S_AXI_REG_arqos),
        .S_AXI_REG_arready(S_AXI_REG_arready),
        .S_AXI_REG_arsize(S_AXI_REG_arsize),
        .S_AXI_REG_arvalid(S_AXI_REG_arvalid),
        .S_AXI_REG_awaddr(S_AXI_REG_awaddr),
        .S_AXI_REG_awburst(S_AXI_REG_awburst),
        .S_AXI_REG_awcache(S_AXI_REG_awcache),
        .S_AXI_REG_awid(S_AXI_REG_awid),
        .S_AXI_REG_awlen(S_AXI_REG_awlen),
        .S_AXI_REG_awlock(S_AXI_REG_awlock),
        .S_AXI_REG_awprot(S_AXI_REG_awprot),
        .S_AXI_REG_awqos(S_AXI_REG_awqos),
        .S_AXI_REG_awready(S_AXI_REG_awready),
        .S_AXI_REG_awsize(S_AXI_REG_awsize),
        .S_AXI_REG_awvalid(S_AXI_REG_awvalid),
        .S_AXI_REG_bid(S_AXI_REG_bid),
        .S_AXI_REG_bready(S_AXI_REG_bready),
        .S_AXI_REG_bresp(S_AXI_REG_bresp),
        .S_AXI_REG_bvalid(S_AXI_REG_bvalid),
        .S_AXI_REG_rdata(S_AXI_REG_rdata),
        .S_AXI_REG_rid(S_AXI_REG_rid),
        .S_AXI_REG_rlast(S_AXI_REG_rlast),
        .S_AXI_REG_rready(S_AXI_REG_rready),
        .S_AXI_REG_rresp(S_AXI_REG_rresp),
        .S_AXI_REG_rvalid(S_AXI_REG_rvalid),
        .S_AXI_REG_wdata(S_AXI_REG_wdata),
        .S_AXI_REG_wid(S_AXI_REG_wid),
        .S_AXI_REG_wlast(S_AXI_REG_wlast),
        .S_AXI_REG_wready(S_AXI_REG_wready),
        .S_AXI_REG_wstrb(S_AXI_REG_wstrb),
        .S_AXI_REG_wvalid(S_AXI_REG_wvalid),

     //   .HK_AXI_ACLK    (axi_gp.ACLK   ),
      //  .HK_AXI_ARESETn (axi_gp.ARESETn),
        .HK_AXI_arvalid (axi_gp.ARVALID),
        .HK_AXI_awvalid (axi_gp.AWVALID),
        .HK_AXI_bready  (axi_gp.BREADY ),
        .HK_AXI_rready  (axi_gp.RREADY ),
        .HK_AXI_wlast   (axi_gp.WLAST  ),
        .HK_AXI_wvalid  (axi_gp.WVALID ),
        .HK_AXI_arid    (axi_gp.ARID   ),
        .HK_AXI_awid    (axi_gp.AWID   ),
        .HK_AXI_wid     (axi_gp.WID    ),
        .HK_AXI_arburst (axi_gp.ARBURST),
        .HK_AXI_arlock  (axi_gp.ARLOCK ),
        .HK_AXI_arsize  (axi_gp.ARSIZE ),
        .HK_AXI_awburst (axi_gp.AWBURST),
        .HK_AXI_awlock  (axi_gp.AWLOCK ),
        .HK_AXI_awsize  (axi_gp.AWSIZE ),
        .HK_AXI_arprot  (axi_gp.ARPROT ),
        .HK_AXI_awprot  (axi_gp.AWPROT ),
        .HK_AXI_araddr  (axi_gp.ARADDR ),
        .HK_AXI_awaddr  (axi_gp.AWADDR ),
        .HK_AXI_wdata   (axi_gp.WDATA  ),
        .HK_AXI_arcache (axi_gp.ARCACHE),
        .HK_AXI_arlen   (axi_gp.ARLEN  ),
        .HK_AXI_arqos   (axi_gp.ARQOS  ),
        .HK_AXI_awcache (axi_gp.AWCACHE),
        .HK_AXI_awlen   (axi_gp.AWLEN  ),
        .HK_AXI_awqos   (axi_gp.AWQOS  ),
        .HK_AXI_wstrb   (axi_gp.WSTRB  ),
        .HK_AXI_arready (axi_gp.ARREADY),
        .HK_AXI_awready (axi_gp.AWREADY),
        .HK_AXI_bvalid  (axi_gp.BVALID ),
        .HK_AXI_rlast   (axi_gp.RLAST  ),
        .HK_AXI_rvalid  (axi_gp.RVALID ),
        .HK_AXI_wready  (axi_gp.WREADY ),
        .HK_AXI_bid     (axi_gp.BID    ),
        .HK_AXI_rid     (axi_gp.RID    ),
        .HK_AXI_bresp   (axi_gp.BRESP  ),
        .HK_AXI_rresp   (axi_gp.RRESP  ),
        .HK_AXI_rdata   (axi_gp.RDATA  ),

        .trig_in        (external_trig),
        .trig_out       (trig_out),
        .gpio_trig      (gpio_trig),
        .adc_clk0       (adc_clk_in[0]),
        .adc_clk1       (adc_clk_in[1]),     
        .clk_out125_0   (clk_out125_0),
        .clk_out125_1   (clk_out125_1),
        .rstn_out_0     (rstn_out_0),
        .rstn_out_1     (rstn_out_1),
        .rstn_saxi      (rstn_saxi),
        .clksel         (clksel),
        .daisy_slave    (daisy_slave),        
        //.gpio_p         (exp_p_io),
        //.gpio_n         (exp_n_io),
        .rst_in(rst_in),     
        .adc_data_ch1   (adc_dat[0]),
        .adc_data_ch2   (adc_dat[1]),
        .adc_data_ch3   (adc_dat[2]),
        .adc_data_ch4   (adc_dat[3]));
/*
OBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18"), .SLEW ("FAST")) i_OBUF_trig
(
  .O  ( daisy_p_o[0]  ),
  .OB ( daisy_n_o[0]  ),
  .I  ( trig_out      )
);

OBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18"), .SLEW ("FAST")) i_OBUF_clk
(
  .O  ( daisy_p_o[1]  ),
  .OB ( daisy_n_o[1]  ),
  .I  ( adc_clk_in[0] )
);

IBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18")) i_IBUF_clkdaisy
(
  .I  ( daisy_p_i[1]  ),
  .IB ( daisy_n_i[1]  ),
  .O  ( adc_clk_daisy )
);

IBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18")) i_IBUFDS_trig
(
  .I  ( daisy_p_i[0]  ),
  .IB ( daisy_n_i[0]  ),
  .O  ( trig_ext      )
);
*/

OBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18"), .SLEW ("FAST")) i_OBUF_trig
(
  .O  ( daisy_p_o[0]  ),
  .OB ( daisy_n_o[0]  ),
  .I  ( 1'b0          )
);

OBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18"), .SLEW ("FAST")) i_OBUF_clk
(
  .O  ( daisy_p_o[1]  ),
  .OB ( daisy_n_o[1]  ),
  .I  ( 1'b0          )
);

assign external_trig = trig_ext | gpio_trig;

endmodule