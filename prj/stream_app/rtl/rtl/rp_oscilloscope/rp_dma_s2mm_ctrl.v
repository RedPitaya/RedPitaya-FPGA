`timescale 1ns / 1ps

module rp_dma_s2mm_ctrl
  #(parameter AXI_ADDR_BITS = 32,  
    parameter AXI_DATA_BITS = 64,
    parameter AXI_BURST_LEN = 16,
    parameter FIFO_CNT_BITS = 9)(
  input  wire                       m_axi_aclk,
  input  wire                       s_axis_aclk,
  input  wire                       m_axi_aresetn,
  //
  output reg                        busy,
  output reg                        intr,
  output reg                        mode,
  //
  //input  wire [REG_ADDR_BITS-1:0]   reg_addr,
  input  wire [31:0]                reg_wr_data,
  input  wire                       reg_wr_we,
  //
  output reg  [31:0]                reg_ctrl,
  output wire [31:0]                reg_sts,
  output reg  [31:0]                reg_diags,
  input  wire [31:0]                reg_dst_addr1,
  input  wire [31:0]                reg_dst_addr2,
  input  wire [31:0]                reg_buf_size,
  input  wire [63:0]                data_ts,        // timestamp of the word at the head of the data FIFO
  input  wire [31:0]                fifo_wr_words,  // words the data FIFO took (stream clock domain, free running)
  input  wire [63:0]                timestamp_init,
  input  wire                       timestamp_init_we,
  output wire                       ctl_start_o,
  input  wire                       ctl_start_ext,
  //

  input  wire                       upsized_we_i,
  output reg                        fifo_rst,
  input  wire [FIFO_CNT_BITS-1:0]   fifo_lvl,
  input  wire [1:0]                 upsize_lvl,
  input  wire                       use_8bit,
  input  wire [7:0]                 req_data,
  input  wire                       req_we,
  input  wire                       data_valid,
  output reg  [63:0]                buf1_timestamp,
  output reg  [63:0]                buf2_timestamp,
  input  wire [15:0]                lost_add,       // samples lost in the stream clock domain, handed over
  input  wire                       lost_add_we,
  input  wire [15:0]                wait_add,       // the part of lost_add dropped while waiting for a trigger
  output wire                       first_rst_o,    // the FIFO reset after the start: words dropped then are not lost
  input  wire                       flush_i,        // no more data before the next trigger: send a last full burst
  input  wire                       series_mode_i,  // block mode: the data comes in series, each one ends with the arm (flush_i)
  output reg  [63:0]                buf1_lost,      // samples lost before buffer 1, latched with its timestamp
  output reg  [63:0]                buf2_lost,
  output reg  [63:0]                buf1_wait,      // samples not written while waiting for a trigger before buffer 1
  output reg  [63:0]                buf2_wait,
  input  wire                       buf_sel_in,     // unused: the interrupt is set on a buffer full edge
  output wire                       buf_sel_out,
  output reg                        fifo_dis,
  //
  output wire [(AXI_ADDR_BITS-1):0] m_axi_awaddr,
  output reg  [7:0]                 m_axi_awlen,
  output wire [2:0]                 m_axi_awsize,
  output wire [1:0]                 m_axi_awburst,
  output wire [2:0]                 m_axi_awprot,
  output wire [3:0]                 m_axi_awcache,
  output reg                        m_axi_awvalid,
  input  wire                       m_axi_awready,
  output wire                       m_axi_wvalid,
  input  wire                       m_axi_wready,
  output wire                       m_axi_wlast
);

///////////////////////////////////////////////////////////
// Parameters
//////////////////////////////////////////////////////////// 

localparam IDLE             = 3'd0;
localparam FIFO_RST         = 3'd1;
localparam WAIT_DATA_RDY    = 3'd2;
localparam SEND_DMA_REQ     = 3'd3;
localparam WAIT_DATA_DONE   = 3'd4;
localparam WAIT_BUF_FULL    = 3'd5;
localparam BUF_FILLING      = 3'd6;
localparam SERIES_WAIT      = 3'd7;  // block mode: the rest of a series that lost data is dropped

localparam CTRL_STRT        = 0;  // Control - Bit[0] : Start DMA
localparam CTRL_INTR_ACK    = 1;  // Control - Bit[1] : Interrupt ACK
localparam CTRL_BUF1_ACK    = 2;  // Control - Bit[2] : Buffer 1 ACK
localparam CTRL_BUF2_ACK    = 3;  // Control - Bit[3] : Buffer 2 ACK
localparam CTRL_RESET       = 4;  // Control - Bit[4] : Reset states and flags
localparam CTRL_MODE_NORM   = 8;  // Control - Bit[8] : Mode normal DMA
localparam CTRL_MODE_STREAM = 9;  // Control - Bit[9] : Mode streaming DMA

localparam STS_BUF1_FULL    = 0;  // Status = Bit[0] : Buffer 1 full
localparam STS_BUF2_FULL    = 1;  // Status = Bit[1] : Buffer 2 full
localparam STS_BUF1_OVF     = 2;  // Status = Bit[2] : Buffer 1 overflow
localparam STS_BUF2_OVF     = 3;  // Status = Bit[3] : Buffer 2 overflow
localparam STS_CURR_BUF     = 4;  // Currently selected buffer


localparam AXI_BURST_BYTES  = AXI_BURST_LEN*AXI_DATA_BITS/8;
localparam BUF_SIZE_BITS    = 24;

////////////////////////////////////////////////////////////
// Signals
//////////////////////////////////////////////////////////// 

reg  [2:0]                state_cs;                // Current state
reg  [2:0]                state_ns;                // Next state  
reg  [199:0]              state_ascii;             // ASCII state
reg  [AXI_ADDR_BITS-1:0]  req_addr;
reg  [AXI_ADDR_BITS-1:0]  req_buf_addr;
reg                       req_buf_addr_sel;
reg                       req_buf_addr_sel_p1;
wire                      req_buf_addr_sel_pedge;
wire                      req_buf_addr_sel_nedge;
wire [7:0]                req_xfer_cnt;
reg                       req_xfer_last;
wire                      dat_ctrl_busy;
wire [7:0]                dat_ctrl_req_data;
wire                      dat_ctrl_req_we;
reg                       buf1_full;
reg                       buf2_full;
reg                       buf1_ovr;
reg                       buf2_ovr;
reg                       data_valid_reg;

reg  [4:0]                fifo_rst_cnt;
wire [10-1:0]             fifo_wr_data;
wire                      fifo_wr_we;
wire [10-1:0]             fifo_rd_data;   // the request FIFO IP also carries the buffer marks of the data control
wire [1:0]                buf_first_beat; // first beat of buffer 1 (bit 0) or 2 (bit 1)
reg                       fifo_rd_re;
wire                      fifo_empty;
reg                       next_buf_full;
reg                       buf1_full_d, buf2_full_d;  // the interrupt is set on a buffer full edge
reg                       fifo_rst_cntdwn;
reg                       transf_end;
reg                       bit_start;
reg                       axi_last_r, axi_last_r2;
reg                       first_rst;

wire                      full_immed;
wire                      dma_req_start;
wire                      buf1_timestamp_we;
wire                      buf2_timestamp_we;

assign m_axi_awaddr  = req_addr;
assign m_axi_awsize  = $clog2(AXI_DATA_BITS/8);   
assign m_axi_awburst = 2'b01;     // INCR
assign m_axi_awprot  = 3'b000;
assign m_axi_awcache = 4'b0011;

assign req_buf_addr_sel_pedge = req_buf_addr_sel & ~req_buf_addr_sel_p1;
assign req_buf_addr_sel_nedge = ~req_buf_addr_sel & req_buf_addr_sel_p1;

assign reg_sts[31:5] = 27'd0;
assign reg_sts[STS_BUF1_FULL] = buf1_full;
assign reg_sts[STS_BUF1_OVF] = buf1_ovr;
assign reg_sts[STS_BUF2_FULL] = buf2_full;
assign reg_sts[STS_BUF2_OVF] = buf2_ovr;
assign reg_sts[STS_CURR_BUF] = req_buf_addr_sel;


assign buf_sel_out = req_buf_addr_sel_p1;
assign ctl_start_o = (reg_ctrl[CTRL_STRT] == 1) | ctl_start_ext | bit_start; // create a pulse of length of 2 clock periods
assign full_immed  = m_axi_wvalid & m_axi_wlast & next_buf_full;
assign dma_req_start = m_axi_awvalid & m_axi_awready;
assign buf1_timestamp_we = dma_req_start & (req_buf_addr_sel == 1'b0) & (req_addr == reg_dst_addr1);
assign buf2_timestamp_we = dma_req_start & (req_buf_addr_sel == 1'b1) & (req_addr == reg_dst_addr2);
////////////////////////////////////////////////////////////
// Name : Request FIFO 
// Stores the DMA requests.
////////////////////////////////////////////////////////////

fifo_axi_req U_fifo_axi_req(
  .wr_clk (s_axis_aclk),
  .rd_clk (m_axi_aclk),      
  .rst    (fifo_rst),    
  .din    (fifo_wr_data),     
  .wr_en  (fifo_wr_we),  
  .full   (),  
  .dout   (fifo_rd_data),   
  .rd_en  (fifo_rd_re), 
  .empty  (fifo_empty));
  
assign fifo_wr_data = {2'b00, req_data};
assign fifo_wr_we   = req_we && ~fifo_dis; // writing request buffer is only enabled when not waiting on clearing of the next buffer. 

////////////////////////////////////////////////////////////
// Name : Data Control
// 
////////////////////////////////////////////////////////////
  
rp_dma_s2mm_data_ctrl U_dma_s2mm_data_ctrl(
  .m_axi_aclk     (m_axi_aclk),            
  .m_axi_aresetn  (m_axi_aresetn),                  
  .fifo_rst       (fifo_rst),              
  .busy           (dat_ctrl_busy),
  .req_data       (dat_ctrl_req_data),              
  .req_we         (dat_ctrl_req_we),            
  .req_xfer_cnt   (req_xfer_cnt),
  .req_mark       ({buf2_timestamp_we, buf1_timestamp_we}),
  .first_beat_mark (buf_first_beat),
  .m_axi_wvalid   (m_axi_wvalid),          
  .m_axi_wready   (m_axi_wready),          
  .m_axi_wlast    (m_axi_wlast));
  
assign dat_ctrl_req_data = m_axi_awlen+1;
assign dat_ctrl_req_we   = (m_axi_awvalid & m_axi_awready) && ~fifo_dis; // writing data buffer is only enabled when not waiting on clearing of the next buffer. 
        
////////////////////////////////////////////////////////////
// Name : Series of the block mode
// A series that lost data (the FIFO reset, the next buffer not free) is not written further:
// its rest is dropped (counted as lost) and the next series starts the free buffer, so every
// buffer stays a whole number of series. Without it the buffers stay out of step with the series
// for good. flush_i and series_mode_i come from the stream clock domain.
////////////////////////////////////////////////////////////

reg  [1:0] series_mode_s, flush_s;
always @(posedge m_axi_aclk) begin
  series_mode_s <= {series_mode_s[0], series_mode_i};
  flush_s       <= {flush_s[0], flush_i};
end
wire series_on = series_mode_s[1] && ~flush_s[1];  // a series is being written

////////////////////////////////////////////////////////////
// Name : State machine seq logic
// Sets the current state to the next state.
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  if (m_axi_aresetn == 0) begin
    state_cs <= IDLE;
  end else begin
    state_cs <= state_ns;
  end
end

always @(posedge m_axi_aclk)
begin
  reg_diags <= {m_axi_awlen,{3'b0,intr},{3'b0,fifo_dis},{3'b0,req_buf_addr_sel},{buf2_ovr,buf1_ovr,buf2_full,buf1_full},{m_axi_awready,m_axi_wready,m_axi_awvalid,m_axi_wvalid},{1'b0,state_cs}};
end

always @(posedge m_axi_aclk)
begin
  bit_start <= (reg_ctrl[CTRL_STRT] == 1) | ctl_start_ext;
end

always @(posedge m_axi_aclk)
begin
  axi_last_r  <= m_axi_wlast;
  axi_last_r2 <= axi_last_r; // FIFO level is delayed by 2 clocks
end

reg upsized_we, upsized_we_r;
always @(posedge s_axis_aclk)
begin
  upsized_we_r <= upsized_we_i;
end

always @(posedge m_axi_aclk)
begin
  if (m_axi_aresetn == 0) begin
    upsized_we <= 1'b0;
  end else begin
    upsized_we <= ~upsized_we & (upsized_we_i | upsized_we_r);
  end
end

////////////////////////////////////////////////////////////
// Name : data_valid synchronisation
// data valid must be delayed by one clock to align with 
// axi signals
////////////////////////////////////////////////////////////
always @(posedge m_axi_aclk)
begin
  if (m_axi_aresetn == 0) begin
    data_valid_reg <= 1'b0;
  end else begin
    data_valid_reg <= data_valid;
  end
end

////////////////////////////////////////////////////////////
// Name : State machine ascii 
// Converts the state to ascii for debug.
////////////////////////////////////////////////////////////

always @(*)
begin
  case (state_cs)
    IDLE:           state_ascii = "IDLE";
    FIFO_RST:       state_ascii = "FIFO_RST";
    WAIT_DATA_RDY:  state_ascii = "WAIT_DATA_RDY";            
    SEND_DMA_REQ:   state_ascii = "SEND_DMA_REQ";       
    WAIT_DATA_DONE: state_ascii = "WAIT_DATA_DONE";
    WAIT_BUF_FULL:  state_ascii = "WAIT_BUF_FULL";  
    BUF_FILLING:    state_ascii = "BUF_FILLING";  
    SERIES_WAIT:    state_ascii = "SERIES_WAIT";
  endcase
end

////////////////////////////////////////////////////////////
// Name : State machine comb logic
// Assigns the next state.
////////////////////////////////////////////////////////////

always @(*)
begin
  state_ns = state_cs;

  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      if (bit_start) begin
        state_ns = FIFO_RST;
      end
    end
    
    // FIFO_RST - Reset the data FIFO
    FIFO_RST: begin
      if (reg_ctrl[CTRL_RESET])
        state_ns = IDLE;
      else if (fifo_rst_cnt == 31) begin
        if (next_buf_full)
          state_ns = WAIT_BUF_FULL;
        else if (series_on)
          state_ns = SERIES_WAIT;
        else
          state_ns = BUF_FILLING;
      end
    end
    
    // WAIT_DATA_RDY - Wait for the data to be buffered before sending the request
    WAIT_DATA_RDY: begin
      if (reg_ctrl[CTRL_RESET])
        state_ns = IDLE;
      else if (fifo_empty == 0) begin
        state_ns = SEND_DMA_REQ;
      end
      
    end

    // SEND_DMA_REQ - Send the request 
    SEND_DMA_REQ: begin

        if (reg_ctrl[CTRL_RESET])
          state_ns = IDLE;
        else if (transf_end) begin
          if (next_buf_full) // if next transfer results in overwriting the buffer, wait until the buffer is completely read out.
           state_ns = FIFO_RST; // first reset the FIFO, then wait. That way, we don't have to wait for the FIFO to finish its reset. 
          else if (req_xfer_last == 1) begin // Test for the last transfer
            state_ns = WAIT_DATA_DONE;   
          end else begin
            if (fifo_lvl < AXI_BURST_LEN)
              state_ns = BUF_FILLING;     
            else
              state_ns = WAIT_DATA_RDY;     
          end  
        end  
    end    
    
    // WAIT_DATA_DONE - Wait until data from all requests has been sent
    WAIT_DATA_DONE: begin
      // Test if the data control is busy
      if (reg_ctrl[CTRL_RESET])
          state_ns = IDLE;
      else if (dat_ctrl_busy == 0) begin
        state_ns = IDLE;  
      end
    end

    WAIT_BUF_FULL: begin
      if (reg_ctrl[CTRL_RESET])
          state_ns = IDLE;
      else if (~next_buf_full) begin // if next buffer is full, then wait
        state_ns = series_on ? SERIES_WAIT : BUF_FILLING; // go back to filling FIFOs
      end
    end

    SERIES_WAIT: begin
      if (reg_ctrl[CTRL_RESET])
          state_ns <= IDLE;
      else if (~series_on)
        state_ns = BUF_FILLING;
    end

    BUF_FILLING: begin
      if (reg_ctrl[CTRL_RESET])
          state_ns = IDLE;
      // A last burst at the end of a series of the block mode is sent too: nothing
      // follows it until the next trigger.
      else if ((fifo_lvl > AXI_BURST_LEN) || (flush_i && (fifo_lvl >= AXI_BURST_LEN))) begin
        state_ns = WAIT_DATA_RDY; // wait for FIFO 
      end
    end

  endcase
end

////////////////////////////////////////////////////////////
// Name : Control Register
// 
////////////////////////////////////////////////////////////
always @(posedge m_axi_aclk)
begin
  if (m_axi_aresetn == 0) begin
    reg_ctrl <= 0;
  end else begin
    if (reg_wr_we == 1) begin
      reg_ctrl <= reg_wr_data;
    end else begin
      // Start
      if (reg_ctrl[CTRL_STRT] == 1) begin
        reg_ctrl[CTRL_STRT] <= 0;
      end

      // Intr ACK
      if (reg_ctrl[CTRL_INTR_ACK] == 1) begin
        reg_ctrl[CTRL_INTR_ACK] <= 0;
      end
      
      // Buf 1 ACK
      if (reg_ctrl[CTRL_BUF1_ACK] && state_cs != FIFO_RST) begin
        reg_ctrl[CTRL_BUF1_ACK] <= 0;
      end

      // Buf 2 ACK
      if (reg_ctrl[CTRL_BUF2_ACK] && state_cs != FIFO_RST) begin
        reg_ctrl[CTRL_BUF2_ACK] <= 0;
      end   
      
      // Reset state machine
      if (reg_ctrl[CTRL_RESET]) begin
        reg_ctrl[CTRL_RESET] <= 0;
      end   
      // Mode normal
      if (reg_ctrl[CTRL_MODE_NORM] == 1) begin
        reg_ctrl[CTRL_MODE_NORM] <= 0;
      end            

      // Mode streaming
      if (reg_ctrl[CTRL_MODE_STREAM] == 1) begin
        reg_ctrl[CTRL_MODE_STREAM] <= 0;
      end

    end
  end
end

////////////////////////////////////////////////////////////
// Transfer end
// All data has been transferred
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  if (m_axi_aresetn == 0)
    transf_end <= 0;
  else begin
    if ((m_axi_wvalid == 1) && (m_axi_wlast == 1))
      transf_end <= 1'b1;
    else 
      transf_end <= 1'b0;
  end
end

always @(posedge m_axi_aclk)
begin
  if (m_axi_aresetn == 0) begin
    buf1_timestamp    <= 64'd0;
    buf2_timestamp    <= 64'd0;
  end else begin
    // the first word written to the buffer: its timestamp is the one of the first sample
    if (buf_first_beat[0])
      buf1_timestamp <= data_ts;

    if (buf_first_beat[1])
      buf2_timestamp <= data_ts;
  end
end

assign first_rst_o = first_rst;

////////////////////////////////////////////////////////////
// Name : 64 bit lost sample counter
// Counts the samples that were not written: whole words dropped while the
// next buffer is not free and the samples dropped while the acquisition
// waits for a trigger (both counted in the stream clock domain, lost_add),
// and the words in the FIFO when it is reset (words taken minus words read minus words
// already thrown away, taken at the end of the reset when no word is written). The count is latched into the register of a buffer
// with its timestamp (the first request of the buffer), so it holds the
// samples lost right before that buffer. It does not saturate.
////////////////////////////////////////////////////////////

wire [ 4-1:0] samps_per_word = use_8bit ? 4'd8 : 4'd4;
(* ASYNC_REG = "TRUE" *) reg [31:0] wr_words_m, wr_words_s;
reg  [31:0]   rd_words, gone_words, rst_drop;
reg           rst_drop_we;

// The FIFO is disabled from the last transfer before its reset to the end of FIFO_RST: the
// count of the words it took is stable when it is taken at the end of the reset. The reset
// after the start only aligns the counts (those words are not lost).
always @(posedge m_axi_aclk)
begin
  wr_words_m <= fifo_wr_words;
  wr_words_s <= wr_words_m;
  if (m_axi_aresetn == 0) begin
    rd_words    <= 32'd0;
    gone_words  <= 32'd0;
    rst_drop    <= 32'd0;
    rst_drop_we <= 1'b0;
  end else begin
    if (m_axi_wvalid && m_axi_wready)
      rd_words <= rd_words + 32'd1;
    rst_drop_we <= 1'b0;
    if ((state_cs == FIFO_RST) && (fifo_rst_cnt == 30)) begin
      rst_drop    <= wr_words_s - rd_words - gone_words;
      gone_words  <= wr_words_s - rd_words;
      rst_drop_we <= ~first_rst;
    end
  end
end

// The total is never cleared: a buffer gets the total minus the mark of the previous buffer
// start, so the buffer start (an address compare) is only an enable, not in the adder path.
reg  [64-1:0] lost_total, lost_mark;
reg  [32-1:0] lost_inc;   // the samples lost in the previous clock

always @(posedge m_axi_aclk)
begin
  if ((m_axi_aresetn == 0) || (state_cs == IDLE)) begin
    lost_total <= 64'd0;
    lost_mark  <= 64'd0;
    lost_inc   <= 32'd0;
    buf1_lost  <= 64'd0;
    buf2_lost  <= 64'd0;
  end else begin
    // the words in the FIFO when it is reset are lost as well
    lost_inc   <= (lost_add_we ? lost_add : 16'd0)
                + (rst_drop_we ? rst_drop * samps_per_word : 32'd0);
    lost_total <= lost_total + lost_inc;
    if (buf1_timestamp_we)
      buf1_lost <= lost_total + lost_inc - lost_mark;
    if (buf2_timestamp_we)
      buf2_lost <= lost_total + lost_inc - lost_mark;
    if (buf1_timestamp_we || buf2_timestamp_we)
      lost_mark <= lost_total + lost_inc;
  end
end

// The samples not written while the acquisition waits for a trigger, latched like the lost
// count (they are part of it): the series gap before a buffer, 0 without the trigger mode.
reg  [64-1:0] wait_total, wait_mark;
reg  [16-1:0] wait_inc;

always @(posedge m_axi_aclk)
begin
  if ((m_axi_aresetn == 0) || (state_cs == IDLE)) begin
    wait_total <= 64'd0;
    wait_mark  <= 64'd0;
    wait_inc   <= 16'd0;
    buf1_wait  <= 64'd0;
    buf2_wait  <= 64'd0;
  end else begin
    wait_inc   <= lost_add_we ? wait_add : 16'd0;
    wait_total <= wait_total + wait_inc;
    if (buf1_timestamp_we)
      buf1_wait <= wait_total + wait_inc - wait_mark;
    if (buf2_timestamp_we)
      buf2_wait <= wait_total + wait_inc - wait_mark;
    if (buf1_timestamp_we || buf2_timestamp_we)
      wait_mark <= wait_total + wait_inc;
  end
end

////////////////////////////////////////////////////////////
// First reset
// Indicates first reset from IDLE state
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs)
    IDLE: begin
      first_rst <= 1'b1; // go back to filling FIFOs
    end

    BUF_FILLING: begin
      first_rst <= 1'b0;
    end

    WAIT_BUF_FULL: begin
      first_rst <= 1'b0;
    end
  endcase
end  
////////////////////////////////////////////////////////////
// FIFO reset countdown active
// only activates after data loss FIFO reset
// used to increase missed sample counter during FIFO reset
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs)
    SEND_DMA_REQ: begin
      if (full_immed) begin // if next buffer is full, then wait
        fifo_rst_cntdwn <= 1'b1; // go back to filling FIFOs
      end
    end

    FIFO_RST: begin
      if (fifo_rst_cnt == 31) begin
        fifo_rst_cntdwn <= 1'b0;
      end
      if (reg_ctrl[CTRL_RESET])
        fifo_rst_cntdwn <= 1'b0;
    end     

    default: begin
        fifo_rst_cntdwn <= 1'b0;
      end

  endcase
end  

////////////////////////////////////////////////////////////
// FIFO disable signal
// Prevents writing new data into FIFOs
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs)

    FIFO_RST: begin
        fifo_dis <= 1'b1; // disable signal
      end

    SEND_DMA_REQ: begin
      if (full_immed)
        fifo_dis <= 1'b1;
      end
      
    WAIT_BUF_FULL: begin
        fifo_dis <= next_buf_full || series_on; // disable signal
      end

    SERIES_WAIT: begin
        fifo_dis <= 1'b1;
      end

    default: begin
        fifo_dis <= 1'b0; // disable signal
      end
  endcase
end  

////////////////////////////////////////////////////////////
// Name : DMA Mode
// 0 = Normal
// 1 = Streaming
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  if (m_axi_aresetn == 0) begin
    mode <= 0;
  end else begin
    if (reg_ctrl[CTRL_MODE_NORM] == 1) begin
      mode <= 0;
    end
    
    if (reg_ctrl[CTRL_MODE_STREAM] == 1) begin
      mode <= 1;
    end    
  end
end

////////////////////////////////////////////////////////////
// next buffer is still full
////////////////////////////////////////////////////////////
 
always @(posedge m_axi_aclk)
begin
  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      next_buf_full <= 0;  
    end    

    default: begin
        if (reg_ctrl[CTRL_BUF1_ACK] || reg_ctrl[CTRL_BUF2_ACK])
            next_buf_full <= 0;
        else if ((req_addr+AXI_BURST_BYTES) >= (req_buf_addr[AXI_ADDR_BITS-1:0]+reg_buf_size[BUF_SIZE_BITS-1:0])) begin
          if (((req_buf_addr_sel == 0) && buf2_full) || ((req_buf_addr_sel == 1) && buf1_full)) begin // data loss is occuring
            next_buf_full <= 1;  
          end
        end 
      end          
  endcase
end  

////////////////////////////////////////////////////////////
// Name : Buffer 1 Full
// Set when buffer 1 is full.
////////////////////////////////////////////////////////////
 
always @(posedge m_axi_aclk)
begin
  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      buf1_full <= 0;  
    end 

    default: begin
      if (reg_ctrl[CTRL_BUF1_ACK] == 1) begin
        buf1_full <= 0;     
      end else begin
        // Only with the switch in SEND_DMA_REQ: transf_end holds while the memory stalls the last
        // beat of a burst, and in the next state the request address is already at the last burst
        // of the buffer: the flag came a burst early, a release in that time was undone by the
        // second flag, and the buffer stayed full (an overflow a round later).
        if (transf_end && (state_cs == SEND_DMA_REQ)) begin
          // Reset to the start of the buffer if we have reached the end
          if ((req_addr+AXI_BURST_BYTES) >= (req_buf_addr[AXI_ADDR_BITS-1:0]+reg_buf_size[BUF_SIZE_BITS-1:0])) begin
            if (req_buf_addr_sel == 0) begin // buffer 1 is full if next transfer goes over specified buffer size
              buf1_full <= 1;
            end
          end
        end   
      end     
    end
  endcase
end  

////////////////////////////////////////////////////////////
// Name : Buffer 1 Overflow
// Set when buffer 1 is full and cannot be switched into 
// when still in buffer 2.
////////////////////////////////////////////////////////////
 
always @(posedge m_axi_aclk)
begin
  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      buf1_ovr <= 0;  
    end    

    default: begin
      if (reg_ctrl[CTRL_BUF1_ACK] == 1) begin
        buf1_ovr <= 0;     
      end else begin
          // Reset to the start of the buffer if we have reached the end
        if ((req_addr+AXI_BURST_BYTES) >= (req_buf_addr[AXI_ADDR_BITS-1:0]+reg_buf_size[BUF_SIZE_BITS-1:0])) begin
            if ((req_buf_addr_sel == 1) && buf1_full)
              buf1_ovr <= 1;  
        end
      end
    end   
  endcase
end  
      
////////////////////////////////////////////////////////////
// Name : Buffer 2 Full
// Set when buffer 2 is full.
////////////////////////////////////////////////////////////
 
always @(posedge m_axi_aclk)
begin
  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      buf2_full <= 0;  
    end    

    default: begin
      if (reg_ctrl[CTRL_BUF2_ACK] == 1) begin
        buf2_full <= 0;     
      end else begin
        if (transf_end && (state_cs == SEND_DMA_REQ)) begin  // as buffer 1
          if ((req_addr+AXI_BURST_BYTES) >= (req_buf_addr[AXI_ADDR_BITS-1:0]+reg_buf_size[BUF_SIZE_BITS-1:0])) begin
            if (req_buf_addr_sel == 1) begin // buffer 2 is full if next transfer goes over specified buffer size
              buf2_full <= 1;  
            end
          end
        end   
      end     
    end
  endcase
end  

////////////////////////////////////////////////////////////
// Name : Buffer 1 Overflow
// Set when buffer 1 is full and cannot be switched into 
// when still in buffer 2.
////////////////////////////////////////////////////////////
 
always @(posedge m_axi_aclk)
begin
  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      buf2_ovr <= 0;  
    end    

    default: begin
      if (reg_ctrl[CTRL_BUF2_ACK] == 1) begin
        buf2_ovr <= 0;     
      end else begin
        if ((req_addr+AXI_BURST_BYTES) >= (req_buf_addr[AXI_ADDR_BITS-1:0]+reg_buf_size[BUF_SIZE_BITS-1:0])) begin
            if ((req_buf_addr_sel == 0) && buf2_full) 
              buf2_ovr <= 1;  
        end
      end   
    end     
  endcase
end  
            
////////////////////////////////////////////////////////////
// Name : Request Address
// Holds the address of the buffer in memory where data will
// be written.
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      req_addr <= reg_dst_addr1;  
    end
    
    SEND_DMA_REQ: begin
      if (transf_end) begin
        // Swap the buffer if we have reached the end of the current one
        if ((req_addr+AXI_BURST_BYTES) >= (req_buf_addr[AXI_ADDR_BITS-1:0]+reg_buf_size[BUF_SIZE_BITS-1:0])) begin
          if ((req_buf_addr_sel == 0) && ~buf2_full) begin // only switch addresses when next buffer is read out
            req_addr <= reg_dst_addr2;          
          end 
          if ((req_buf_addr_sel == 1) && ~buf1_full) begin
            req_addr <= reg_dst_addr1;
          end        
        end else begin
          req_addr <= req_addr + AXI_BURST_BYTES;
        end
      end  
    end
    
    WAIT_BUF_FULL: begin
      if (~next_buf_full) begin
        // Swap the buffer if we have reached the end of the current one
          if ((req_buf_addr_sel == 0) && ~buf2_full) begin // only switch addresses when next buffer is read out
            req_addr <= reg_dst_addr2;          
          end 
          if ((req_buf_addr_sel == 1) && ~buf1_full) begin
            req_addr <= reg_dst_addr1;
          end        
      end   
    end      
  endcase
end

////////////////////////////////////////////////////////////
// Name : Request Buffer Address Select
// Selects the current buffer to use in memory.
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      req_buf_addr <= reg_dst_addr1;  
    end  
    
    SEND_DMA_REQ: begin
      if (transf_end) begin        // Reset to the start of the buffer if we have reached the end
        if ((req_addr+AXI_BURST_BYTES) >= (req_buf_addr[AXI_ADDR_BITS-1:0]+reg_buf_size[BUF_SIZE_BITS-1:0])) begin
          if ((req_buf_addr_sel == 0) && ~buf2_full) begin //only start writing to buf2 if it's empty
            req_buf_addr <= reg_dst_addr2;          
          end 
          if ((req_buf_addr_sel == 1) && ~buf1_full) begin //only start writing to buf1 if it's empty
            req_buf_addr <= reg_dst_addr1;
          end   
        end
      end  
    end
    
    WAIT_BUF_FULL: begin
      if (~next_buf_full) begin
        // Swap the buffer if we have reached the end of the current one
          if ((req_buf_addr_sel == 0) && ~buf2_full) begin // only switch addresses when next buffer is read out
            req_buf_addr <= reg_dst_addr2;          
          end 
          if ((req_buf_addr_sel == 1) && ~buf1_full) begin
            req_buf_addr <= reg_dst_addr1;
          end  
        end      
      end          
  endcase
end

////////////////////////////////////////////////////////////
// Name : Request Buffer Address Select
// Selects the current buffer to use in memory.
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs)
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      req_buf_addr_sel <= 0;  
    end  
    
    SEND_DMA_REQ: begin
      if (transf_end) begin        // Reset to the start of the buffer if we have reached the end
        if ((req_addr+AXI_BURST_BYTES) >= (req_buf_addr[AXI_ADDR_BITS-1:0]+reg_buf_size[BUF_SIZE_BITS-1:0])) begin
          if (~buf1_full && req_buf_addr_sel == 1'b1) 
            req_buf_addr_sel <= 1'b0;
        
          if (~buf2_full && req_buf_addr_sel == 1'b0)
            req_buf_addr_sel <= 1'b1;
        end
      end  
    end  
    
    WAIT_BUF_FULL: begin // only happens when exiting FIFO reset state after data loss
      if (~next_buf_full) begin
          req_buf_addr_sel <= ~req_buf_addr_sel;
        end      
      end        
  endcase
end

always @(posedge m_axi_aclk)
begin
  req_buf_addr_sel_p1 <= req_buf_addr_sel;
  buf1_full_d         <= buf1_full;
  buf2_full_d         <= buf2_full;
end

////////////////////////////////////////////////////////////
// Name : Request Transfer Last
// Set on the last transfer.
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs) 
    // WAIT_DATA_RDY - Wait until there is enough data to send an AXI transfer
    WAIT_DATA_RDY: begin
      req_xfer_last <= fifo_rd_data[7];
    end

  endcase   
end

////////////////////////////////////////////////////////////
// Name : Busy
// Signals when the DMA is busy.
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs) 
    // IDLE - Wait for the DMA start signal
    IDLE: begin
      if (bit_start) begin
        busy <= 1;
      end else begin
        busy <= 0;
      end
    end 
  endcase  
end

////////////////////////////////////////////////////////////
// Name : Interrupt
// Sends an interrupt to signal that the DMA has finished.
////////////////////////////////////////////////////////////
always @(posedge m_axi_aclk)
begin
  case (state_cs)
    IDLE: begin
        intr <= 1'b0;
      end

    default: begin
      if (m_axi_aresetn == 0) begin
        intr <= 0;
      end else begin
        // Set when a buffer of this channel gets full. It was set on a buffer switch, and only
        // when the other channel was not behind (buf_sel_in): with the channels a buffer apart
        // both switch the opposite way at once and neither set it, and a channel whose next
        // buffer is full gets its buffer full without a switch. The software takes a buffer
        // when every channel has it full (0x54), an extra interrupt only wakes it for nothing.
        // A buffer full in the clock of an ACK wins over it.
        if (((state_cs == WAIT_DATA_DONE) && (dat_ctrl_busy == 0)) || (buf1_full && ~buf1_full_d) || (buf2_full && ~buf2_full_d))
          intr <= 1;
        else if (reg_ctrl[CTRL_INTR_ACK] == 1)
          intr <= 0;
      end
    end
  endcase
end

////////////////////////////////////////////////////////////
// Name : FIFO Reset 
// Resets the Xilinx FIFOs
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs) 
    // FIFO_RST - Reset the data FIFO
    FIFO_RST: begin
      if (fifo_rst_cnt < 1) begin
        fifo_rst <= 1;  
      end else begin
        fifo_rst <= 0;
      end
    end   
  
    default: begin
      fifo_rst <= 0;
    end   
  endcase  
end

////////////////////////////////////////////////////////////
// Name : FIFO Reset Count
// The Xilinx FIFO needs a certain reset time.
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs) 
   // FIFO_RST - Reset the data FIFO
    FIFO_RST: begin
      fifo_rst_cnt <= fifo_rst_cnt + 1;
    end   
  
    default: begin
      fifo_rst_cnt <= 0;
    end   
  endcase   
end

////////////////////////////////////////////////////////////
// Name : FIFO Read Enable
// Reads requests from the FIFO when available. 
////////////////////////////////////////////////////////////

always @(*)
begin
  fifo_rd_re = 0;
        
  case (state_cs)   
    // WAIT_DATA_RDY - Wait until there is enough data to send an AXI transfer
    WAIT_DATA_RDY: begin
      if (fifo_empty == 0) begin
        fifo_rd_re = 1;
      end
    end
     
  endcase   
end

////////////////////////////////////////////////////////////
// Name : Master AXI AWVALID
// 
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  if (m_axi_aresetn == 0) begin
    m_axi_awvalid <= 0;
  end else begin
    case (state_cs) 
       // WAIT_DATA_RDY - Wait until there is enough data to send an AXI transfer
      WAIT_DATA_RDY: begin
        if (fifo_empty == 0) begin
          m_axi_awvalid <= 1;  
        end
      end
      
      SEND_DMA_REQ: begin
        if ((m_axi_awvalid == 1) && (m_axi_awready == 1)) begin
          m_axi_awvalid <= 0;  
        end  
      end          

      default: begin
        m_axi_awvalid <= 0;  
      end    
    endcase   
  end
end

////////////////////////////////////////////////////////////
// Name : Master AXI AWLEN
// 
////////////////////////////////////////////////////////////

always @(posedge m_axi_aclk)
begin
  case (state_cs) 
    // WAIT_DATA_RDY - Wait until there is enough data to send an AXI transfer
    WAIT_DATA_RDY: begin
      m_axi_awlen <= fifo_rd_data[6:0]-1;
    end

    

  endcase   
end

endmodule
