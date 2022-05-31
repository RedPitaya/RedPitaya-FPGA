`timescale 1ns / 1ps

module rp_dma_s2mm_upsize
  #(parameter AXI_DATA_BITS   = 64,
    parameter AXIS_DATA_BITS  = 16,     
    parameter AXI_BURST_LEN   = 16)(    
  input  wire                       clk,
  input  wire                       rst,
  
  output reg  [7:0]                 req_data,
  output reg                        req_we,
  output      [1:0]                 upsize_lvl,
  input  wire                       use_8bit,

  input  wire [AXIS_DATA_BITS-1:0]  s_axis_tdata,
  input  wire                       s_axis_tvalid,
  output wire                       s_axis_tready,      
  input  wire                       s_axis_tlast,    
  
  output wire [AXI_DATA_BITS-1:0]   m_axis_tdata,
  output reg                        m_axis_tvalid,
  input  wire                       m_axis_tready 
);

localparam MUX_MAX  = AXI_DATA_BITS/AXIS_DATA_BITS;
localparam MUX_MAX8 = AXI_DATA_BITS/(AXIS_DATA_BITS/2);



reg  [1:0]  mux_sel;
reg  [3:0]  mux_sel8;
reg  [6:0]  xfer_cnt;
wire [6:0]  req_len;
reg         tlast;
wire        max_cond_16bit = (mux_sel  == MUX_MAX -1);
wire        max_cond_8bit  = (mux_sel8 == MUX_MAX8-1);

reg  [AXI_DATA_BITS-1:0] upsized_data_8bit, upsized_data_16bit;

genvar      i,k;

assign s_axis_tready = 1'b1;
assign req_len = xfer_cnt+1;
assign upsize_lvl = mux_sel;
assign m_axis_tdata = use_8bit ? upsized_data_8bit : upsized_data_16bit;

////////////////////////////////////////////////////////////
// Name : 
// 
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst == 1) begin
    xfer_cnt <= 0;  
  end else begin
    if ((m_axis_tvalid == 1) && (m_axis_tready == 1)) begin
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
    if (((m_axis_tvalid == 1) && (m_axis_tready == 1) && ((tlast == 1) || (xfer_cnt == AXI_BURST_LEN-1)))) begin
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
    if ((s_axis_tvalid == 1) && (s_axis_tready == 1) && ~use_8bit) begin
      if (max_cond_16bit) begin
        mux_sel <= 0;
      end else begin
        mux_sel <= mux_sel + 1;
      end
    end
  end
end

always @(posedge clk)
begin
  if (rst == 1) begin
    mux_sel8 <= 0;  
  end else begin
    if ((s_axis_tvalid == 1) && (s_axis_tready == 1) &&  use_8bit) begin
      if (max_cond_8bit) begin
        mux_sel8 <= 0;
      end else begin
        mux_sel8 <= mux_sel8 + 1;
      end
    end
  end
end

////////////////////////////////////////////////////////////
// Name : TDATA
// 
////////////////////////////////////////////////////////////

generate 
  for (i=0; i<MUX_MAX; i=i+1) begin : gen_data16
    always @(posedge clk)
    begin
      if (mux_sel == i) begin
        upsized_data_16bit[i*AXIS_DATA_BITS +: AXIS_DATA_BITS] <= s_axis_tdata;
      end
    end
  end  
endgenerate

generate 
  for (k=0; k<MUX_MAX8; k=k+1) begin : gen_data8
    always @(posedge clk)
    begin
      if (mux_sel8 == k) begin
        upsized_data_8bit[k*(AXIS_DATA_BITS/2) +: (AXIS_DATA_BITS/2)] <= s_axis_tdata[16-1 : 8];
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
    if (( ((max_cond_16bit && ~use_8bit) || (max_cond_8bit && use_8bit)) || (s_axis_tlast == 1)) && (s_axis_tvalid == 1) && (s_axis_tready == 1)) begin
      m_axis_tvalid <= 1;
    end else begin
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
    if ((s_axis_tlast == 1) && (s_axis_tvalid == 1) && (s_axis_tready == 1)) begin
      tlast <= 1;
    end 
  end
end

endmodule