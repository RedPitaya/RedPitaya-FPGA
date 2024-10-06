`timescale 1ns / 1ps

module rp_dma_mm2s_downsize
  #(parameter AXI_DATA_BITS   = 64,
    parameter AXI_ADDR_BITS   = 32,
    parameter AXIS_DATA_BITS  = 16,     
    parameter AXI_BURST_LEN   = 15)(    
  input                           clk,
  input                           rst,

  input                           fifo_empty,
  input                           fifo_full,

  input      [ AXI_DATA_BITS-1:0] fifo_rd_data,
  output                          fifo_rd_re,      
  input      [ AXI_ADDR_BITS-1:0] dac_pntr_step,
  input                           set_8bit_i,

  output reg [AXIS_DATA_BITS-1:0] m_axis_tdata,
  output reg                      m_axis_tvalid
);

localparam NUM_SAMPS      = AXI_DATA_BITS/8;   // how many samples in one read from FIFO
localparam NUM_SAMPS_BITS = $clog2(NUM_SAMPS); // how many bits is the above number
localparam ADDR_DECS      = AXI_ADDR_BITS+16;  // to be able to get a finer pointer step

reg  [ADDR_DECS-1:0]      dac_rp_curr;
wire [ADDR_DECS-1:0]      step_sh_next;
wire [ADDR_DECS-1:0]      step_sh_next_next;

assign step_sh_next      = {16'h0,dac_pntr_step} << {     1'b0  ,!set_8bit_i}; //SHL 00 or 01
assign step_sh_next_next = {16'h0,dac_pntr_step} << {!set_8bit_i, set_8bit_i}; //SHL 01 or 10
(* use_dsp="yes" *) reg [ADDR_DECS-1:0]      dac_rp_next      ;
(* use_dsp="yes" *) reg [ADDR_DECS-1:0]      dac_rp_next_next ;

reg [8-1:0] samp_buf [0:NUM_SAMPS-1]; 

wire bit8_rd  = dac_rp_next_next[NUM_SAMPS_BITS+1+16] ^ dac_rp_next[NUM_SAMPS_BITS+1+16];
wire bit16_rd = dac_rp_next_next[NUM_SAMPS_BITS+0+16] ^ dac_rp_next[NUM_SAMPS_BITS+0+16];
wire rp_rd_en = set_8bit_i ? bit8_rd : bit16_rd;
reg  rp_rd_en_r;

assign fifo_rd_re = rp_rd_en && ~(state_cs == EMPTY_L || state_ns == EMPTY_L); // state_cs == REQ_READ || state_cs == INIT_RD;

localparam RESET     = 0; // reset state
localparam INIT_FULL = 1; // initial full state
localparam INIT_RD   = 2; // initial full state
localparam EMPTY_W   = 3; // waiting for fifo to empty
localparam REQ_READ  = 4; // request FIFO read
localparam REDUCE    = 5; // reduce 64 bit read to separate samples
localparam EMPTY_L   = 6; // read out the last sample in the sample buffer
localparam EMPTY_REC = 7; // recover from empty state

reg  [ 4-1:0]   state_cs; // Current state
reg  [ 4-1:0]   state_ns; // Next state  

`ifdef SIMULATION
reg  [199:0] state_ascii; // ASCII state
always @(*)
begin
  case (state_cs)
    RESET:      state_ascii = "RESET";
    INIT_FULL:  state_ascii = "INIT_FULL";
    INIT_RD:    state_ascii = "INIT_RD";
    EMPTY_W:    state_ascii = "EMPTY_W";            
    REQ_READ:   state_ascii = "REQ_READ";       
    REDUCE:     state_ascii = "REDUCE";  
    EMPTY_L:    state_ascii = "EMPTY_L";  
    EMPTY_REC:  state_ascii = "EMPTY_REC";  
  endcase
end
`endif

always @(posedge clk)
begin
  if (rst == 0) begin
    state_cs <= RESET;
  end else begin
    state_cs <= state_ns;
  end
end

always @(*)
begin
  state_ns   = state_cs;

  case (state_cs)
    RESET: begin
      if (rst == 0)
        state_ns = RESET;
      else 
        state_ns = INIT_FULL;
    end
    
    INIT_FULL: begin
      if (fifo_full)
        state_ns = INIT_RD;
    end

    INIT_RD: begin
      state_ns = REDUCE;
    end

    REQ_READ: begin
      if (fifo_empty)
        state_ns = EMPTY_L;
      else
        state_ns = REDUCE;
    end

    REDUCE: begin
      if (rp_rd_en) begin
        if (fifo_empty)
          state_ns = EMPTY_L;
        else          
          state_ns = REQ_READ;
      end
    end

    EMPTY_L: begin
      if (rp_rd_en_r) begin
        state_ns = EMPTY_W;
      end
    end


    EMPTY_W: begin
      if (~fifo_empty) begin
        state_ns = EMPTY_REC;
      end
    end

    default: begin
      if (rp_rd_en) begin
        state_ns = REQ_READ;
      end
    end
  endcase
end

always @(posedge clk)
begin
  rp_rd_en_r       <= rp_rd_en;
  dac_rp_next      <= dac_rp_curr+step_sh_next;
  dac_rp_next_next <= dac_rp_curr+step_sh_next_next;
end

always @(posedge clk)
begin
  if (rst == 0) begin
    dac_rp_curr <= 'h0;
  end else begin 
    if (state_cs > EMPTY_W) // wait for the FIFO to be full before starting to read, stop if empty
      dac_rp_curr <= dac_rp_curr+step_sh_next;
  end
end

genvar GV;
generate
for (GV = 0; GV < NUM_SAMPS; GV = GV + 1) begin : read_decoder
  always @(posedge clk) begin
    if (state_cs == INIT_RD || state_cs == REQ_READ)
      samp_buf[GV] <= fifo_rd_data[GV*8 +: 8];  
  end
end
endgenerate

reg  [3-1 :0] rp_8bit ;
reg  [3-1 :0] rp_16bit_hi;
reg  [3-1 :0] rp_16bit_lo;

always @(posedge clk)
begin
  rp_8bit     <=  dac_rp_curr[NUM_SAMPS_BITS+16:17];
  rp_16bit_hi <= {dac_rp_curr[NUM_SAMPS_BITS+15:17],1'b1};
  rp_16bit_lo <= {dac_rp_curr[NUM_SAMPS_BITS+15:17],1'b0};
end


always @(posedge clk)
begin
  if (rst == 0) begin
    m_axis_tvalid <= 'h0;
  end else begin 
    m_axis_tvalid <= state_cs > INIT_RD ;

    if(state_cs > EMPTY_W && state_cs < EMPTY_REC)
      m_axis_tdata  <= set_8bit_i ? {samp_buf[rp_8bit]    , {8{samp_buf[rp_8bit][8-1]}}} : 
                                    {samp_buf[rp_16bit_hi],    samp_buf[rp_16bit_lo]   } ;
  end
end
endmodule
