`timescale 1ns / 1ps

module rp_dma_mm2s
  #(parameter AXI_ADDR_BITS   = 32,                    
    parameter AXI_DATA_BITS   = 64,                        
    parameter AXIS_DATA_BITS  = 16,              
    parameter AXI_BURST_LEN   = 16,
    parameter REG_ADDR_BITS   = 1,
    parameter CH_NUM          = 0
)(    
  input  wire                           m_axi_aclk,
  input  wire                           s_axis_aclk,   
  input  wire                           axi_rstn,      
  input  wire                           adc_rstn,      

  //
  output wire                           busy,
  output wire                           intr,
  output wire                           mode,  
  //
  //output      [31:0]                    reg_ctrl,
  input  wire                           ctrl_val, 
  output      [31:0]                    reg_sts,
  //input  wire                           sts_val, 

  input [AXI_ADDR_BITS-1:0]             dac_step,
  input [AXI_ADDR_BITS-1:0]             dac_buf_size,
  input [AXI_ADDR_BITS-1:0]             dac_buf1_adr,
  input [AXI_ADDR_BITS-1:0]             dac_buf2_adr,
  output [AXI_ADDR_BITS-1:0]            dac_rp,


  input                                 dac_trig,
  input  [ 8-1:0]                       dac_ctrl_reg,
  //
  output wire [AXIS_DATA_BITS-1: 0]     dac_rdata_o,
  output wire                           dac_rvalid_o,
  output [32-1:0]                       diag_reg,
  output [32-1:0]                       diag_reg2,
  input                                 set_8bit_i,

  // 
  output wire [3:0]                       m_axi_arid_o     , // read address ID
  output wire [AXI_ADDR_BITS-1: 0]        m_axi_araddr_o   , // read address
  output wire [7:0]                       m_axi_arlen_o    , // read burst length
  output wire [2:0]                       m_axi_arsize_o   , // read burst size
  output wire [1:0]                       m_axi_arburst_o  , // read burst type
  output wire [1:0]                       m_axi_arlock_o   , // read lock type
  output wire [3:0]                       m_axi_arcache_o  , // read cache type
  output wire [2:0]                       m_axi_arprot_o   , // read protection type
  output wire                             m_axi_arvalid_o  , // read address valid
  input  wire                             m_axi_arready_i  , // read address ready
  output wire [3:0]                       m_axi_arqos_o    , // read QOS
  input  wire [    3: 0]                  m_axi_rid_i      , // read response ID
  input  wire [AXI_DATA_BITS-1: 0]        m_axi_rdata_i    , // read data
  input  wire [    1: 0]                  m_axi_rresp_i    , // read response
  input  wire                             m_axi_rlast_i    , // read last
  input  wire                             m_axi_rvalid_i   , // read response valid
  output wire                             m_axi_rready_o     // read response ready                   
 );

////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////

localparam FIFO_CNT_BITS = 12;  // Size of the FIFO data counter
localparam FIFO_MAX      = 256-2;

////////////////////////////////////////////////////////////
// Signals
////////////////////////////////////////////////////////////

wire                      fifo_rst;
wire                      downsize_rst;

reg  [AXI_DATA_BITS-1:0]  fifo_wr_data; 
reg                       fifo_wr_we;

wire [AXI_DATA_BITS-1:0]  fifo_rd_data;
wire                      fifo_rd_re;
wire                      fifo_empty;
wire                      fifo_full;
reg                       fifo_full_r;
reg                       fifo_full_rr;

wire [FIFO_CNT_BITS-1:0]  fifo_wr_cnt; 
wire [FIFO_CNT_BITS-1:0]  fifo_rd_cnt; 
wire                      fifo_almost_full    = fifo_wr_cnt > FIFO_MAX;
wire                      fifo_almost_full_rd = fifo_rd_cnt > FIFO_MAX;
reg                       rstn_logic,rstn_fifo;


always @(posedge m_axi_aclk) begin
fifo_wr_data <= m_axi_rdata_i;                    // write data into the FIFO from AXI
fifo_wr_we   <= m_axi_rvalid_i && m_axi_rready_o; // when valid data is on the bus
end

assign m_axi_arlock_o  = 2'b00; 
assign m_axi_arsize_o  = $clog2(AXI_DATA_BITS/8); // how many bytes per beat  
assign m_axi_arburst_o = 2'b01;     // Incrementing burst
assign m_axi_arprot_o  = 3'b000;    // no protected read
assign m_axi_arcache_o = 4'b0011;   // buffering allowed, cached
assign m_axi_arid_o    = CH_NUM + 2;   // different IDs for each channel
assign m_axi_arqos_o   = 4'hF;        // elevate QOS priority


always @(posedge m_axi_aclk) // resolve high fanout timing issues
begin
  rstn_logic <= axi_rstn;
  rstn_fifo  <= axi_rstn;
end
////////////////////////////////////////////////////////////
// Name : DMA MM2S Control
// Accepts DMA requests and sends data over the AXI bus.
////////////////////////////////////////////////////////////

rp_dma_mm2s_ctrl #(
  .AXI_ADDR_BITS  (AXI_ADDR_BITS),
  .AXI_DATA_BITS  (AXI_DATA_BITS),
  .AXI_BURST_LEN  (AXI_BURST_LEN),
  .FIFO_CNT_BITS  (FIFO_CNT_BITS),
  .REG_ADDR_BITS  (REG_ADDR_BITS))
  U_dma_mm2s_ctrl(
  .m_axi_aclk     (m_axi_aclk),         
  .s_axis_aclk    (s_axis_aclk),       
  .m_axi_aresetn  (rstn_logic),     
  .busy           (busy),
  .intr           (intr),      
  .mode           (mode),    
  .ctrl_val       (ctrl_val),
  .reg_sts        (reg_sts),
  .data_valid       (dac_rvalid_o),
  .dac_rp           (dac_rp),
  .dac_buf_size     (dac_buf_size),
  .dac_buf1_adr     (dac_buf1_adr),
  .dac_buf2_adr     (dac_buf2_adr),
  .dac_trig         (dac_trig),
  .dac_ctrl_reg     (dac_ctrl_reg),
  .diag_reg         (diag_reg),
  .diag_reg2        (diag_reg2),
  .fifo_rst_o       (fifo_rst),
  .downsize_rst_o   (downsize_rst),
  .fifo_full        (fifo_full | fifo_almost_full),   
  .fifo_re          ((fifo_rd_re | fifo_empty)),   
  .m_axi_dac_araddr_o   (m_axi_araddr_o),       
  .m_axi_dac_arlen_o    (m_axi_arlen_o),      
  .m_axi_dac_arvalid_o  (m_axi_arvalid_o), 
  .m_axi_dac_rready_o   (m_axi_rready_o),            
  .m_axi_dac_arready_i  (m_axi_arready_i), 
  .m_axi_dac_rvalid_i   (m_axi_rvalid_i),    
  .m_axi_dac_rlast_i    (m_axi_rlast_i));      
 
////////////////////////////////////////////////////////////
// Name : DMA MM2S Downsize 
// Packs input data into the AXI bus width. 
////////////////////////////////////////////////////////////

always @(posedge s_axis_aclk) // resolve high fanout timing issues
begin
  fifo_full_r  <= fifo_full;
  fifo_full_rr <= fifo_full_r;
end

rp_dma_mm2s_downsize #(
  .AXI_DATA_BITS  (AXI_DATA_BITS),
  .AXI_ADDR_BITS  (AXI_ADDR_BITS),
  .AXIS_DATA_BITS (AXIS_DATA_BITS),
  .AXI_BURST_LEN  (AXI_BURST_LEN))
  U_dma_mm2s_downsize(
  .clk            (s_axis_aclk),              
  .rst            ((adc_rstn==1'b1 && downsize_rst==1'b0)),        
  .fifo_empty     (fifo_empty),
  .fifo_full      (fifo_full_rr | fifo_almost_full_rd),
  .fifo_rd_data   (fifo_rd_data),          
  .fifo_rd_re     (fifo_rd_re),     
  .dac_pntr_step  (dac_step),
  .set_8bit_i     (set_8bit_i),
  .m_axis_tdata   (dac_rdata_o),      
  .m_axis_tvalid  (dac_rvalid_o));      


////////////////////////////////////////////////////////////
// Name : Data FIFO
// Stores the data to transfer.
////////////////////////////////////////////////////////////


fifo_axi_data_dac 
  U_fifo_axi_data(
  .wr_clk         (m_axi_aclk),               
  .rd_clk         (s_axis_aclk),               
  .rst            (!(rstn_fifo==1'b1 && fifo_rst==1'b0)),
  .din            (fifo_wr_data),                                 
  .wr_en          (fifo_wr_we),            
  .full           (fifo_full),   
  .dout           (fifo_rd_data),    
  .rd_en          (fifo_rd_re),
  .rd_data_count  (fifo_rd_cnt),
  .wr_data_count  (fifo_wr_cnt),
  .empty          (fifo_empty)
);

endmodule
