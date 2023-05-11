`timescale 1ns / 1ps

module rp_oscilloscope
  #(parameter S_AXI_REG_ADDR_BITS   = 32,
    parameter M_AXI_OSC1_ADDR_BITS  = 32,
    parameter M_AXI_OSC1_DATA_BITS  = 64,
    parameter M_AXI_OSC2_ADDR_BITS  = 32,
    parameter M_AXI_OSC2_DATA_BITS  = 64,
    parameter M_AXI_OSC3_ADDR_BITS  = 32,
    parameter M_AXI_OSC3_DATA_BITS  = 64,
    parameter M_AXI_OSC4_ADDR_BITS  = 32,
    parameter M_AXI_OSC4_DATA_BITS  = 64,
    parameter ADC_DATA_BITS         = 14,
    parameter ID_WIDTHS              = 4,
    parameter EVENT_SRC_NUM         = 7,
    parameter TRIG_SRC_NUM          = 7,
    parameter NUM_CHANNELS          = 2)(
  input  wire                                   clk,
  input  wire                                   rst_n,
  output wire                                   intr,

  //
  input  wire [ADC_DATA_BITS-1:0]               adc_data_ch1,
  input  wire [ADC_DATA_BITS-1:0]               adc_data_ch2,
  input  wire [ADC_DATA_BITS-1:0]               adc_data_ch3,
  input  wire [ADC_DATA_BITS-1:0]               adc_data_ch4,
  //
  input  wire [EVENT_SRC_NUM-1:0]               event_ip_trig,
  input  wire [EVENT_SRC_NUM-1:0]               event_ip_stop,
  input  wire [EVENT_SRC_NUM-1:0]               event_ip_start,
  input  wire [EVENT_SRC_NUM-1:0]               event_ip_reset,
  input  wire [TRIG_SRC_NUM-1:0]                trig_ip,
  output wire                                   trig_out,
  output wire                                   clksel_o,
  input  wire                                   daisy_slave_i,
  //
  output wire [3:0]                             osc1_event_op,
  output wire [3:0]                             osc2_event_op,
  output wire [3:0]                             osc3_event_op,
  output wire [3:0]                             osc4_event_op,
  //
  output wire                                   osc1_trig_op,
  output wire                                   osc2_trig_op,
  output wire                                   osc3_trig_op,
  output wire                                   osc4_trig_op,
  //
  output wire [7:0]                             loopback_sel,
  //
  input  wire                                   s_axi_reg_aclk,
  input  wire                                   s_axi_reg_aresetn,
  input  wire [S_AXI_REG_ADDR_BITS-1:0]         s_axi_reg_awaddr,
  input  wire [2:0]                             s_axi_reg_awprot,
  input  wire                                   s_axi_reg_awvalid,
  output wire                                   s_axi_reg_awready,
  input  wire [31:0]                            s_axi_reg_wdata,
  input  wire [3:0]                             s_axi_reg_wstrb,
  input  wire                                   s_axi_reg_wvalid,
  output wire                                   s_axi_reg_wready,
  input  wire                                   s_axi_reg_wlast,
  output wire [1:0]                             s_axi_reg_bresp,
  output wire                                   s_axi_reg_bvalid,
  input  wire                                   s_axi_reg_bready,
  input  wire [S_AXI_REG_ADDR_BITS-1:0]         s_axi_reg_araddr,
  input  wire [2:0]                             s_axi_reg_arprot,
  input  wire                                   s_axi_reg_arvalid,
  output wire                                   s_axi_reg_arready,
  output wire [31:0]                            s_axi_reg_rdata,
  output wire [1:0]                             s_axi_reg_rresp,
  output wire                                   s_axi_reg_rvalid,
  input  wire                                   s_axi_reg_rready,
  output wire                                   s_axi_reg_rlast,
  input  wire [ID_WIDTHS-1:0]                   s_axi_reg_awid,
  input  wire [ID_WIDTHS-1:0]                   s_axi_reg_arid,
  input  wire [ID_WIDTHS-1:0]                   s_axi_reg_wid,
  output wire [ID_WIDTHS-1:0]                   s_axi_reg_rid,
  output wire [ID_WIDTHS-1:0]                   s_axi_reg_bid,

  input  wire                                   m_axi_osc1_aclk,
  input  wire                                   m_axi_osc1_aresetn,
  output wire [(M_AXI_OSC1_ADDR_BITS-1):0]      m_axi_osc1_awaddr,
  output wire [7:0]                             m_axi_osc1_awlen,
  output wire [2:0]                             m_axi_osc1_awsize,
  output wire [1:0]                             m_axi_osc1_awburst,
  output wire [2:0]                             m_axi_osc1_awprot,
  output wire [3:0]                             m_axi_osc1_awcache,
  output wire                                   m_axi_osc1_awvalid,
  input  wire                                   m_axi_osc1_awready,
  output wire [M_AXI_OSC1_DATA_BITS-1:0]        m_axi_osc1_wdata,
  output wire [((M_AXI_OSC1_DATA_BITS/8)-1):0]  m_axi_osc1_wstrb,
  output wire                                   m_axi_osc1_wlast,
  output wire                                   m_axi_osc1_wvalid,
  input  wire                                   m_axi_osc1_wready,
  input  wire [1:0]                             m_axi_osc1_bresp,
  input  wire                                   m_axi_osc1_bvalid,
  output wire                                   m_axi_osc1_bready,
  //
  input  wire                                   m_axi_osc2_aclk,
  input  wire                                   m_axi_osc2_aresetn,
  output wire [(M_AXI_OSC2_ADDR_BITS-1):0]      m_axi_osc2_awaddr,
  output wire [7:0]                             m_axi_osc2_awlen,
  output wire [2:0]                             m_axi_osc2_awsize,
  output wire [1:0]                             m_axi_osc2_awburst,
  output wire [2:0]                             m_axi_osc2_awprot,
  output wire [3:0]                             m_axi_osc2_awcache,
  output wire                                   m_axi_osc2_awvalid,
  input  wire                                   m_axi_osc2_awready,
  output wire [M_AXI_OSC2_DATA_BITS-1:0]        m_axi_osc2_wdata,
  output wire [((M_AXI_OSC2_DATA_BITS/8)-1):0]  m_axi_osc2_wstrb,
  output wire                                   m_axi_osc2_wlast,
  output wire                                   m_axi_osc2_wvalid,
  input  wire                                   m_axi_osc2_wready,
  input  wire [1:0]                             m_axi_osc2_bresp,
  input  wire                                   m_axi_osc2_bvalid,
  output wire                                   m_axi_osc2_bready,

  input  wire                                   m_axi_osc3_aclk,
  input  wire                                   m_axi_osc3_aresetn,
  output wire [(M_AXI_OSC3_ADDR_BITS-1):0]      m_axi_osc3_awaddr,
  output wire [7:0]                             m_axi_osc3_awlen,
  output wire [2:0]                             m_axi_osc3_awsize,
  output wire [1:0]                             m_axi_osc3_awburst,
  output wire [2:0]                             m_axi_osc3_awprot,
  output wire [3:0]                             m_axi_osc3_awcache,
  output wire                                   m_axi_osc3_awvalid,
  input  wire                                   m_axi_osc3_awready,
  output wire [M_AXI_OSC3_DATA_BITS-1:0]        m_axi_osc3_wdata,
  output wire [((M_AXI_OSC3_DATA_BITS/8)-1):0]  m_axi_osc3_wstrb,
  output wire                                   m_axi_osc3_wlast,
  output wire                                   m_axi_osc3_wvalid,
  input  wire                                   m_axi_osc3_wready,
  input  wire [1:0]                             m_axi_osc3_bresp,
  input  wire                                   m_axi_osc3_bvalid,
  output wire                                   m_axi_osc3_bready,
  //
  input  wire                                   m_axi_osc4_aclk,
  input  wire                                   m_axi_osc4_aresetn,
  output wire [(M_AXI_OSC4_ADDR_BITS-1):0]      m_axi_osc4_awaddr,
  output wire [7:0]                             m_axi_osc4_awlen,
  output wire [2:0]                             m_axi_osc4_awsize,
  output wire [1:0]                             m_axi_osc4_awburst,
  output wire [2:0]                             m_axi_osc4_awprot,
  output wire [3:0]                             m_axi_osc4_awcache,
  output wire                                   m_axi_osc4_awvalid,
  input  wire                                   m_axi_osc4_awready,
  output wire [M_AXI_OSC4_DATA_BITS-1:0]        m_axi_osc4_wdata,
  output wire [((M_AXI_OSC4_DATA_BITS/8)-1):0]  m_axi_osc4_wstrb,
  output wire                                   m_axi_osc4_wlast,
  output wire                                   m_axi_osc4_wvalid,
  input  wire                                   m_axi_osc4_wready,
  input  wire [1:0]                             m_axi_osc4_bresp,
  input  wire                                   m_axi_osc4_bvalid,
  output wire                                   m_axi_osc4_bready
);

////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////
    
localparam DEC_CNT_BITS     = 17; // Decimator counter bits
localparam DEC_SHIFT_BITS   = 4;  // Decimator shifter bits
localparam TRIG_CNT_BITS    = 32; // Trigger counter bits
localparam S_AXIS_DATA_BITS = 16;
localparam M_AXI_OSC_BYTES  = M_AXI_OSC1_DATA_BITS/8;
////////////////////////////////////////////////////////////
// Signals
////////////////////////////////////////////////////////////
reg  signed [16-1:0]            adc_data_ch1_signed;
reg  signed [16-1:0]            adc_data_ch2_signed;
reg  signed [16-1:0]            adc_data_ch3_signed;
reg  signed [16-1:0]            adc_data_ch4_signed;

wire [NUM_CHANNELS-1:0]         buf_sel;
wire [NUM_CHANNELS-1:0]         dma_intr;                            

wire                            adc_sign_ch1 = adc_data_ch1[ADC_DATA_BITS-1];
wire                            adc_sign_ch2 = adc_data_ch2[ADC_DATA_BITS-1];
wire                            adc_sign_ch3 = adc_data_ch3[ADC_DATA_BITS-1];
wire                            adc_sign_ch4 = adc_data_ch4[ADC_DATA_BITS-1];

always @(posedge clk)
begin
  adc_data_ch1_signed <= {adc_data_ch1[ADC_DATA_BITS-1:0], {(16-ADC_DATA_BITS){adc_sign_ch1}}};  
  adc_data_ch2_signed <= {adc_data_ch2[ADC_DATA_BITS-1:0], {(16-ADC_DATA_BITS){adc_sign_ch2}}}; 
  adc_data_ch3_signed <= {adc_data_ch3[ADC_DATA_BITS-1:0], {(16-ADC_DATA_BITS){adc_sign_ch3}}}; 
  adc_data_ch4_signed <= {adc_data_ch4[ADC_DATA_BITS-1:0], {(16-ADC_DATA_BITS){adc_sign_ch4}}}; 
end

reg rstn_cfg;
always @(posedge clk)
begin
  rstn_cfg <= rst_n;
end

reg rstn_cfgax;
always @(posedge m_axi_osc1_aclk)
begin
  rstn_cfgax <= m_axi_osc1_aresetn;
end

wire [4*16-1:0]                 s_axis_osc_tdata;
assign s_axis_osc_tdata[1*16-1:0*16] = adc_data_ch1_signed;
assign s_axis_osc_tdata[2*16-1:1*16] = adc_data_ch2_signed;
assign s_axis_osc_tdata[3*16-1:2*16] = adc_data_ch3_signed;
assign s_axis_osc_tdata[4*16-1:3*16] = adc_data_ch4_signed;


wire                        dma_mode;

wire [             3-1:0]   cfg_event_sel;
wire [             4-1:0]   cfg_event_op;
wire [TRIG_SRC_NUM-1:0]     cfg_trig_mask;

wire                        ctl_trg;

wire [TRIG_CNT_BITS-1:0]    cfg_trig_pre_samp;

wire [TRIG_CNT_BITS-1:0]    cfg_trig_post_samp;

wire [S_AXIS_DATA_BITS-1:0] cfg_trig_low_level;
wire [S_AXIS_DATA_BITS-1:0] cfg_trig_high_level;
wire                        cfg_trig_edge;  
wire                        trig_mod_op;

wire                        cfg_avg_en; 
wire [  DEC_CNT_BITS-1:0]   cfg_dec_factor;  
wire [DEC_SHIFT_BITS-1:0]   cfg_dec_rshift;  
wire [            32-1:0]   cfg_loopback;

wire                         cfg_filt_bypass;  
wire [31:0]                 cfg_dma_buf_size;
wire [31:0]                 cfg_dma_ctrl;
wire                        cfg_dma_ctrl_we;
wire                        cfg_8bit_dat;
wire [4*32-1:0]             cfg_dma_sts;
wire [ 4*4-1:0]             cfg_event_sts;
wire [4*TRIG_CNT_BITS-1:0]  sts_trig_pre_cnt;
wire [   4-1:0]             sts_trig_pre_overflow;

wire [4*TRIG_CNT_BITS-1:0]  sts_trig_post_cnt;
wire [   4-1:0]             sts_trig_post_overflow;

wire [4*18-1:0]             cfg_filt_coeff_aa; 
wire [4*25-1:0]             cfg_filt_coeff_bb; 
wire [4*25-1:0]             cfg_filt_coeff_kk; 
wire [4*25-1:0]             cfg_filt_coeff_pp; 

wire [4*32-1:0]             cfg_dma_dst_addr1;
wire [4*32-1:0]             cfg_dma_dst_addr2;

wire [4*16-1:0]             cfg_calib_offset;
wire [4*16-1:0]             cfg_calib_gain;

wire [4*32-1:0]             buf1_ms_cnt;
wire [4*32-1:0]             buf2_ms_cnt;
wire [4*32-1:0]             curr_wp;

wire [ 4*4-1:0]             osc_event_op;
wire [NUM_CHANNELS-1:0]     osc_trig_op;
wire [NUM_CHANNELS-1:0]     ser_trig;

wire [4*32-1:0]             diag1;
wire [4*32-1:0]             diag2;
wire [4*32-1:0]             diag3;
wire [4*32-1:0]             diag4;

wire [4-1:0]                ramp_en;
wire [4-1:0]                loopback_gpio;
wire [4-1:0]                loopback_dac;

assign osc1_event_op = cfg_event_op;
assign osc2_event_op = cfg_event_op;
assign osc3_event_op = cfg_event_op;
assign osc4_event_op = cfg_event_op;

assign osc1_trig_op  = osc_trig_op[0];
assign osc2_trig_op  = osc_trig_op[1];
assign osc3_trig_op  = osc_trig_op[2];
assign osc4_trig_op  = osc_trig_op[3];

assign ramp_en       = {cfg_loopback[20],cfg_loopback[16],cfg_loopback[12],cfg_loopback[8]};
assign loopback_gpio = {2'h0,cfg_loopback[4],cfg_loopback[0]};
assign loopback_dac  = {2'h0,cfg_loopback[5],cfg_loopback[1]};
assign loopback_sel  = cfg_loopback[8-1:0];

assign intr = |dma_intr;
assign trig_out = |ser_trig;


wire [4*M_AXI_OSC1_ADDR_BITS-1:0]      m_axi_osc_awaddr;
wire [4*8-1:0]                         m_axi_osc_awlen;
wire [4*3-1:0]                         m_axi_osc_awsize;
wire [4*2-1:0]                         m_axi_osc_awburst;
wire [4*3-1:0]                         m_axi_osc_awprot;
wire [4*4-1:0]                         m_axi_osc_awcache;
wire [  4-1:0]                         m_axi_osc_awvalid;
wire [  4-1:0]                         m_axi_osc_awready;
wire [4*M_AXI_OSC1_DATA_BITS-1:0]      m_axi_osc_wdata;
wire [4*M_AXI_OSC_BYTES-1:0]           m_axi_osc_wstrb;
wire [  4-1:0]                         m_axi_osc_wlast;
wire [  4-1:0]                         m_axi_osc_wvalid;
wire [  4-1:0]                         m_axi_osc_wready;
wire [4*2-1:0]                         m_axi_osc_bresp;
wire [  4-1:0]                         m_axi_osc_bvalid;
wire [  4-1:0]                         m_axi_osc_bready;

assign m_axi_osc1_awaddr  = m_axi_osc_awaddr[1*M_AXI_OSC1_ADDR_BITS-1:0*M_AXI_OSC1_ADDR_BITS];
assign m_axi_osc1_awlen   = m_axi_osc_awlen[1*8-1:0*8];
assign m_axi_osc1_awsize  = m_axi_osc_awsize[1*3-1:0*3];
assign m_axi_osc1_awburst = m_axi_osc_awburst[1*2-1:0*2];
assign m_axi_osc1_awprot  = m_axi_osc_awprot[1*3-1:0*3];
assign m_axi_osc1_awcache = m_axi_osc_awcache[1*4-1:0*4];
assign m_axi_osc1_awvalid = m_axi_osc_awvalid[0];
assign m_axi_osc1_wdata   = m_axi_osc_wdata[1*M_AXI_OSC1_DATA_BITS-1:0*M_AXI_OSC1_DATA_BITS];
assign m_axi_osc1_wstrb   = m_axi_osc_wstrb[1*M_AXI_OSC_BYTES-1:0*M_AXI_OSC_BYTES];
assign m_axi_osc1_wlast   = m_axi_osc_wlast[0];
assign m_axi_osc1_wvalid  = m_axi_osc_wvalid[0];
assign m_axi_osc1_bready  = m_axi_osc_bready[0];
assign m_axi_osc_awready[0]       = m_axi_osc1_awready;
assign m_axi_osc_wready[0]        = m_axi_osc1_wready;
assign m_axi_osc_bresp[1*2-1:0*2] = m_axi_osc1_bresp;
assign m_axi_osc_bvalid[0]        = m_axi_osc1_bvalid;

assign m_axi_osc2_awaddr  = m_axi_osc_awaddr[2*M_AXI_OSC1_ADDR_BITS-1:1*M_AXI_OSC1_ADDR_BITS];
assign m_axi_osc2_awlen   = m_axi_osc_awlen[2*8-1:1*8];
assign m_axi_osc2_awsize  = m_axi_osc_awsize[2*3-1:1*3];
assign m_axi_osc2_awburst = m_axi_osc_awburst[2*2-1:1*2];
assign m_axi_osc2_awprot  = m_axi_osc_awprot[2*3-1:1*3];
assign m_axi_osc2_awcache = m_axi_osc_awcache[2*4-1:1*4];
assign m_axi_osc2_awvalid = m_axi_osc_awvalid[1];
assign m_axi_osc2_wdata   = m_axi_osc_wdata[2*M_AXI_OSC1_DATA_BITS-1:1*M_AXI_OSC1_DATA_BITS];
assign m_axi_osc2_wstrb   = m_axi_osc_wstrb[2*M_AXI_OSC_BYTES-1:1*M_AXI_OSC_BYTES];
assign m_axi_osc2_wlast   = m_axi_osc_wlast[1];
assign m_axi_osc2_wvalid  = m_axi_osc_wvalid[1];
assign m_axi_osc2_bready  = m_axi_osc_bready[1];
assign m_axi_osc_awready[1]       = m_axi_osc2_awready;
assign m_axi_osc_wready[1]        = m_axi_osc2_wready;
assign m_axi_osc_bresp[2*2-1:1*2] = m_axi_osc2_bresp;
assign m_axi_osc_bvalid[1]        = m_axi_osc2_bvalid;


assign m_axi_osc3_awaddr  = m_axi_osc_awaddr[3*M_AXI_OSC1_ADDR_BITS-1:2*M_AXI_OSC1_ADDR_BITS];
assign m_axi_osc3_awlen   = m_axi_osc_awlen[3*8-1:2*8];
assign m_axi_osc3_awsize  = m_axi_osc_awsize[3*3-1:2*3];
assign m_axi_osc3_awburst = m_axi_osc_awburst[3*2-1:2*2];
assign m_axi_osc3_awprot  = m_axi_osc_awprot[3*3-1:2*3];
assign m_axi_osc3_awcache = m_axi_osc_awcache[3*4-1:2*4];
assign m_axi_osc3_awvalid = m_axi_osc_awvalid[2];
assign m_axi_osc3_wdata   = m_axi_osc_wdata[3*M_AXI_OSC1_DATA_BITS-1:2*M_AXI_OSC1_DATA_BITS];
assign m_axi_osc3_wstrb   = m_axi_osc_wstrb[3*M_AXI_OSC_BYTES-1:2*M_AXI_OSC_BYTES];
assign m_axi_osc3_wlast   = m_axi_osc_wlast[2];
assign m_axi_osc3_wvalid  = m_axi_osc_wvalid[2];
assign m_axi_osc3_bready  = m_axi_osc_bready[2];
assign m_axi_osc_awready[2]       = m_axi_osc3_awready;
assign m_axi_osc_wready[2]        = m_axi_osc3_wready;
assign m_axi_osc_bresp[3*2-1:2*2] = m_axi_osc3_bresp;
assign m_axi_osc_bvalid[2]        = m_axi_osc3_bvalid;

assign m_axi_osc4_awaddr  = m_axi_osc_awaddr[4*M_AXI_OSC1_ADDR_BITS-1:3*M_AXI_OSC1_ADDR_BITS];
assign m_axi_osc4_awlen   = m_axi_osc_awlen[4*8-1:3*8];
assign m_axi_osc4_awsize  = m_axi_osc_awsize[4*3-1:3*3];
assign m_axi_osc4_awburst = m_axi_osc_awburst[4*2-1:3*2];
assign m_axi_osc4_awprot  = m_axi_osc_awprot[4*3-1:3*3];
assign m_axi_osc4_awcache = m_axi_osc_awcache[4*4-1:3*4];
assign m_axi_osc4_awvalid = m_axi_osc_awvalid[3];
assign m_axi_osc4_wdata   = m_axi_osc_wdata[4*M_AXI_OSC1_DATA_BITS-1:3*M_AXI_OSC1_DATA_BITS];
assign m_axi_osc4_wstrb   = m_axi_osc_wstrb[4*M_AXI_OSC_BYTES-1:3*M_AXI_OSC_BYTES];
assign m_axi_osc4_wlast   = m_axi_osc_wlast[3];
assign m_axi_osc4_wvalid  = m_axi_osc_wvalid[3];
assign m_axi_osc4_bready  = m_axi_osc_bready[3];
assign m_axi_osc_awready[3]       = m_axi_osc4_awready;
assign m_axi_osc_wready[3]        = m_axi_osc4_wready;
assign m_axi_osc_bresp[4*2-1:3*2] = m_axi_osc4_bresp;
assign m_axi_osc_bvalid[3]        = m_axi_osc4_bvalid;

scope_cfg #(
  .M_AXI_ADDR_BITS  (M_AXI_OSC1_ADDR_BITS),
  .M_AXI_DATA_BITS  (M_AXI_OSC1_DATA_BITS),
  .ID_WIDTHS        (ID_WIDTHS),
  .S_AXIS_DATA_BITS (S_AXIS_DATA_BITS), 
  .REG_ADDR_BITS    (S_AXI_REG_ADDR_BITS),
  .DEC_CNT_BITS     (DEC_CNT_BITS),
  .DEC_SHIFT_BITS   (DEC_SHIFT_BITS),
  .TRIG_CNT_BITS    (TRIG_CNT_BITS),
  .EVENT_SRC_NUM    (EVENT_SRC_NUM),
  .TRIG_SRC_NUM     (TRIG_SRC_NUM)
  )
  U_scope_cfg
  (
    
  .s_axi_reg_aclk           (s_axi_reg_aclk),       
  .s_axi_reg_aresetn        (s_axi_reg_aresetn), 
  .s_axi_reg_awaddr         (s_axi_reg_awaddr),   
  .s_axi_reg_awprot         (s_axi_reg_awprot),   
  .s_axi_reg_awvalid        (s_axi_reg_awvalid), 
  .s_axi_reg_awready        (s_axi_reg_awready), 
  .s_axi_reg_wdata          (s_axi_reg_wdata),     
  .s_axi_reg_wstrb          (s_axi_reg_wstrb),     
  .s_axi_reg_wvalid         (s_axi_reg_wvalid),   
  .s_axi_reg_wready         (s_axi_reg_wready),   
  .s_axi_reg_wlast          (s_axi_reg_wlast),   
  .s_axi_reg_bresp          (s_axi_reg_bresp),     
  .s_axi_reg_bvalid         (s_axi_reg_bvalid),   
  .s_axi_reg_bready         (s_axi_reg_bready),   
  .s_axi_reg_araddr         (s_axi_reg_araddr),   
  .s_axi_reg_arprot         (s_axi_reg_arprot),   
  .s_axi_reg_arvalid        (s_axi_reg_arvalid), 
  .s_axi_reg_arready        (s_axi_reg_arready), 
  .s_axi_reg_rdata          (s_axi_reg_rdata),     
  .s_axi_reg_rresp          (s_axi_reg_rresp),     
  .s_axi_reg_rvalid         (s_axi_reg_rvalid),   
  .s_axi_reg_rready         (s_axi_reg_rready),  
  .s_axi_reg_rlast          (s_axi_reg_rlast),   
  .s_axi_reg_awid           (s_axi_reg_awid),
  .s_axi_reg_arid           (s_axi_reg_arid),
  .s_axi_reg_wid            (s_axi_reg_wid),
  .s_axi_reg_rid            (s_axi_reg_rid),
  .s_axi_reg_bid            (s_axi_reg_bid),


  .clk_axi_i                (m_axi_osc1_aclk),   
  .clk_adc_i                (clk),   
  .axi_rstn_i               (rstn_cfgax), 
  .adc_rstn_i               (rstn_cfg), 


  .cfg_event_op_trig_o      (cfg_event_op[0]),
  .cfg_event_op_stop_o      (cfg_event_op[1]),
  .cfg_event_op_start_o     (cfg_event_op[2]),
  .cfg_event_op_reset_o     (cfg_event_op[3]),
  .cfg_event_sts_i          (cfg_event_sts[1*4-1:0*4]),
  .cfg_event_sel_o          (cfg_event_sel),

  .cfg_trig_mask_o          (cfg_trig_mask),
  .cfg_trig_pre_samp_o      (cfg_trig_pre_samp),
  .cfg_trig_post_samp_o     (cfg_trig_post_samp),

  .sts_trig_pre_cnt_i       (sts_trig_pre_cnt[1*TRIG_CNT_BITS-1:0*TRIG_CNT_BITS]),
  .sts_trig_post_cnt_i      (sts_trig_post_cnt[1*TRIG_CNT_BITS-1:0*TRIG_CNT_BITS]),
  .sts_trig_pre_overflow_i  (sts_trig_pre_overflow[0]),
  .sts_trig_post_overflow_i (sts_trig_post_overflow[0]),

  .cfg_trig_low_level_o     (cfg_trig_low_level),
  .cfg_trig_high_level_o    (cfg_trig_high_level),
  .cfg_trig_edge_o          (cfg_trig_edge),

  .cfg_dec_factor_o         (cfg_dec_factor),
  .cfg_dec_rshift_o         (cfg_dec_rshift),
  .cfg_avg_en_o             (cfg_avg_en),
  .cfg_loopback_o           (cfg_loopback),
  .cfg_8bit_dat_o           (cfg_8bit_dat),
  .clksel_o                 (clksel_o),
  .daisy_slave_i            (daisy_slave_i),
  
  .cfg_filt_bypass_o        (cfg_filt_bypass),

  .cfg_filt_coeff_aa_o      (cfg_filt_coeff_aa),
  .cfg_filt_coeff_bb_o      (cfg_filt_coeff_bb),
  .cfg_filt_coeff_kk_o      (cfg_filt_coeff_kk),
  .cfg_filt_coeff_pp_o      (cfg_filt_coeff_pp),

  .cfg_dma_dst_addr1_o      (cfg_dma_dst_addr1),
  .cfg_dma_dst_addr2_o      (cfg_dma_dst_addr2),

  .cfg_calib_offset_o       (cfg_calib_offset),
  .cfg_calib_gain_o         (cfg_calib_gain),

  .buf1_ms_cnt_i            (buf1_ms_cnt),
  .buf2_ms_cnt_i            (buf2_ms_cnt),
  .curr_wp_i                (curr_wp),


  .cfg_dma_buf_size_o       (cfg_dma_buf_size),
  .cfg_dma_ctrl_o           (cfg_dma_ctrl),
  .cfg_dma_ctrl_we_o        (cfg_dma_ctrl_we),
  .cfg_dma_sts_i            (cfg_dma_sts[1*32-1:0*32]),

  .diag1_i                  (diag1[1*32-1:0*32]),
  .diag2_i                  (diag2[1*32-1:0*32]),
  .diag3_i                  (diag3[1*32-1:0*32]),
  .diag4_i                  (diag4[1*32-1:0*32])
); 


genvar GV, GZ, GX;

generate
  for (GV = 0; GV < NUM_CHANNELS; GV = GV + 1) begin : acq_ch_gen
  wire                    bufs_in;
  wire [NUM_CHANNELS-1:0] other_bufs;
    for (GZ = 0; GZ < NUM_CHANNELS; GZ = GZ + 1) begin : buf_sels
      if (GZ==GV)
        assign other_bufs[GZ] = 1'b0;
      else
        assign other_bufs[GZ] = buf_sel[GV];
    end
  assign bufs_in = |other_bufs;
osc_top #(
  .M_AXI_ADDR_BITS  (M_AXI_OSC1_ADDR_BITS),
  .M_AXI_DATA_BITS  (M_AXI_OSC1_DATA_BITS),
  .S_AXIS_DATA_BITS (16), 
  .EVENT_SRC_NUM    (EVENT_SRC_NUM),
  .TRIG_SRC_NUM     (TRIG_SRC_NUM),
  .TRIG_CNT_BITS    (TRIG_CNT_BITS),
  .DEC_CNT_BITS     (DEC_CNT_BITS),
  .DEC_SHIFT_BITS   (DEC_SHIFT_BITS),
  .CHAN_NUM         (GV))
  U_osc2(
  .clk_axi          (m_axi_osc1_aclk),   
  .clk_adc          (clk),   
  .axi_rstn         (m_axi_osc1_aresetn), 
  .adc_rstn         (rst_n), 
  .s_axis_tdata     (s_axis_osc_tdata[(GV+1)*16-1:GV*16]), 
  .s_axis_tvalid    (1'b1),

  .event_ip_trig    (event_ip_trig),  
  .event_ip_stop    (event_ip_stop),  
  .event_ip_start   (event_ip_start), 
  .event_ip_reset   (event_ip_reset), 

  .event_sts_o      (cfg_event_sts[(GV+1)*4-1:GV*4]),
  .event_sel_i      (cfg_event_sel),
  .trig_mask_i      (cfg_trig_mask),
  
  .cfg_trig_pre_samp_i      (cfg_trig_pre_samp),
  .cfg_trig_post_samp_i     (cfg_trig_post_samp),
  .cfg_trig_low_level_i     (cfg_trig_low_level),
  .cfg_trig_high_level_i    (cfg_trig_high_level),
  .sts_trig_pre_cnt_o       (sts_trig_pre_cnt[(GV+1)*TRIG_CNT_BITS-1:GV*TRIG_CNT_BITS]),
  .sts_trig_post_cnt_o      (sts_trig_post_cnt[(GV+1)*TRIG_CNT_BITS-1:GV*TRIG_CNT_BITS]),
  .sts_trig_pre_overflow_o  (sts_trig_pre_overflow[GV]),
  .sts_trig_post_overflow_o (sts_trig_post_overflow[GV]),
  .cfg_trig_edge_i          (cfg_trig_edge),

  .cfg_dec_factor_i         (cfg_dec_factor),
  .cfg_dec_rshift_i         (cfg_dec_rshift),
  .cfg_avg_en_i             (cfg_avg_en),
  .cfg_loopback_i           ({ramp_en[GV],loopback_gpio[GV],loopback_dac[GV]}),
  .cfg_8bit_dat_i           (cfg_8bit_dat),
  .cfg_calib_offset_i       (cfg_calib_offset[(GV+1)*16-1:GV*16]),
  .cfg_calib_gain_i         (cfg_calib_gain[(GV+1)*16-1:GV*16]),

  .cfg_filt_bypass_i        (cfg_filt_bypass),
  .cfg_filt_coeff_aa_i      (cfg_filt_coeff_aa[(GV+1)*18-1:GV*18]),
  .cfg_filt_coeff_bb_i      (cfg_filt_coeff_bb[(GV+1)*25-1:GV*25]),
  .cfg_filt_coeff_kk_i      (cfg_filt_coeff_kk[(GV+1)*25-1:GV*25]),
  .cfg_filt_coeff_pp_i      (cfg_filt_coeff_pp[(GV+1)*25-1:GV*25]),

  .cfg_dma_sts_o            (cfg_dma_sts[(GV+1)*32-1:GV*32]),
  .cfg_dma_dst_addr1_i      (cfg_dma_dst_addr1[(GV+1)*32-1:GV*32]),
  .cfg_dma_dst_addr2_i      (cfg_dma_dst_addr2[(GV+1)*32-1:GV*32]),
  .cfg_dma_buf_size_i       (cfg_dma_buf_size),
  .cfg_dma_ctrl_i           (cfg_dma_ctrl),
  .cfg_dma_ctrl_we_i        (cfg_dma_ctrl_we),

  .buf1_ms_cnt_o            (buf1_ms_cnt[(GV+1)*32-1:GV*32]),
  .buf2_ms_cnt_o            (buf2_ms_cnt[(GV+1)*32-1:GV*32]),

  .curr_wp_o                (curr_wp[(GV+1)*32-1:GV*32]),
  .diag1_o                  (diag1[(GV+1)*32-1:GV*32]),
  .diag2_o                  (diag2[(GV+1)*32-1:GV*32]),
  .diag3_o                  (diag3[(GV+1)*32-1:GV*32]),
  .diag4_o                  (diag4[(GV+1)*32-1:GV*32]),

  .trig_ip          (trig_ip),
  .trig_op          (osc_trig_op[GV]),  
  .trig_o           (ser_trig[GV]),
  .ctl_rst          (),

  .buf_sel_in       (bufs_in),
  .buf_sel_out      (buf_sel[GV]),
  .dma_intr         (dma_intr[GV]),

  .m_axi_awaddr(m_axi_osc_awaddr[(GV+1)*M_AXI_OSC1_ADDR_BITS-1:GV*M_AXI_OSC1_ADDR_BITS]),
  .m_axi_awlen(m_axi_osc_awlen[(GV+1)*8-1:GV*8]),
  .m_axi_awsize(m_axi_osc_awsize[(GV+1)*3-1:GV*3]),
  .m_axi_awburst(m_axi_osc_awburst[(GV+1)*2-1:GV*2]),
  .m_axi_awprot(m_axi_osc_awprot[(GV+1)*3-1:GV*3]),
  .m_axi_awcache(m_axi_osc_awcache[(GV+1)*4-1:GV*4]),
  .m_axi_awvalid(m_axi_osc_awvalid[GV]),
  .m_axi_awready(m_axi_osc_awready[GV]),
  .m_axi_wdata(m_axi_osc_wdata[(GV+1)*M_AXI_OSC1_DATA_BITS-1:GV*M_AXI_OSC1_DATA_BITS]),
  .m_axi_wstrb(m_axi_osc_wstrb[(GV+1)*M_AXI_OSC_BYTES-1:GV*M_AXI_OSC_BYTES]),
  .m_axi_wlast(m_axi_osc_wlast[GV]),
  .m_axi_wvalid(m_axi_osc_wvalid[GV]),
  .m_axi_wready(m_axi_osc_wready[GV]),
  .m_axi_bresp(m_axi_osc_bresp[(GV+1)*2-1:GV*2]),
  .m_axi_bvalid(m_axi_osc_bvalid[GV]),
  .m_axi_bready(m_axi_osc_bready[GV]));
  end


endgenerate

endmodule
