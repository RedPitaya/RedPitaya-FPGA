`timescale 1ns / 1ps

module rp_oscilloscope
  #(parameter S_AXI_REG_ADDR_BITS   = 32,
    parameter M_AXI_OSC1_ADDR_BITS  = 32,
    parameter M_AXI_OSC1_DATA_BITS  = 64,
    parameter M_AXI_OSC2_ADDR_BITS  = 32,
    parameter M_AXI_OSC2_DATA_BITS  = 64,
    parameter ADC_DATA_BITS         = 14,
    parameter EVENT_SRC_NUM         = 7,
    parameter TRIG_SRC_NUM          = 7)(    
  input  wire                                   clk,
  input  wire                                   rst_n,
  output wire                                   intr,

  //
  input  wire [ADC_DATA_BITS-1:0]               adc_data_ch1,
  input  wire [ADC_DATA_BITS-1:0]               adc_data_ch2,  
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
  output wire                                   osc1_trig_op,    
  // 
  output wire [3:0]                             osc2_event_op,      
  output wire                                   osc2_trig_op,  
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
  input  wire [3:0]                             s_axi_reg_awid,     
  input  wire [3:0]                             s_axi_reg_arid,     
  input  wire [3:0]                             s_axi_reg_wid,     
  output wire [3:0]                             s_axi_reg_rid,     
  output wire [3:0]                             s_axi_reg_bid,     

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
  output wire                                   m_axi_osc2_bready   
);

////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////
    
localparam DEC_CNT_BITS   = 17; // Decimator counter bits
localparam DEC_SHIFT_BITS = 4;  // Decimator shifter bits
localparam TRIG_CNT_BITS  = 32; // Trigger counter bits
localparam S_AXIS_DATA_BITS = 16;
////////////////////////////////////////////////////////////
// Signals
////////////////////////////////////////////////////////////
reg  signed [16-1:0]            adc_data_ch1_signed;        
reg  signed [16-1:0]            adc_data_ch2_signed;        

wire signed [15:0]              s_axis_osc1_tdata;
wire signed [15:0]              s_axis_osc2_tdata;

wire                            adr_is_setting;
wire                            adr_is_ch1, adr_is_ch2;
wire                            adr_is_cal_ch1, adr_is_cal_ch2;
wire                            adr_is_dma_ch1, adr_is_dma_ch2;
wire                            adr_is_diag_ch1, adr_is_diag_ch2;
wire                            adr_is_cntms_ch1, adr_is_cntms_ch2;
wire                            adr_is_filt_ch1, adr_is_filt_ch2;
wire                            buf_sel_ch1, buf_sel_ch2;

wire                            adc_sign_ch1 = ~adc_data_ch1[ADC_DATA_BITS-1];
wire                            adc_sign_ch2 = ~adc_data_ch2[ADC_DATA_BITS-1];

always @(posedge clk)
begin
  adc_data_ch1_signed <= {{adc_data_ch1},{(16-ADC_DATA_BITS){1'b0}}};  
end

assign s_axis_osc1_tdata = $signed(adc_data_ch1_signed);

always @(posedge clk)
begin
  adc_data_ch2_signed <= {{adc_data_ch2},{(16-ADC_DATA_BITS){1'b0}}};  
end

assign s_axis_osc2_tdata = $signed(adc_data_ch2_signed);

assign intr = osc1_dma_intr | osc2_dma_intr;
assign trig_out = trig_out1 | trig_out2;

wire                        dma_mode;

wire [             3-1:0]   cfg_event_sel;
wire [             4-1:0]   cfg_event_op;
wire [             4-1:0]   cfg_event_sts;
wire [TRIG_SRC_NUM-1:0]     cfg_trig_mask;

wire                        ctl_trg;

wire [TRIG_CNT_BITS-1:0]    cfg_trig_pre_samp;
wire [TRIG_CNT_BITS-1:0]    sts_trig_pre_cnt;
wire                        sts_trig_pre_overflow;

wire [TRIG_CNT_BITS-1:0]    cfg_trig_post_samp;
wire [TRIG_CNT_BITS-1:0]    sts_trig_post_cnt;
wire                        sts_trig_post_overflow;

wire [S_AXIS_DATA_BITS-1:0] cfg_trig_low_level;
wire [S_AXIS_DATA_BITS-1:0] cfg_trig_high_level;
wire                        cfg_trig_edge;  
wire                        trig_mod_op;

wire                        cfg_avg_en; 
wire [DEC_CNT_BITS-1:0]     cfg_dec_factor;  
wire [DEC_SHIFT_BITS-1:0]   cfg_dec_rshift;  
wire [            16-1:0]   cfg_loopback;

wire                         cfg_filt_bypass;  
wire signed [18-1:0]         cfg_filt_coeff_aa_ch1; 
wire signed [25-1:0]         cfg_filt_coeff_bb_ch1; 
wire signed [25-1:0]         cfg_filt_coeff_kk_ch1; 
wire signed [25-1:0]         cfg_filt_coeff_pp_ch1; 
wire signed [18-1:0]         cfg_filt_coeff_aa_ch2; 
wire signed [25-1:0]         cfg_filt_coeff_bb_ch2; 
wire signed [25-1:0]         cfg_filt_coeff_kk_ch2; 
wire signed [25-1:0]         cfg_filt_coeff_pp_ch2; 

wire [31:0]                 cfg_dma_dst_addr1_ch1;
wire [31:0]                 cfg_dma_dst_addr2_ch1;
wire [31:0]                 cfg_dma_dst_addr1_ch2;
wire [31:0]                 cfg_dma_dst_addr2_ch2;
wire [31:0]                 cfg_dma_buf_size;
wire [31:0]                 cfg_dma_ctrl;
wire                        cfg_dma_ctrl_we;
wire [31:0]                 cfg_dma_sts;
wire [31:0]                 cfg_dma_diags_reg;

wire                        cfg_8bit_dat;

wire [16-1:0]               cfg_calib_offset_ch1;
wire [16-1:0]               cfg_calib_gain_ch1;
wire [16-1:0]               cfg_calib_offset_ch2;
wire [16-1:0]               cfg_calib_gain_ch2;


wire [S_AXIS_DATA_BITS-1:0] calib_tdata;   
wire [S_AXIS_DATA_BITS-1:0] calib_datain;    

wire                        calib_tvalid;   
wire                        calib_tready;   

wire [S_AXIS_DATA_BITS-1:0] dec_indata;    
wire [S_AXIS_DATA_BITS-1:0] dec_tdata;    
wire                        dec_tvalid;   
wire                        dec_tready;   
wire                        ramp_en;
wire                        loopback_en;

wire [S_AXIS_DATA_BITS-1:0] trig_tdata;    
wire                        trig_tvalid;   
wire                        trig_tready;   

wire [S_AXIS_DATA_BITS-1:0] acq_tdata;    
wire                        acq_tvalid;   
wire                        acq_tready;   
wire                        acq_tlast;

wire  [31:0]                buf1_ms_cnt_ch1;
wire  [31:0]                buf2_ms_cnt_ch1;
wire  [31:0]                buf1_ms_cnt_ch2;
wire  [31:0]                buf2_ms_cnt_ch2;
wire  [31:0]                curr_wp_ch1;
wire  [31:0]                curr_wp_ch2;

wire [S_AXIS_DATA_BITS-1:0] filt_tdata;   
wire                        filt_tvalid;   

wire  [31:0]                diag1_ch1, diag1_ch2;
wire  [31:0]                diag2_ch1, diag2_ch2;
wire  [31:0]                diag3_ch1, diag3_ch2;
wire  [31:0]                diag4_ch1, diag4_ch2;


assign osc1_event_op = cfg_event_op;
assign osc2_event_op = cfg_event_op;

scope_cfg #(
  .M_AXI_ADDR_BITS  (M_AXI_OSC1_ADDR_BITS),
  .M_AXI_DATA_BITS  (M_AXI_OSC1_DATA_BITS),
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
  .s_axi_reg_awid           (s_axi_reg_awid),
  .s_axi_reg_arid           (s_axi_reg_arid),
  .s_axi_reg_wid            (s_axi_reg_wid),
  .s_axi_reg_rid            (s_axi_reg_rid),
  .s_axi_reg_bid            (s_axi_reg_bid),

  .clk_i                    (clk),   
  .rstn_i                   (m_axi_osc1_aresetn), 

  .cfg_event_op_trig_o      (cfg_event_op[0]),
  .cfg_event_op_stop_o      (cfg_event_op[1]),
  .cfg_event_op_start_o     (cfg_event_op[2]),
  .cfg_event_op_reset_o     (cfg_event_op[3]),
  .cfg_event_sts_i          (cfg_event_sts),
  .cfg_event_sel_o          (cfg_event_sel),

  .cfg_trig_mask_o          (cfg_trig_mask),
  .cfg_trig_pre_samp_o      (cfg_trig_pre_samp),
  .cfg_trig_post_samp_o     (cfg_trig_post_samp),
  .sts_trig_pre_cnt_i       (sts_trig_pre_cnt),
  .sts_trig_post_cnt_i      (sts_trig_post_cnt),
  .sts_trig_pre_overflow_i  (sts_trig_pre_overflow),
  .sts_trig_post_overflow_i (sts_trig_post_overflow),
  .cfg_trig_low_level_o     (cfg_trig_low_level),
  .cfg_trig_high_level_o    (cfg_trig_high_level),
  .cfg_trig_edge_o          (cfg_trig_edge),

  .cfg_dec_factor_o         (cfg_dec_factor),
  .cfg_dec_rshift_o         (cfg_dec_rshift),
  .cfg_avg_en_o             (cfg_avg_en),
  .cfg_loopback_o           (cfg_loopback),
  .cfg_8bit_dat_o           (cfg_8bit_dat),
  .cfg_calib_offset_ch1_o   (cfg_calib_offset_ch1),
  .cfg_calib_offset_ch2_o   (cfg_calib_offset_ch2),
  .cfg_calib_gain_ch1_o     (cfg_calib_gain_ch1),
  .cfg_calib_gain_ch2_o     (cfg_calib_gain_ch2),
  .clksel_o                 (clksel_o),
  .daisy_slave_i            (daisy_slave_i),
  
  .cfg_filt_bypass_o        (cfg_filt_bypass),
  .cfg_filt_coeff_aa_ch1_o  (cfg_filt_coeff_aa_ch1),
  .cfg_filt_coeff_bb_ch1_o  (cfg_filt_coeff_bb_ch1),
  .cfg_filt_coeff_kk_ch1_o  (cfg_filt_coeff_kk_ch1),
  .cfg_filt_coeff_pp_ch1_o  (cfg_filt_coeff_pp_ch1),
  .cfg_filt_coeff_aa_ch2_o  (cfg_filt_coeff_aa_ch2),
  .cfg_filt_coeff_bb_ch2_o  (cfg_filt_coeff_bb_ch2),
  .cfg_filt_coeff_kk_ch2_o  (cfg_filt_coeff_kk_ch2),
  .cfg_filt_coeff_pp_ch2_o  (cfg_filt_coeff_pp_ch2),

  .cfg_dma_dst_addr1_ch1_o  (cfg_dma_dst_addr1_ch1),
  .cfg_dma_dst_addr2_ch1_o  (cfg_dma_dst_addr2_ch1),
  .cfg_dma_dst_addr1_ch2_o  (cfg_dma_dst_addr1_ch2),
  .cfg_dma_dst_addr2_ch2_o  (cfg_dma_dst_addr2_ch2),
  .cfg_dma_buf_size_o       (cfg_dma_buf_size),
  .cfg_dma_ctrl_o           (cfg_dma_ctrl),
  .cfg_dma_ctrl_we_o        (cfg_dma_ctrl_we),
  .cfg_dma_sts_i            (cfg_dma_sts),

  .buf1_ms_cnt_ch1_i        (buf1_ms_cnt_ch1),
  .buf2_ms_cnt_ch1_i        (buf2_ms_cnt_ch1),
  .buf1_ms_cnt_ch2_i        (buf1_ms_cnt_ch2),
  .buf2_ms_cnt_ch2_i        (buf2_ms_cnt_ch2),

  .curr_wp_ch1_i            (curr_wp_ch1),
  .curr_wp_ch2_i            (curr_wp_ch2),

  .diag1_i                  (diag1_ch1),
  .diag2_i                  (diag2_ch1),
  .diag3_i                  (diag3_ch1),
  .diag4_i                  (diag4_ch1)
); 

assign loopback_sel = cfg_loopback[8-1:0];
////////////////////////////////////////////////////////////
// Name : Oscilloscope 1
// 
////////////////////////////////////////////////////////////     

osc_top #(
  .M_AXI_ADDR_BITS  (M_AXI_OSC1_ADDR_BITS),
  .M_AXI_DATA_BITS  (M_AXI_OSC1_DATA_BITS),
  .S_AXIS_DATA_BITS (S_AXIS_DATA_BITS), 
  .EVENT_SRC_NUM    (EVENT_SRC_NUM),
  .TRIG_SRC_NUM     (TRIG_SRC_NUM),
  .TRIG_CNT_BITS    (TRIG_CNT_BITS),
  .DEC_CNT_BITS     (DEC_CNT_BITS),
  .DEC_SHIFT_BITS   (DEC_SHIFT_BITS),
  .CHAN_NUM         (1))
  U_osc1(
  .clk_axi          (m_axi_osc1_aclk),   
  .clk_adc          (clk),   
  .rst_n            (m_axi_osc1_aresetn), 
  .s_axis_tdata     (s_axis_osc1_tdata), 
  .s_axis_tvalid    (rst_n),

  .event_ip_trig    (event_ip_trig),  
  .event_ip_stop    (event_ip_stop),  
  .event_ip_start   (event_ip_start), 
  .event_ip_reset   (event_ip_reset),  

  .event_sts_o      (cfg_event_sts),
  .event_sel_i      (cfg_event_sel),
  .trig_mask_i      (cfg_trig_mask),

  .cfg_trig_pre_samp_i      (cfg_trig_pre_samp),
  .cfg_trig_post_samp_i     (cfg_trig_post_samp),
  .sts_trig_pre_cnt_o       (sts_trig_pre_cnt),
  .sts_trig_post_cnt_o      (sts_trig_post_cnt),
  .sts_trig_pre_overflow_o  (sts_trig_pre_overflow),
  .sts_trig_post_overflow_o (sts_trig_post_overflow),
  .cfg_trig_low_level_i     (cfg_trig_low_level),
  .cfg_trig_high_level_i    (cfg_trig_high_level),
  .cfg_trig_edge_i          (cfg_trig_edge),

  .cfg_dec_factor_i         (cfg_dec_factor),
  .cfg_dec_rshift_i         (cfg_dec_rshift),
  .cfg_avg_en_i             (cfg_avg_en),
  .cfg_loopback_i           ({cfg_loopback[8],cfg_loopback[0]}),
  .cfg_8bit_dat_i           (cfg_8bit_dat),
  .cfg_calib_offset_i       (cfg_calib_offset_ch1),
  .cfg_calib_gain_i         (cfg_calib_gain_ch1),

  .cfg_filt_bypass_i        (cfg_filt_bypass),
  .cfg_filt_coeff_aa_i      (cfg_filt_coeff_aa_ch1),
  .cfg_filt_coeff_bb_i      (cfg_filt_coeff_bb_ch1),
  .cfg_filt_coeff_kk_i      (cfg_filt_coeff_kk_ch1),
  .cfg_filt_coeff_pp_i      (cfg_filt_coeff_pp_ch1),

  .cfg_dma_dst_addr1_i      (cfg_dma_dst_addr1_ch1),
  .cfg_dma_dst_addr2_i      (cfg_dma_dst_addr2_ch1),
  .cfg_dma_buf_size_i       (cfg_dma_buf_size),
  .cfg_dma_ctrl_i           (cfg_dma_ctrl),
  .cfg_dma_ctrl_we_i        (cfg_dma_ctrl_we),

  .cfg_dma_sts_o            (cfg_dma_sts),
  .buf1_ms_cnt_o            (buf1_ms_cnt_ch1),
  .buf2_ms_cnt_o            (buf2_ms_cnt_ch1),

  .curr_wp_o                (curr_wp_ch1),
  .diag1_o                  (diag1_ch1),
  .diag2_o                  (diag2_ch1),
  .diag3_o                  (diag3_ch1),
  .diag4_o                  (diag4_ch1),

  .trig_ip          (trig_ip),
  .trig_op          (osc1_trig_op),  
  .trig_o           (trig_out1),
  .ctl_rst          (),

  .buf_sel_in       (buf_sel_ch2),
  .buf_sel_out      (buf_sel_ch1),
  .dma_intr         (osc1_dma_intr),

  .m_axi_awaddr     (m_axi_osc1_awaddr), 
  .m_axi_awlen      (m_axi_osc1_awlen),  
  .m_axi_awsize     (m_axi_osc1_awsize), 
  .m_axi_awburst    (m_axi_osc1_awburst),
  .m_axi_awprot     (m_axi_osc1_awprot), 
  .m_axi_awcache    (m_axi_osc1_awcache),
  .m_axi_awvalid    (m_axi_osc1_awvalid),
  .m_axi_awready    (m_axi_osc1_awready),
  .m_axi_wdata      (m_axi_osc1_wdata),  
  .m_axi_wstrb      (m_axi_osc1_wstrb),  
  .m_axi_wlast      (m_axi_osc1_wlast),  
  .m_axi_wvalid     (m_axi_osc1_wvalid), 
  .m_axi_wready     (m_axi_osc1_wready), 
  .m_axi_bresp      (m_axi_osc1_bresp),  
  .m_axi_bvalid     (m_axi_osc1_bvalid), 
  .m_axi_bready     (m_axi_osc1_bready));

////////////////////////////////////////////////////////////
// Name : Oscilloscope 2
// 
////////////////////////////////////////////////////////////     

osc_top #(
  .M_AXI_ADDR_BITS  (M_AXI_OSC1_ADDR_BITS),
  .M_AXI_DATA_BITS  (M_AXI_OSC1_DATA_BITS),
  .S_AXIS_DATA_BITS (16), 
  .EVENT_SRC_NUM    (EVENT_SRC_NUM),
  .TRIG_SRC_NUM     (TRIG_SRC_NUM),
  .TRIG_CNT_BITS    (TRIG_CNT_BITS),
  .DEC_CNT_BITS     (DEC_CNT_BITS),
  .DEC_SHIFT_BITS   (DEC_SHIFT_BITS),
  .CHAN_NUM         (2))
  U_osc2(
  .clk_axi          (m_axi_osc2_aclk),   
  .clk_adc          (clk),   
  .rst_n            (m_axi_osc2_aresetn), 
  .s_axis_tdata     (s_axis_osc2_tdata), 
  .s_axis_tvalid    (rst_n),

  .event_ip_trig    (event_ip_trig),  
  .event_ip_stop    (event_ip_stop),  
  .event_ip_start   (event_ip_start), 
  .event_ip_reset   (event_ip_reset), 

  .event_sel_i      (cfg_event_sel),
  .trig_mask_i      (cfg_trig_mask),
  
  .cfg_trig_pre_samp_i      (cfg_trig_pre_samp),
  .cfg_trig_post_samp_i     (cfg_trig_post_samp),
  .cfg_trig_low_level_i     (cfg_trig_low_level),
  .cfg_trig_high_level_i    (cfg_trig_high_level),
  .cfg_trig_edge_i          (cfg_trig_edge),

  .cfg_dec_factor_i         (cfg_dec_factor),
  .cfg_dec_rshift_i         (cfg_dec_rshift),
  .cfg_avg_en_i             (cfg_avg_en),
  .cfg_loopback_i           ({cfg_loopback[12],cfg_loopback[4]}),
  .cfg_8bit_dat_i           (cfg_8bit_dat),
  .cfg_calib_offset_i       (cfg_calib_offset_ch2),
  .cfg_calib_gain_i         (cfg_calib_gain_ch2),

  .cfg_filt_bypass_i        (cfg_filt_bypass),
  .cfg_filt_coeff_aa_i      (cfg_filt_coeff_aa_ch2),
  .cfg_filt_coeff_bb_i      (cfg_filt_coeff_bb_ch2),
  .cfg_filt_coeff_kk_i      (cfg_filt_coeff_kk_ch2),
  .cfg_filt_coeff_pp_i      (cfg_filt_coeff_pp_ch2),

  .cfg_dma_dst_addr1_i      (cfg_dma_dst_addr1_ch2),
  .cfg_dma_dst_addr2_i      (cfg_dma_dst_addr2_ch2),
  .cfg_dma_buf_size_i       (cfg_dma_buf_size),
  .cfg_dma_ctrl_i           (cfg_dma_ctrl),
  .cfg_dma_ctrl_we_i        (cfg_dma_ctrl_we),

  .buf1_ms_cnt_o            (buf1_ms_cnt_ch2),
  .buf2_ms_cnt_o            (buf2_ms_cnt_ch2),

  .curr_wp_o                (curr_wp_ch2),
  .diag1_o                  (diag1_ch2),
  .diag2_o                  (diag2_ch2),
  .diag3_o                  (diag3_ch2),
  .diag4_o                  (diag4_ch2),

  .trig_ip          (trig_ip),
  .trig_op          (osc2_trig_op),  
  .trig_o           (trig_out2),
  .ctl_rst          (),

  .buf_sel_in       (buf_sel_ch1),
  .buf_sel_out      (buf_sel_ch2),
  .dma_intr         (osc2_dma_intr),
  .m_axi_awaddr     (m_axi_osc2_awaddr), 
  .m_axi_awlen      (m_axi_osc2_awlen),  
  .m_axi_awsize     (m_axi_osc2_awsize), 
  .m_axi_awburst    (m_axi_osc2_awburst),
  .m_axi_awprot     (m_axi_osc2_awprot), 
  .m_axi_awcache    (m_axi_osc2_awcache),
  .m_axi_awvalid    (m_axi_osc2_awvalid),
  .m_axi_awready    (m_axi_osc2_awready),
  .m_axi_wdata      (m_axi_osc2_wdata),  
  .m_axi_wstrb      (m_axi_osc2_wstrb),  
  .m_axi_wlast      (m_axi_osc2_wlast),  
  .m_axi_wvalid     (m_axi_osc2_wvalid), 
  .m_axi_wready     (m_axi_osc2_wready), 
  .m_axi_bresp      (m_axi_osc2_bresp),  
  .m_axi_bvalid     (m_axi_osc2_bvalid), 
  .m_axi_bready     (m_axi_osc2_bready));

endmodule