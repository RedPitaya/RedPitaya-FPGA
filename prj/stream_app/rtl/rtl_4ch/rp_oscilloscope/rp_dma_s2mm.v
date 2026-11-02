`timescale 1ns / 1ps

module rp_dma_s2mm
  #(parameter AXI_ADDR_BITS   = 32,                    
    parameter AXI_DATA_BITS   = 64,                        
    parameter AXIS_DATA_BITS  = 16,              
    parameter AXI_BURST_LEN   = 16)( 
  input  wire                           m_axi_aclk,
  input  wire                           s_axis_aclk,   
  input  wire                           aresetn,      
  //
  output wire                           busy,
  output wire                           intr,
  output wire                           mode,
  //
  input  wire [31:0]                    reg_wr_data,
  input  wire                           reg_wr_we,      
  //
  output wire [31:0]                    reg_ctrl,
  output wire [31:0]                    reg_sts,  
  output wire [31:0]                    reg_diags,
  input  wire [31:0]                    reg_dst_addr1,  
  input  wire [31:0]                    reg_dst_addr2,  
  input  wire [31:0]                    reg_buf_size,
  input  wire [63:0]                    timestamp_counter,  // in the stream clock domain
  input  wire [63:0]                    timestamp_init,
  input  wire                           timestamp_init_we,
  output wire                           ctl_start_o,
  input  wire                           ctl_start_ext,
  input  wire                           use_8bit,

  //
  output wire [63:0]                    buf1_timestamp,
  output wire [63:0]                    buf2_timestamp,
  input  wire                           s_axis_drop,
  input  wire                           s_axis_flush,
  input  wire                           s_axis_series,  // block mode: series that end with the arm (s_axis_flush)
  output wire [63:0]                    buf1_lost,
  output wire [63:0]                    buf2_lost,
  output wire [63:0]                    buf1_wait,
  output wire [63:0]                    buf2_wait,
  input  wire                           buf_sel_in,
  output wire                           buf_sel_out,
  //                                        
  output wire [(AXI_ADDR_BITS-1):0]     m_axi_awaddr,     
  output wire [7:0]                     m_axi_awlen,      
  output wire [2:0]                     m_axi_awsize,     
  output wire [1:0]                     m_axi_awburst,    
  output wire [2:0]                     m_axi_awprot,     
  output wire [3:0]                     m_axi_awcache,    
  output wire                           m_axi_awvalid,    
  input  wire                           m_axi_awready,     
  output wire [AXI_DATA_BITS-1:0]       m_axi_wdata,                                            
  output wire [((AXI_DATA_BITS/8)-1):0] m_axi_wstrb,      
  output wire                           m_axi_wlast,      
  output wire                           m_axi_wvalid,     
  input  wire                           m_axi_wready,     
  input  wire [1:0]                     m_axi_bresp,      
  input  wire                           m_axi_bvalid,     
  output wire                           m_axi_bready,            
  // 
  input  wire [AXIS_DATA_BITS-1:0]      s_axis_tdata,
  input  wire                           s_axis_tvalid,
  output wire                           s_axis_tready,      
  input  wire                           s_axis_tlast                       
 );

////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////

localparam FIFO_CNT_BITS = 10;  // Size of the FIFO data counter

////////////////////////////////////////////////////////////
// Signals
////////////////////////////////////////////////////////////

wire                      fifo_rst;
wire [AXI_DATA_BITS-1:0]  fifo_wr_data; 
wire [63:0]               fifo_wr_ts;     // timestamp of the first sample of the word
wire [63:0]               fifo_rd_ts;
wire                      fifo_wr_en;
wire                      fifo_wr_ok;
wire                      fifo_full;
reg  [31:0]               fifo_wr_words;  // words the data FIFO took, free running
wire                      fifo_wr_we;
wire [AXI_DATA_BITS-1:0]  fifo_rd_data;
wire                      fifo_rd_re;
wire                      fifo_empty;
wire [FIFO_CNT_BITS-1:0]  fifo_rd_cnt;
wire [7:0]                req_data;
wire                      req_we;
wire                      fifo_dis;
reg                       fifo_dis_r;

wire [1:0]                upsize_lvl;
reg                       ctl_start_r;
reg                       use_8bit_r;

assign m_axi_wdata  = fifo_rd_data;

////////////////////////////////////////////////////////////
// Name : Lost samples, stream clock domain
// Words the FIFO does not take (the same condition as its write enable) and
// samples dropped while the acquisition waits for a trigger are summed in the
// stream clock domain and handed over to the controller with a toggle handshake
// (the 250-12 runs the stream at 250 MHz and the AXI side at 125 MHz).
////////////////////////////////////////////////////////////

wire        first_rst;
reg  [ 2:0] first_rst_s;
reg  [ 2:0] lost_ack_s;
reg  [15:0] lost_acc, lost_xfer;
reg  [15:0] wait_acc, wait_xfer;  // the part of the lost samples dropped while waiting for a trigger
reg         lost_req;
reg  [ 2:0] lost_req_m;
reg  [15:0] lost_add, wait_add;
reg         lost_add_we;
wire [15:0] lost_now = ((fifo_wr_we && ~fifo_wr_ok && ~first_rst_s[2]) ? (use_8bit ? 16'd8 : 16'd4) : 16'd0)
                     + s_axis_drop;

always @(posedge s_axis_aclk) begin
  first_rst_s <= {first_rst_s[1:0], first_rst};
  lost_ack_s  <= {lost_ack_s[1:0], lost_req_m[2]};
  if (~aresetn) begin
    lost_acc <= 16'd0;
    wait_acc <= 16'd0;
    lost_req <= 1'b0;
  end else if ((lost_req == lost_ack_s[2]) && ((lost_acc != 16'd0) || (lost_now != 16'd0))) begin
    lost_xfer <= lost_acc + lost_now;
    wait_xfer <= wait_acc + s_axis_drop;
    lost_acc  <= 16'd0;
    wait_acc  <= 16'd0;
    lost_req  <= ~lost_req;
  end else begin
    lost_acc  <= lost_acc + lost_now;
    wait_acc  <= wait_acc + s_axis_drop;
  end
end

always @(posedge m_axi_aclk) begin
  lost_req_m  <= {lost_req_m[1:0], lost_req};
  lost_add_we <= lost_req_m[2] ^ lost_req_m[1];
  lost_add    <= lost_xfer;  // stable since before the toggle
  wait_add    <= wait_xfer;
end
assign m_axi_wstrb  = {AXI_DATA_BITS/8{1'b1}};
assign m_axi_bready = m_axi_bvalid;

////////////////////////////////////////////////////////////
// Name : DMA S2MM Control
// Accepts DMA requests and sends data over the AXI bus.
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk) begin
  ctl_start_r <= ctl_start_o;
  use_8bit_r  <= use_8bit;
end

always @(posedge s_axis_aclk)
  fifo_dis_r <= fifo_dis;

rp_dma_s2mm_ctrl #(
  .AXI_ADDR_BITS  (AXI_ADDR_BITS),
  .AXI_DATA_BITS  (AXI_DATA_BITS),
  .AXI_BURST_LEN  (AXI_BURST_LEN),
  .FIFO_CNT_BITS  (FIFO_CNT_BITS))
  U_dma_s2mm_ctrl(
  .m_axi_aclk     (m_axi_aclk),         
  .s_axis_aclk    (s_axis_aclk),       
  .m_axi_aresetn  (aresetn),     
  .busy           (busy),
  .intr           (intr),      
  .mode           (mode),    
  .reg_wr_data    (reg_wr_data),       
  .reg_wr_we      (reg_wr_we),           
  .reg_ctrl       (reg_ctrl),  
  .reg_sts        (reg_sts),  
  .reg_diags      (reg_diags),  
  .reg_dst_addr1  (reg_dst_addr1),  
  .reg_dst_addr2  (reg_dst_addr2),  
  .reg_buf_size   (reg_buf_size), 
  .data_ts        (fifo_rd_ts),
  .fifo_wr_words  (fifo_wr_words),
  .timestamp_init (timestamp_init),
  .timestamp_init_we (timestamp_init_we),
  .ctl_start_o    (ctl_start_o),  
  .ctl_start_ext  (ctl_start_ext),     
  .upsized_we_i   (fifo_wr_we),
  .fifo_rst       (fifo_rst),    
  .fifo_lvl       (fifo_rd_cnt),
  .upsize_lvl     (upsize_lvl),
  .use_8bit       (use_8bit),  
  .req_data       (req_data),
  .req_we         (req_we), 
  .data_valid     (s_axis_tvalid),
  .buf1_timestamp (buf1_timestamp),
  .buf2_timestamp (buf2_timestamp),
  .lost_add       (lost_add),
  .lost_add_we    (lost_add_we),
  .wait_add       (wait_add),
  .first_rst_o    (first_rst),
  .flush_i        (s_axis_flush),
  .series_mode_i  (s_axis_series),
  .buf1_lost      (buf1_lost),
  .buf2_lost      (buf2_lost),
  .buf1_wait      (buf1_wait),
  .buf2_wait      (buf2_wait),
  .buf_sel_in     (buf_sel_in),
  .buf_sel_out    (buf_sel_out),
  .fifo_dis       (fifo_dis),
  .m_axi_awaddr   (m_axi_awaddr),       
  .m_axi_awlen    (m_axi_awlen),        
  .m_axi_awsize   (m_axi_awsize),       
  .m_axi_awburst  (m_axi_awburst),      
  .m_axi_awprot   (m_axi_awprot),       
  .m_axi_awcache  (m_axi_awcache),      
  .m_axi_awvalid  (m_axi_awvalid),      
  .m_axi_awready  (m_axi_awready), 
  .m_axi_wvalid   (m_axi_wvalid),    
  .m_axi_wready   (m_axi_wready),     
  .m_axi_wlast    (m_axi_wlast));      

////////////////////////////////////////////////////////////
// Name : DMA S2MM Upsizer
// Packs input data into the AXI bus width. 
////////////////////////////////////////////////////////////

rp_dma_s2mm_upsize #(
  .AXI_DATA_BITS  (AXI_DATA_BITS),
  .AXIS_DATA_BITS (AXIS_DATA_BITS))
  U_dma_s2mm_upsize(
  .clk            (s_axis_aclk),              
  .rst            (~aresetn || (ctl_start_o & ~ctl_start_r) || (use_8bit ^ use_8bit_r)),    
  .req_data       (req_data),
  .req_we         (req_we),
  .upsize_lvl     (upsize_lvl),
  .use_8bit       (use_8bit),
  .ts_i           (timestamp_counter),
  .s_axis_tdata   (s_axis_tdata),      
  .s_axis_tvalid  (s_axis_tvalid),     
  .s_axis_tready  (s_axis_tready),     
  .s_axis_tlast   (s_axis_tlast),                 
  .m_axis_tdata   (fifo_wr_data),      
  .m_axis_tts     (fifo_wr_ts),
  .m_axis_tvalid  (fifo_wr_we),     
  .m_axis_tready  (1'b1));      

////////////////////////////////////////////////////////////
// Name : Data FIFO
// Stores the data to transfer.
////////////////////////////////////////////////////////////

fifo_axi_data 
  U_fifo_axi_data(
  .wr_clk         (s_axis_aclk),               
  .rd_clk         (m_axi_aclk),               
  .rst            (fifo_rst),     
  .din            ({fifo_wr_ts, fifo_wr_data}),
  .wr_en          (fifo_wr_en),
  .full           (fifo_full),  // also high while the FIFO is in reset
  .dout           ({fifo_rd_ts, fifo_rd_data}),
  .rd_en          (fifo_rd_re),                                 
  .empty          (fifo_empty),                 
  .rd_data_count  (fifo_rd_cnt), 
  .wr_rst_busy    (),     
  .rd_rst_busy    ());
  
assign fifo_rd_re = m_axi_wvalid & m_axi_wready;  

assign fifo_wr_en = fifo_wr_we && ~fifo_dis;
// a word the FIFO does not take (disabled, in reset or full) is lost
assign fifo_wr_ok = fifo_wr_en && ~fifo_full;

always @(posedge s_axis_aclk) begin
  if (~aresetn)
    fifo_wr_words <= 32'd0;
  else if (fifo_wr_ok)
    fifo_wr_words <= fifo_wr_words + 32'd1;
end
 
endmodule
