`timescale 1ns / 1ps

module osc_acquire
  #(parameter AXIS_DATA_BITS  = 16,
    parameter CNT_BITS        = 32)( // No. of bits for the counters
  input  wire                       clk,
  input  wire                       rst_n,
  // Slave AXI-S
  input  wire [AXIS_DATA_BITS-1:0]  s_axis_tdata,
  input  wire                       s_axis_tvalid,
  output wire                       s_axis_tready,
  // Master AXI-S
  output reg  [AXIS_DATA_BITS-1:0]  m_axis_tdata,
  output reg                        m_axis_tvalid,
  input  wire                       m_axis_tready, 
  output reg                        m_axis_tlast,    
  // Control
  input  wire                       ctl_start, 
  input  wire                       ctl_rst,
  input  wire                       ctl_stop,
  input  wire                       ctl_trig,
  input  wire                       cfg_trigger_mode,
  input  wire [16-1:0]              cfg_trig_blocks,   // blocks per trigger, 0 - continuous
  input  wire [CNT_BITS-1:0]        cfg_block_samples, // samples in one DMA buffer
  // Config
  input  wire                       cfg_mode, 
  input  wire [CNT_BITS-1:0]        cfg_trig_pre_samp, 
  input  wire [CNT_BITS-1:0]        cfg_trig_post_samp,
  // Status
  output reg                        sts_start,
  output wire                       sts_stop,     
  output reg                        sts_trig,
  output reg  [CNT_BITS-1:0]        sts_trig_pre_cnt,
  output reg                        sts_trig_pre_overflow,  
  output reg  [CNT_BITS-1:0]        sts_trig_post_cnt,
  output reg                        sts_trig_post_overflow,
  output wire                       sts_armed,
  output wire                       accepted_trigger,
  output wire                       sts_drop,          // a sample is not written while waiting
  output wire                       trig_taken         // a trigger started or extended the writing
);

////////////////////////////////////////////////////////////
// Parameters
//////////////////////////////////////////////////////////// 

localparam IDLE                 = 3'd0;
localparam PRE_SAMP_FILL        = 3'd1;
localparam PRE_SAMP_WAIT_TRIG   = 3'd2;
localparam POST_SAMP_WAIT_TRIG  = 3'd3;
localparam POST_SAMP_FILL       = 3'd4;
localparam STRM_SAMP            = 3'd5;

localparam NORM_MODE            = 0;
localparam STREAM_MODE          = 1;

////////////////////////////////////////////////////////////
// Signals
////////////////////////////////////////////////////////////

reg  [2:0]    state_cs;             
reg  [2:0]    state_ns;          
reg  [199:0]  state_ascii;      
reg           sts_acquire;
reg           sts_last;

assign s_axis_tready  = 1;
assign sts_stop       = ~sts_start;
assign sts_armed      = cfg_trigger_mode &&
                        (cfg_mode == STREAM_MODE) &&
                        (state_cs == PRE_SAMP_WAIT_TRIG) &&
                        !ctl_stop;

// the pre/post trigger counts are static while the core runs: compare against registered
// values (timing at 250 MHz)
reg  [CNT_BITS-1:0] pre_samp_m1, post_samp_m1;
reg                 pre_samp_nz;
always @(posedge clk)
begin
  pre_samp_m1  <= cfg_trig_pre_samp - 1;
  post_samp_m1 <= cfg_trig_post_samp - 1;
  pre_samp_nz  <= (cfg_trig_pre_samp != 0);
end

// The counters reach the last pre / post sample: compared a clock ahead and registered, so the
// state machine gets a flag, not a wide compare (the post compare was the worst path at 250 MHz).
// The flag of the next clock: the count after this clock against the last sample.
reg  [CNT_BITS-1:0] pre_samp_m2, post_samp_m2;
reg                 pre_last, post_last;
always @(posedge clk)
begin
  pre_samp_m2  <= cfg_trig_pre_samp - 2;
  post_samp_m2 <= cfg_trig_post_samp - 2;
  if ((rst_n == 0) || (ctl_rst == 1))
    pre_last <= (pre_samp_m1 == 0);
  else if ((s_axis_tvalid == 1) && ((state_cs == PRE_SAMP_FILL) || (state_cs == PRE_SAMP_WAIT_TRIG)))
    pre_last <= (sts_trig_pre_cnt == pre_samp_m2);
  else
    pre_last <= (sts_trig_pre_cnt == pre_samp_m1);
  if ((rst_n == 0) || (ctl_rst == 1))
    post_last <= (post_samp_m1 == 0);
  else if ((s_axis_tvalid == 1) && (state_cs == POST_SAMP_FILL))
    post_last <= (sts_trig_post_cnt == post_samp_m2);
  else
    post_last <= (sts_trig_post_cnt == post_samp_m1);
end

// Only a rising edge of the trigger seen while armed is accepted, as in the DAC playback:
// a trigger that is already high when the core arms waits for its next edge.
reg ctl_trig_d1;
always @(posedge clk)
begin
  if (rst_n == 0)
    ctl_trig_d1 <= 1'b0;
  else
    ctl_trig_d1 <= ctl_trig;
end

// late_trig: a trigger on the last sample of a series, taken by the wait that follows
// (inside a series a trigger is taken a clock late, see the block mode)
wire late_trig;
assign accepted_trigger = sts_armed && ((ctl_trig && !ctl_trig_d1) || late_trig);

////////////////////////////////////////////////////////////
// Block mode (trigger mode with cfg_trig_blocks > 0): a trigger writes the
// current block and the blocks after it up to cfg_trig_blocks in total, then
// the core waits for the next trigger. A trigger inside a series sets the
// blocks after the current one to cfg_trig_blocks again (trigger in block k:
// the series ends with block k + N). The samples not written while waiting
// are flagged on sts_drop, so the DMA can count the gap between two series.
////////////////////////////////////////////////////////////
// Timing at 250 MHz: the configuration is static while the core runs, the derived values
// are registered; the position in the block counts down to 0; the counters wait loaded while
// no series is written, and a trigger inside a series is taken a clock late, so the trigger
// path does not reach the counters.
reg                 blocks_mode;
reg  [CNT_BITS-1:0] block_last;  // cfg_block_samples - 1
reg  [16-1:0]       blocks_m1;   // cfg_trig_blocks - 1
reg                 blocks_one;  // cfg_trig_blocks == 1
always @(posedge clk)
begin
  blocks_mode <= cfg_trigger_mode && (cfg_trig_blocks != 0);
  block_last  <= cfg_block_samples - 1;
  blocks_m1   <= cfg_trig_blocks - 1;
  blocks_one  <= (cfg_trig_blocks == 1);
end

reg                 trig_edge_r, strm_r;
always @(posedge clk)
begin
  trig_edge_r <= ctl_trig && !ctl_trig_d1;
  strm_r      <= (state_cs == STRM_SAMP);
end

wire                sample_wr   = sts_acquire && s_axis_tvalid;
reg  [CNT_BITS-1:0] blk_rem;   // samples of the current block still to write, minus one
reg  [16-1:0]       blk_left;  // blocks of the series after the current one
reg                 blk_none;  // blk_left == 0
wire                blk_end     = sample_wr && (blk_rem == 0);
wire                retrig      = blocks_mode && (state_cs == STRM_SAMP) && strm_r && trig_edge_r;
wire                series_end  = blocks_mode && blk_end && blk_none && !retrig;
assign              late_trig   = blocks_mode && strm_r && trig_edge_r;

always @(posedge clk)
begin
  if ((rst_n == 0) || (state_cs != STRM_SAMP)) begin
    blk_rem  <= block_last;
    blk_left <= blocks_m1;
    blk_none <= blocks_one;
  end else begin
    if (sample_wr)
      blk_rem <= blk_end ? block_last : blk_rem - 1;
    if (retrig) begin
      blk_left <= blk_end ? blocks_m1 : cfg_trig_blocks;
      blk_none <= blk_end && blocks_one;
    end else if (blk_end && !blk_none) begin
      blk_left <= blk_left - 1;
      blk_none <= (blk_left == 1);
    end
  end
end

assign trig_taken = accepted_trigger || retrig;

assign sts_drop = s_axis_tvalid && !sts_acquire && (cfg_mode == STREAM_MODE) && (state_cs == PRE_SAMP_WAIT_TRIG);

////////////////////////////////////////////////////////////
// Name : State machine seq logic
// Sets the current state to the next state.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst_n == 0) begin
    state_cs <= IDLE;
  end else begin
    if (ctl_stop == 1) begin
      state_cs <= IDLE; 
    end else begin
      state_cs <= state_ns;
    end
  end
end

////////////////////////////////////////////////////////////
// Name : State machine ascii 
// Converts the state to ascii for debug.
////////////////////////////////////////////////////////////

always @(*)
begin
  case (state_cs)
    IDLE:                 state_ascii = "IDLE";
    PRE_SAMP_FILL:        state_ascii = "PRE_SAMP_FILL";
    PRE_SAMP_WAIT_TRIG:   state_ascii = "PRE_SAMP_WAIT_TRIG";
    POST_SAMP_WAIT_TRIG:  state_ascii = "POST_SAMP_WAIT_TRIG";
    POST_SAMP_FILL:       state_ascii = "POST_SAMP_FILL";        
    STRM_SAMP:            state_ascii = "STRM_SAMP";                                                                                     
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
    // IDLE - 
    IDLE: begin
      if (ctl_start == 1) begin
        if (cfg_mode == STREAM_MODE) begin
          state_ns = cfg_trigger_mode ? PRE_SAMP_WAIT_TRIG : STRM_SAMP;
        end else begin     
          // Check if the pre buffer is enabled
          if (pre_samp_nz) begin
            state_ns = PRE_SAMP_FILL;
          end else begin
            state_ns = POST_SAMP_WAIT_TRIG;        
          end
        end
      end
    end
    
    // PRE_SAMP_FILL - Fills the pre sample buffer 
    PRE_SAMP_FILL: begin
      if ((s_axis_tvalid == 1) && pre_last) begin
        state_ns = PRE_SAMP_WAIT_TRIG;  
      end
    end
    
    // PRE_SAMP_WAIT_TRIG - Wait until we get a trigger
    // In streaming the wait leaves on an accepted trigger edge, or at once when the trigger
    // mode is cleared while waiting (the DAC playback does the same).
    PRE_SAMP_WAIT_TRIG: begin
      if (cfg_mode == STREAM_MODE) begin
        if (accepted_trigger || !cfg_trigger_mode) begin
          state_ns = STRM_SAMP;
        end
      end else if (ctl_trig == 1) begin
        state_ns = POST_SAMP_FILL;
      end
    end
    
    // POST_SAMP_WAIT_TRIG - Wait until we get a trigger
    POST_SAMP_WAIT_TRIG: begin
      if (ctl_trig == 1) begin
        state_ns = POST_SAMP_FILL;  
      end
    end        
    
    // POST_SAMP_FILL - Fills the post sample buffer 
    POST_SAMP_FILL: begin
      if ((s_axis_tvalid == 1) && post_last) begin
        state_ns = IDLE;  
      end
    end    
    
    // STRM_SAMP - Streaming mode, data is continuously sent to the DMA
    // (in the block mode until the series ends, then wait for a trigger again)
    STRM_SAMP: begin
      if (ctl_stop == 1) begin
        state_ns = IDLE;
      end else if (series_end) begin
        state_ns = PRE_SAMP_WAIT_TRIG;
      end
    end
  endcase
end

////////////////////////////////////////////////////////////
// Name : Status Start
// Set when the process is running.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst_n == 0) begin
    sts_start <= 0;
  end else begin
    if (sts_last == 1) begin
      sts_start <= 0;
    end else begin
      if (ctl_start == 1) begin 
        sts_start <= 1; 
      end    
    end
  end
end

////////////////////////////////////////////////////////////
// Name : Status Acquire
// Set when data is being captured.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst_n == 0) begin
    sts_acquire <= 0;
  end else begin
    if ((sts_last == 1) || series_end) begin
      sts_acquire <= 0;
    end else begin
      // Start acquire if the pre buffer is enabled,
      // there is no pre buffer and a trigger has been detected or
      // streaming mode
      if (((ctl_start == 1) && (cfg_mode == NORM_MODE) &&
           pre_samp_nz) ||
          ((state_cs == POST_SAMP_WAIT_TRIG) && (ctl_trig == 1)) ||
          ((ctl_start == 1) && (cfg_mode == STREAM_MODE) && !cfg_trigger_mode) ||
          ((state_cs == PRE_SAMP_WAIT_TRIG) && (cfg_mode == STREAM_MODE) && !cfg_trigger_mode) ||
          accepted_trigger) begin
        sts_acquire <= 1;
      end    
    end
  end
end

////////////////////////////////////////////////////////////
// Name : Status Last
// Set on the last data sample. 
////////////////////////////////////////////////////////////

always @(*)
begin
  sts_last = 0;
  
  if (ctl_stop == 1) begin
    sts_last = 1;    
  end else begin
    case (state_cs)
      // POST_SAMP_FILL - Fills the post sample buffer 
      POST_SAMP_FILL: begin
        if ((s_axis_tvalid == 1) && post_last) begin
          sts_last = 1;  
        end
      end    
    endcase  
  end
end

////////////////////////////////////////////////////////////
// Name : Pre Sample Count
// Counts the pre sample data.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst_n == 0) begin
    sts_trig_pre_cnt <= 0;
  end else begin
    if (ctl_rst == 1) begin
      sts_trig_pre_cnt <= 0; 
    end else begin
      if ((s_axis_tvalid == 1) && ((state_cs == PRE_SAMP_FILL) || (state_cs == PRE_SAMP_WAIT_TRIG))) begin
        sts_trig_pre_cnt <= sts_trig_pre_cnt + 1; 
      end
    end
  end
end

////////////////////////////////////////////////////////////
// Name : Pre Sample Overflow
// Set when the counter overflows.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst_n == 0) begin
    sts_trig_pre_overflow <= 0;
  end else begin
    if (ctl_rst == 1) begin
      sts_trig_pre_overflow <= 0; 
    end else begin
      if ((sts_trig_pre_overflow == 0) && (sts_trig_pre_cnt == (2**CNT_BITS)-1)) begin
        sts_trig_pre_overflow <= 1;
      end
    end
  end
end

////////////////////////////////////////////////////////////
// Name : Post Sample Count
// Counts the post sample data.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst_n == 0) begin
    sts_trig_post_cnt <= 0;
  end else begin
    if (ctl_rst == 1) begin
      sts_trig_post_cnt <= 0; 
    end else begin
      if ((s_axis_tvalid == 1) && (state_cs == POST_SAMP_FILL)) begin
        sts_trig_post_cnt <= sts_trig_post_cnt + 1; 
      end
    end
  end
end

////////////////////////////////////////////////////////////
// Name : Post Sample Overflow
// Set when the counter overflows.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst_n == 0) begin
    sts_trig_post_overflow <= 0;
  end else begin
    if (ctl_rst == 1) begin
      sts_trig_post_overflow <= 0; 
    end else begin
      if ((sts_trig_post_overflow == 0) && (sts_trig_post_cnt == (2**CNT_BITS)-1)) begin
        sts_trig_post_overflow <= 1;
      end
    end
  end
end

////////////////////////////////////////////////////////////
// Name : Status Trigger
// Set when the trigger is detected in the trigger detect 
// state.
////////////////////////////////////////////////////////////

always @(posedge clk)
begin
  if (rst_n == 0) begin
    sts_trig <= 0;
  end else begin
    if (ctl_rst == 1) begin
      sts_trig <= 0; 
    end else begin
      case (state_cs)
        // PRE_SAMP_WAIT_TRIG - Wait until we get a trigger
        PRE_SAMP_WAIT_TRIG: begin
          if (ctl_trig == 1) begin
            sts_trig <= 1;
          end
        end    
        
        // POST_SAMP_WAIT_TRIG - Wait until we get a trigger
        POST_SAMP_WAIT_TRIG: begin
          if (ctl_trig == 1) begin
            sts_trig <= 1;
          end
        end        
      endcase      
    end
  end
end

always @(posedge clk)
begin
  if (rst_n == 0) begin
    m_axis_tvalid <= 0;
  end else begin
    if ((sts_acquire == 1) && (s_axis_tvalid == 1)) begin
      m_axis_tvalid <= 1;
    end else begin
      m_axis_tvalid <= 0;
    end
  end  
end

always @(posedge clk)
begin
  m_axis_tlast <= sts_last;
end

always @(posedge clk)
begin
  m_axis_tdata <= s_axis_tdata;
end

endmodule
