`timescale 1ns / 1ps

module gpio_dma_s2mm_upsize
  #(parameter AXI_DATA_BITS   = 64,
    parameter AXIS_DATA_BITS  = 16,     
    parameter AXI_BURST_LEN   = 16)(    
  input  wire                       clk,
  input  wire                       rst,
  
  output reg  [7:0]                 req_data,
  output reg                        req_we,

  input  wire [AXIS_DATA_BITS-1:0]  s_axis_tdata,
  input  wire                       s_axis_tvalid,
  output wire                       s_axis_tready,      
  input  wire                       s_axis_tlast,    
  
  output reg  [AXI_DATA_BITS-1:0]   m_axis_tdata,
  output reg                        m_axis_tvalid,
  input  wire                       m_axis_tready 
);

localparam MUX_MAX = AXI_DATA_BITS/AXIS_DATA_BITS;
localparam [1:0] MUX_LAST = MUX_MAX[1:0]-1'b1;

reg  [1:0]  mux_sel;
reg  [6:0]  xfer_cnt;
wire [6:0]  req_len;
reg         tlast;
genvar      i;
wire        input_transfer;
wire        output_transfer;
wire        word_complete;

assign s_axis_tready = ~m_axis_tvalid | m_axis_tready;
assign input_transfer = s_axis_tvalid & s_axis_tready;
assign output_transfer = m_axis_tvalid & m_axis_tready;
assign word_complete = input_transfer &
                       ((mux_sel == MUX_LAST) | s_axis_tlast);
assign req_len = xfer_cnt+1;

////////////////////////////////////////////////////////////
// Name : 
// 
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst == 1) begin
    xfer_cnt <= 0;  
  end else begin
    if (output_transfer) begin
      if (xfer_cnt == AXI_BURST_LEN-1) begin
        xfer_cnt <= 0;      
      end else begin
        xfer_cnt <= xfer_cnt + 1;      
      end
    end
  end
end

////////////////////////////////////////////////////////////
// Name : Request Data
// Sends the transfer count and indicates if this is the 
// last transfer.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  req_data <= {tlast, req_len};
end

////////////////////////////////////////////////////////////
// Name : 
// 
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst == 1) begin
    req_we <= 0;  
  end else begin
    if (output_transfer && ((tlast == 1) || (xfer_cnt == AXI_BURST_LEN-1))) begin
      req_we <= 1;      
    end else begin
      req_we <= 0;  
    end
  end
end

////////////////////////////////////////////////////////////
// Name : Mux Select
// Selects which part of the output data should have the
// input sample assigned. 
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst == 1) begin
    mux_sel <= 0;  
  end else begin
    if (input_transfer) begin
      if ((mux_sel == MUX_LAST) || s_axis_tlast) begin
        mux_sel <= 0;
      end else begin
        mux_sel <= mux_sel + 1;
      end
    end
  end
end

////////////////////////////////////////////////////////////
// Name : TDATA
// 
////////////////////////////////////////////////////////////

generate 
  for (i=0; i<MUX_MAX; i=i+1) begin : gen_data
    always @(posedge clk)
    begin
      if ((mux_sel == i) && input_transfer) begin
        m_axis_tdata[i*AXIS_DATA_BITS +: AXIS_DATA_BITS] <= s_axis_tdata;
      end
    end
  end  
endgenerate

////////////////////////////////////////////////////////////
// Name : TVALID
// Set the valid signal if all samples are assigned to the
// ouput data or the last sample has arrived.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst == 1) begin
    m_axis_tvalid <= 0;
  end else begin
    if (word_complete) begin
      m_axis_tvalid <= 1;
    end else if (output_transfer) begin
      m_axis_tvalid <= 0;
    end
  end
end

////////////////////////////////////////////////////////////
// Name : TLAST
// Indicates that the last sample has been sent. 
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst == 1) begin
    tlast <= 0;
  end else begin
    if (word_complete) begin
      tlast <= s_axis_tlast;
    end else if (output_transfer) begin
      tlast <= 0;
    end
  end
end

endmodule
