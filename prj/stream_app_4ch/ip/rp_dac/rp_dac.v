`timescale 1ns / 1ps

module rp_dac
  #(parameter S_AXI_REG_ADDR_BITS   = 12,
    parameter M_AXI_DAC_ADDR_BITS   = 32,
    parameter M_AXI_DAC_DATA_BITS   = 64,
    parameter M_AXI_DAC_DATA_BITS_O = 64,
    parameter DAC_DATA_BITS         = 14,
    parameter AXI_BURST_LEN         = 16,
    parameter EVENT_SRC_NUM         = 7,
    parameter TRIG_SRC_NUM          = 7,
    parameter ID_WIDTHS             = 4,
    parameter ID_WIDTH              = 4)(    
  input  wire                                   clk,
  input  wire                                   rst_n,
  output wire                                   intr,

  //
  output wire [DAC_DATA_BITS-1:0]               dac_data_cha_o,
  output wire [DAC_DATA_BITS-1:0]               dac_data_chb_o,
  //
  input  wire [EVENT_SRC_NUM-1:0]               event_ip_trig,
  input  wire [EVENT_SRC_NUM-1:0]               event_ip_stop,
  input  wire [EVENT_SRC_NUM-1:0]               event_ip_start,
  input  wire [EVENT_SRC_NUM-1:0]               event_ip_reset,
  input  wire [TRIG_SRC_NUM-1:0]                trig_ip,
  //
  output wire [3:0]                             dac1_event_op,    
  output wire                                   dac1_trig_op,    
  // 
  output wire [3:0]                             dac2_event_op,      
  output wire                                   dac2_trig_op,  
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

  input  wire                                   m_axi_dac1_aclk       ,
  input  wire                                   m_axi_dac1_aresetn    ,
  output wire [ID_WIDTH-1: 0]                   m_axi_dac1_arid_o     ,
  output wire [M_AXI_DAC_ADDR_BITS-1: 0]        m_axi_dac1_araddr_o   ,
  output wire [3:0]                             m_axi_dac1_arlen_o    ,
  output wire [2:0]                             m_axi_dac1_arsize_o   ,
  output wire [1:0]                             m_axi_dac1_arburst_o  ,
  output wire [1:0]                             m_axi_dac1_arlock_o   ,
  output wire [3:0]                             m_axi_dac1_arcache_o  ,
  output wire [2:0]                             m_axi_dac1_arprot_o   ,
  output wire                                   m_axi_dac1_arvalid_o  ,
  input  wire                                   m_axi_dac1_arready_i  ,
  output wire [       3:0]                      m_axi_dac1_arqos_o    ,
  input  wire [ID_WIDTH-1: 0]                   m_axi_dac1_rid_i      ,
  input  wire [ M_AXI_DAC_DATA_BITS-1: 0]       m_axi_dac1_rdata_i    ,
  input  wire [    1: 0]                        m_axi_dac1_rresp_i    ,
  input  wire                                   m_axi_dac1_rlast_i    ,
  input  wire                                   m_axi_dac1_rvalid_i   ,
  output wire                                   m_axi_dac1_rready_o   ,

  input  wire                                   m_axi_dac2_aclk       ,    
  input  wire                                   m_axi_dac2_aresetn    ,    
  output wire [ID_WIDTH-1:0]                    m_axi_dac2_arid_o     ,
  output wire [M_AXI_DAC_ADDR_BITS-1: 0]        m_axi_dac2_araddr_o   ,
  output wire [3:0]                             m_axi_dac2_arlen_o    ,
  output wire [2:0]                             m_axi_dac2_arsize_o   ,
  output wire [1:0]                             m_axi_dac2_arburst_o  ,
  output wire [1:0]                             m_axi_dac2_arlock_o   ,
  output wire [3:0]                             m_axi_dac2_arcache_o  ,
  output wire [2:0]                             m_axi_dac2_arprot_o   ,
  output wire                                   m_axi_dac2_arvalid_o  ,
  input  wire                                   m_axi_dac2_arready_i  ,
  output wire [       3:0]                      m_axi_dac2_arqos_o    ,
  input  wire [ID_WIDTH-1:0]                    m_axi_dac2_rid_i      ,
  input  wire [ M_AXI_DAC_DATA_BITS-1: 0]       m_axi_dac2_rdata_i    ,
  input  wire [1:0]                             m_axi_dac2_rresp_i    ,
  input  wire                                   m_axi_dac2_rlast_i    ,
  input  wire                                   m_axi_dac2_rvalid_i   ,
  output wire                                   m_axi_dac2_rready_o
);


////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////
    
localparam REG_ADDR_BITS  = 8;
////////////////////////////////////////////////////////////
// Signals
////////////////////////////////////////////////////////////
wire [16-1:0]                   dac_cha_conf;
wire [16-1:0]                   dac_chb_conf;

wire [DAC_DATA_BITS-1:0]        cfg_cha_scale;
wire [DAC_DATA_BITS-1:0]        cfg_cha_offs;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_cha_step;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_cha_rp;
wire [ 5-1:0]                   cfg_cha_outshift;

wire [DAC_DATA_BITS-1:0]        cfg_chb_scale;
wire [DAC_DATA_BITS-1:0]        cfg_chb_offs;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_chb_step;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_chb_rp;
wire [ 5-1:0]                   cfg_chb_outshift;

wire [16-1:0]                   cfg_cha_setdec;
wire [16-1:0]                   cfg_chb_setdec;

wire [EVENT_SRC_NUM-1:0]        cfg_event_sel;
wire [EVENT_SRC_NUM-1:0]        cfg_event_op;
wire [TRIG_SRC_NUM -1:0]        cfg_trig_mask;

wire [ 8-1:0]                   cfg_ctrl_reg_cha;
wire [ 8-1:0]                   cfg_ctrl_reg_chb;

wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_dma_buf_size;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_buf1_adr_cha;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_buf1_adr_chb;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_buf2_adr_cha;
wire [M_AXI_DAC_ADDR_BITS-1:0]  cfg_buf2_adr_chb;
wire                            cfg_loopback_cha;
wire                            cfg_loopback_chb;

wire                            cfg_errs_rst;
reg  [31:0]                     errs_cnt_cha;
reg  [31:0]                     errs_cnt_chb;

wire [31:0]                     sts_cha; 
wire [31:0]                     sts_chb; 

wire [31:0]                     diag1_ch1, diag1_ch2;
wire [31:0]                     diag2_ch1, diag2_ch2;
wire [31:0]                     diag3_ch1, diag3_ch2;
wire [31:0]                     diag4_ch1, diag4_ch2;

assign intr = 1'b0;
assign dac1_event_op = cfg_event_op;
assign dac2_event_op = cfg_event_op;
assign dac_data_cha_o = dac_a_r;
assign dac_data_chb_o = dac_b_r;

wire [DAC_DATA_BITS-1:0]        dac_data_cha, dac_data_chb;
reg  [DAC_DATA_BITS-1:0]        dac_a_r, dac_b_r;
reg  [DAC_DATA_BITS-1:0]        dac_a_diff, dac_b_diff;    
always @(posedge clk)
begin
  dac_a_r <= dac_data_cha;
  dac_b_r <= dac_data_chb;
  dac_a_diff <= dac_data_cha - dac_a_r;
  dac_b_diff <= dac_data_chb - dac_b_r;
  if (~rstn_cfg) begin
    errs_cnt_cha <= 'h0;
    errs_cnt_chb <= 'h0;
  end else begin
    if (cfg_errs_rst)
      errs_cnt_cha <= 'h0;  
    else if ((dac_a_diff != cfg_cha_setdec) & (dac_a_diff != 'h0) & (dac_a_diff < 16'h7000))
      errs_cnt_cha <= errs_cnt_cha + 'h1;

    if (cfg_errs_rst)
      errs_cnt_chb <= 'h0;
    else if ((dac_b_diff != cfg_chb_setdec) & (dac_b_diff != 'h0) & (dac_b_diff < 16'h7000))
      errs_cnt_chb <= errs_cnt_chb + 'h1;
  end
end


reg rstn_cfg;
always @(posedge clk)
begin
  rstn_cfg <= rst_n;
end

reg rstn_cfgax;
always @(posedge m_axi_dac1_aclk)
begin
  rstn_cfgax <= m_axi_dac1_aresetn;
end

////////////////////////////////////////////////////////////
// Register Interface
////////////////////////////////////////////////////////////   

dac_cfg #(
  .M_AXI_DAC_ADDR_BITS  (M_AXI_DAC_ADDR_BITS),
  .DAC_DATA_BITS        (DAC_DATA_BITS),
  .REG_ADDR_BITS        (REG_ADDR_BITS),
  .EVENT_SRC_NUM        (EVENT_SRC_NUM),
  .ID_WIDTHS            (ID_WIDTHS),
  .TRIG_SRC_NUM         (TRIG_SRC_NUM)
  )
  U_dac_cfg
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

  .clk_axi_i                (m_axi_dac1_aclk),   
  .clk_adc_i                (clk),   
  .axi_rstn_i               (rstn_cfgax), 
  .adc_rstn_i               (rstn_cfg), 

  .cfg_event_op_trig_o      (cfg_event_op[0]),
  .cfg_event_op_stop_o      (cfg_event_op[1]),
  .cfg_event_op_start_o     (cfg_event_op[2]),
  .cfg_event_op_reset_o     (cfg_event_op[3]),
  .cfg_event_sts_i          (cfg_event_op),
  .cfg_event_sel_o          (cfg_event_sel),

  .dac_cha_conf_o           (dac_cha_conf),
  .dac_chb_conf_o           (dac_chb_conf),

  .cfg_cha_scale_o          (cfg_cha_scale),
  .cfg_cha_offs_o           (cfg_cha_offs),
  .cfg_cha_step_o           (cfg_cha_step),
  .cfg_cha_outshift_o       (cfg_cha_outshift),
  .cfg_cha_setdec_o         (cfg_cha_setdec),

  .cfg_chb_scale_o          (cfg_chb_scale),
  .cfg_chb_offs_o           (cfg_chb_offs),
  .cfg_chb_step_o           (cfg_chb_step),
  .cfg_chb_outshift_o       (cfg_chb_outshift),
  .cfg_chb_setdec_o         (cfg_chb_setdec),

  .cfg_ctrl_reg_cha_o       (cfg_ctrl_reg_cha),
  .cfg_ctrl_reg_chb_o       (cfg_ctrl_reg_chb),
  .cfg_dma_ctrl_we_o        (cfg_dma_ctrl_we),
  .sts_cha_i                (sts_cha),
  .sts_chb_i                (sts_chb),

  .cfg_dma_buf_size_o       (cfg_dma_buf_size),
  .cfg_buf1_adr_cha_o       (cfg_buf1_adr_cha),
  .cfg_buf2_adr_cha_o       (cfg_buf2_adr_cha),
  .cfg_buf1_adr_chb_o       (cfg_buf1_adr_chb),
  .cfg_buf2_adr_chb_o       (cfg_buf2_adr_chb),

  .cfg_loopback_cha_o       (cfg_loopback_cha),
  .cfg_loopback_chb_o       (cfg_loopback_chb),

  .cfg_cha_rp_i             (cfg_cha_rp),
  .cfg_chb_rp_i             (cfg_chb_rp),

  .cfg_errs_rst_o           (cfg_errs_rst),
  .errs_cnt_cha_i           (errs_cnt_cha),
  .errs_cnt_chb_i           (errs_cnt_chb),

  .diag1_i                  (diag1_ch1),
  .diag2_i                  (diag2_ch1),
  .diag3_i                  (diag3_ch1),
  .diag4_i                  (diag4_ch1)
  );

////////////////////////////////////////////////////////////
// Name : DAC 1
// 
////////////////////////////////////////////////////////////     
dac_top #(
  .M_AXI_DAC_ADDR_BITS  (M_AXI_DAC_ADDR_BITS),
  .M_AXI_DAC_DATA_BITS  (M_AXI_DAC_DATA_BITS_O),
  .DAC_DATA_BITS    (DAC_DATA_BITS), 
  .REG_ADDR_BITS    (REG_ADDR_BITS),
  .EVENT_SRC_NUM    (EVENT_SRC_NUM),
  .TRIG_SRC_NUM     (TRIG_SRC_NUM),
  .AXI_BURST_LEN    (AXI_BURST_LEN),
  .CH_NUM           (0))
  U_dac1(
  .clk_axi          (m_axi_dac1_aclk),   
  .clk_adc          (clk),   
  //.axi_rstn         (m_axi_dac1_aresetn), 
  //.adc_rstn         (rst_n), 
  .axi_rstn         (rstn_cfgax), 
  .adc_rstn         (rstn_cfg), 

  .event_ip_trig    (event_ip_trig),  
  .event_ip_stop    (event_ip_stop),  
  .event_ip_start   (event_ip_start), 
  .event_ip_reset   (event_ip_reset),  
  // .event_op_trig    (dac1_event_op[0]),
  // .event_op_stop    (dac1_event_op[1]),
  // .event_op_start   (dac1_event_op[2]),
  // .event_op_reset   (dac1_event_op[3]),
  .event_sel        (cfg_event_sel),
  .event_val        (event_val),
  .trig_ip          (trig_ip),
  .trig_op          (dac1_trig_op),  
  //.reg_ctrl         (ctrl_cha_o),
  .reg_sts          (sts_cha),
  //.sts_val          (sts_cha),  
  .dac_conf         (dac_cha_conf),
  .dac_scale        (cfg_cha_scale),
  .dac_offs         (cfg_cha_offs),
  .dac_outshift     (cfg_cha_outshift),
  .dac_step         (cfg_cha_step),
  .dac_rp           (cfg_cha_rp),
  .dac_trig         (cfg_trig_mask),
  .dac_ctrl_reg     (cfg_ctrl_reg_cha),
  .ctrl_val         (cfg_dma_ctrl_we),
  .dac_buf_size     (cfg_dma_buf_size),
  .dac_buf1_adr     (cfg_buf1_adr_cha),
  .dac_buf2_adr     (cfg_buf2_adr_cha),
  .dac_data_o       (dac_data_cha),
  .diag_reg         (diag_reg),
  .diag_reg2        (diag_reg2),
  .loopback_en      (cfg_loopback_cha),

  .m_axi_dac_arid_o     (m_axi_dac1_arid_o),
  .m_axi_dac_araddr_o   (m_axi_dac1_araddr_o),
  .m_axi_dac_arlen_o    (m_axi_dac1_arlen_o),
  .m_axi_dac_arsize_o   (m_axi_dac1_arsize_o),
  .m_axi_dac_arburst_o  (m_axi_dac1_arburst_o),
  .m_axi_dac_arlock_o   (m_axi_dac1_arlock_o),
  .m_axi_dac_arcache_o  (m_axi_dac1_arcache_o),
  .m_axi_dac_arprot_o   (m_axi_dac1_arprot_o),
  .m_axi_dac_arvalid_o  (m_axi_dac1_arvalid_o),
  .m_axi_dac_arready_i  (m_axi_dac1_arready_i),
  .m_axi_dac_arqos_o    (m_axi_dac1_arqos_o),
  .m_axi_dac_rid_i      (m_axi_dac1_rid_i),
  .m_axi_dac_rdata_i    (m_axi_dac1_rdata_i),
  .m_axi_dac_rresp_i    (m_axi_dac1_rresp_i),
  .m_axi_dac_rlast_i    (m_axi_dac1_rlast_i),
  .m_axi_dac_rvalid_i   (m_axi_dac1_rvalid_i),
  .m_axi_dac_rready_o   (m_axi_dac1_rready_o));
////////////////////////////////////////////////////////////
// Name : DAC 2
// 
////////////////////////////////////////////////////////////     

dac_top #(
  .M_AXI_DAC_ADDR_BITS  (M_AXI_DAC_ADDR_BITS),
  .M_AXI_DAC_DATA_BITS  (M_AXI_DAC_DATA_BITS_O),
  .DAC_DATA_BITS    (DAC_DATA_BITS), 
  .REG_ADDR_BITS    (REG_ADDR_BITS),
  .EVENT_SRC_NUM    (EVENT_SRC_NUM),
  .TRIG_SRC_NUM     (TRIG_SRC_NUM),
  .AXI_BURST_LEN    (AXI_BURST_LEN),
  .CH_NUM           (1))
  U_dac2(
  .clk_axi          (m_axi_dac2_aclk),   
  .clk_adc          (clk),   
  //.axi_rstn         (m_axi_dac1_aresetn), 
  //.adc_rstn         (rst_n), 
  .axi_rstn         (rstn_cfgax), 
  .adc_rstn         (rstn_cfg), 
  
  .event_ip_trig    (event_ip_trig),  
  .event_ip_stop    (event_ip_stop),  
  .event_ip_start   (event_ip_start), 
  .event_ip_reset   (event_ip_reset),  
  // .event_op_trig    (dac2_event_op[0]),
  // .event_op_stop    (dac2_event_op[1]),
  // .event_op_start   (dac2_event_op[2]),
  // .event_op_reset   (dac2_event_op[3]),
  .event_sel        (cfg_event_sel),
  .event_val        (event_val),
  .trig_ip          (trig_ip),
  .trig_op          (dac2_trig_op),  
  //.reg_ctrl         (ctrl_chb_o),
  .reg_sts          (sts_chb),
  //.sts_val          (sts_chb), 
  .dac_conf         (dac_chb_conf),
  .dac_scale        (cfg_chb_scale),
  .dac_offs         (cfg_chb_offs),
  .dac_outshift     (cfg_chb_outshift),
  .dac_step         (cfg_chb_step),
  .dac_rp           (cfg_chb_rp),
  .dac_trig         (cfg_trig_mask),
  .dac_ctrl_reg     (cfg_ctrl_reg_chb),
  .ctrl_val         (cfg_dma_ctrl_we),
  .dac_buf_size     (cfg_dma_buf_size),
  .dac_buf1_adr     (cfg_buf1_adr_chb),
  .dac_buf2_adr     (cfg_buf2_adr_chb),
  .dac_data_o       (dac_data_chb),
  .loopback_en      (cfg_loopback_chb),
  
  .m_axi_dac_arid_o     (m_axi_dac2_arid_o),
  .m_axi_dac_araddr_o   (m_axi_dac2_araddr_o),
  .m_axi_dac_arlen_o    (m_axi_dac2_arlen_o),
  .m_axi_dac_arsize_o   (m_axi_dac2_arsize_o),
  .m_axi_dac_arburst_o  (m_axi_dac2_arburst_o),
  .m_axi_dac_arlock_o   (m_axi_dac2_arlock_o),
  .m_axi_dac_arcache_o  (m_axi_dac2_arcache_o),
  .m_axi_dac_arprot_o   (m_axi_dac2_arprot_o),
  .m_axi_dac_arvalid_o  (m_axi_dac2_arvalid_o),
  .m_axi_dac_arready_i  (m_axi_dac2_arready_i),
  .m_axi_dac_arqos_o    (m_axi_dac2_arqos_o),
  .m_axi_dac_rid_i      (m_axi_dac2_rid_i),
  .m_axi_dac_rdata_i    (m_axi_dac2_rdata_i),
  .m_axi_dac_rresp_i    (m_axi_dac2_rresp_i),
  .m_axi_dac_rlast_i    (m_axi_dac2_rlast_i),
  .m_axi_dac_rvalid_i   (m_axi_dac2_rvalid_i),
  .m_axi_dac_rready_o   (m_axi_dac2_rready_o));      

endmodule