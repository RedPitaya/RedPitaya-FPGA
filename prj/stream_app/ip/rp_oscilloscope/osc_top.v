`timescale 1ns / 1ps

module osc_top
  #(parameter M_AXI_ADDR_BITS   = 32, // DMA Address bits
    parameter M_AXI_DATA_BITS   = 64, // DMA data bits
    parameter S_AXIS_DATA_BITS  = 16, // ADC data bits
    parameter DEC_CNT_BITS      = 17, // Decimator counter bits
    parameter DEC_SHIFT_BITS    = 4,  // Decimator shifter bits
    parameter TRIG_CNT_BITS     = 32, // Trigger counter bits
    parameter EVENT_SRC_NUM     = 1,  // Number of event sources
    parameter TRIG_SRC_NUM      = 1, // Number of trigger sources
    parameter CHAN_NUM          = 1)( // which channel
  input wire                              clk_axi,
  input wire                              clk_adc,
  input wire                              axi_rstn,
  input wire                              adc_rstn,
  // Slave AXI-S
  input  wire [S_AXIS_DATA_BITS-1:0]      s_axis_tdata,
  input  wire                             s_axis_tvalid,
  //
  input  wire [EVENT_SRC_NUM-1:0]         event_ip_trig,
  input  wire [EVENT_SRC_NUM-1:0]         event_ip_stop,
  input  wire [EVENT_SRC_NUM-1:0]         event_ip_start,
  input  wire [EVENT_SRC_NUM-1:0]         event_ip_reset,
  //
  output wire [             4-1:0]        event_sts_o,
  input  wire [             3-1:0]        event_sel_i,

  input  wire [    TRIG_SRC_NUM-1:0]      trig_mask_i             ,
  input  wire [   TRIG_CNT_BITS-1:0]      cfg_trig_pre_samp_i     ,
  input  wire [   TRIG_CNT_BITS-1:0]      cfg_trig_post_samp_i    ,
  output wire [   TRIG_CNT_BITS-1:0]      sts_trig_pre_cnt_o      ,
  output wire [   TRIG_CNT_BITS-1:0]      sts_trig_post_cnt_o     ,
  output wire                             sts_trig_pre_overflow_o ,
  output wire                             sts_trig_post_overflow_o,
  input  wire [S_AXIS_DATA_BITS-1:0]      cfg_trig_low_level_i    ,
  input  wire [S_AXIS_DATA_BITS-1:0]      cfg_trig_high_level_i   ,
  input  wire                             cfg_trig_edge_i         ,

  input  wire [    DEC_CNT_BITS-1:0]      cfg_dec_factor_i        ,
  input  wire [  DEC_SHIFT_BITS-1:0]      cfg_dec_rshift_i        ,
  input  wire                             cfg_avg_en_i            ,
  input  wire [               3-1:0]      cfg_loopback_i          ,
  input  wire                             cfg_8bit_dat_i          ,
  input  wire [              16-1:0]      cfg_calib_offset_i      ,
  input  wire [              16-1:0]      cfg_calib_gain_i        ,

  input  wire                             cfg_filt_bypass_i       ,
  input  wire [              18-1:0]      cfg_filt_coeff_aa_i     ,
  input  wire [              25-1:0]      cfg_filt_coeff_bb_i     ,
  input  wire [              25-1:0]      cfg_filt_coeff_kk_i     ,
  input  wire [              25-1:0]      cfg_filt_coeff_pp_i     ,

  input  wire [              32-1:0]      cfg_dma_dst_addr1_i ,
  input  wire [              32-1:0]      cfg_dma_dst_addr2_i ,
  input  wire [              32-1:0]      cfg_dma_buf_size_i      ,
  input  wire [              32-1:0]      cfg_dma_ctrl_i          ,
  input  wire                             cfg_dma_ctrl_we_i       ,
  output wire [              32-1:0]      cfg_dma_sts_o           ,


  output wire [              32-1:0]      buf1_ms_cnt_o           ,
  output wire [              32-1:0]      buf2_ms_cnt_o           ,

  output wire [              32-1:0]      curr_wp_o               ,
  output wire [              32-1:0]      diag1_o                 ,
  output wire [              32-1:0]      diag2_o                 ,
  output wire [              32-1:0]      diag3_o                 ,
  output wire [              32-1:0]      diag4_o                 ,

  input  wire [TRIG_SRC_NUM-1:0]          trig_ip,
  output wire                             trig_op,
  output wire                             ctl_rst,
  output wire                             trig_o,
  //
  input  wire                             buf_sel_in,
  output wire                             buf_sel_out,
  //   
  output wire                             dma_intr,
  //
  output wire [(M_AXI_ADDR_BITS-1):0]     m_axi_awaddr,    
  output wire [7:0]                       m_axi_awlen,     
  output wire [2:0]                       m_axi_awsize,    
  output wire [1:0]                       m_axi_awburst,   
  output wire [2:0]                       m_axi_awprot,    
  output wire [3:0]                       m_axi_awcache,   
  output wire                             m_axi_awvalid,   
  input  wire                             m_axi_awready,   
  output wire [M_AXI_DATA_BITS-1:0]       m_axi_wdata,     
  output wire [((M_AXI_DATA_BITS/8)-1):0] m_axi_wstrb,     
  output wire                             m_axi_wlast,     
  output wire                             m_axi_wvalid,    
  input  wire                             m_axi_wready,    
  input  wire [1:0]                       m_axi_bresp,     
  input  wire                             m_axi_bvalid,    
  output wire                             m_axi_bready       
);

////////////////////////////////////////////////////////////
// Signals
////////////////////////////////////////////////////////////

wire                        dma_mode;

reg                         event_num_trig;
reg                         event_num_stop;
reg                         event_num_start;
reg                         event_num_reset;

wire                        event_sts_trig;
wire                        event_sts_stop;
wire                        event_sts_start;
wire                        event_sts_reset;
wire                        ctl_trg;

wire [31:0]                 cfg_dma_diags;

wire [S_AXIS_DATA_BITS-1:0] calib_tdata;   
wire                        calib_tvalid;   
wire                        calib_tready;   

wire [S_AXIS_DATA_BITS-1:0] dec_indata;    
wire [S_AXIS_DATA_BITS-1:0] dec_tdata;    
wire                        dec_tvalid;   
wire                        dec_tready;   
wire                        ramp_en;
wire                        loopback_gpio;
wire                        loopback_dac;

wire [S_AXIS_DATA_BITS-1:0] trig_tdata;    
wire                        trig_tvalid;   
wire                        trig_tready;   

wire [S_AXIS_DATA_BITS-1:0] acq_tdata;    
wire                        acq_tvalid;   
wire                        acq_tready;   
wire                        acq_tlast;

wire  [31:0]                buf1_ms_cnt;
wire  [31:0]                buf2_ms_cnt;

wire [S_AXIS_DATA_BITS-1:0] filt_tdata;   
wire                        filt_tvalid;   

wire                        external_trig_val;

reg                         intr_reg;
reg [32-1:0]                intr_cnt;

reg [32-1:0]                curr_wp_r1, curr_wp_r2;

always @(posedge clk_adc)
begin
  curr_wp_r1 <= m_axi_awaddr;
  curr_wp_r2 <= curr_wp_r1;
end
assign curr_wp_o = curr_wp_r2;

always @(posedge clk_adc)
begin
  intr_reg <= dma_intr;
  if (~adc_rstn)
    intr_cnt <= 'h0;
  else if (~intr_reg && dma_intr) begin
    intr_cnt <= intr_cnt+1;
  end  
end

reg [32-1:0] trig_cnt, clk_cnt;
always @(posedge clk_adc)
begin
  if (~adc_rstn) begin
    trig_cnt <= 'h0;
    clk_cnt  <= 'h0;
  end else begin
    if (cfg_dma_ctrl_we_i & cfg_dma_ctrl_i[0])
      clk_cnt  <= clk_cnt + 'h1;

    if (cfg_dma_ctrl_we_i) begin
      trig_cnt <= trig_cnt + 'h1;
    end  
  end
end

reg [S_AXIS_DATA_BITS-1:0] ramp_sig;    
always @(posedge clk_adc)
begin
  if (~adc_rstn)
    ramp_sig <= 'h0;
  else begin
      ramp_sig <= ramp_sig + 'h1;
  end
end

reg [S_AXIS_DATA_BITS-1:0] dec_test;    
always @(posedge clk_adc)
begin
  if (dec_tvalid)
    dec_test <= dec_tdata;
end

assign external_trig_val = trig_ip[5] & (trig_mask_i == 'h20);

assign ramp_en       = cfg_loopback_i[2];
assign loopback_gpio = cfg_loopback_i[1];
assign loopback_dac  = cfg_loopback_i[0];
assign event_sts_o   = {event_sts_trig, event_sts_stop, event_sts_start, event_sts_reset};


assign diag1_o = intr_cnt;
assign diag2_o = trig_cnt;
assign diag3_o = clk_cnt;
assign diag4_o = cfg_dma_diags;

reg rstn_fil, rstn_cal, rstn_dec, rstn_trg, rstn_acq, rstn_smm;
always @(posedge clk_adc) // resolve high fanout timing issues
begin
  rstn_fil <= adc_rstn;
  rstn_cal <= adc_rstn;
  rstn_dec <= adc_rstn;
  rstn_trg <= adc_rstn;
  rstn_acq <= adc_rstn;
  rstn_smm <= adc_rstn;
end

osc_filter i_dfilt (
   // ADC
  .clk              ( clk_adc     ),  // ADC clock
  .rst_n            ( rstn_fil    ),  // ADC reset - active low
  // Slave AXI-S
  .s_axis_tdata     (s_axis_tdata),
  .s_axis_tvalid    (s_axis_tvalid),
  .s_axis_tready    (),
  // Master AXI-S
  .m_axis_tdata     (filt_tdata),
  .m_axis_tvalid    (filt_tvalid),
  .m_axis_tready    (),
   // configuration
  .cfg_bypass      ( cfg_filt_bypass_i   ),
  .cfg_coeff_aa    ( cfg_filt_coeff_aa_i),  // config AA coefficient
  .cfg_coeff_bb    ( cfg_filt_coeff_bb_i ),  // config BB coefficient
  .cfg_coeff_kk    ( cfg_filt_coeff_kk_i ),  // config KK coefficient
  .cfg_coeff_pp    ( cfg_filt_coeff_pp_i )   // config PP coefficient
);

////////////////////////////////////////////////////////////
// Name : Calibration
// 
////////////////////////////////////////////////////////////

osc_calib #(
  .AXIS_DATA_BITS   (S_AXIS_DATA_BITS))
  U_osc_calib(
  .clk              (clk_adc),
  .rst_n            (rstn_cal),        
  // Slave AXI-S
  .s_axis_tdata     (filt_tdata),
  .s_axis_tvalid    (filt_tvalid),
  .s_axis_tready    (),
  // Master AXI-S
  .m_axis_tdata     (calib_tdata),
  .m_axis_tvalid    (calib_tvalid),
  .m_axis_tready    (calib_tready),
  // Config
  .cfg_calib_offset (cfg_calib_offset_i), 
  .cfg_calib_gain   (cfg_calib_gain_i));

////////////////////////////////////////////////////////////
// Name : Decimation
// 
////////////////////////////////////////////////////////////
assign dec_indata = ramp_en      ? ramp_sig     : 
                   (loopback_dac ? s_axis_tdata : calib_tdata);    

osc_decimator #(
  .AXIS_DATA_BITS (S_AXIS_DATA_BITS), 
  .CNT_BITS       (17),
  .SHIFT_BITS     (4))
  U_osc_decimator(
  .clk            (clk_adc),                   
  .rst_n          (rstn_dec),        
  .s_axis_tdata   (dec_indata),          
  .s_axis_tvalid  (calib_tvalid),     
  .s_axis_tready  (calib_tready),                                                                 
  .m_axis_tdata   (dec_tdata),          
  .m_axis_tvalid  (dec_tvalid),    
  .m_axis_tready  (dec_tready),      
  .ctl_rst        (event_num_reset),                                                                     
  .cfg_avg_en     (cfg_avg_en_i),            
  .cfg_dec_factor (cfg_dec_factor_i),        
  .cfg_dec_rshift (cfg_dec_rshift_i));       

////////////////////////////////////////////////////////////
// Name : Trigger
// 
////////////////////////////////////////////////////////////

osc_trigger #(
  .AXIS_DATA_BITS       (S_AXIS_DATA_BITS),
  .TRIG_LEVEL_BITS      (S_AXIS_DATA_BITS))
  U_osc_trigger(
  .clk                  (clk_adc),                         
  .rst_n                (rstn_trg),                                                    
  .ctl_rst              (event_num_reset),                                                    
  .cfg_trig_low_level   (cfg_trig_low_level_i),          
  .cfg_trig_high_level  (cfg_trig_high_level_i),         
  .cfg_trig_edge        (cfg_trig_edge_i),                                                 
  .trig                 (trig_op),                                                    
  .s_axis_tdata         (dec_tdata),                
  .s_axis_tvalid        (dec_tvalid),               
  .s_axis_tready        (dec_tready),                                                          
  .m_axis_tdata         (trig_tdata),                
  .m_axis_tvalid        (trig_tvalid),  
  .m_axis_tready        (trig_tready));                  

////////////////////////////////////////////////////////////
// Name : Acquire
// 
////////////////////////////////////////////////////////////

osc_acquire #(
  .AXIS_DATA_BITS         (S_AXIS_DATA_BITS),
  .CNT_BITS               (TRIG_CNT_BITS))
  U_osc_acq(
  .clk                    (clk_adc),
  .rst_n                  (rstn_acq),
  .s_axis_tdata           (trig_tdata),     
  .s_axis_tvalid          (trig_tvalid), 
  .s_axis_tready          (trig_tready),                                
  .m_axis_tdata           (acq_tdata),     
  .m_axis_tvalid          (acq_tvalid),    
  .m_axis_tready          (acq_tready),
  .m_axis_tlast           (acq_tlast),  
  .ctl_start              (event_num_start), 
  .ctl_rst                (event_num_reset),   
  .ctl_stop               (event_num_stop),   
  .ctl_trig               (ctl_trg),   
  .cfg_mode               (dma_mode),
  .cfg_trig_pre_samp      (cfg_trig_pre_samp_i),  
  .cfg_trig_post_samp     (cfg_trig_post_samp_i),   
  .sts_start              (event_sts_start), 
  .sts_stop               (event_sts_stop),
  .sts_trig               (event_sts_trig),
  .sts_trig_pre_cnt       (sts_trig_pre_cnt_o),
  .sts_trig_pre_overflow  (sts_trig_pre_overflow_o),  
  .sts_trig_post_cnt      (sts_trig_post_cnt_o),
  .sts_trig_post_overflow (sts_trig_post_overflow_o));    
  
////////////////////////////////////////////////////////////
// Name : DMA S2MM
// 
////////////////////////////////////////////////////////////
  
rp_dma_s2mm #(
  .AXI_ADDR_BITS  (M_AXI_ADDR_BITS),
  .AXI_DATA_BITS  (M_AXI_DATA_BITS),
  .AXIS_DATA_BITS (S_AXIS_DATA_BITS),
  .AXI_BURST_LEN  (16))
  U_dma_s2mm(
  .m_axi_aclk     (clk_axi),        
  .s_axis_aclk    (clk_adc),      
  .aresetn        (rstn_smm),  
  .busy           (),
  .intr           (dma_intr),     
  .mode           (dma_mode),  
  .reg_wr_data    (cfg_dma_ctrl_i),       
  .reg_wr_we      (cfg_dma_ctrl_we_i),   
  .reg_sts        (cfg_dma_sts_o),
  .reg_diags      (cfg_dma_diags),  
  .reg_dst_addr1  (cfg_dma_dst_addr1_i),
  .reg_dst_addr2  (cfg_dma_dst_addr2_i),
  .reg_buf_size   (cfg_dma_buf_size_i),
  .ctl_start_o    (ctl_start_o),
  .ctl_start_ext  (external_trig_val),
  .use_8bit       (cfg_8bit_dat_i),
  .buf1_ms_cnt    (buf1_ms_cnt_o),
  .buf2_ms_cnt    (buf2_ms_cnt_o),
  .buf_sel_in     (buf_sel_in),
  .buf_sel_out    (buf_sel_out),
  .m_axi_awaddr   (m_axi_awaddr), 
  .m_axi_awlen    (m_axi_awlen),  
  .m_axi_awsize   (m_axi_awsize), 
  .m_axi_awburst  (m_axi_awburst),
  .m_axi_awprot   (m_axi_awprot), 
  .m_axi_awcache  (m_axi_awcache),
  .m_axi_awvalid  (m_axi_awvalid),
  .m_axi_awready  (m_axi_awready),
  .m_axi_wdata    (m_axi_wdata),  
  .m_axi_wstrb    (m_axi_wstrb),  
  .m_axi_wlast    (m_axi_wlast),  
  .m_axi_wvalid   (m_axi_wvalid), 
  .m_axi_wready   (m_axi_wready), 
  .m_axi_bresp    (m_axi_bresp),  
  .m_axi_bvalid   (m_axi_bvalid), 
  .m_axi_bready   (m_axi_bready), 
  .s_axis_tdata   (acq_tdata),    
  .s_axis_tvalid  (acq_tvalid),  
  .s_axis_tready  (acq_tready),  
  .s_axis_tlast   (acq_tlast));     

always @(posedge clk_adc)
begin
  if (adc_rstn == 0) begin
    event_num_trig  <= 0;    
    event_num_start <= 0;   
    event_num_stop  <= 0;    
    event_num_reset <= 0;   
  end else begin
    event_num_trig  <= event_ip_trig[event_sel_i];    
    event_num_start <= event_ip_start[event_sel_i];   
    event_num_stop  <= event_ip_stop[event_sel_i];     
    event_num_reset <= event_ip_reset[event_sel_i];  
  end  
end

assign ctl_rst = event_num_reset;
assign event_sts_reset = 0;

assign ctl_trg = event_num_trig | |(trig_ip & trig_mask_i);
assign trig_o  = ctl_start_o;
endmodule