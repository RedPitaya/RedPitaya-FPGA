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
   input  wire [3:0]                             s_axi_reg_awid,     
   input  wire [3:0]                             s_axi_reg_arid,     
   input  wire [3:0]                             s_axi_reg_wid,     
   output wire [3:0]                             s_axi_reg_rid,     
   output wire [3:0]                             s_axi_reg_bid,     

   // signals
   input                               clk_i                   ,
   input                               rstn_i                  ,

   output wire                         cfg_event_op_trig_o     ,
   output wire                         cfg_event_op_stop_o     ,
   output wire                         cfg_event_op_start_o    ,
   output wire                         cfg_event_op_reset_o    ,
   output wire [               4-1:0]  cfg_event_sts_i         ,
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
   output wire [              16-1:0]  cfg_loopback_o          ,
   output wire                         cfg_8bit_dat_o          ,
   output wire [              16-1:0]  cfg_calib_offset_ch1_o  ,
   output wire [              16-1:0]  cfg_calib_offset_ch2_o  ,
   output wire [              16-1:0]  cfg_calib_gain_ch1_o    ,
   output wire [              16-1:0]  cfg_calib_gain_ch2_o    ,
   output reg                          clksel_o            ,

   output wire                         cfg_filt_bypass_o       ,
   output wire [              18-1:0]  cfg_filt_coeff_aa_ch1_o ,
   output wire [              25-1:0]  cfg_filt_coeff_bb_ch1_o ,
   output wire [              25-1:0]  cfg_filt_coeff_kk_ch1_o ,
   output wire [              25-1:0]  cfg_filt_coeff_pp_ch1_o ,
   output wire [              18-1:0]  cfg_filt_coeff_aa_ch2_o ,
   output wire [              25-1:0]  cfg_filt_coeff_bb_ch2_o ,
   output wire [              25-1:0]  cfg_filt_coeff_kk_ch2_o ,
   output wire [              25-1:0]  cfg_filt_coeff_pp_ch2_o ,

   output wire [              32-1:0]  cfg_dma_dst_addr1_ch1_o ,
   output wire [              32-1:0]  cfg_dma_dst_addr2_ch1_o ,
   output wire [              32-1:0]  cfg_dma_dst_addr1_ch2_o ,
   output wire [              32-1:0]  cfg_dma_dst_addr2_ch2_o ,
   output wire [              32-1:0]  cfg_dma_buf_size_o      ,
   output wire [              32-1:0]  cfg_dma_ctrl_o          ,
   output wire                         cfg_dma_ctrl_we_o       ,
   input  wire [              32-1:0]  cfg_dma_sts_i           ,


   input  wire [              32-1:0]  buf1_ms_cnt_ch1_i       ,
   input  wire [              32-1:0]  buf2_ms_cnt_ch1_i       ,
   input  wire [              32-1:0]  buf1_ms_cnt_ch2_i       ,
   input  wire [              32-1:0]  buf2_ms_cnt_ch2_i       ,

   input  wire [              32-1:0]  curr_wp_ch1_i           ,
   input  wire [              32-1:0]  curr_wp_ch2_i           ,

   input  wire [              32-1:0]  diag1_i                 ,
   input  wire [              32-1:0]  diag2_i                 ,
   input  wire [              32-1:0]  diag3_i                 ,
   input  wire [              32-1:0]  diag4_i
);




// more or less globaly spread signals
reg            reg_write ;
reg            reg_read  ;
reg  [12-1: 0] reg_ofs   ;
reg  [32-1: 0] reg_wdat  ;
reg  [ 4-1: 0] reg_sel   ;
reg            reg_ack  ;
reg  [32-1: 0] reg_rdat ;

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

localparam DMA_CTRL_ADDR_CH1        = 12'h50;  // DMA control register
localparam DMA_STS_ADDR_CH1         = 12'h54;  // DMA status register
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
localparam DMA_CTRL_ADDR_CH2        = 12'h8C;  // DMA control register CH2
localparam DMA_STS_ADDR_CH2         = 12'h90;  // DMA status register CH2
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

localparam DIAG_REG1                = 12'hE0; // interrupt counter
localparam DIAG_REG2                = 12'hE4; // external trigger counter
localparam DIAG_REG3                = 12'hE8; // clock counter
localparam DIAG_REG4                = 12'hEC; // status of state machine

localparam READY_REG                = 12'h100;   // status of FPGA clock
localparam CLKSEL_REG               = 16'h1000;  // FPGA mode


reg  [           3-1:0]     cfg_event_sel;
reg  [TRIG_SRC_NUM-1:0]     cfg_trig_mask;

reg  [TRIG_CNT_BITS-1:0]    cfg_trig_pre_samp;
reg  [TRIG_CNT_BITS-1:0]    cfg_trig_post_samp;

reg  [S_AXIS_DATA_BITS-1:0] cfg_trig_low_level;
reg  [S_AXIS_DATA_BITS-1:0] cfg_trig_high_level;
reg                         cfg_trig_edge;  

reg                         cfg_avg_en; 
reg  [DEC_CNT_BITS-1:0]     cfg_dec_factor;  
reg  [DEC_SHIFT_BITS-1:0]   cfg_dec_rshift;  
reg  [            16-1:0]   cfg_loopback;

reg                         cfg_filt_bypass;  
reg signed [18-1:0]         cfg_filt_coeff_aa_ch1; 
reg signed [25-1:0]         cfg_filt_coeff_bb_ch1; 
reg signed [25-1:0]         cfg_filt_coeff_kk_ch1; 
reg signed [25-1:0]         cfg_filt_coeff_pp_ch1; 
reg signed [18-1:0]         cfg_filt_coeff_aa_ch2; 
reg signed [25-1:0]         cfg_filt_coeff_bb_ch2; 
reg signed [25-1:0]         cfg_filt_coeff_kk_ch2; 
reg signed [25-1:0]         cfg_filt_coeff_pp_ch2; 


reg  [32-1:0]               cfg_dma_dst_addr1_ch1;
reg  [32-1:0]               cfg_dma_dst_addr2_ch1;
reg  [32-1:0]               cfg_dma_dst_addr1_ch2;
reg  [32-1:0]               cfg_dma_dst_addr2_ch2;
reg  [32-1:0]               cfg_dma_buf_size;
reg                         cfg_8bit_dat;
reg  [32-1:0]               cfg_dma_ctrl;
reg                         cfg_dma_ctrl_we;
reg                         cfg_clksel;

reg  [16-1:0]               cfg_calib_offset_ch1;
reg  [16-1:0]               cfg_calib_gain_ch1;
reg  [16-1:0]               cfg_calib_offset_ch2;
reg  [16-1:0]               cfg_calib_gain_ch2;

reg  [ 4-1: 0]              event_op_reg;

sys_bus_if bus (.clk (s_axi_reg_aclk), .rstn (s_axi_reg_aresetn));
axi4_if #(.DW (32), .AW (REG_ADDR_BITS), .IW (4), .LW (4)) axi_gp (.ACLK (s_axi_reg_aclk), .ARESETn (s_axi_reg_aresetn));

wire [ 4-1:0] s_axi_reg_awlen   = 4'h0;    // single word burst
wire [ 3-1:0] s_axi_reg_awsize  = 3'b010;  // 4 bytes
wire [ 3-1:0] s_axi_reg_awburst = 3'b00;   // fixed
wire [ 2-1:0] s_axi_reg_awlock  = 2'h00;   // normal
wire [ 4-1:0] s_axi_reg_awcache = 4'b0011; // non-cacheable
wire          s_axi_reg_wlast   = 1'b0;    // not last
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
assign axi_gp.BID     = s_axi_reg_bid      ;
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
assign axi_gp.RID     = s_axi_reg_rid      ;
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
  .IW (4)
) axi_slave (
  // AXI bus
  .axi       (axi_gp),
  // system read/write channel
  .bus       (bus)
);

///////////////////////////////////////////////////////////////////////////////////////////
// Write logic
///////////////////////////////////////////////////////////////////////////////////////////
reg [4-1:0] event_op_reg_r;
always @(posedge clk_i) begin
   event_op_reg_r <= event_op_reg;
end
always @(posedge clk_i)
begin
   if (rstn_i == 1'b0) begin
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
      cfg_loopback            <= 16'h0;
      cfg_filt_bypass         <=  1'b1;
      cfg_filt_coeff_aa_ch1   <= 18'h0;
      cfg_filt_coeff_bb_ch1   <= 25'h0;
      cfg_filt_coeff_kk_ch1   <= 25'hffffff;
      cfg_filt_coeff_pp_ch1   <= 25'h0;
      cfg_filt_coeff_aa_ch2   <= 18'h0;
      cfg_filt_coeff_bb_ch2   <= 25'h0;
      cfg_filt_coeff_kk_ch2   <= 25'hffffff;
      cfg_filt_coeff_pp_ch2   <= 25'h0;
      cfg_dma_ctrl            <= 32'h0;
      cfg_dma_dst_addr1_ch1   <= 32'h0;
      cfg_dma_dst_addr2_ch1   <= 32'h0;
      cfg_dma_dst_addr1_ch2   <= 32'h0;
      cfg_dma_dst_addr2_ch2   <= 32'h0;
      cfg_dma_buf_size        <= 32'h0;
      cfg_calib_offset_ch1    <= 16'h0;
      cfg_calib_offset_ch2    <= 16'h0;
      cfg_calib_gain_ch1      <= 16'h8000;
      cfg_calib_gain_ch2      <= 16'h8000;
      cfg_8bit_dat            <=  1'b0;

   end else begin
      if (reg_write && (reg_ofs[12-1:0]==EVENT_STS_ADDR)        )  event_op_reg            <= reg_wdat[3:0]; else event_op_reg <= 4'h0;
      if (reg_write && (reg_ofs[12-1:0]==EVENT_SEL_ADDR)        )  cfg_event_sel           <= reg_wdat[3-1:0];
      if (reg_write && (reg_ofs[12-1:0]==TRIG_MASK_ADDR )       )  cfg_trig_mask           <= reg_wdat[TRIG_SRC_NUM-1:0];
      if (reg_write && (reg_ofs[12-1:0]==TRIG_PRE_SAMP_ADDR)    )  cfg_trig_pre_samp       <= reg_wdat[TRIG_CNT_BITS-1:0];
      if (reg_write && (reg_ofs[12-1:0]==TRIG_POST_SAMP_ADDR)   )  cfg_trig_post_samp      <= reg_wdat[TRIG_CNT_BITS-1:0];
      if (reg_write && (reg_ofs[12-1:0]==TRIG_LOW_LEVEL_ADDR)   )  cfg_trig_low_level      <= reg_wdat[S_AXIS_DATA_BITS-1:0];
      if (reg_write && (reg_ofs[12-1:0]==TRIG_HIGH_LEVEL_ADDR)  )  cfg_trig_high_level     <= reg_wdat[S_AXIS_DATA_BITS-1:0];
      if (reg_write && (reg_ofs[12-1:0]==TRIG_HIGH_LEVEL_ADDR)  )  cfg_trig_edge           <= reg_wdat[0];
      if (reg_write && (reg_ofs[12-1:0]==DEC_FACTOR_ADDR)       )  cfg_dec_factor          <= reg_wdat[DEC_CNT_BITS-1:0];
      if (reg_write && (reg_ofs[12-1:0]==DEC_RSHIFT_ADDR)       )  cfg_dec_rshift          <= reg_wdat[DEC_SHIFT_BITS-1:0];
      if (reg_write && (reg_ofs[12-1:0]==AVG_EN_ADDR)           )  cfg_avg_en              <= reg_wdat[0];
      if (reg_write && (reg_ofs[12-1:0]==LOOPBACK_ADDR)         )  cfg_loopback            <= reg_wdat[16-1:0];
      if (reg_write && (reg_ofs[12-1:0]==SHIFT_8BIT)            )  cfg_8bit_dat            <= reg_wdat[0];
      if (reg_write && (reg_ofs[12-1:0]==CALIB_OFFSET_ADDR_CH1) )  cfg_calib_offset_ch1    <= reg_wdat[16-1:0];
      if (reg_write && (reg_ofs[12-1:0]==CALIB_GAIN_ADDR_CH1)   )  cfg_calib_gain_ch1      <= reg_wdat[16-1:0];
      if (reg_write && (reg_ofs[12-1:0]==CALIB_OFFSET_ADDR_CH2) )  cfg_calib_offset_ch2    <= reg_wdat[16-1:0];
      if (reg_write && (reg_ofs[12-1:0]==CALIB_GAIN_ADDR_CH2)   )  cfg_calib_gain_ch2      <= reg_wdat[16-1:0];
      if (reg_write && (reg_ofs[12-1:0]==DMA_CTRL_ADDR_CH1)     )  cfg_dma_ctrl            <= reg_wdat;
      if (reg_write && (reg_ofs[12-1:0]==DMA_DST_ADDR1_CH1)     )  cfg_dma_dst_addr1_ch1   <= reg_wdat[32-1:0];
      if (reg_write && (reg_ofs[12-1:0]==DMA_DST_ADDR2_CH1)     )  cfg_dma_dst_addr2_ch1   <= reg_wdat[32-1:0];
      if (reg_write && (reg_ofs[12-1:0]==DMA_DST_ADDR1_CH2)     )  cfg_dma_dst_addr1_ch2   <= reg_wdat[32-1:0];
      if (reg_write && (reg_ofs[12-1:0]==DMA_DST_ADDR2_CH2)     )  cfg_dma_dst_addr2_ch2   <= reg_wdat[32-1:0];
      if (reg_write && (reg_ofs[12-1:0]==DMA_BUF_SIZE_ADDR)     )  cfg_dma_buf_size        <= reg_wdat[32-1:0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_BYPASS_ADDR)      )  cfg_filt_bypass         <= reg_wdat[0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_COEFF_AA_CH1)     )  cfg_filt_coeff_aa_ch1   <= reg_wdat[18-1:0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_COEFF_BB_CH1)     )  cfg_filt_coeff_bb_ch1   <= reg_wdat[25-1:0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_COEFF_KK_CH1)     )  cfg_filt_coeff_kk_ch1   <= reg_wdat[25-1:0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_COEFF_PP_CH1)     )  cfg_filt_coeff_pp_ch1   <= reg_wdat[25-1:0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_COEFF_AA_CH2)     )  cfg_filt_coeff_aa_ch2   <= reg_wdat[18-1:0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_COEFF_BB_CH2)     )  cfg_filt_coeff_bb_ch2   <= reg_wdat[25-1:0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_COEFF_KK_CH2)     )  cfg_filt_coeff_kk_ch2   <= reg_wdat[25-1:0];
      if (reg_write && (reg_ofs[12-1:0]==FILT_COEFF_PP_CH2)     )  cfg_filt_coeff_pp_ch2   <= reg_wdat[25-1:0];
   end
end

always @(posedge clk_i)
   cfg_dma_ctrl_we <= reg_write && (reg_ofs[12-1:0]==DMA_CTRL_ADDR_CH1);

reg [32-1:0] dma_ctrl1, dma_ctrl2, dma_ctrl3, dma_ctrl4;
always @(posedge clk_i) begin
   if (reg_write && (reg_ofs[12-1:0]==EVENT_STS_ADDR)) begin
      dma_ctrl1 <= reg_wdat[3:0];
      dma_ctrl2 <= dma_ctrl1;
      dma_ctrl3 <= dma_ctrl2;
      dma_ctrl4 <= dma_ctrl3;
   end
end

///////////////////////////////////////////////////////////////////////////////////////////
// Read logic
///////////////////////////////////////////////////////////////////////////////////////////
always @ (*) 
begin
   casez(reg_ofs[12-1:0])
      EVENT_STS_ADDR         : begin  reg_ack = 1'b1;       reg_rdat = {{32-4{1'b0}}                , cfg_event_sts_i};         end
      EVENT_SEL_ADDR         : begin  reg_ack = 1'b1;       reg_rdat = {{32-3{1'b0}}                , cfg_event_sel};           end
      TRIG_MASK_ADDR         : begin  reg_ack = 1'b1;       reg_rdat = {{32-TRIG_SRC_NUM{1'b0}}     , cfg_trig_mask};           end
      TRIG_PRE_SAMP_ADDR     : begin  reg_ack = 1'b1;       reg_rdat = {{32-TRIG_CNT_BITS{1'b0}}    , cfg_trig_pre_samp};       end
      TRIG_POST_SAMP_ADDR    : begin  reg_ack = 1'b1;       reg_rdat = {{32-TRIG_CNT_BITS{1'b0}}    , cfg_trig_post_samp};      end
      TRIG_PRE_CNT_ADDR      : begin  reg_ack = 1'b1;       reg_rdat = {sts_trig_pre_overflow_i   , sts_trig_pre_cnt_i[30:0]};  end
      TRIG_POST_CNT_ADDR     : begin  reg_ack = 1'b1;       reg_rdat = {sts_trig_post_overflow_i  , sts_trig_post_cnt_i[30:0]}; end
      CALIB_OFFSET_ADDR_CH1  : begin  reg_ack = 1'b1;       reg_rdat = {{32-16{1'b0}}               , cfg_calib_offset_ch1};    end
      CALIB_GAIN_ADDR_CH1    : begin  reg_ack = 1'b1;       reg_rdat = {{32-16{1'b0}}               , cfg_calib_gain_ch1};      end
      CALIB_OFFSET_ADDR_CH2  : begin  reg_ack = 1'b1;       reg_rdat = {{32-16{1'b0}}               , cfg_calib_offset_ch2};    end
      CALIB_GAIN_ADDR_CH2    : begin  reg_ack = 1'b1;       reg_rdat = {{32-16{1'b0}}               , cfg_calib_gain_ch2};      end
      FILT_BYPASS_ADDR       : begin  reg_ack = 1'b1;       reg_rdat = {{32- 1{1'b0}}               , cfg_filt_bypass};         end
      DMA_CTRL_ADDR_CH1      : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_ctrl; end
      DMA_STS_ADDR_CH1       : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_sts_i;            end
      DMA_CTRL_ADDR_CH2      : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_ctrl; end
      DMA_STS_ADDR_CH2       : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_sts_i;            end
      DMA_DST_ADDR1_CH1      : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_dst_addr1_ch1;    end
      DMA_DST_ADDR2_CH1      : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_dst_addr2_ch1;    end
      DMA_DST_ADDR1_CH2      : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_dst_addr1_ch2;    end
      DMA_DST_ADDR2_CH2      : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_dst_addr2_ch2;    end
      DMA_BUF_SIZE_ADDR      : begin  reg_ack = 1'b1;       reg_rdat =                                cfg_dma_buf_size;         end
      BUF1_LOST_SAMP_CNT_CH1 : begin  reg_ack = 1'b1;       reg_rdat =                                buf1_ms_cnt_ch1_i;        end
      BUF2_LOST_SAMP_CNT_CH1 : begin  reg_ack = 1'b1;       reg_rdat =                                buf2_ms_cnt_ch1_i;        end
      BUF1_LOST_SAMP_CNT_CH2 : begin  reg_ack = 1'b1;       reg_rdat =                                buf1_ms_cnt_ch2_i;        end
      BUF2_LOST_SAMP_CNT_CH2 : begin  reg_ack = 1'b1;       reg_rdat =                                buf2_ms_cnt_ch2_i;        end
      CURR_WP_CH1            : begin  reg_ack = 1'b1;       reg_rdat =                                curr_wp_ch1_i;            end
      CURR_WP_CH2            : begin  reg_ack = 1'b1;       reg_rdat =                                curr_wp_ch2_i;            end
      FILT_COEFF_AA_CH1      : begin  reg_ack = 1'b1;       reg_rdat = {{32-18{1'b0}}               , cfg_filt_coeff_aa_ch1};   end
      FILT_COEFF_BB_CH1      : begin  reg_ack = 1'b1;       reg_rdat = {{32-25{1'b0}}               , cfg_filt_coeff_bb_ch1};   end
      FILT_COEFF_KK_CH1      : begin  reg_ack = 1'b1;       reg_rdat = {{32-25{1'b0}}               , cfg_filt_coeff_kk_ch1};   end
      FILT_COEFF_PP_CH1      : begin  reg_ack = 1'b1;       reg_rdat = {{32-25{1'b0}}               , cfg_filt_coeff_pp_ch1};   end
      FILT_COEFF_AA_CH2      : begin  reg_ack = 1'b1;       reg_rdat = {{32-18{1'b0}}               , cfg_filt_coeff_aa_ch2};   end
      FILT_COEFF_BB_CH2      : begin  reg_ack = 1'b1;       reg_rdat = {{32-25{1'b0}}               , cfg_filt_coeff_bb_ch2};   end
      FILT_COEFF_KK_CH2      : begin  reg_ack = 1'b1;       reg_rdat = {{32-25{1'b0}}               , cfg_filt_coeff_kk_ch2};   end
      FILT_COEFF_PP_CH2      : begin  reg_ack = 1'b1;       reg_rdat = {{32-25{1'b0}}               , cfg_filt_coeff_pp_ch2};   end
      DIAG_REG1              : begin  reg_ack = 1'b1;       reg_rdat =                                diag1_i;                  end
      DIAG_REG2              : begin  reg_ack = 1'b1;       reg_rdat =                                diag2_i;                  end
      DIAG_REG3              : begin  reg_ack = 1'b1;       reg_rdat =                                diag3_i;                  end
      DIAG_REG4              : begin  reg_ack = 1'b1;       reg_rdat =                                diag4_i;                  end
      READY_REG              : begin  reg_ack = 1'b1;       reg_rdat =                                rstn_i;                   end
      default : begin  reg_ack = 1'b1;       reg_rdat = {32{1'b0}} ; end
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
assign cfg_calib_offset_ch1_o  = cfg_calib_offset_ch1;
assign cfg_calib_offset_ch2_o  = cfg_calib_offset_ch2;
assign cfg_calib_gain_ch1_o    = cfg_calib_gain_ch1;
assign cfg_calib_gain_ch2_o    = cfg_calib_gain_ch2;
assign cfg_dma_ctrl_o          = cfg_dma_ctrl;
assign cfg_dma_ctrl_we_o       = cfg_dma_ctrl_we;


assign cfg_filt_bypass_o       = cfg_filt_bypass;
assign cfg_filt_coeff_aa_ch1_o = cfg_filt_coeff_aa_ch1;
assign cfg_filt_coeff_bb_ch1_o = cfg_filt_coeff_bb_ch1;
assign cfg_filt_coeff_kk_ch1_o = cfg_filt_coeff_kk_ch1;
assign cfg_filt_coeff_pp_ch1_o = cfg_filt_coeff_pp_ch1;
assign cfg_filt_coeff_aa_ch2_o = cfg_filt_coeff_aa_ch2;
assign cfg_filt_coeff_bb_ch2_o = cfg_filt_coeff_bb_ch2;
assign cfg_filt_coeff_kk_ch2_o = cfg_filt_coeff_kk_ch2;
assign cfg_filt_coeff_pp_ch2_o = cfg_filt_coeff_pp_ch2;

assign cfg_dma_dst_addr1_ch1_o = cfg_dma_dst_addr1_ch1;
assign cfg_dma_dst_addr2_ch1_o = cfg_dma_dst_addr2_ch1;
assign cfg_dma_dst_addr1_ch2_o = cfg_dma_dst_addr1_ch2;
assign cfg_dma_dst_addr2_ch2_o = cfg_dma_dst_addr2_ch2;
assign cfg_dma_buf_size_o      = cfg_dma_buf_size;
//--------------------------------------------------------------------------------------
wire    reg_write_synced ;
wire    reg_read_synced ;
wire    reg_ack_sync = (reg_write || reg_read) && reg_ack ;

wire    ctrl_we  = bus.wen & ~bus.addr[13-1];
wire    ctrl_re  = bus.ren & ~bus.addr[13-1];
wire    ctrl_ack ;

reg          fclk_ack;
reg [32-1:0] fclk_rdat;

assign bus.rdata = bus.addr[13-1] ? fclk_rdat : reg_rdat;
assign bus.ack   = bus.addr[13-1] ? fclk_ack  : ctrl_ack;

sync_rw_single
#(
  .REG_RST_ACT_LVL    (  1'b0            ) ,
  .CTRL_RST_ACT_LVL   (  1'b0            )
)
i_sync_single
(
  .ctrl_clk_i (   bus.clk           ) ,
  .ctrl_rst_i (   bus.rstn          ) ,

  .reg_clk_i  (   clk_i             ) ,
  .reg_rst_i  (   rstn_i            ) ,

  .ctrl_we_i  (   ctrl_we           ) ,
  .ctrl_re_i  (   ctrl_re           ) ,
  .ctrl_ack_o (   ctrl_ack          ) , //bus.ack

  .reg_we_o   (   reg_write_synced    ) ,
  .reg_re_o   (   reg_read_synced     ) ,
  .reg_ack_i  (   reg_ack_sync        )
);


always @ (posedge clk_i)
begin
   if (rstn_i == 1'b0)
   begin
      reg_write <= 1'b0 ;
      reg_read <= 1'b0 ;
   end else
   begin
      reg_write <= reg_write ? !reg_ack : reg_write_synced ;
      reg_read  <= reg_read  ? !reg_ack : reg_read_synced ;
   end
end

always @ (posedge clk_i)
begin
   if (reg_write_synced || reg_read_synced)
   begin
      reg_ofs  <= bus.addr[12-1:0] ;
      reg_wdat <= bus.wdata ;
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


