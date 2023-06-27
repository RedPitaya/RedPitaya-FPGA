/*
* Copyright (c) 2016 Instrumentation Technologies, d.d.
* All Rights Reserved.
*
* $Id: $
*/




module scope_cfg
#(
    parameter M_AXI_ADDR_BITS   = 32, // DMA Address bits
    parameter M_AXI_DATA_BITS   = 64, // DMA data bits
    parameter ID_WIDTHS         = 4,
    parameter S_AXIS_DATA_BITS  = 16, // ADC data bits
    parameter REG_ADDR_BITS     = 32, // Register interface address bits
    parameter DEC_CNT_BITS      = 17, // Decimator counter bits
    parameter DEC_SHIFT_BITS    = 4,  // Decimator shifter bits
    parameter TRIG_CNT_BITS     = 32, // Trigger counter bits
    parameter EVENT_SRC_NUM     = 1,  // Number of event sources
    parameter TRIG_SRC_NUM      = 1   // Number of trigger sources
) // which channel
(
   // configuration ports

   input  wire                                   s_axi_reg_aclk,
   input  wire                                   s_axi_reg_aresetn,
   input  wire [REG_ADDR_BITS-1:0]               s_axi_reg_awaddr,
   input  wire [3-1:0]                           s_axi_reg_awprot,
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
   input  wire [REG_ADDR_BITS-1:0]               s_axi_reg_araddr,
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

   // signals
   input                               clk_axi_i               ,
   input                               clk_adc_i               ,
   input                               axi_rstn_i              ,
   input                               adc_rstn_i              ,

   output wire                         cfg_event_op_trig_o     ,
   output wire                         cfg_event_op_stop_o     ,
   output wire                         cfg_event_op_start_o    ,
   output wire                         cfg_event_op_reset_o    ,
   input  wire [               4-1:0]  cfg_event_sts_i         ,
   output wire [               3-1:0]  cfg_event_sel_o         ,
   output wire [    TRIG_SRC_NUM-1:0]  cfg_trig_mask_o         ,
   output wire [   TRIG_CNT_BITS-1:0]  cfg_trig_pre_samp_o     ,
   output wire [   TRIG_CNT_BITS-1:0]  cfg_trig_post_samp_o    ,
   input  wire [   TRIG_CNT_BITS-1:0]  sts_trig_pre_cnt_i      ,
   input  wire [   TRIG_CNT_BITS-1:0]  sts_trig_post_cnt_i     ,
   input  wire                         sts_trig_pre_overflow_i ,
   input  wire                         sts_trig_post_overflow_i,
   output wire [S_AXIS_DATA_BITS-1:0]  cfg_trig_low_level_o    ,
   output wire [S_AXIS_DATA_BITS-1:0]  cfg_trig_high_level_o   ,
   output wire                         cfg_trig_edge_o         ,

   output wire [    DEC_CNT_BITS-1:0]  cfg_dec_factor_o        ,
   output wire [  DEC_SHIFT_BITS-1:0]  cfg_dec_rshift_o        ,
   output wire                         cfg_avg_en_o            ,
   output wire [              32-1:0]  cfg_loopback_o          ,
   output wire                         cfg_8bit_dat_o          ,
   output reg                          clksel_o                ,
   input  wire                         daisy_slave_i           ,

   output wire                         cfg_filt_bypass_o       ,
   output wire [              32-1:0]  cfg_dma_buf_size_o      ,
   output wire [              32-1:0]  cfg_dma_ctrl_o          ,
   output wire                         cfg_dma_ctrl_we_o       ,
   input  wire [              32-1:0]  cfg_dma_sts_i           ,

   output wire [            4*16-1:0]  cfg_calib_offset_o  ,
   output wire [            4*16-1:0]  cfg_calib_gain_o    ,

   output wire [            4*18-1:0]  cfg_filt_coeff_aa_o ,
   output wire [            4*25-1:0]  cfg_filt_coeff_bb_o ,
   output wire [            4*25-1:0]  cfg_filt_coeff_kk_o ,
   output wire [            4*25-1:0]  cfg_filt_coeff_pp_o ,

   output wire [            4*32-1:0]  cfg_dma_dst_addr1_o ,
   output wire [            4*32-1:0]  cfg_dma_dst_addr2_o ,

   input  wire [            4*32-1:0]  buf1_ms_cnt_i       ,
   input  wire [            4*32-1:0]  buf2_ms_cnt_i       ,

   input  wire [            4*32-1:0]  curr_wp_i           ,

   input  wire [              32-1:0]  diag1_i                 ,
   input  wire [              32-1:0]  diag2_i                 ,
   input  wire [              32-1:0]  diag3_i                 ,
   input  wire [              32-1:0]  diag4_i
);




// more or less globaly spread signals
reg            reg_write_axi ;
reg            reg_read_axi  ;
reg  [12-1: 0] reg_ofs_axi   ;
reg  [32-1: 0] reg_wdat_axi  ;
reg  [ 4-1: 0] reg_sel_axi   ;
reg            reg_ack_axi   ;
reg  [32-1: 0] reg_rdat_axi  ;

reg            reg_write_adc ;
reg            reg_read_adc  ;
reg  [12-1: 0] reg_ofs_adc   ;
reg  [32-1: 0] reg_wdat_adc  ;
reg  [ 4-1: 0] reg_sel_adc   ;
reg            reg_ack_adc   ;
reg  [32-1: 0] reg_rdat_adc  ;

// Address map
localparam EVENT_STS_ADDR           = 12'h0;   // Event status address 
localparam EVENT_SEL_ADDR           = 12'h4;   // Event select address
localparam TRIG_MASK_ADDR           = 12'h8;   // Trigger mask address
localparam TRIG_PRE_SAMP_ADDR       = 12'h10;  // Trigger pre samples address
localparam TRIG_POST_SAMP_ADDR      = 12'h14;  // Trigger post samples address
localparam TRIG_PRE_CNT_ADDR        = 12'h18;  // Trigger pre count address
localparam TRIG_POST_CNT_ADDR       = 12'h1C;  // Trigger post count address
localparam TRIG_LOW_LEVEL_ADDR      = 12'h20;  // Trigger low level address
localparam TRIG_HIGH_LEVEL_ADDR     = 12'h24;  // Trigger high level address
localparam TRIG_EDGE_ADDR           = 12'h28;  // Trigger edge address
localparam DEC_FACTOR_ADDR          = 12'h30;  // Decimation factor address
localparam DEC_RSHIFT_ADDR          = 12'h34;  // Decimation right shift address
localparam AVG_EN_ADDR              = 12'h38;  // Average enable address
localparam FILT_BYPASS_ADDR         = 12'h3C;  // Filter bypass address
localparam LOOPBACK_ADDR            = 12'h40;  // Digital loopback
localparam SHIFT_8BIT               = 12'h44;  // Use 8 bit data
localparam DMA_CTRL_ADDR            = 12'h50;  // DMA control register
localparam DMA_STS_ADDR             = 12'h54;  // DMA status register
localparam DMA_BUF_SIZE_ADDR        = 12'h58;  // DMA buffer size

localparam BUF1_LOST_SAMP_CNT_CH1   = 12'h5C;  // Number of lost samples in buffer 1
localparam BUF2_LOST_SAMP_CNT_CH1   = 12'h60;  // Number of lost samples in buffer 2
localparam DMA_DST_ADDR1_CH1        = 12'h64;  // DMA destination address 1
localparam DMA_DST_ADDR2_CH1        = 12'h68;  // DMA destination address 2
localparam DMA_DST_ADDR1_CH2        = 12'h6C;  // DMA destination address 1
localparam DMA_DST_ADDR2_CH2        = 12'h70;  // DMA destination address 2
localparam CALIB_OFFSET_ADDR_CH1    = 12'h74;  // Calibraton offset CH1
localparam CALIB_GAIN_ADDR_CH1      = 12'h78;  // Calibraton gain CH1
localparam CALIB_OFFSET_ADDR_CH2    = 12'h7C;  // Calibraton offset CH2
localparam CALIB_GAIN_ADDR_CH2      = 12'h80;  // Calibraton gain CH2
localparam BUF1_LOST_SAMP_CNT_CH2   = 12'h9C;  // Number of lost samples in buffer 1
localparam BUF2_LOST_SAMP_CNT_CH2   = 12'hA0;  // Number of lost samples in buffer 2
localparam CURR_WP_CH1              = 12'hA4;  //current write pointer CH1
localparam CURR_WP_CH2              = 12'hA8;  //current write pointer CH2

localparam FILT_COEFF_AA_CH1        = 12'hC0;  // Filter coeff AA address CH1
localparam FILT_COEFF_BB_CH1        = 12'hC4;  // Filter coeff BB address CH1
localparam FILT_COEFF_KK_CH1        = 12'hC8;  // Filter coeff KK address CH1
localparam FILT_COEFF_PP_CH1        = 12'hCC;  // Filter coeff PP address CH1

localparam FILT_COEFF_AA_CH2        = 12'hD0;  // Filter coeff AA address CH2
localparam FILT_COEFF_BB_CH2        = 12'hD4;  // Filter coeff BB address CH2
localparam FILT_COEFF_KK_CH2        = 12'hD8;  // Filter coeff KK address CH2
localparam FILT_COEFF_PP_CH2        = 12'hDC;  // Filter coeff PP address CH2

localparam BUF1_LOST_SAMP_CNT_CH3   = 12'h15C;  // Number of lost samples in buffer 1
localparam BUF2_LOST_SAMP_CNT_CH3   = 12'h160;  // Number of lost samples in buffer 2
localparam DMA_DST_ADDR1_CH3        = 12'h164;  // DMA destination address 1
localparam DMA_DST_ADDR2_CH3        = 12'h168;  // DMA destination address 2
localparam DMA_DST_ADDR1_CH4        = 12'h16C;  // DMA destination address 1
localparam DMA_DST_ADDR2_CH4        = 12'h170;  // DMA destination address 2
localparam CALIB_OFFSET_ADDR_CH3    = 12'h174;  // Calibraton offset CH1
localparam CALIB_GAIN_ADDR_CH3      = 12'h178;  // Calibraton gain CH1
localparam CALIB_OFFSET_ADDR_CH4    = 12'h17C;  // Calibraton offset CH2
localparam CALIB_GAIN_ADDR_CH4      = 12'h180;  // Calibraton gain CH2
localparam BUF1_LOST_SAMP_CNT_CH4   = 12'h19C;  // Number of lost samples in buffer 1
localparam BUF2_LOST_SAMP_CNT_CH4   = 12'h1A0;  // Number of lost samples in buffer 2
localparam CURR_WP_CH3              = 12'h1A4;  //current write pointer CH1
localparam CURR_WP_CH4              = 12'h1A8;  //current write pointer CH2

localparam FILT_COEFF_AA_CH3        = 12'h1C0;  // Filter coeff AA address CH1
localparam FILT_COEFF_BB_CH3        = 12'h1C4;  // Filter coeff BB address CH1
localparam FILT_COEFF_KK_CH3        = 12'h1C8;  // Filter coeff KK address CH1
localparam FILT_COEFF_PP_CH3        = 12'h1CC;  // Filter coeff PP address CH1

localparam FILT_COEFF_AA_CH4        = 12'h1D0;  // Filter coeff AA address CH2
localparam FILT_COEFF_BB_CH4        = 12'h1D4;  // Filter coeff BB address CH2
localparam FILT_COEFF_KK_CH4        = 12'h1D8;  // Filter coeff KK address CH2
localparam FILT_COEFF_PP_CH4        = 12'h1DC;  // Filter coeff PP address CH2

localparam DIAG_REG1                = 12'hE0; // interrupt counter
localparam DIAG_REG2                = 12'hE4; // external trigger counter
localparam DIAG_REG3                = 12'hE8; // clock counter
localparam DIAG_REG4                = 12'hEC; // status of state machine

localparam STATUS_REG               = 12'h100;   // status of FPGA clock
localparam CLKSEL_REG               = 16'h1000;  // FPGA mode


reg  [           3-1:0]     cfg_event_sel;
reg  [TRIG_SRC_NUM-1:0]     cfg_trig_mask;

reg  [TRIG_CNT_BITS-1:0]    cfg_trig_pre_samp;
reg  [TRIG_CNT_BITS-1:0]    cfg_trig_post_samp;

reg  [S_AXIS_DATA_BITS-1:0] cfg_trig_low_level;
reg  [S_AXIS_DATA_BITS-1:0] cfg_trig_high_level;
reg                         cfg_trig_edge;  

reg                         cfg_avg_en; 
reg  [  DEC_CNT_BITS-1:0]   cfg_dec_factor;  
reg  [DEC_SHIFT_BITS-1:0]   cfg_dec_rshift;  
reg  [            32-1:0]   cfg_loopback;

reg                         cfg_filt_bypass;  

reg  [32-1:0]               cfg_dma_buf_size;
reg                         cfg_8bit_dat;
reg  [32-1:0]               cfg_dma_ctrl;
reg                         cfg_dma_ctrl_we;
reg                         cfg_clksel;

reg  [4*32-1:0]               cfg_dma_dst_addr1;
reg  [4*32-1:0]               cfg_dma_dst_addr2;

reg  [4*16-1:0]               cfg_calib_offset;
reg  [4*16-1:0]               cfg_calib_gain;

reg signed [4*18-1:0]         cfg_filt_coeff_aa; 
reg signed [4*25-1:0]         cfg_filt_coeff_bb; 
reg signed [4*25-1:0]         cfg_filt_coeff_kk; 
reg signed [4*25-1:0]         cfg_filt_coeff_pp; 

reg  [ 4-1: 0]              event_op_reg;

wire axi_clk_regs;

reg pll_locked;
always @(posedge clk_adc_i) begin
   if (adc_rstn_i == 1'b0)
      pll_locked <= 1'b0;
   else
      pll_locked <= 1'b1;
end

reg [13-1:0] daisy_cnt      =  'h0;
reg          daisy_slave    = 1'b0;
reg          daisy_slave_r  = 1'b0;
reg          daisy_slave_r2 = 1'b0;

always @(posedge clk_adc_i) begin // if there is a clock present on the daisy chain connector, the board will be treated as a slave
   daisy_slave_r  <= daisy_slave_i;
   daisy_slave_r2 <= daisy_slave_r;
   if (adc_rstn_i == 1'b0) begin
      daisy_cnt     <= 'h0;
      daisy_slave <= 1'b0;
  end else begin 
      if (daisy_cnt < 13'h1100)
         daisy_cnt <= daisy_cnt + 'h1;
      if (daisy_cnt == 13'hFFF)
         daisy_slave <= daisy_slave_r2;
  end
end

assign axi_clk_regs =  (bus.addr[12-1:0] == DMA_CTRL_ADDR          ||
                        bus.addr[12-1:0] == DMA_STS_ADDR           ||
                        bus.addr[12-1:0] == DMA_BUF_SIZE_ADDR      ||
                        bus.addr[12-1:0] == BUF1_LOST_SAMP_CNT_CH1 ||
                        bus.addr[12-1:0] == BUF2_LOST_SAMP_CNT_CH1 ||
                        bus.addr[12-1:0] == BUF1_LOST_SAMP_CNT_CH2 ||
                        bus.addr[12-1:0] == BUF2_LOST_SAMP_CNT_CH2 ||
                        bus.addr[12-1:0] == BUF1_LOST_SAMP_CNT_CH3 ||
                        bus.addr[12-1:0] == BUF2_LOST_SAMP_CNT_CH3 ||
                        bus.addr[12-1:0] == BUF1_LOST_SAMP_CNT_CH4 ||
                        bus.addr[12-1:0] == BUF2_LOST_SAMP_CNT_CH4 ||
                        bus.addr[12-1:0] == DMA_DST_ADDR1_CH1      ||
                        bus.addr[12-1:0] == DMA_DST_ADDR2_CH1      ||
                        bus.addr[12-1:0] == DMA_DST_ADDR1_CH2      ||
                        bus.addr[12-1:0] == DMA_DST_ADDR2_CH2      ||
                        bus.addr[12-1:0] == DMA_DST_ADDR1_CH3      ||
                        bus.addr[12-1:0] == DMA_DST_ADDR2_CH3      ||
                        bus.addr[12-1:0] == DMA_DST_ADDR1_CH4      ||
                        bus.addr[12-1:0] == DMA_DST_ADDR2_CH4      ||
                        bus.addr[12-1:0] == CURR_WP_CH1            ||
                        bus.addr[12-1:0] == CURR_WP_CH2            ||
                        bus.addr[12-1:0] == CURR_WP_CH3            ||
                        bus.addr[12-1:0] == CURR_WP_CH4              );

sys_bus_if bus (.clk (s_axi_reg_aclk), .rstn (s_axi_reg_aresetn));
axi4_if #(.DW (32), .AW (REG_ADDR_BITS), .IW (ID_WIDTHS), .LW (4)) axi_gp (.ACLK (s_axi_reg_aclk), .ARESETn (s_axi_reg_aresetn));

wire [ 4-1:0] s_axi_reg_awlen   = 4'h0;    // single word burst
wire [ 3-1:0] s_axi_reg_awsize  = 3'b010;  // 4 bytes
wire [ 3-1:0] s_axi_reg_awburst = 3'b00;   // fixed
wire [ 2-1:0] s_axi_reg_awlock  = 2'h00;   // normal
wire [ 4-1:0] s_axi_reg_awcache = 4'b0011; // non-cacheable
wire [ 4-1:0] s_axi_reg_arlen   = 4'h0;    // single word burst
wire [ 3-1:0] s_axi_reg_arsize  = 3'b010;  // 4 bytes
wire [ 3-1:0] s_axi_reg_arburst = 3'b00;   // fixed
wire [ 2-1:0] s_axi_reg_arlock  = 2'h00;   // normal
wire [ 4-1:0] s_axi_reg_arcache = 4'b0011; // non-cacheable

assign axi_gp.AWID    = s_axi_reg_awid     ;
assign axi_gp.AWADDR  = s_axi_reg_awaddr   ;
assign axi_gp.AWLEN   = s_axi_reg_awlen    ;
assign axi_gp.AWSIZE  = s_axi_reg_awsize   ;
assign axi_gp.AWBURST = s_axi_reg_awburst  ;
assign axi_gp.AWLOCK  = s_axi_reg_awlock   ;
assign axi_gp.AWCACHE = s_axi_reg_awcache  ;
assign axi_gp.AWPROT  = s_axi_reg_awprot   ;
assign axi_gp.AWVALID = s_axi_reg_awvalid  ;
assign axi_gp.WID     = s_axi_reg_wid      ;
assign axi_gp.WDATA   = s_axi_reg_wdata    ;
assign axi_gp.WSTRB   = s_axi_reg_wstrb    ;
assign axi_gp.WLAST   = s_axi_reg_wlast    ;
assign axi_gp.WVALID  = s_axi_reg_wvalid   ;
assign axi_gp.BREADY  = s_axi_reg_bready   ;
assign axi_gp.ARID    = s_axi_reg_arid     ;
assign axi_gp.ARADDR  = s_axi_reg_araddr   ;
assign axi_gp.ARLEN   = s_axi_reg_arlen    ;
assign axi_gp.ARSIZE  = s_axi_reg_arsize   ;
assign axi_gp.ARBURST = s_axi_reg_arburst  ;
assign axi_gp.ARLOCK  = s_axi_reg_arlock   ;
assign axi_gp.ARCACHE = s_axi_reg_arcache  ;
assign axi_gp.ARPROT  = s_axi_reg_arprot   ;
assign axi_gp.ARVALID = s_axi_reg_arvalid  ;
assign axi_gp.RREADY  = s_axi_reg_rready   ;

assign s_axi_reg_awready = axi_gp.AWREADY  ;
assign s_axi_reg_wready  = axi_gp.WREADY   ;
assign s_axi_reg_arready = axi_gp.ARREADY  ;
assign s_axi_reg_bresp   = axi_gp.BRESP    ;
assign s_axi_reg_bvalid  = axi_gp.BVALID   ;
assign s_axi_reg_rdata   = axi_gp.RDATA    ;
assign s_axi_reg_rresp   = axi_gp.RRESP    ;
assign s_axi_reg_rvalid  = axi_gp.RVALID   ;
assign s_axi_reg_rlast   = axi_gp.RLAST    ;
assign s_axi_reg_bid     = axi_gp.BID;
assign s_axi_reg_rid     = axi_gp.RID;

axi4_slave #(
  .DW (32),
  .AW (REG_ADDR_BITS),
  .IW (ID_WIDTHS)
) axi_slave (
  // AXI bus
  .axi       (axi_gp),
  // system read/write channel
  .bus       (bus)
);

///////////////////////////////////////////////////////////////////////////////////////////
// Write logic ADC regs
///////////////////////////////////////////////////////////////////////////////////////////
reg [4-1:0] event_op_reg_r;
always @(posedge clk_adc_i) begin
   event_op_reg_r <= event_op_reg;
end

always @(posedge clk_adc_i)
begin
   if (adc_rstn_i == 1'b0) begin
      event_op_reg            <=  4'h0;
      cfg_event_sel           <=  3'h0;
      cfg_trig_mask           <=   'h0;
      cfg_trig_pre_samp       <=   'h0;
      cfg_trig_post_samp      <=   'h0;
      cfg_trig_low_level      <=   'h0;
      cfg_trig_high_level     <=   'h0;
      cfg_trig_edge           <=  1'b0;
      cfg_dec_factor          <=   'h0;
      cfg_dec_rshift          <=   'h0;
      cfg_avg_en              <=  1'b0;
      cfg_loopback            <= 32'h0;
      cfg_filt_bypass         <=  1'b1;
      cfg_8bit_dat            <=  1'b0;

      cfg_filt_coeff_aa       <= {4{18'h0}};
      cfg_filt_coeff_bb       <= {4{25'h0}};
      cfg_filt_coeff_kk       <= {4{25'hffffff}};
      cfg_filt_coeff_pp       <= {4{25'h0}};

      cfg_calib_offset        <= {4{16'h0}};
      cfg_calib_gain          <= {4{16'h8000}};
   end else begin
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==EVENT_STS_ADDR)        )  event_op_reg            <= reg_wdat_adc[3:0]; else event_op_reg <= 4'h0;
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==EVENT_SEL_ADDR)        )  cfg_event_sel           <= reg_wdat_adc[3-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==TRIG_MASK_ADDR )       )  cfg_trig_mask           <= reg_wdat_adc[TRIG_SRC_NUM-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==TRIG_PRE_SAMP_ADDR)    )  cfg_trig_pre_samp       <= reg_wdat_adc[TRIG_CNT_BITS-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==TRIG_POST_SAMP_ADDR)   )  cfg_trig_post_samp      <= reg_wdat_adc[TRIG_CNT_BITS-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==TRIG_LOW_LEVEL_ADDR)   )  cfg_trig_low_level      <= reg_wdat_adc[S_AXIS_DATA_BITS-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==TRIG_HIGH_LEVEL_ADDR)  )  cfg_trig_high_level     <= reg_wdat_adc[S_AXIS_DATA_BITS-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==TRIG_HIGH_LEVEL_ADDR)  )  cfg_trig_edge           <= reg_wdat_adc[0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==DEC_FACTOR_ADDR)       )  cfg_dec_factor          <= reg_wdat_adc[DEC_CNT_BITS-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==DEC_RSHIFT_ADDR)       )  cfg_dec_rshift          <= reg_wdat_adc[DEC_SHIFT_BITS-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==AVG_EN_ADDR)           )  cfg_avg_en              <= reg_wdat_adc[0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==LOOPBACK_ADDR)         )  cfg_loopback            <= reg_wdat_adc[32-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==SHIFT_8BIT)            )  cfg_8bit_dat            <= reg_wdat_adc[0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_BYPASS_ADDR)      )  cfg_filt_bypass         <= reg_wdat_adc[0];

      if (reg_write_adc && (reg_ofs_adc[12-1:0]==CALIB_OFFSET_ADDR_CH1) )  cfg_calib_offset[1*16-1:0*16]  <= reg_wdat_adc[16-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==CALIB_OFFSET_ADDR_CH2) )  cfg_calib_offset[2*16-1:1*16]  <= reg_wdat_adc[16-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==CALIB_OFFSET_ADDR_CH3) )  cfg_calib_offset[3*16-1:2*16]  <= reg_wdat_adc[16-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==CALIB_OFFSET_ADDR_CH4) )  cfg_calib_offset[4*16-1:3*16]  <= reg_wdat_adc[16-1:0];

      if (reg_write_adc && (reg_ofs_adc[12-1:0]==CALIB_GAIN_ADDR_CH1)   )  cfg_calib_gain[1*16-1:0*16]    <= reg_wdat_adc[16-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==CALIB_GAIN_ADDR_CH2)   )  cfg_calib_gain[2*16-1:1*16]    <= reg_wdat_adc[16-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==CALIB_GAIN_ADDR_CH3)   )  cfg_calib_gain[3*16-1:2*16]    <= reg_wdat_adc[16-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==CALIB_GAIN_ADDR_CH4)   )  cfg_calib_gain[4*16-1:3*16]    <= reg_wdat_adc[16-1:0];

      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_AA_CH1)     )  cfg_filt_coeff_aa[1*18-1:0*18] <= reg_wdat_adc[18-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_AA_CH2)     )  cfg_filt_coeff_aa[2*18-1:1*18] <= reg_wdat_adc[18-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_AA_CH3)     )  cfg_filt_coeff_aa[3*18-1:2*18] <= reg_wdat_adc[18-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_AA_CH4)     )  cfg_filt_coeff_aa[4*18-1:3*18] <= reg_wdat_adc[18-1:0];

      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_BB_CH1)     )  cfg_filt_coeff_bb[1*25-1:0*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_BB_CH2)     )  cfg_filt_coeff_bb[2*25-1:1*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_BB_CH3)     )  cfg_filt_coeff_bb[3*25-1:2*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_BB_CH4)     )  cfg_filt_coeff_bb[4*25-1:3*25] <= reg_wdat_adc[25-1:0];

      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_KK_CH1)     )  cfg_filt_coeff_kk[1*25-1:0*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_KK_CH2)     )  cfg_filt_coeff_kk[2*25-1:1*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_KK_CH3)     )  cfg_filt_coeff_kk[3*25-1:2*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_KK_CH4)     )  cfg_filt_coeff_kk[4*25-1:3*25] <= reg_wdat_adc[25-1:0];

      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_PP_CH1)     )  cfg_filt_coeff_pp[1*25-1:0*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_PP_CH2)     )  cfg_filt_coeff_pp[2*25-1:1*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_PP_CH3)     )  cfg_filt_coeff_pp[3*25-1:2*25] <= reg_wdat_adc[25-1:0];
      if (reg_write_adc && (reg_ofs_adc[12-1:0]==FILT_COEFF_PP_CH4)     )  cfg_filt_coeff_pp[4*25-1:3*25] <= reg_wdat_adc[25-1:0];

   end
end

///////////////////////////////////////////////////////////////////////////////////////////
// Read logic ADC regs
///////////////////////////////////////////////////////////////////////////////////////////
always @ (*) 
begin
   casez(reg_ofs_adc[12-1:0])
      EVENT_STS_ADDR         : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-4{1'b0}}                , cfg_event_sts_i};         end
      EVENT_SEL_ADDR         : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-3{1'b0}}                , cfg_event_sel};           end
      TRIG_MASK_ADDR         : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-TRIG_SRC_NUM{1'b0}}     , cfg_trig_mask};           end
      TRIG_PRE_SAMP_ADDR     : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-TRIG_CNT_BITS{1'b0}}    , cfg_trig_pre_samp};       end
      TRIG_POST_SAMP_ADDR    : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-TRIG_CNT_BITS{1'b0}}    , cfg_trig_post_samp};      end
      TRIG_PRE_CNT_ADDR      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {sts_trig_pre_overflow_i   , sts_trig_pre_cnt_i[30:0]};  end
      TRIG_POST_CNT_ADDR     : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {sts_trig_post_overflow_i  , sts_trig_post_cnt_i[30:0]}; end
      FILT_BYPASS_ADDR       : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32- 1{1'b0}}               , cfg_filt_bypass};         end

      DIAG_REG1              : begin  reg_ack_adc = 1'b1;       reg_rdat_adc =                                diag1_i;                  end
      DIAG_REG2              : begin  reg_ack_adc = 1'b1;       reg_rdat_adc =                                diag2_i;                  end
      DIAG_REG3              : begin  reg_ack_adc = 1'b1;       reg_rdat_adc =                                diag3_i;                  end
      DIAG_REG4              : begin  reg_ack_adc = 1'b1;       reg_rdat_adc =                                diag4_i;                  end
      STATUS_REG             : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32- 2{1'b0}}               , daisy_slave, pll_locked}; end

      CALIB_OFFSET_ADDR_CH1  : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-16{1'b0}}               , cfg_calib_offset[1*16-1:0*16]};    end
      CALIB_OFFSET_ADDR_CH2  : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-16{1'b0}}               , cfg_calib_offset[2*16-1:1*16]};    end
      CALIB_OFFSET_ADDR_CH3  : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-16{1'b0}}               , cfg_calib_offset[3*16-1:2*16]};    end
      CALIB_OFFSET_ADDR_CH4  : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-16{1'b0}}               , cfg_calib_offset[4*16-1:3*16]};    end

      CALIB_GAIN_ADDR_CH1    : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-16{1'b0}}               , cfg_calib_gain[1*16-1:0*16]};      end
      CALIB_GAIN_ADDR_CH2    : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-16{1'b0}}               , cfg_calib_gain[2*16-1:1*16]};      end
      CALIB_GAIN_ADDR_CH3    : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-16{1'b0}}               , cfg_calib_gain[3*16-1:2*16]};      end
      CALIB_GAIN_ADDR_CH4    : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-16{1'b0}}               , cfg_calib_gain[4*16-1:3*16]};      end

      FILT_COEFF_AA_CH1      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-18{1'b0}}               , cfg_filt_coeff_aa[1*18-1:0*18]};   end
      FILT_COEFF_AA_CH2      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-18{1'b0}}               , cfg_filt_coeff_aa[2*18-1:1*18]};   end
      FILT_COEFF_AA_CH3      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-18{1'b0}}               , cfg_filt_coeff_aa[3*18-1:2*18]};   end
      FILT_COEFF_AA_CH4      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-18{1'b0}}               , cfg_filt_coeff_aa[4*18-1:3*18]};   end

      FILT_COEFF_BB_CH1      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_bb[1*25-1:0*25]};   end
      FILT_COEFF_BB_CH2      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_bb[2*25-1:1*25]};   end
      FILT_COEFF_BB_CH3      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_bb[3*25-1:2*25]};   end
      FILT_COEFF_BB_CH4      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_bb[4*25-1:3*25]};   end

      FILT_COEFF_KK_CH1      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_kk[1*25-1:0*25]};   end
      FILT_COEFF_KK_CH2      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_kk[2*25-1:1*25]};   end
      FILT_COEFF_KK_CH3      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_kk[3*25-1:2*25]};   end
      FILT_COEFF_KK_CH4      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_kk[4*25-1:3*25]};   end

      FILT_COEFF_PP_CH1      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_pp[1*25-1:0*25]};   end
      FILT_COEFF_PP_CH2      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_pp[2*25-1:1*25]};   end
      FILT_COEFF_PP_CH3      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_pp[3*25-1:2*25]};   end
      FILT_COEFF_PP_CH4      : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-25{1'b0}}               , cfg_filt_coeff_pp[4*25-1:3*25]};   end

      default : begin  reg_ack_adc = 1'b1;       reg_rdat_adc = {32{1'b0}} ; end
   endcase
end

always @(posedge clk_axi_i)
   cfg_dma_ctrl_we <= reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_CTRL_ADDR);
///////////////////////////////////////////////////////////////////////////////////////////
// Write logic AXI regs
///////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk_axi_i)
begin
   if (adc_rstn_i == 1'b0) begin
      cfg_dma_ctrl            <= 32'h0;
      cfg_dma_buf_size        <= 32'h0;
      cfg_dma_dst_addr1       <= {4{32'h0}};
      cfg_dma_dst_addr2       <= {4{32'h0}};

   end else begin
      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_CTRL_ADDR    ))  cfg_dma_ctrl            <= reg_wdat_axi;
      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_BUF_SIZE_ADDR))  cfg_dma_buf_size        <= reg_wdat_axi[32-1:0];

      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_DST_ADDR1_CH1))  cfg_dma_dst_addr1[1*32-1:0*32] <= reg_wdat_axi[32-1:0];
      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_DST_ADDR1_CH2))  cfg_dma_dst_addr1[2*32-1:1*32] <= reg_wdat_axi[32-1:0];
      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_DST_ADDR1_CH3))  cfg_dma_dst_addr1[3*32-1:2*32] <= reg_wdat_axi[32-1:0];
      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_DST_ADDR1_CH4))  cfg_dma_dst_addr1[4*32-1:3*32] <= reg_wdat_axi[32-1:0];

      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_DST_ADDR2_CH1))  cfg_dma_dst_addr2[1*32-1:0*32] <= reg_wdat_axi[32-1:0];
      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_DST_ADDR2_CH2))  cfg_dma_dst_addr2[2*32-1:1*32] <= reg_wdat_axi[32-1:0];
      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_DST_ADDR2_CH3))  cfg_dma_dst_addr2[3*32-1:2*32] <= reg_wdat_axi[32-1:0];
      if (reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_DST_ADDR2_CH4))  cfg_dma_dst_addr2[4*32-1:3*32] <= reg_wdat_axi[32-1:0];

   end
end

///////////////////////////////////////////////////////////////////////////////////////////
// Read logic AXI regs
///////////////////////////////////////////////////////////////////////////////////////////
always @ (*) 
begin
   casez(reg_ofs_axi[12-1:0])
      DMA_CTRL_ADDR          : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_ctrl;                end
      DMA_STS_ADDR           : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_sts_i;               end
      DMA_BUF_SIZE_ADDR      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_buf_size;            end

      DMA_DST_ADDR1_CH1      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_dst_addr1[1*32-1:0*32]; end
      DMA_DST_ADDR1_CH2      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_dst_addr1[2*32-1:1*32]; end
      DMA_DST_ADDR1_CH3      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_dst_addr1[3*32-1:2*32]; end
      DMA_DST_ADDR1_CH4      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_dst_addr1[4*32-1:3*32]; end

      DMA_DST_ADDR2_CH1      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_dst_addr2[1*32-1:0*32]; end
      DMA_DST_ADDR2_CH2      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_dst_addr2[2*32-1:1*32]; end
      DMA_DST_ADDR2_CH3      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_dst_addr2[3*32-1:2*32]; end
      DMA_DST_ADDR2_CH4      : begin  reg_ack_axi = 1'b1; reg_rdat_axi = cfg_dma_dst_addr2[4*32-1:3*32]; end

      BUF1_LOST_SAMP_CNT_CH1 : begin  reg_ack_axi = 1'b1; reg_rdat_axi = buf1_ms_cnt_i[1*32-1:0*32];  end
      BUF1_LOST_SAMP_CNT_CH2 : begin  reg_ack_axi = 1'b1; reg_rdat_axi = buf1_ms_cnt_i[2*32-1:1*32];  end
      BUF1_LOST_SAMP_CNT_CH3 : begin  reg_ack_axi = 1'b1; reg_rdat_axi = buf1_ms_cnt_i[3*32-1:2*32];  end
      BUF1_LOST_SAMP_CNT_CH4 : begin  reg_ack_axi = 1'b1; reg_rdat_axi = buf1_ms_cnt_i[4*32-1:3*32];  end

      BUF2_LOST_SAMP_CNT_CH1 : begin  reg_ack_axi = 1'b1; reg_rdat_axi = buf2_ms_cnt_i[1*32-1:0*32];  end
      BUF2_LOST_SAMP_CNT_CH2 : begin  reg_ack_axi = 1'b1; reg_rdat_axi = buf2_ms_cnt_i[2*32-1:1*32];  end
      BUF2_LOST_SAMP_CNT_CH3 : begin  reg_ack_axi = 1'b1; reg_rdat_axi = buf2_ms_cnt_i[3*32-1:2*32];  end
      BUF2_LOST_SAMP_CNT_CH4 : begin  reg_ack_axi = 1'b1; reg_rdat_axi = buf2_ms_cnt_i[4*32-1:3*32];  end

      CURR_WP_CH1            : begin  reg_ack_axi = 1'b1; reg_rdat_axi = curr_wp_i[1*32-1:0*32];      end
      CURR_WP_CH2            : begin  reg_ack_axi = 1'b1; reg_rdat_axi = curr_wp_i[2*32-1:1*32];      end
      CURR_WP_CH3            : begin  reg_ack_axi = 1'b1; reg_rdat_axi = curr_wp_i[3*32-1:2*32];      end
      CURR_WP_CH4            : begin  reg_ack_axi = 1'b1; reg_rdat_axi = curr_wp_i[4*32-1:3*32];      end

      default : begin  reg_ack_axi = 1'b1;       reg_rdat_axi = {32{1'b0}} ; end
   endcase
end

assign cfg_event_op_trig_o     = event_op_reg[3] | event_op_reg_r[3];
assign cfg_event_op_stop_o     = event_op_reg[2] | event_op_reg_r[2];
assign cfg_event_op_start_o    = event_op_reg[1] | event_op_reg_r[1];
assign cfg_event_op_reset_o    = event_op_reg[0] | event_op_reg_r[0];
assign cfg_event_sel_o         = cfg_event_sel;
assign cfg_trig_mask_o         = cfg_trig_mask;
assign cfg_trig_pre_samp_o     = cfg_trig_pre_samp;
assign cfg_trig_post_samp_o    = cfg_trig_post_samp;
assign cfg_trig_low_level_o    = cfg_trig_low_level;
assign cfg_trig_high_level_o   = cfg_trig_high_level;
assign cfg_trig_edge_o         = cfg_trig_edge;

assign cfg_dec_factor_o        = cfg_dec_factor;
assign cfg_dec_rshift_o        = cfg_dec_rshift;
assign cfg_avg_en_o            = cfg_avg_en;
assign cfg_loopback_o          = cfg_loopback;
assign cfg_8bit_dat_o          = cfg_8bit_dat;
assign cfg_dma_ctrl_o          = cfg_dma_ctrl;
assign cfg_dma_ctrl_we_o       = cfg_dma_ctrl_we;


assign cfg_filt_bypass_o       = cfg_filt_bypass;
assign cfg_dma_buf_size_o      = cfg_dma_buf_size;


assign cfg_filt_coeff_aa_o     = cfg_filt_coeff_aa;
assign cfg_filt_coeff_bb_o     = cfg_filt_coeff_bb;
assign cfg_filt_coeff_kk_o     = cfg_filt_coeff_kk;
assign cfg_filt_coeff_pp_o     = cfg_filt_coeff_pp;

assign cfg_dma_dst_addr1_o     = cfg_dma_dst_addr1;
assign cfg_dma_dst_addr2_o     = cfg_dma_dst_addr2;

assign cfg_calib_offset_o      = cfg_calib_offset;
assign cfg_calib_gain_o        = cfg_calib_gain;

//--------------------------------------------------------------------------------------
wire    reg_write_synced_adc ;
wire    reg_read_synced_adc  ;
wire    reg_write_synced_axi ;
wire    reg_read_synced_axi  ;

wire    reg_ack_sync_adc = (reg_write_adc || reg_read_adc) && reg_ack_adc ;
wire    reg_ack_sync_axi = (reg_write_axi || reg_read_axi) && reg_ack_axi ;

wire    ctrl_we_adc  = !axi_clk_regs & bus.wen & ~bus.addr[13-1];
wire    ctrl_re_adc  = !axi_clk_regs & bus.ren & ~bus.addr[13-1];
wire    ctrl_we_axi  =  axi_clk_regs & bus.wen & ~bus.addr[13-1];
wire    ctrl_re_axi  =  axi_clk_regs & bus.ren & ~bus.addr[13-1];
wire    ctrl_ack_axi ;
wire    ctrl_ack_adc ;

wire [32-1:0] reg_rdat;
wire          ctrl_ack ;

reg           fclk_ack;
reg  [32-1:0] fclk_rdat;

assign ctrl_ack  = axi_clk_regs ? ctrl_ack_axi : ctrl_ack_adc;
assign reg_rdat  = axi_clk_regs ? reg_rdat_axi : reg_rdat_adc;

assign bus.rdata = bus.addr[13-1] ? fclk_rdat : reg_rdat;
assign bus.ack   = bus.addr[13-1] ? fclk_ack  : ctrl_ack;

sync_rw_single
#(
  .REG_RST_ACT_LVL    (  1'b0            ) ,
  .CTRL_RST_ACT_LVL   (  1'b0            )
)
i_sync_single_adc
(
  .ctrl_clk_i (   s_axi_reg_aclk    ) ,
  .ctrl_rst_i (   s_axi_reg_aresetn ) ,

  .reg_clk_i  (   clk_adc_i         ) ,
  .reg_rst_i  (   adc_rstn_i        ) ,

  .ctrl_we_i  (   ctrl_we_adc       ) ,
  .ctrl_re_i  (   ctrl_re_adc       ) ,
  .ctrl_ack_o (   ctrl_ack_adc      ) , //bus.ack

  .reg_we_o   (   reg_write_synced_adc) ,
  .reg_re_o   (   reg_read_synced_adc ) ,
  .reg_ack_i  (   reg_ack_sync_adc    )
);


sync_rw_single
#(
  .REG_RST_ACT_LVL    (  1'b0            ) ,
  .CTRL_RST_ACT_LVL   (  1'b0            )
)
i_sync_single_axi
(
  .ctrl_clk_i (   s_axi_reg_aclk    ) ,
  .ctrl_rst_i (   s_axi_reg_aresetn ) ,

  .reg_clk_i  (   clk_axi_i         ) ,
  .reg_rst_i  (   axi_rstn_i        ) ,

  .ctrl_we_i  (   ctrl_we_axi       ) ,
  .ctrl_re_i  (   ctrl_re_axi       ) ,
  .ctrl_ack_o (   ctrl_ack_axi      ) , //bus.ack

  .reg_we_o   (   reg_write_synced_axi) ,
  .reg_re_o   (   reg_read_synced_axi ) ,
  .reg_ack_i  (   reg_ack_sync_axi    )
);

always @ (posedge clk_adc_i)
begin
   if (adc_rstn_i == 1'b0)
   begin
      reg_write_adc <= 1'b0 ;
      reg_read_adc <= 1'b0 ;
   end else
   begin
      reg_write_adc <= reg_write_adc ? !reg_ack_adc : reg_write_synced_adc ;
      reg_read_adc  <= reg_read_adc  ? !reg_ack_adc : reg_read_synced_adc ;
   end
end

always @ (posedge clk_adc_i)
begin
   if (reg_write_synced_adc || reg_read_synced_adc)
   begin
      reg_ofs_adc  <= bus.addr[12-1:0] ;
      reg_wdat_adc <= bus.wdata ;
   end
end

always @ (posedge clk_axi_i)
begin
   if (axi_rstn_i == 1'b0)
   begin
      reg_write_axi <= 1'b0 ;
      reg_read_axi <= 1'b0 ;
   end else
   begin
      reg_write_axi <= reg_write_axi ? !reg_ack_axi : reg_write_synced_axi ;
      reg_read_axi  <= reg_read_axi  ? !reg_ack_axi : reg_read_synced_axi ;
   end
end

always @ (posedge clk_axi_i)
begin
   if (reg_write_synced_axi || reg_read_synced_axi)
   begin
      reg_ofs_axi  <= bus.addr[12-1:0] ;
      reg_wdat_axi <= bus.wdata ;
   end
end

always @ (posedge s_axi_reg_aclk)
begin
   if (s_axi_reg_aresetn == 1'b0)
      clksel_o <= 1'b0 ;
   else begin 
      if (bus.wen & bus.addr[16-1:0] == CLKSEL_REG) begin
         if (bus.wen) clksel_o <= bus.wdata[0] ;
      end
   end
end

always @ (*)
begin
   if (bus.addr[16-1:0] == CLKSEL_REG) begin
      fclk_ack  = 1'b1;
      fclk_rdat = {31'h0,clksel_o};
   end else begin
      fclk_ack  = 1'b1;
      fclk_rdat = 32'h0;   
   end
end
endmodule


