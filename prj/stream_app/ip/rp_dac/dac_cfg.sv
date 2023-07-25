/*
* Copyright (c) 2016 Instrumentation Technologies, d.d.
* All Rights Reserved.
*
* $Id: $
*/




module dac_cfg
#(
    parameter M_AXI_DAC_ADDR_BITS = 32, // DMA Address bits
    parameter DAC_DATA_BITS     = 16, // ADC data bits
    parameter REG_ADDR_BITS     = 32, // Register interface address bits
    parameter EVENT_SRC_NUM     = 1,  // Number of event sources
    parameter ID_WIDTHS         = 4,
    parameter TRIG_SRC_NUM      = 1   // Number of trigger sources
) // which channel
(
   // configuration ports

   input  wire                         s_axi_reg_aclk,
   input  wire                         s_axi_reg_aresetn,
   input  wire [REG_ADDR_BITS-1:0]     s_axi_reg_awaddr,
   input  wire [3-1:0]                 s_axi_reg_awprot,
   input  wire                         s_axi_reg_awvalid,
   output wire                         s_axi_reg_awready,
   input  wire [31:0]                  s_axi_reg_wdata,
   input  wire [3:0]                   s_axi_reg_wstrb,
   input  wire                         s_axi_reg_wvalid,
   output wire                         s_axi_reg_wready,
   input  wire                         s_axi_reg_wlast,
   output wire [1:0]                   s_axi_reg_bresp,
   output wire                         s_axi_reg_bvalid,
   input  wire                         s_axi_reg_bready,
   input  wire [REG_ADDR_BITS-1:0]     s_axi_reg_araddr,
   input  wire [2:0]                   s_axi_reg_arprot,
   input  wire                         s_axi_reg_arvalid,
   output wire                         s_axi_reg_arready,
   output wire [31:0]                  s_axi_reg_rdata,
   output wire [1:0]                   s_axi_reg_rresp,
   output wire                         s_axi_reg_rvalid,
   input  wire                         s_axi_reg_rready,
   output wire                         s_axi_reg_rlast,
   input  wire [ID_WIDTHS-1:0]         s_axi_reg_awid,
   input  wire [ID_WIDTHS-1:0]         s_axi_reg_arid,
   input  wire [ID_WIDTHS-1:0]         s_axi_reg_wid,
   output wire [ID_WIDTHS-1:0]         s_axi_reg_rid,
   output wire [ID_WIDTHS-1:0]         s_axi_reg_bid,

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
   output reg                          clksel_o                ,
   input  wire                         daisy_slave_i           ,


   output wire                            cfg_dma_ctrl_we_o,
   output wire [                 16-1:0]  dac_cha_conf_o,
   output wire [                 16-1:0]  dac_chb_conf_o,

   output wire [      DAC_DATA_BITS-1:0]  cfg_cha_scale_o,
   output wire [      DAC_DATA_BITS-1:0]  cfg_cha_offs_o,
   output wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_cha_step_o,
   output wire [                  5-1:0]  cfg_cha_outshift_o,
   output wire [                 16-1:0]  cfg_cha_setdec_o,

   output wire [      DAC_DATA_BITS-1:0]  cfg_chb_scale_o,
   output wire [      DAC_DATA_BITS-1:0]  cfg_chb_offs_o,
   output wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_chb_step_o,
   output wire [                  5-1:0]  cfg_chb_outshift_o,
   output wire [                 16-1:0]  cfg_chb_setdec_o,

   output wire [                  8-1:0]  cfg_ctrl_reg_cha_o,
   output wire [                  8-1:0]  cfg_ctrl_reg_chb_o,
   input  wire [                 32-1:0]  sts_cha_i,
   input  wire [                 32-1:0]  sts_chb_i,

   output wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_dma_buf_size_o,
   output wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_buf1_adr_cha_o,
   output wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_buf2_adr_cha_o,
   output wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_buf1_adr_chb_o,
   output wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_buf2_adr_chb_o,

   output wire                            cfg_loopback_cha_o,
   output wire                            cfg_loopback_chb_o,

   input  wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_cha_rp_i,
   input  wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_chb_rp_i,

   output wire                            cfg_errs_rst_o,
   input  wire [                 32-1:0]  errs_cnt_cha_i,
   input  wire [                 32-1:0]  errs_cnt_chb_i,

   input  wire [                 32-1:0]  diag1_i                 ,
   input  wire [                 32-1:0]  diag2_i                 ,
   input  wire [                 32-1:0]  diag3_i                 ,
   input  wire [                 32-1:0]  diag4_i
);




// more or less globaly spread signals
reg            reg_write_axi ;
reg            reg_write_axi_r;
reg            reg_read_axi  ;
reg            reg_read_axi_r;
reg  [12-1: 0] reg_ofs_axi   ;
reg  [32-1: 0] reg_wdat_axi  ;
reg  [12-1: 0] reg_ofs_axi_r ;
reg  [32-1: 0] reg_wdat_axi_r;
reg  [ 4-1: 0] reg_sel_axi   ;
reg            reg_ack_axi   ;
reg  [32-1: 0] reg_rdat_axi  ;
reg  [32-1: 0] reg_rdat_axi_r;

reg            reg_write_adc ;
reg            reg_write_adc_r ;
reg            reg_read_adc  ;
reg            reg_read_adc_r;
reg  [12-1: 0] reg_ofs_adc   ;
reg  [32-1: 0] reg_wdat_adc  ;
reg  [12-1: 0] reg_ofs_adc_r ;
reg  [32-1: 0] reg_wdat_adc_r;
reg  [ 4-1: 0] reg_sel_adc   ;
reg            reg_ack_adc   ;
reg  [32-1: 0] reg_rdat_adc  ;
reg  [32-1: 0] reg_rdat_adc_r;

// Address map
localparam DAC_CONF_REG         = 12'h0; 

localparam DAC_CHA_SCALE_OFFS   = 12'h4;
localparam DAC_CHA_CNT_STEP     = 12'h8;
localparam DAC_CHA_CUR_RP       = 12'hC;

localparam DAC_CHB_SCALE_OFFS   = 12'h10;
localparam DAC_CHB_CNT_STEP     = 12'h14;
localparam DAC_CHB_CUR_RP       = 12'h18;

localparam EVENT_STS_ADDR       = 12'h1C;
localparam EVENT_SEL_ADDR       = 12'h20;
localparam TRIG_MASK_ADDR       = 12'h24;

localparam DMA_CTRL_ADDR        = 12'h28;
localparam DMA_STS_ADDR         = 12'h2C;

localparam DMA_BUF_SIZE_ADDR    = 12'h34;
localparam DMA_BUF1_ADR_CHA     = 12'h38;
localparam DMA_BUF2_ADR_CHA     = 12'h3C;
localparam DMA_BUF1_ADR_CHB     = 12'h40;
localparam DMA_BUF2_ADR_CHB     = 12'h44;

localparam SETDEC_CHA           = 12'h48; // diagnostic only, to test the ramp signal.
localparam SETDEC_CHB           = 12'h4C;
localparam ERRS_RST             = 12'h50;
localparam ERRS_CNT_CHA         = 12'h54;
localparam ERRS_CNT_CHB         = 12'h58;
localparam LOOPBACK_EN          = 12'h5C;

localparam OUT_SHIFT_CH1        = 12'h60;
localparam OUT_SHIFT_CH2        = 12'h64;

localparam DIAG_REG_ADDR1       = 12'h70;
localparam DIAG_REG_ADDR2       = 12'h74;
localparam DIAG_REG_ADDR3       = 12'h78;
localparam DIAG_REG_ADDR4       = 12'h8C;
localparam STATUS_REG           = 12'h100;   // status of FPGA clock
localparam CLKSEL_REG           = 16'h1000;  // FPGA mode


reg [16-1:0]                    dac_cha_conf;
reg [16-1:0]                    dac_chb_conf;

reg [DAC_DATA_BITS-1:0]         cfg_cha_scale;
reg [DAC_DATA_BITS-1:0]         cfg_cha_offs;
reg [M_AXI_DAC_ADDR_BITS-1:0]   cfg_cha_step;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_cha_rp;
reg [ 5-1:0]                    cfg_cha_outshift;

reg [ 4-1:0]                    event_op_reg;

reg [DAC_DATA_BITS-1:0]         cfg_chb_scale;
reg [DAC_DATA_BITS-1:0]         cfg_chb_offs;
reg [M_AXI_DAC_ADDR_BITS-1:0]   cfg_chb_step;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_chb_rp;
reg [ 5-1:0]                    cfg_chb_outshift;

reg [16-1:0]                    cfg_cha_setdec;
reg [16-1:0]                    cfg_chb_setdec;

reg [EVENT_SRC_NUM-1:0]         cfg_event_sel;
reg [TRIG_SRC_NUM -1:0]         cfg_trig_mask;

reg [ 8-1:0]                    cfg_ctrl_reg_cha;
reg [ 8-1:0]                    cfg_ctrl_reg_chb;
reg                             cfg_dma_ctrl_we;

reg [M_AXI_DAC_ADDR_BITS-1:0]   cfg_dma_buf_size;
reg [M_AXI_DAC_ADDR_BITS-1:0]   cfg_buf1_adr_cha;
reg [M_AXI_DAC_ADDR_BITS-1:0]   cfg_buf1_adr_chb;
reg [M_AXI_DAC_ADDR_BITS-1:0]   cfg_buf2_adr_cha;
reg [M_AXI_DAC_ADDR_BITS-1:0]   cfg_buf2_adr_chb;

reg                             cfg_errs_rst;
reg                             cfg_loopback_cha, cfg_loopback_chb;

reg ctrl_cha;
reg ctrl_chb;

wire [31:0] ctrl_cha_o; 
wire [31:0] ctrl_chb_o;
wire [31:0] sts_cha_o; 
wire [31:0] sts_chb_o; 

wire [31:0] diag_reg;
wire [31:0] diag_reg2;


reg pll_locked;
always @(posedge clk_adc_i) begin
   if (adc_rstn_i == 1'b0)
      pll_locked <= 1'b0;
   else
      pll_locked <= 1'b1;
end

assign axi_clk_regs =  (bus.addr[12-1:0] == DMA_CTRL_ADDR          ||
                        bus.addr[12-1:0] == DMA_STS_ADDR           ||
                        bus.addr[12-1:0] == DMA_BUF_SIZE_ADDR      ||
                        bus.addr[12-1:0] == DMA_BUF1_ADR_CHA       ||
                        bus.addr[12-1:0] == DMA_BUF2_ADR_CHA       ||
                        bus.addr[12-1:0] == DMA_BUF1_ADR_CHB       ||
                        bus.addr[12-1:0] == DMA_BUF2_ADR_CHB       ||
                        bus.addr[12-1:0] == DAC_CHA_CUR_RP         ||
                        bus.addr[12-1:0] == DAC_CHB_CUR_RP           );

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
      dac_cha_conf        <= 16'h0;    
      dac_chb_conf        <= 16'h0;

      cfg_cha_scale       <= 16'h8000;
      cfg_cha_offs        <= 16'h0;
      cfg_cha_outshift    <= 8'h0;
      cfg_chb_scale       <= 16'h8000;
      cfg_chb_offs        <= 16'h0;
      cfg_chb_outshift    <= 8'h0;

      event_op_reg        <=  'h0;
      cfg_event_sel       <=  'h0;
      cfg_trig_mask       <=  'h0;

      cfg_cha_setdec      <= 16'h1;
      cfg_chb_setdec      <= 16'h1;
      cfg_loopback_cha    <= 16'h0;
      cfg_loopback_chb    <= 16'h0;
      cfg_errs_rst        <=  1'b0;

      cfg_cha_step        <= 32'h0;
      cfg_chb_step        <= 32'h0;
   end else begin
      if ((reg_ofs_adc[12-1:0] == DAC_CONF_REG      ) && reg_write_adc) begin dac_chb_conf       <= reg_wdat_adc[31:16];
                                                                              dac_cha_conf       <= reg_wdat_adc[15:0];        end
      if ((reg_ofs_adc[12-1:0] == DAC_CHA_SCALE_OFFS) && reg_write_adc) begin cfg_cha_offs       <={reg_wdat_adc[29:16], 2'h0};
                                                                              cfg_cha_scale      <={reg_wdat_adc[13:0], 2'h0}; end
      if ((reg_ofs_adc[12-1:0] == DAC_CHB_SCALE_OFFS) && reg_write_adc) begin cfg_chb_offs       <={reg_wdat_adc[29:16], 2'h0};
                                                                              cfg_chb_scale      <={reg_wdat_adc[13:0], 2'h0}; end

      if ((reg_ofs_adc[12-1:0] == EVENT_STS_ADDR    ) && reg_write_adc)       event_op_reg       <= reg_wdat_adc[3:0]; else event_op_reg <= 4'h0;
      if ((reg_ofs_adc[12-1:0] == EVENT_SEL_ADDR    ) && reg_write_adc)       cfg_event_sel      <= reg_wdat_adc[EVENT_SRC_NUM-1:0];
      if ((reg_ofs_adc[12-1:0] == TRIG_MASK_ADDR    ) && reg_write_adc)       cfg_trig_mask      <= reg_wdat_adc[TRIG_SRC_NUM -1:0];

      if ((reg_ofs_adc[12-1:0] == OUT_SHIFT_CH1     ) && reg_write_adc)       cfg_cha_outshift   <= reg_wdat_adc[4:0];
      if ((reg_ofs_adc[12-1:0] == OUT_SHIFT_CH2     ) && reg_write_adc)       cfg_chb_outshift   <= reg_wdat_adc[4:0];

      if ((reg_ofs_adc[12-1:0] == SETDEC_CHA        ) && reg_write_adc)       cfg_cha_setdec     <= reg_wdat_adc[15:0];
      if ((reg_ofs_adc[12-1:0] == SETDEC_CHB        ) && reg_write_adc)       cfg_chb_setdec     <= reg_wdat_adc[15:0];

      if ((reg_ofs_adc[12-1:0] == DAC_CHA_CNT_STEP  ) && reg_write_adc)       cfg_cha_step       <= reg_wdat_adc;
      if ((reg_ofs_adc[12-1:0] == DAC_CHB_CNT_STEP  ) && reg_write_adc)       cfg_chb_step       <= reg_wdat_adc;

      if ((reg_ofs_adc[12-1:0] == ERRS_RST          ) && reg_write_adc)       cfg_errs_rst       <= 1'b1; else cfg_errs_rst <= 1'b0;
      if ((reg_ofs_adc[12-1:0] == LOOPBACK_EN       ) && reg_write_adc) begin cfg_loopback_cha   <= reg_wdat_adc[0];
                                                                              cfg_loopback_chb   <= reg_wdat_adc[4]; end
   end
end

///////////////////////////////////////////////////////////////////////////////////////////
// Read logic ADC regs
///////////////////////////////////////////////////////////////////////////////////////////
always @ (*) 
begin
   casez(reg_ofs_adc[12-1:0])
      DAC_CONF_REG:          begin reg_ack_adc = 1'b1;       reg_rdat_adc = {dac_chb_conf, dac_cha_conf};                  end

      DAC_CHA_SCALE_OFFS:    begin reg_ack_adc = 1'b1;       reg_rdat_adc = {cfg_cha_offs, cfg_cha_scale};                 end
      DAC_CHB_SCALE_OFFS:    begin reg_ack_adc = 1'b1;       reg_rdat_adc = {cfg_chb_offs, cfg_chb_scale};                 end

      EVENT_STS_ADDR:        begin reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-EVENT_SRC_NUM{1'b0}}, cfg_event_sts_i};   end
      EVENT_SEL_ADDR:        begin reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-EVENT_SRC_NUM{1'b0}}, cfg_event_sel};     end
      TRIG_MASK_ADDR:        begin reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-TRIG_SRC_NUM{1'b0}} , cfg_trig_mask};     end

      ERRS_CNT_CHA:          begin reg_ack_adc = 1'b1;       reg_rdat_adc = errs_cnt_cha_i;                                end
      ERRS_CNT_CHB:          begin reg_ack_adc = 1'b1;       reg_rdat_adc = errs_cnt_chb_i;                                end
      OUT_SHIFT_CH1:         begin reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-5{1'b0}}, cfg_cha_outshift};              end
      OUT_SHIFT_CH2:         begin reg_ack_adc = 1'b1;       reg_rdat_adc = {{32-5{1'b0}}, cfg_chb_outshift};              end

      DAC_CHA_CNT_STEP:      begin reg_ack_adc = 1'b1;       reg_rdat_adc = cfg_cha_step;                                  end
      DAC_CHB_CNT_STEP:      begin reg_ack_adc = 1'b1;       reg_rdat_adc = cfg_chb_step;                                  end

      DIAG_REG_ADDR1:        begin reg_ack_adc = 1'b1;       reg_rdat_adc = diag1_i;                                       end
      DIAG_REG_ADDR2:        begin reg_ack_adc = 1'b1;       reg_rdat_adc = diag2_i;                                       end
      DIAG_REG_ADDR3:        begin reg_ack_adc = 1'b1;       reg_rdat_adc = diag3_i;                                       end
      DIAG_REG_ADDR4:        begin reg_ack_adc = 1'b1;       reg_rdat_adc = diag4_i;                                       end
      default :              begin reg_ack_adc = 1'b1;       reg_rdat_adc = {32{1'b0}} ;                                   end
   endcase
end

///////////////////////////////////////////////////////////////////////////////////////////
// Write logic AXI regs
///////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk_axi_i)
begin
   if (axi_rstn_i == 1'b0) begin
      cfg_ctrl_reg_cha    <=  8'h0;
      cfg_ctrl_reg_chb    <=  8'h0;

      cfg_dma_buf_size    <= 32'h0;
      cfg_buf1_adr_cha    <= 32'h0;
      cfg_buf1_adr_chb    <= 32'h0;
      cfg_buf2_adr_cha    <= 32'h0;
      cfg_buf2_adr_chb    <= 32'h0;
   end else begin
      if ((reg_ofs_axi[12-1:0] == DMA_CTRL_ADDR     ) && reg_write_axi) begin cfg_ctrl_reg_cha   <= reg_wdat_axi[ 8-1:0];
                                                                              cfg_ctrl_reg_chb   <= reg_wdat_axi[16-1:8]; end

      if ((reg_ofs_axi[12-1:0] == DMA_BUF_SIZE_ADDR ) && reg_write_axi)       cfg_dma_buf_size   <= reg_wdat_axi;
      if ((reg_ofs_axi[12-1:0] == DMA_BUF1_ADR_CHA  ) && reg_write_axi)       cfg_buf1_adr_cha   <= reg_wdat_axi;
      if ((reg_ofs_axi[12-1:0] == DMA_BUF1_ADR_CHB  ) && reg_write_axi)       cfg_buf1_adr_chb   <= reg_wdat_axi;
      if ((reg_ofs_axi[12-1:0] == DMA_BUF2_ADR_CHA  ) && reg_write_axi)       cfg_buf2_adr_cha   <= reg_wdat_axi;
      if ((reg_ofs_axi[12-1:0] == DMA_BUF2_ADR_CHB  ) && reg_write_axi)       cfg_buf2_adr_chb   <= reg_wdat_axi;

   end
end

///////////////////////////////////////////////////////////////////////////////////////////
// Read logic AXI regs
///////////////////////////////////////////////////////////////////////////////////////////
always @ (*) 
begin
   casez(reg_ofs_axi[12-1:0])
      DMA_CTRL_ADDR:           begin reg_ack_axi = 1'b1;       reg_rdat_axi = {8'h0, cfg_ctrl_reg_cha, 8'h0, cfg_ctrl_reg_chb};  end
      DMA_STS_ADDR:            begin reg_ack_axi = 1'b1;       reg_rdat_axi = {sts_chb_i[15:0] , sts_cha_i[15:0]};               end

      DMA_BUF_SIZE_ADDR:       begin reg_ack_axi = 1'b1;       reg_rdat_axi = cfg_dma_buf_size;                                  end
      DMA_BUF1_ADR_CHA:        begin reg_ack_axi = 1'b1;       reg_rdat_axi = cfg_buf1_adr_cha;                                  end
      DMA_BUF1_ADR_CHB:        begin reg_ack_axi = 1'b1;       reg_rdat_axi = cfg_buf1_adr_chb;                                  end
      DMA_BUF2_ADR_CHA:        begin reg_ack_axi = 1'b1;       reg_rdat_axi = cfg_buf2_adr_cha;                                  end
      DMA_BUF2_ADR_CHB:        begin reg_ack_axi = 1'b1;       reg_rdat_axi = cfg_buf2_adr_chb;                                  end

      DAC_CHA_CUR_RP:          begin reg_ack_axi = 1'b1;       reg_rdat_axi = cfg_cha_rp_i;                                      end
      DAC_CHB_CUR_RP:          begin reg_ack_axi = 1'b1;       reg_rdat_axi = cfg_chb_rp_i;                                      end

      default :                begin reg_ack_axi = 1'b1;       reg_rdat_axi = {32{1'b0}} ;                                       end
   endcase
end

always @(posedge clk_axi_i)
   cfg_dma_ctrl_we <= reg_write_axi && (reg_ofs_axi[12-1:0]==DMA_CTRL_ADDR);


///////////////////////////////////////////////////////////////////////////////////////////
// Output assignments
///////////////////////////////////////////////////////////////////////////////////////////
assign cfg_event_op_trig_o    = event_op_reg[3] | event_op_reg_r[3];
assign cfg_event_op_stop_o    = event_op_reg[2] | event_op_reg_r[2];
assign cfg_event_op_start_o   = event_op_reg[1] | event_op_reg_r[1];
assign cfg_event_op_reset_o   = event_op_reg[0] | event_op_reg_r[0];
assign cfg_event_sel_o        = cfg_event_sel;
assign cfg_trig_mask_o        = cfg_trig_mask;
assign dac_cha_conf_o         = dac_cha_conf;
assign dac_chb_conf_o         = dac_chb_conf;

assign cfg_cha_scale_o        = cfg_cha_scale;
assign cfg_cha_offs_o         = cfg_cha_offs;
assign cfg_cha_step_o         = cfg_cha_step;
assign cfg_cha_outshift_o     = cfg_cha_outshift;
assign cfg_cha_setdec_o       = cfg_cha_setdec;

assign cfg_chb_scale_o        = cfg_chb_scale;
assign cfg_chb_offs_o         = cfg_chb_offs;
assign cfg_chb_step_o         = cfg_chb_step;
assign cfg_chb_outshift_o     = cfg_chb_outshift;
assign cfg_chb_setdec_o       = cfg_chb_setdec;

assign cfg_ctrl_reg_cha_o     = cfg_ctrl_reg_cha;
assign cfg_ctrl_reg_chb_o     = cfg_ctrl_reg_chb;
assign cfg_dma_ctrl_we_o      = cfg_dma_ctrl_we;

assign cfg_dma_buf_size_o     = cfg_dma_buf_size;
assign cfg_buf1_adr_cha_o     = cfg_buf1_adr_cha;
assign cfg_buf2_adr_cha_o     = cfg_buf2_adr_cha;
assign cfg_buf1_adr_chb_o     = cfg_buf1_adr_chb;
assign cfg_buf2_adr_chb_o     = cfg_buf2_adr_chb;

assign cfg_loopback_cha_o     = cfg_loopback_cha;
assign cfg_loopback_chb_o     = cfg_loopback_chb;
assign cfg_errs_rst_o         = cfg_errs_rst;

//--------------------------------------------------------------------------------------
wire    reg_write_synced_adc0 ;
wire    reg_read_synced_adc0  ;
wire    reg_write_synced_axi0 ;
wire    reg_read_synced_axi0  ;

reg     reg_write_synced_adc ;
reg     reg_read_synced_adc  ;
reg     reg_write_synced_axi ;
reg     reg_read_synced_axi  ;

wire    reg_ack_sync_adc = (reg_write_adc || reg_read_adc) && reg_ack_adc ;
wire    reg_ack_sync_axi = (reg_write_axi || reg_read_axi) && reg_ack_axi ;

//wire    ctrl_we_adc  = !axi_clk_regs & bus.wen & ~bus.addr[13-1];
//wire    ctrl_re_adc  = !axi_clk_regs & bus.ren & ~bus.addr[13-1];
//wire    ctrl_we_axi  =  axi_clk_regs & bus.wen & ~bus.addr[13-1];
//wire    ctrl_re_axi  =  axi_clk_regs & bus.ren & ~bus.addr[13-1];

wire    ctrl_we  = bus.wen & ~bus.addr[13-1];
wire    ctrl_re  = bus.ren & ~bus.addr[13-1];

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

  .ctrl_we_i  (   ctrl_we/*_adc */      ) ,
  .ctrl_re_i  (   ctrl_re/*_adc*/       ) ,
  .ctrl_ack_o (   ctrl_ack_adc      ) , //bus.ack

  .reg_we_o   (   reg_write_synced_adc0) ,
  .reg_re_o   (   reg_read_synced_adc0 ) ,
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

  .ctrl_we_i  (   ctrl_we/*_axi  */     ) ,
  .ctrl_re_i  (   ctrl_re/*_axi */     ) ,
  .ctrl_ack_o (   ctrl_ack_axi      ) , //bus.ack

  .reg_we_o   (   reg_write_synced_axi0) ,
  .reg_re_o   (   reg_read_synced_axi0 ) ,
  .reg_ack_i  (   reg_ack_sync_axi    )
);

always @ (posedge clk_adc_i)
begin
   reg_write_synced_adc <= reg_write_synced_adc0;
   reg_read_synced_adc  <= reg_read_synced_adc0;
   if (adc_rstn_i == 1'b0)
   begin
      reg_write_adc <= 1'b0 ;
      reg_read_adc <= 1'b0 ;
   end else
   begin
      reg_write_adc <= reg_write_adc ? !reg_ack_adc : reg_write_synced_adc ;
      reg_read_adc  <= reg_read_adc  ? !reg_ack_adc : reg_read_synced_adc ;
   //   reg_write_adc_r <= reg_write_adc_r ? !reg_ack_adc : reg_write_synced_adc ;
   //   reg_read_adc_r  <= reg_read_adc  ? !reg_ack_adc : reg_read_synced_adc ;
   end
   //reg_write_adc <= reg_write_adc_r;
   //reg_read_adc  <= reg_read_adc_r;
end

always @ (posedge clk_adc_i)
begin
   if (reg_write_synced_adc || reg_read_synced_adc)
   begin
      reg_ofs_adc  <= bus.addr[12-1:0] ;
      reg_wdat_adc <= bus.wdata ;
   //   reg_ofs_adc_r  <= bus.addr[12-1:0] ;
   //   reg_wdat_adc_r <= bus.wdata ;
   end
   //reg_ofs_adc  <= reg_ofs_adc_r;
   //reg_wdat_adc <= reg_wdat_adc_r;
   //reg_rdat_adc_r <= reg_rdat_adc;
end

always @ (posedge clk_axi_i)
begin
   reg_write_synced_axi <= reg_write_synced_axi0;
   reg_read_synced_axi  <= reg_read_synced_axi0;
   if (axi_rstn_i == 1'b0)
   begin
      reg_write_axi <= 1'b0 ;
      reg_read_axi <= 1'b0 ;
   end else
   begin
      reg_write_axi <= reg_write_axi ? !reg_ack_axi : reg_write_synced_axi ;
      reg_read_axi  <= reg_read_axi  ? !reg_ack_axi : reg_read_synced_axi ;
      //reg_write_axi_r <= reg_write_axi_r ? !reg_ack_axi : reg_write_synced_axi ;
      //reg_read_axi_r  <= reg_read_axi_r  ? !reg_ack_axi : reg_read_synced_axi ;
   end
   //reg_write_axi <= reg_write_axi_r;
   //reg_read_axi  <= reg_read_axi_r;
end


always @ (posedge clk_axi_i)
begin
   if (reg_write_synced_axi || reg_read_synced_axi)
   begin
      reg_ofs_axi  <= bus.addr[12-1:0] ;
      reg_wdat_axi <= bus.wdata ;
      //reg_ofs_axi_r  <= bus.addr[12-1:0] ;
      //reg_wdat_axi_r <= bus.wdata ;
   end
   //reg_ofs_axi  <= reg_ofs_axi_r;
   //reg_wdat_axi <= reg_wdat_axi_r;
   //reg_rdat_axi_r <= reg_rdat_axi;
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