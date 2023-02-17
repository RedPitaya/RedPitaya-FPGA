`timescale 1ns / 1ps

module gpio_dma_mm2s_downsize
  #(parameter AXI_DATA_BITS   = 64,
    parameter AXIS_DATA_BITS  = 16,     
    parameter AXI_BURST_LEN   = 16)(    
  input  wire                       clk,
  input  wire                       rst,
  
  input  wire                       fifo_empty,
  input  wire                       fifo_full,

  input  wire [AXI_DATA_BITS-1:0]   fifo_rd_data,
  output wire                       fifo_rd_re,
    
  output reg  [AXIS_DATA_BITS-1:0]  m_axis_tdata,
  output wire                       m_axis_tvalid,
  input  wire                       m_axis_tready 
);

reg  [2:0]  rd_cnt;
reg  [2:0]  empty_reg;
reg         first_full, full_r, full_r2;


// FIFO read pulse
assign fifo_rd_re     = (rd_cnt == 'd1) & m_axis_tready & first_full; 

// enable RLE when FIFO is filled up
assign m_axis_tvalid  = first_full;

// must wait to fill up the FIFO before starting to read
always @(posedge clk)
begin
  if (rst == 0) begin
    first_full <= 'b0;
  end else begin 
    if (fifo_full & ~fifo_empty & ~first_full)
      first_full <= 'h1;
  end
end

always @(posedge clk)
  full_r <= first_full;

always @(posedge clk)
begin
  if (rst == 0) begin
    first_full <= 'b0;
  end else begin 
    if (fifo_full & ~fifo_empty & ~first_full)
      first_full <= 'h1;
  end
end

// FIFO empty, delayed
always @(posedge clk)
begin
  if (rst == 0)
    empty_reg <= 'b111;
  else 
    empty_reg <= {empty_reg[1:0], fifo_empty};
end




// output select counter
always @(posedge clk)
begin
  if (rst == 0) begin
    rd_cnt <= 'd0;
  end else begin 
    if (~empty_reg[2] & first_full) begin
      if (rd_cnt == 'd0 && m_axis_tready) // downsize from 64 to 32 bit. 
        rd_cnt <= rd_cnt + 1;
      else if (rd_cnt >= 'd1 && m_axis_tready)
        rd_cnt <= 'd0;      
    end
  end 
end

// output data mux
always @(posedge clk)
begin
  case(rd_cnt)
    'd0: m_axis_tdata <= fifo_rd_data[31: 0];
    'd1: m_axis_tdata <= fifo_rd_data[63:32];
  endcase
end

endmodule