////////////////////////////////////////////////////////////////////////////////
// Module: Red Pitaya top FPGA module
// Author: Iztok Jeras
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module top_tb_4ADC #(
  // time period
  realtime  TP = 8.0ns,  // 250MHz
  realtime  AXIP = 5.0ns,  // 200MHz
  realtime  RP = 100.1ns,  // ~10MHz
  // DUT configuration
  int unsigned RSZ = 14  // RAM size is 2**RSZ
);

////////////////////////////////////////////////////////////////////////////////
// IO port signals
////////////////////////////////////////////////////////////////////////////////

// PS connections
wire  [54-1:0] FIXED_IO_mio     ;
wire           FIXED_IO_ps_clk  ;
wire           FIXED_IO_ps_porb ;
wire           FIXED_IO_ps_srstb;
wire           FIXED_IO_ddr_vrn ;
wire           FIXED_IO_ddr_vrp ;
// DDR
wire  [15-1:0] DDR_addr   ;
wire  [ 3-1:0] DDR_ba     ;
wire           DDR_cas_n  ;
wire           DDR_ck_n   ;
wire           DDR_ck_p   ;
wire           DDR_cke    ;
wire           DDR_cs_n   ;
wire  [ 4-1:0] DDR_dm     ;
wire  [32-1:0] DDR_dq     ;
wire  [ 4-1:0] DDR_dqs_n  ;
wire  [ 4-1:0] DDR_dqs_p  ;
wire           DDR_odt    ;
wire           DDR_ras_n  ;
wire           DDR_reset_n;
wire           DDR_we_n   ;

// ADC
logic [2-1:0] [ 7-1:0] adc_dat;
logic         [ 2-1:0] adc_dco;

// XADC
logic         [ 5-1:0] vinp;        // voltages p
logic         [ 5-1:0] vinn;        // voltages n
// Expansion connector
wire          [ 9-1:0] exp_p_io;
wire          [ 9-1:0] exp_n_io;
wire                   exp_9_io;
// Expansion output data/enable
logic         [ 9-1:0] exp_p_od, exp_p_oe;
logic         [ 9-1:0] exp_n_od, exp_n_oe;
logic                  exp_9_od, exp_9_oe;
// SATA
logic         [ 4-1:0] daisy_p;
logic         [ 4-1:0] daisy_n;

// LED
wire          [ 8-1:0] led;

logic         [ 2-1:0] temp_prot;
logic                  pll_lo;
logic                  pll_hi;
logic                  pll_ref;
logic                  trig;

logic                  intr;

logic               clk0, clk1, clk_250 ;
logic               axi_clk ;

logic               clkn;
wire                rstn_out0;
wire                rstn_out1;
logic               rstn;

//glbl glbl();

localparam OSC_DW = 64;
localparam REG_DW = 32;
localparam OSC_AW = 32;
localparam REG_AW = 32;
localparam REG_IW = 12;
localparam IW = 4;
localparam LW = 8;

localparam GEN1_EVENT = 0;
localparam GEN2_EVENT = 1;
localparam OSC1_EVENT = 2;
localparam OSC2_EVENT = 3;
localparam LA_EVENT = 4;

localparam OSC1_INTR = 15;
localparam GEN_INTR  = 14;
localparam GPIO_INTR = 13;
localparam OSC2_INTR = 12;



localparam GPIO_IN_CTRL_ADDR  = 'h8C;
localparam GPIO_OUT_CTRL_ADDR = 'h90;

wire interf_clk, interf_rst;

wire clkout_125_0, clkout_125_1, clkout_625;

wire          [ 8-1:0] gpio_p_i;
wire          [ 8-1:0] gpio_n_i;

wire          [ 8-1:0] dirp;
wire          [ 8-1:0] dirn;

reg          [ 8-1:0] gpio_p_o;
reg          [ 8-1:0] gpio_n_o;

reg          [10-1:0] gpio_cnt;

//assign gpio_p_o = 8'h01;
//assign gpio_n_o = 8'hFE;
//--------------------------------------------------------------------------------------------
localparam MASTER = 0;
localparam SLAVE  = 1;
wire mode = MASTER;
//`define DAC

assign interf_clk=clkout_125_0;
assign interf_rst=rstn_out0;
//--------------------------------------------------------------------------------------------


always @(posedge clk0) begin
  if (~rstn) begin
    gpio_cnt <= 'h0;
    gpio_p_o <= 'h0;
    gpio_n_o <= 'h0;
  end else begin
    if (gpio_cnt >= 10'd100) begin
      gpio_cnt <= 'h0;
      gpio_p_o <= gpio_p_o + 1;
      gpio_n_o <= gpio_n_o - 1;      
    end else
      gpio_cnt <= gpio_cnt + 1;
  end
end
wire [31:0] read_dat1={8'd100, gpio_p_o,   8'd100, gpio_n_o  };
wire [31:0] read_dat2={8'd100, gpio_p_o+1, 8'd100, gpio_n_o-1};
wire [63:0] read_dat ={read_dat1, read_dat2};


/*axi4_if #(.DW (REG_DW), .AW (REG_AW), .IW (IW), .LW (LW)) axi_reg (
  .ACLK    (clk   ),  .ARESETn (rstn)
);

axi4_if #(.DW (OSC_DW), .AW (OSC_AW), .IW (IW), .LW (LW)) axi_osc1 (
  .ACLK    (clk   ),  .ARESETn (rstn)
);*/

axi4_if #(.DW (REG_DW), .AW (REG_AW), .IW (REG_IW), .LW (LW)) axi_reg (
  .ACLK    (clkout_625   ),  .ARESETn (rstn_out0)
);


axi4_if #(.DW (REG_DW), .AW (REG_AW), .IW (REG_IW), .LW (LW)) axi_syncd (
  .ACLK    (clkout_625   ),  .ARESETn (rstn_out0)
);

axi4_if #(.DW (OSC_DW), .AW (OSC_AW), .IW (IW), .LW (LW)) axi_osc0 (
  .ACLK    (interf_clk   ),  .ARESETn (interf_rst)
);

axi4_if #(.DW (OSC_DW), .AW (OSC_AW), .IW (IW), .LW (LW)) axi_osc1 (
  .ACLK    (interf_clk   ),  .ARESETn (interf_rst)
);

/*axi4_if #(.DW (OSC_DW), .AW (OSC_AW), .IW (IW), .LW (LW)) axi_osc2 (
  .ACLK    (clk   ),  .ARESETn (rstn)
);*/



axi_bus_model #(.AW (REG_AW), .DW (REG_DW), .IW (REG_IW), .LW (LW)) axi_bm_reg  (axi_reg );
/*
axi_slave_model #(.AXI_AW (OSC_AW), .AXI_DW (OSC_DW), .AXI_IW (IW), .AXI_ID(0)) 
axi_bm_reg (
   // global signals
  .axi_clk_i      (clkout_625), // global clock
  .axi_rstn_i     (rstn_out0), // global reset
   // axi write address channel
  .axi_awid_i     (axi_reg.AWID), // write address ID
  .axi_awaddr_i   (axi_reg.AWADDR), // write address
  .axi_awlen_i    (axi_reg.AWLEN), // write burst length
  .axi_awsize_i   (axi_reg.AWSIZE), // write burst size
  .axi_awburst_i  (axi_reg.AWBURST), // write burst type
  .axi_awlock_i   (axi_reg.AWLOCK), // write lock type
  .axi_awcache_i  (axi_reg.AWCACHE), // write cache type
  .axi_awprot_i   (axi_reg.AWPROT), // write protection type
  .axi_awvalid_i  (axi_reg.AWVALID), // write address valid
  .axi_awready_o  (axi_reg.AWREADY), // write ready
   // axi write data channel
  .axi_wid_i      (axi_reg.WID), // write data ID
  .axi_wdata_i    (axi_reg.WDATA), // write data
  .axi_wstrb_i    (axi_reg.WSTRB), // write strobes
  .axi_wlast_i    (axi_reg.WLAST), // write last
  .axi_wvalid_i   (axi_reg.WVALID), // write valid
  .axi_wready_o   (axi_reg.WREADY), // write ready
   // axi write response channel
  .axi_bid_o      (axi_reg.BID), // write response ID
  .axi_bresp_o    (axi_reg.BRESP), // write response
  .axi_bvalid_o   (axi_reg.BVALID), // write response valid
  .axi_bready_i   (axi_reg.BREADY), // write response ready
   // axi read address channel
  .axi_arid_i     (axi_reg.ARID), // read address ID
  .axi_araddr_i   (axi_reg.ARADDR), // read address
  .axi_arlen_i    (axi_reg.ARLEN), // read burst length
  .axi_arsize_i   (axi_reg.ARSIZE), // read burst size
  .axi_arburst_i  (axi_reg.ARBURST), // read burst type
  .axi_arlock_i   (axi_reg.ARLOCK), // read lock type
  .axi_arcache_i  (axi_reg.ARCACHE), // read cache type
  .axi_arprot_i   (axi_reg.ARPROT), // read protection type
  .axi_arvalid_i  (axi_reg.ARVALID), // read address valid
  .axi_arready_o  (axi_reg.ARREADY), // read address ready
   // axi read data channel
  .axi_rid_o      (axi_reg.RID), // read response ID
  .axi_rdata_o    (axi_reg.RDATA), // read data
  .axi_rresp_o    (axi_reg.RRESP), // read response
  .axi_rlast_o    (axi_reg.RLAST), // read last
  .axi_rvalid_o   (axi_reg.RVALID), // read response valid
  .axi_rready_i   (axi_reg.RREADY) // read response ready
);

*/
axi_slave_model #(.AXI_AW (OSC_AW), .AXI_DW (OSC_DW), .AXI_IW (IW), .AXI_ID(0)) 
axi_bm_osc0 (
   // global signals
  .axi_clk_i      (interf_clk), // global clock
  .axi_rstn_i     (interf_rst), // global reset
   // axi write address channel
  .axi_awid_i     (axi_osc0.AWID), // write address ID
  .axi_awaddr_i   (axi_osc0.AWADDR), // write address
  .axi_awlen_i    (axi_osc0.AWLEN), // write burst length
  .axi_awsize_i   (axi_osc0.AWSIZE), // write burst size
  .axi_awburst_i  (axi_osc0.AWBURST), // write burst type
  .axi_awlock_i   (axi_osc0.AWLOCK), // write lock type
  .axi_awcache_i  (axi_osc0.AWCACHE), // write cache type
  .axi_awprot_i   (axi_osc0.AWPROT), // write protection type
  .axi_awvalid_i  (axi_osc0.AWVALID), // write address valid
  .axi_awready_o  (axi_osc0.AWREADY), // write ready
   // axi write data channel
  .axi_wid_i      (axi_osc0.WID), // write data ID
  .axi_wdata_i    (axi_osc0.WDATA), // write data
  .axi_wstrb_i    (axi_osc0.WSTRB), // write strobes
  .axi_wlast_i    (axi_osc0.WLAST), // write last
  .axi_wvalid_i   (axi_osc0.WVALID), // write valid
  .axi_wready_o   (axi_osc0.WREADY), // write ready
   // axi write response channel
  .axi_bid_o      (axi_osc0.BID), // write response ID
  .axi_bresp_o    (axi_osc0.BRESP), // write response
  .axi_bvalid_o   (axi_osc0.BVALID), // write response valid
  .axi_bready_i   (axi_osc0.BREADY), // write response ready
   // axi read address channel
  .axi_arid_i     (axi_osc0.ARID), // read address ID
  .axi_araddr_i   (axi_osc0.ARADDR), // read address
  .axi_arlen_i    (axi_osc0.ARLEN), // read burst length
  .axi_arsize_i   (axi_osc0.ARSIZE), // read burst size
  .axi_arburst_i  (axi_osc0.ARBURST), // read burst type
  .axi_arlock_i   (axi_osc0.ARLOCK), // read lock type
  .axi_arcache_i  (axi_osc0.ARCACHE), // read cache type
  .axi_arprot_i   (axi_osc0.ARPROT), // read protection type
  .axi_arvalid_i  (axi_osc0.ARVALID), // read address valid
  .axi_arready_o  (axi_osc0.ARREADY), // read address ready
   // axi read data channel
  .axi_rid_o      (axi_osc0.RID), // read response ID
  .axi_rdata_o    (axi_osc0.RDATA), // read data
  .axi_rresp_o    (axi_osc0.RRESP), // read response
  .axi_rlast_o    (axi_osc0.RLAST), // read last
  .axi_rvalid_o   (axi_osc0.RVALID), // read response valid
  .axi_rready_i   (axi_osc0.RREADY) // read response ready
);

axi_slave_model #(.AXI_AW (OSC_AW), .AXI_DW (OSC_DW), .AXI_IW (IW), .AXI_ID(0)) 
axi_bm_osc1 (
   // global signals
  .axi_clk_i      (interf_clk), // global clock
  .axi_rstn_i     (interf_rst), // global reset
   // axi write address channel
  .axi_awid_i     (axi_osc1.AWID), // write address ID
  .axi_awaddr_i   (axi_osc1.AWADDR), // write address
  .axi_awlen_i    (axi_osc1.AWLEN), // write burst length
  .axi_awsize_i   (axi_osc1.AWSIZE), // write burst size
  .axi_awburst_i  (axi_osc1.AWBURST), // write burst type
  .axi_awlock_i   (axi_osc1.AWLOCK), // write lock type
  .axi_awcache_i  (axi_osc1.AWCACHE), // write cache type
  .axi_awprot_i   (axi_osc1.AWPROT), // write protection type
  .axi_awvalid_i  (axi_osc1.AWVALID), // write address valid
  .axi_awready_o  (axi_osc1.AWREADY), // write ready
   // axi write data channel
  .axi_wid_i      (axi_osc1.WID), // write data ID
  .axi_wdata_i    (axi_osc1.WDATA), // write data
  .axi_wstrb_i    (axi_osc1.WSTRB), // write strobes
  .axi_wlast_i    (axi_osc1.WLAST), // write last
  .axi_wvalid_i   (axi_osc1.WVALID), // write valid
  .axi_wready_o   (axi_osc1.WREADY), // write ready
   // axi write response channel
  .axi_bid_o      (axi_osc1.BID), // write response ID
  .axi_bresp_o    (axi_osc1.BRESP), // write response
  .axi_bvalid_o   (axi_osc1.BVALID), // write response valid
  .axi_bready_i   (axi_osc1.BREADY), // write response ready
   // axi read address channel
  .axi_arid_i     (axi_osc1.ARID), // read address ID
  .axi_araddr_i   (axi_osc1.ARADDR), // read address
  .axi_arlen_i    (axi_osc1.ARLEN), // read burst length
  .axi_arsize_i   (axi_osc1.ARSIZE), // read burst size
  .axi_arburst_i  (axi_osc1.ARBURST), // read burst type
  .axi_arlock_i   (axi_osc1.ARLOCK), // read lock type
  .axi_arcache_i  (axi_osc1.ARCACHE), // read cache type
  .axi_arprot_i   (axi_osc1.ARPROT), // read protection type
  .axi_arvalid_i  (axi_osc1.ARVALID), // read address valid
  .axi_arready_o  (axi_osc1.ARREADY), // read address ready
   // axi read data channel
  .axi_rid_o      (axi_osc1.RID), // read response ID
  .axi_rdata_o    (axi_osc1.RDATA), // read data
  .axi_rresp_o    (axi_osc1.RRESP), // read response
  .axi_rlast_o    (axi_osc1.RLAST), // read last
  .axi_rvalid_o   (axi_osc1.RVALID), // read response valid
  .axi_rready_i   (axi_osc1.RREADY) // read response ready
);
/*
axi4_sync sync (
.axi_i(axi_reg),
.axi_o(axi_syncd)
);*/

////////////////////////////////////////////////////////////////////////////////
// Clock and reset generation
////////////////////////////////////////////////////////////////////////////////
default clocking cb @ (posedge clk0);
  input  rstn;

endclocking: cb

assign clkn = ~clk0;
// clock
initial begin 
  clk0 = 1'b0;
  ##1;
end
always #(TP/2) clk0 = ~clk0;

initial begin 
  clk1 = 1'b0;
  ##3;
end
always #(TP/2) clk1 = ~clk1;

initial        pll_ref = 1'b0;
always #(RP/2) pll_ref = ~pll_ref;

initial          axi_clk = 1'b0;
always #(AXIP/2) axi_clk = ~axi_clk;

initial        clk_250 = 1'b0;
always #(TP/4) clk_250 = ~clk_250;

// default clocking 

// reset
initial begin
        rstn = 1'b0;
  ##4;  rstn = 1'b1;
end

// clock cycle counter
int unsigned cyc=0;
always_ff @ (posedge clk0)
cyc <= cyc+1;






////////////////////////////////////////////////////////////////////////////////
// initializtion
////////////////////////////////////////////////////////////////////////////////

initial begin
  exp_p_od = '0;
  exp_n_od = '0;
  exp_p_oe = '0;
  exp_n_oe = '0;
end

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

//initial begin
//  ##6000;
//  $display("ERROR: timeout!");
//  $finish();
//end

initial begin
  ##500;

   //top_tc.test_hk                 (0<<20, 32'h55);
   //top_tc.test_sata               (5<<20, 32'h55);
   top_tc_4ADC.test_osc                (32'h40000000, OSC1_EVENT, OSC1_INTR);
  // top_tc_4ADC.test_osc                (32'h40100000, GEN1_EVENT, OSC2_INTR);

  //top_tc_gpio.test_gpio (32'h40100000, GPIO_OUT_CTRL_ADDR, LA_EVENT);

//   top_tc.test_asg                (2<<20, 32'h40090000, 2);


  ##1600000000;
  $finish();
end

reg  [16-1:0] out_dat, out_dat2, out_dat3;
reg  [8-1:0] out_l, out_l2, out_r;

reg seldat;
integer fd;

/*initial begin
   fd = $fopen("RPstreamtest2.bin", "r");
  seldat   = 'h0;

end

always @ (clk) begin
  out_l <= out_l2;
  out_r <= out_l;
  seldat <= ~seldat;

  if (seldat)
    //out_dat <= {out_r[15:8], out_l[15:8]};
    out_dat <= {out_l, out_r};

  if (rstn_out) begin
    if (!$feof(fd)) begin
      $fgets(out_l2 , fd);
    end else
      $fclose(fd);
  end
end
*/
////////////////////////////////////////////////////////////////////////////////
// signal generation
////////////////////////////////////////////////////////////////////////////////

localparam int unsigned DWM = 14;
localparam int unsigned CWM = 14;
localparam int unsigned CWF = 16;

//int buf_len = 2**CWM;
int buf_len = 'hff+1;
real freq  = 10_000; // 10kHz
real phase = 0; // DEG

always begin
  trig <= 1'b0;
  ##100000;
  trig <= 1'b1;
  ##1200;
  trig <= 1'b0;
end


always begin
  temp_prot <= 2'b00;
  ##50000;
  temp_prot <= 2'b10;
  ##1000;
  temp_prot <= 2'b00;
end


//localparam int unsigned SIZ_REF = 64;
//
//bit [16-1:0] dat_ref [SIZ_REF];
//
//initial begin
//  logic signed [16-1:0] dat;
//  for (int unsigned i=0; i<SIZ_REF; i++) begin
//      dat = -SIZ_REF/2+i;
//      dat_ref[i] = {dat[16-1], ~dat[16-2:0]};
//  end
//end

bit [14-1:0] dat_ref [2*15];

initial begin
  for (int unsigned i=0; i<31; i++) begin
    dat_ref [i] = {i, 2'b0};
    dat_ref [16-1-i] = {1'b1, 15'(1<<i)};
    dat_ref [16  +i] = {1'b0, 15'(1<<i)};
  end
end

// ADC
logic [2-1:0] [14-1:0] adc_dr ;
assign adc_dr[0] =  dat_ref[cyc % $size(dat_ref)];
assign adc_dr[1] = ~dat_ref[cyc % $size(dat_ref)];

always @(clk0) begin
  if (clk0==1) begin
    #(0.1);
    adc_dat[0] <= {adc_dr[0][12], adc_dr[0][10], adc_dr[0][8], adc_dr[0][6], adc_dr[0][4], adc_dr[0][2]};
    adc_dat[1] <= {adc_dr[1][12], adc_dr[1][10], adc_dr[1][8], adc_dr[1][6], adc_dr[1][4], adc_dr[1][2]};
  end else begin
    #(0.1);
    adc_dat[0] <= {adc_dr[0][13], adc_dr[0][11], adc_dr[0][9], adc_dr[0][7], adc_dr[0][5], adc_dr[0][3]};
    adc_dat[1] <= {adc_dr[1][13], adc_dr[1][11], adc_dr[1][9], adc_dr[1][7], adc_dr[1][5], adc_dr[1][3]};
  end
end

always @(clk0) begin
  if (clk0==1) begin
    #(0.7);
    adc_dco[1] <= 1;
    adc_dco[0] <= 0;
  end else begin
    #(0.7);
    adc_dco[1] <= 0;
    adc_dco[0] <= 1;
  end
end

// XADC
assign vinp = '0;
assign vinn = '0;

// Expansion connector
//assign exp_p_io = 8'h0;
//assign exp_n_io = 8'h0;

// LED


assign #0.2 daisy_p[3] = daisy_p[1] ;
assign #0.2 daisy_n[3] = daisy_n[1] ;
assign #0.2 daisy_p[2] = daisy_p[0] ;
assign #0.2 daisy_n[2] = daisy_n[0] ;



wire [ 1:0] clko = 2'b01;
wire [15:0] wdat10; 
wire [15:0] wdat20;
wire [15:0] wdat30;
wire [15:0] wdat40;

wire [15:0] wdat50; 
wire [15:0] wdat60;
wire [15:0] wdat70;
wire [15:0] wdat80;
assign wdat10 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc1_wdata[15: 0];
assign wdat20 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc1_wdata[31:16];
assign wdat30 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc1_wdata[47:32];
assign wdat40 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc1_wdata[63:48];

assign wdat50 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc2_wdata[15: 0];
assign wdat60 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc2_wdata[31:16];
assign wdat70 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc2_wdata[47:32];
assign wdat80 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc2_wdata[63:48];

wire [15:0] wdat11; 
wire [15:0] wdat21;
wire [15:0] wdat31;
wire [15:0] wdat41;

wire [15:0] wdat51; 
wire [15:0] wdat61;
wire [15:0] wdat71;
wire [15:0] wdat81;
assign wdat11 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc3_wdata[15: 0];
assign wdat21 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc3_wdata[31:16];
assign wdat31 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc3_wdata[47:32];
assign wdat41 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc3_wdata[63:48];

assign wdat51 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc4_wdata[15: 0];
assign wdat61 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc4_wdata[31:16];
assign wdat71 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc4_wdata[47:32];
assign wdat81 = rp_4ADC_sim.system_wrapper_i.system_i.rp_oscilloscope.m_axi_osc4_wdata[63:48];

reg [15:0] wdat10_r; 
reg [15:0] wdat20_r;
reg [15:0] wdat30_r;
reg [15:0] wdat40_r;

reg [15:0] wdat50_r; 
reg [15:0] wdat60_r;
reg [15:0] wdat70_r;
reg [15:0] wdat80_r;

reg [15:0] wdat11_r; 
reg [15:0] wdat21_r;
reg [15:0] wdat31_r;
reg [15:0] wdat41_r;

reg [15:0] wdat51_r; 
reg [15:0] wdat61_r;
reg [15:0] wdat71_r;
reg [15:0] wdat81_r;

always @(posedge interf_clk) begin
  if (interf_rst==0) begin
    wdat10_r <= 'h0;
    wdat20_r <= 'h0;
    wdat30_r <= 'h0;
    wdat40_r <= 'h0;
    wdat50_r <= 'h0;
    wdat60_r <= 'h0;
    wdat70_r <= 'h0;
    wdat80_r <= 'h0;
    
    wdat11_r <= 'h0;
    wdat21_r <= 'h0;
    wdat31_r <= 'h0;
    wdat41_r <= 'h0;
    wdat51_r <= 'h0;
    wdat61_r <= 'h0;
    wdat71_r <= 'h0;
    wdat81_r <= 'h0;
  end else begin
    if (axi_osc0.WVALID & axi_osc0.WREADY) begin
      wdat10_r <= wdat10;
      wdat20_r <= wdat20;
      wdat30_r <= wdat30;
      wdat40_r <= wdat40;
      wdat50_r <= wdat50;
      wdat60_r <= wdat60;
      wdat70_r <= wdat70;
      wdat80_r <= wdat80;
    end
    if (axi_osc1.WVALID & axi_osc1.WREADY) begin
      wdat11_r <= wdat11;
      wdat21_r <= wdat21;
      wdat31_r <= wdat31;
      wdat41_r <= wdat41;
      wdat51_r <= wdat51;
      wdat61_r <= wdat61;
      wdat71_r <= wdat71;
      wdat81_r <= wdat81;
    end
  end
end

reg signed [13:0] cnter1, cnter2, cnter3, cnter4;

//wire [13:0] cnter1_dat = {1'b0, cnter1};
//wire [13:0] cnter2_dat = {1'b0, cnter2};
//wire [13:0] cnter3_dat = {1'b0, cnter3};
//wire [13:0] cnter4_dat = {1'b0, cnter4};

//wire [13:0] cnter1_dat = {cnter1[13], ~cnter1[12:0]};
//wire [13:0] cnter2_dat = {cnter2[13], ~cnter2[12:0]};
//wire [13:0] cnter3_dat = {cnter3[13], ~cnter3[12:0]};
//wire [13:0] cnter4_dat = {cnter4[13], ~cnter4[12:0]};

wire [13:0] cnter1_diag = {cnter1_dat[13], ~cnter1_dat[12:0]};
wire [13:0] cnter2_diag = {cnter2_dat[13], ~cnter2_dat[12:0]};
wire [13:0] cnter3_diag = {cnter3_dat[13], ~cnter3_dat[12:0]};
wire [13:0] cnter4_diag = {cnter4_dat[13], ~cnter4_dat[12:0]};

wire [6:0] cnter1_o ;
wire [6:0] cnter2_o;
wire [6:0] cnter3_o;
wire [6:0] cnter4_o;

reg  [6:0] cnter1_h, cnter1_l;
reg  [6:0] cnter2_h, cnter2_l;
reg  [6:0] cnter3_h, cnter3_l;
reg  [6:0] cnter4_h, cnter4_l;

reg [13:0] cnter1_dat;
reg [13:0] cnter2_dat;
reg [13:0] cnter3_dat;
reg [13:0] cnter4_dat;

always @(posedge clk0) begin
  cnter1_dat <= {cnter1[13], ~cnter1[12:0]};
  cnter2_dat <= {cnter2[13], ~cnter2[12:0]};
end

always @(posedge clk1) begin
  cnter3_dat <= {cnter3[13], ~cnter3[12:0]};
  cnter4_dat <= {cnter4[13], ~cnter4[12:0]};
end

genvar GV;
generate
for (GV = 0; GV < 7; GV = GV + 1) begin : adc_encode
  assign cnter1_o[GV] = clk0 ? cnter1_dat[2*GV] : cnter1_dat[2*GV+1]; 
  assign cnter2_o[GV] = clk0 ? cnter2_dat[2*GV] : cnter2_dat[2*GV+1]; 
  assign cnter3_o[GV] = clk1 ? cnter3_dat[2*GV] : cnter3_dat[2*GV+1]; 
  assign cnter4_o[GV] = clk1 ? cnter4_dat[2*GV] : cnter4_dat[2*GV+1]; 
  //assign cnter2_o[GV] = clk  ? cnter2_dat[2*GV] : cnter2_dat[2*GV+1]; 
  //assign cnter3_o[GV] = clk1 ? cnter3_dat[2*GV] : cnter3_dat[2*GV+1]; 
  //assign cnter4_o[GV] = clk1 ? cnter4_dat[2*GV] : cnter4_dat[2*GV+1]; 
  always @(*) begin
    if (clk0) begin
      cnter1_h[GV] <= cnter1_dat[2*GV];
      cnter2_h[GV] <= cnter2_dat[2*GV];
      cnter3_h[GV] <= cnter3_dat[2*GV];
      cnter4_h[GV] <= cnter4_dat[2*GV];
    end
    if (~clk0) begin
      cnter1_l[GV] <= cnter1_dat[2*GV+1];
      cnter2_l[GV] <= cnter2_dat[2*GV+1];
      cnter3_l[GV] <= cnter3_dat[2*GV+1];
      cnter4_l[GV] <= cnter4_dat[2*GV+1];
    end
  end
end 
endgenerate
always @(clk0) begin

    if (rstn==0)
        cnter1 <= -1000;
    else if (cnter1>=1000 && clk0==1)
        cnter1 <= -1000;
    else if (clk0 == 1)
        cnter1 <= cnter1 + 1; 


    if (rstn==0)
        cnter2 <= -500;
    else if (cnter2>=1000 && clk0==1)
        cnter2 <= -1000;
    else if (clk0 == 1)
        cnter2 <= cnter2 + 1; 
end

always @(clk1) begin
    if (rstn==0)
        cnter3 <= 1000;
    else if (cnter3>=1000 && clk1==1)
        cnter3 <= -1000;
    else if (clk1 == 1)
        cnter3 <= cnter3 + 1; 


    if (rstn==0)
        cnter4 <= 500;
    else if (cnter4>=1000 && clk1==1)
        cnter4 <= -1000;
    else if (clk1 == 1)
        cnter4 <= cnter4 + 1; 
end

reg [32-1:0] trig_cnt;
reg          daisy_trig;
always @(posedge clk0) begin
  if (rstn==0)
    trig_cnt <= 'h0;
  else
    trig_cnt <= trig_cnt + 'h1; 

  daisy_trig <= &trig_cnt[12-1:0];
end

wire adc_clk, adc_clk1;

wire [ 2-1:0] inclk0 = {~adc_clk,adc_clk};
wire [ 2-1:0] inclk1 = {~adc_clk1,adc_clk1};

wire pll_in_clk = mode == MASTER ? clk0  : clko[0] & ~clko[1];
wire daisy_clk  = mode == MASTER ? 1'b0 : clk_250;

clk_gen #(
  .CLKA_PERIOD  (  8000   ),
  .CLKA_JIT     (  0      ),
  .DEL          (  1     ) // in percent
)
i_clgen_model
(
  .clk_i  ( pll_in_clk ) ,
  .clk_o  ( adc_clk    )
);

clk_gen #(
  .CLKA_PERIOD  (  8000   ),
  .CLKA_JIT     (  0      ),
  .DEL          (  2     ) // in percent
)
i_clgen_model2
(
  .clk_i  ( clk1 ) ,
  .clk_o  ( adc_clk1    )
);


////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// module under test

 rp_4ADC_sim rp_4ADC_sim
       (.DDR_addr(),
        .DDR_ba(),
        .DDR_cas_n(),
        .DDR_ck_n(),
        .DDR_ck_p(),
        .DDR_cke(),
        .DDR_cs_n(),
        .DDR_dm(),
        .DDR_dq(),
        .DDR_dqs_n(),
        .DDR_dqs_p(),
        .DDR_odt(),
        .DDR_ras_n(),
        .DDR_reset_n(),
        .DDR_we_n(),
        .FIXED_IO_ddr_vrn(),
        .FIXED_IO_ddr_vrp(),
        .FIXED_IO_mio(),
        .FIXED_IO_ps_clk(),
        .FIXED_IO_ps_porb(),
        .FIXED_IO_ps_srstb(),

        .M_AXI_OSC0_awaddr(axi_osc0.AWADDR),
        .M_AXI_OSC0_awburst(axi_osc0.AWBURST),
        .M_AXI_OSC0_awcache(axi_osc0.AWCACHE),
        .M_AXI_OSC0_awid(axi_osc0.AWID),
        .M_AXI_OSC0_awlen(axi_osc0.AWLEN),
        .M_AXI_OSC0_awlock(axi_osc0.AWLOCK),
        .M_AXI_OSC0_awprot(axi_osc0.AWPROT),
        .M_AXI_OSC0_awqos(axi_osc0.AWQOS),
        .M_AXI_OSC0_awready(axi_osc0.AWREADY),
        .M_AXI_OSC0_awsize(axi_osc0.AWSIZE),
        .M_AXI_OSC0_awvalid(axi_osc0.AWVALID),
        .M_AXI_OSC0_bid(axi_osc0.BID),
        .M_AXI_OSC0_bready(axi_osc0.BREADY),
        .M_AXI_OSC0_bresp(axi_osc0.BRESP),
        .M_AXI_OSC0_bvalid(axi_osc0.BVALID),

        .M_AXI_OSC0_wdata(axi_osc0.WDATA),
        .M_AXI_OSC0_wid(axi_osc0.WID),
        .M_AXI_OSC0_wlast(axi_osc0.WLAST),
        .M_AXI_OSC0_wready(axi_osc0.WREADY),
        .M_AXI_OSC0_wstrb(axi_osc0.WSTRB),
        .M_AXI_OSC0_wvalid(axi_osc0.WVALID),

        .M_AXI_OSC1_awaddr(axi_osc1.AWADDR),
        .M_AXI_OSC1_awburst(axi_osc1.AWBURST),
        .M_AXI_OSC1_awcache(axi_osc1.AWCACHE),
        .M_AXI_OSC1_awid(axi_osc1.AWID),
        .M_AXI_OSC1_awlen(axi_osc1.AWLEN),
        .M_AXI_OSC1_awlock(axi_osc1.AWLOCK),
        .M_AXI_OSC1_awprot(axi_osc1.AWPROT),
        .M_AXI_OSC1_awqos(axi_osc1.AWQOS),
        .M_AXI_OSC1_awready(axi_osc1.AWREADY),
        .M_AXI_OSC1_awsize(axi_osc1.AWSIZE),
        .M_AXI_OSC1_awvalid(axi_osc1.AWVALID),
        .M_AXI_OSC1_bid(axi_osc1.BID),
        .M_AXI_OSC1_bready(axi_osc1.BREADY),
        .M_AXI_OSC1_bresp(axi_osc1.BRESP),
        .M_AXI_OSC1_bvalid(axi_osc1.BVALID),

        .M_AXI_OSC1_wdata(axi_osc1.WDATA),
        .M_AXI_OSC1_wid(axi_osc1.WID),
        .M_AXI_OSC1_wlast(axi_osc1.WLAST),
        .M_AXI_OSC1_wready(axi_osc1.WREADY),
        .M_AXI_OSC1_wstrb(axi_osc1.WSTRB),
        .M_AXI_OSC1_wvalid(axi_osc1.WVALID),

        .S_AXI_REG_araddr(axi_reg.ARADDR),
        .S_AXI_REG_arburst(axi_reg.ARBURST),
        .S_AXI_REG_arcache(axi_reg.ARCACHE),
        .S_AXI_REG_arid(axi_reg.ARID),
        .S_AXI_REG_arlen(axi_reg.ARLEN),
        .S_AXI_REG_arlock(axi_reg.ARLOCK),
        .S_AXI_REG_arprot(axi_reg.ARPROT),
        .S_AXI_REG_arqos(axi_reg.ARQOS),
        .S_AXI_REG_arready(axi_reg.ARREADY),
        .S_AXI_REG_arsize(axi_reg.ARSIZE),
        .S_AXI_REG_arvalid(axi_reg.ARVALID),
        .S_AXI_REG_awaddr(axi_reg.AWADDR),
        .S_AXI_REG_awburst(axi_reg.AWBURST),
        .S_AXI_REG_awcache(axi_reg.AWCACHE),
        .S_AXI_REG_awid(axi_reg.AWID),
        .S_AXI_REG_awlen(axi_reg.AWLEN),
        .S_AXI_REG_awlock(axi_reg.AWLOCK),
        .S_AXI_REG_awprot(axi_reg.AWPROT),
        .S_AXI_REG_awqos(axi_reg.AWQOS),
        .S_AXI_REG_awready(axi_reg.AWREADY),
        .S_AXI_REG_awsize(axi_reg.AWSIZE),
        .S_AXI_REG_awvalid(axi_reg.AWVALID),
        .S_AXI_REG_bid(axi_reg.BID),
        .S_AXI_REG_bready(axi_reg.BREADY),
        .S_AXI_REG_bresp(axi_reg.BRESP),
        .S_AXI_REG_bvalid(axi_reg.BVALID),
        .S_AXI_REG_rdata(axi_reg.RDATA),
        .S_AXI_REG_rid(axi_reg.RID),
        .S_AXI_REG_rlast(axi_reg.RLAST),
        .S_AXI_REG_rready(axi_reg.RREADY),
        .S_AXI_REG_rresp(axi_reg.RRESP),
        .S_AXI_REG_rvalid(axi_reg.RVALID),
        .S_AXI_REG_wdata(axi_reg.WDATA),
        .S_AXI_REG_wid(axi_reg.WID),
        .S_AXI_REG_wlast(axi_reg.WLAST),
        .S_AXI_REG_wready(axi_reg.WREADY),
        .S_AXI_REG_wstrb(axi_reg.WSTRB),
        .S_AXI_REG_wvalid(axi_reg.WVALID),

        .clkout_625(clkout_625),
        .clk_out125_0(clkout_125_0),
        .clk_out125_1(clkout_125_1),

        .daisy_p_o(),
        .daisy_n_o(),
        .daisy_p_i({ daisy_clk, daisy_trig}),
        .daisy_n_i({~daisy_clk,~daisy_trig}),

        .rstn_out_0(rstn_out0),
        .rstn_out_1(rstn_out1),
        .rst_in(~rstn),
/*
        .gpio_p_o(gpio_p_i),
        .gpio_n_o(gpio_n_i),
        .gpio_p_i(gpio_p_o),
        .gpio_n_i(gpio_n_o),
        .dirp(dirp),
        .dirn(dirn),
*/
        //.adc_clk_i({2{~adc_clk,adc_clk}}),
        //.adc_clk_o(clko),
        //.adc_clk_p(clk),
        //.adc_data_ch1({1'b0,cnter,2'b0}),
        .adc_dat_i({cnter4_o, cnter3_o, cnter2_o, cnter1_o}),
        .adc_clk_i({inclk1, inclk0}));

/*
        .adc_data_ch1({cnter[15],~cnter[14:0]}),
        .adc_data_ch2({cnter[15:1],1'b0}),
        .adc_data_ch3({cnter2[15],~cnter2[14:0]}),
        .adc_data_ch4({cnter2[15:1],1'b0}));


*/
bufif1 bufif_exp_p_io [9-1:0] (exp_p_io, exp_p_od, exp_p_oe);
bufif1 bufif_exp_n_io [9-1:0] (exp_n_io, exp_n_od, exp_n_oe);
bufif1 bufif_exp_9_io         (exp_9_io, exp_9_od, exp_9_oe);
// testcases
top_tc_4ADC top_tc_4ADC();


////////////////////////////////////////////////////////////////////////////////
// waveforms
////////////////////////////////////////////////////////////////////////////////

initial begin
  $dumpfile("top_tb.vcd");
  $dumpvars(0, top_tb_4ADC);
end



endmodule: top_tb_4ADC
