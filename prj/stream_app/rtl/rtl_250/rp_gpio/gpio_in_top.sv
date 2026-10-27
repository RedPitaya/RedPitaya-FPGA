module gpio_in_top   #(
    parameter S_AXI_REG_ADDR_BITS   = 12,
    parameter M_AXI_GPIO_ADDR_BITS  = 32,
    parameter M_AXI_GPIO_DATA_BITS  = 64,
    parameter GPIO_BITS             = 8,
    parameter DCW = 17,  // decimation counter width
    parameter CW = 32,  // counter width
    parameter TN =  4,  // trigger number
    parameter TW = 64,   // timestamp width
    parameter DN = 1,
    type DT = reg [8-1:0])( 
  input                 clk,
  input                 rst_n,
  axi4_stream_if.d  sti,
  // control
  input  reg          ctl_rst,  // synchronous reset
  input  reg [DCW-1:0] cfg_dec,  // decimation factor
  // bits 7:0 the P lines, 15:8 the N lines
  input  wire [16-1:0] cfg_pol,      // input polarity
  input  wire [16-1:0] cfg_cmp_msk,  // comparator mask
  input  wire [16-1:0] cfg_cmp_val,  // comparator value
  input  wire [16-1:0] cfg_edg_pos,  // edge positive
  input  wire [16-1:0] cfg_edg_neg,  // edge negative
  output reg          irq_trg,  // trigger
  output reg          irq_stp,  // stop
  output reg          trg_out,
  output reg [CW-1:0] sts_cur,  // current     counter status
  output reg [CW-1:0] sts_lst,  // last packet counter status
  input  reg [TN-1:0] cfg_trg,  // trigger mask
  input  reg          cfg_con,  // continuous
  input  reg          cfg_aut,  // automatic
  input  reg          cfg_rle,  // enable RLE
  input  reg [CW-1:0] cfg_pre,
  output reg [CW-1:0] sts_pre,
  input  reg [CW-1:0] cfg_pst,
  output reg [CW-1:0] sts_pst,
  input  reg          ctl_acq,  // acquire start
  output reg          sts_acq,
  output reg [TW-1:0] cts_acq,
  input  reg [TN-1:0] ctl_trg,
  output reg          sts_trg,
  output reg [TW-1:0] cts_trg,
  input  reg          ctl_stp,  // acquire stop
  output reg [TW-1:0] cts_stp,

  input  wire [S_AXI_REG_ADDR_BITS-1:0]   reg_addr,
  input  wire [31:0]                reg_wr_data,
  input  wire                       reg_wr_we, 

  //
  output                                dma_intr,
  output      [31:0]                    reg_ctrl,
  output      [31:0]                    reg_sts,
  input [M_AXI_GPIO_ADDR_BITS-1:0]      gpio_step,
  input [M_AXI_GPIO_ADDR_BITS-1:0]      gpio_buf_size,
  input [M_AXI_GPIO_ADDR_BITS-1:0]      gpio_buf1_adr,
  input [M_AXI_GPIO_ADDR_BITS-1:0]      gpio_buf2_adr,
  output [M_AXI_GPIO_ADDR_BITS-1:0]     gpio_wp,
  input  [ 8-1:0]                       gpio_ctrl_reg,
  output [ 5-1:0]                       gpio_sts_reg,
  output [32-1:0]                       dma_diags,  // state of the input DMA engine, register 0xC4
  // trigger mode and block mode (gpio_in_gate), 64 bit lost counters
  input  wire                           cfg_trig_mode,
  input  wire [16-1:0]                  cfg_trig_blocks,
  input  wire                           trig_i,
  output wire                           sts_armed,
  output wire                           sts_trig_taken,
  output wire [64-1:0]                  buf1_lost,
  output wire [64-1:0]                  buf2_lost,
  output wire [64-1:0]                  buf1_wait,  // the part of the lost samples dropped while waiting for a trigger
  output wire [64-1:0]                  buf2_wait,

  output wire [(M_AXI_GPIO_ADDR_BITS-1):0]      m_axi_gpio_awaddr,    
  output wire [7:0]                             m_axi_gpio_awlen,     
  output wire [2:0]                             m_axi_gpio_awsize,    
  output wire [1:0]                             m_axi_gpio_awburst,   
  output wire [2:0]                             m_axi_gpio_awprot,    
  output wire [3:0]                             m_axi_gpio_awcache,   
  output wire                                   m_axi_gpio_awvalid,   
  input  wire                                   m_axi_gpio_awready,   
  output wire [M_AXI_GPIO_DATA_BITS-1:0]        m_axi_gpio_wdata,     
  output wire [((M_AXI_GPIO_DATA_BITS/8)-1):0]  m_axi_gpio_wstrb,     
  output wire                                   m_axi_gpio_wlast,     
  output wire                                   m_axi_gpio_wvalid,    
  input  wire                                   m_axi_gpio_wready,    
  input  wire [1:0]                             m_axi_gpio_bresp,     
  input  wire                                   m_axi_gpio_bvalid,    
  output wire                                   m_axi_gpio_bready  

);

axi4_stream_if #(.DN (DN), .DT (DT)) stn            (.ACLK (sti.ACLK), .ARESETn (sti.ARESETn));  // from negator
axi4_stream_if #(.DN (DN), .DT (DT)) std            (.ACLK (sti.ACLK), .ARESETn (sti.ARESETn));  // from decimator
axi4_stream_if #(.DN (DN), .DT (DT)) stt            (.ACLK (sti.ACLK), .ARESETn (sti.ARESETn));  // from trigger
axi4_stream_if #(.DN (DN), .DT (DT)) sta_str        (.ACLK (sti.ACLK), .ARESETn (sti.ARESETn));  // from acquire
axi4_stream_if #(.DN (1),  .DT (reg [16-1:0])) sta  (.ACLK (sti.ACLK), .ARESETn (sti.ARESETn));  // from acquire, {N, P}

axi4_stream_if #(.DN (1), .DT (reg [8+16-1:0])) sto1  (.ACLK (sti.ACLK), .ARESETn (sti.ARESETn));  // RLE output {count, N, P}

wire   external_trig_val;
// in the trigger mode the external trigger is a trigger, it does not restart the DMA
assign external_trig_val = ctl_trg[5] & (cfg_trg == 'h20) & ~cfg_trig_mode;

DT latrg;
////////////////////////////////////////////////////////////////////////////////
// Decimation
////////////////////////////////////////////////////////////////////////////////

str_dec #(
  .DN (DN),
  .CW (DCW)
) dec (
  // control
  .ctl_rst  (ctl_rst),
  // configuration
  .cfg_dec  (cfg_dec),
  // streams
  .sti      (sti),
  .sto      (std)
);

////////////////////////////////////////////////////////////////////////////////
// bitwise input polarity
////////////////////////////////////////////////////////////////////////////////

// 0 0 0
// 0 1 1
// 1 0 1
// 1 1 0

assign stn.TDATA  = std.TDATA ^ cfg_pol;  // TDATA[0] (bits 7:0) P, TDATA[1] N
assign stn.TKEEP  = std.TKEEP ;
assign stn.TLAST  = std.TLAST ;
assign stn.TVALID = std.TVALID;

assign std.TREADY = stn.TREADY;

////////////////////////////////////////////////////////////////////////////////
// Edge detection (trigger source)
////////////////////////////////////////////////////////////////////////////////

// la_trg takes its DN lanes as consecutive samples (the logic analyzer); here the
// lanes are the P and N lines of one sample, so it sees them as one 16 bit lane
axi4_stream_if #(.DN (1), .DT (reg [16-1:0])) stn16 (.ACLK (sti.ACLK), .ARESETn (sti.ARESETn));
axi4_stream_if #(.DN (1), .DT (reg [16-1:0])) stt16 (.ACLK (sti.ACLK), .ARESETn (sti.ARESETn));
wire [1-1:0] latrg16;

assign stn16.TDATA  = stn.TDATA;
assign stn16.TKEEP  = |stn.TKEEP;
assign stn16.TLAST  = stn.TLAST;
assign stn16.TVALID = stn.TVALID;
assign stn.TREADY   = stn16.TREADY;

la_trg #(
  .DN (1),
  .DT (reg [16-1:0])
) la_trg (
  // control
  .ctl_rst  (ctl_rst),
  // configuration
  .cfg_cmp_msk (cfg_cmp_msk),
  .cfg_cmp_val (cfg_cmp_val),
  .cfg_edg_pos (cfg_edg_pos),
  .cfg_edg_neg (cfg_edg_neg),
  // output triggers
  .sts_trg  (latrg16),
  // stream monitor
  .sti      (stn16),
  .sto      (stt16)
);

assign stt.TDATA  = stt16.TDATA;
assign stt.TKEEP  = {DN{stt16.TKEEP}};
assign stt.TLAST  = stt16.TLAST;
assign stt.TVALID = stt16.TVALID;
assign stt16.TREADY = stt.TREADY;
assign latrg      = latrg16;

wire [TW-1:0] cts;
cts cts_i (
  // system signals
  .clk  (clk),
  .rstn (rst_n),
  // counter
  .cts  (cts)
);

////////////////////////////////////////////////////////////////////////////////
// aquire and trigger status handler
////////////////////////////////////////////////////////////////////////////////

old_acq #(
  .DN (DN),
  .TN (TN),
  .TW (TW),
  .CW (CW)
) acq (
  // stream input/output
  .sti      (stt),
  .sto      (sta_str),
  // current time stamp
  .cts      (cts),
  // interrupts
  .irq_trg  (irq_trg),
  .irq_stp  (irq_stp),
  // control
  .ctl_rst  (ctl_rst),
  // configuration (mode)
  .cfg_trg  (cfg_trg),
  .cfg_con  (cfg_con),
  .cfg_aut  (cfg_aut),
  // configuration/status pre trigger
  .cfg_pre  (cfg_pre),
  .sts_pre  (sts_pre),
  // configuration/status post trigger
  .cfg_pst  (cfg_pst),
  .sts_pst  (sts_pst),
  // control/status/timestamp acquire
  .ctl_acq  (ctl_acq),
  .sts_acq  (sts_acq),
  .cts_acq  (cts_acq),
  // control/status/timestamp trigger
  .ctl_trg  (trg_ext),
  .sts_trg  (sts_trg),
  .cts_trg  (cts_trg),
  // control/status/timestamp stop
  .ctl_stp  (ctl_stp),
  .cts_stp  (cts_stp)
);

// one RLE over both lanes: a word is written when any line changes, and both
// lanes carry the same count (two encoders paced by the P lane lost the N lane)
assign sta.TDATA  = {sta_str.TDATA [1], sta_str.TDATA [0]};
assign sta.TKEEP  = sta_str.TKEEP ;
assign sta.TLAST  = sta_str.TLAST ;
assign sta.TVALID = sta_str.TVALID;
assign sta_str.TREADY = sta.TREADY;

rle #(
  // counter properties
  .CW (8),
  // stream properties
  .DN (DN),
  .DTI (reg [   16-1:0]),
  .DTO (reg [8+16-1:0])
) rle (
  // input stream input/output
  .sti      (sta),
  .sto      (sto1),
  // configuration
  .ctl_rst  (ctl_rst),
  .cfg_ena  (cfg_rle)
);

axi4_stream_cnt #(
  .DN (DN),
  .CW (CW)
) axi4_stream_cnt (
  // control
  .ctl_rst  (ctl_rst),
  // counter staus
  .sts_cur  (sts_cur),
  .sts_lst  (sts_lst),
  // stream monitor
  .str      (sto1)
);

////////////////////////////////////////////////////////////
// Name : Trigger mode and block mode
////////////////////////////////////////////////////////////

wire [31:0] gate_tdata;
wire        gate_tvalid, gate_tready, gate_tlast;
wire [ 8:0] drop_samples;

gpio_in_gate gate (
  .clk             (clk),
  .rst_n           (rst_n),
  .ctl_start       (ctl_acq),
  .ctl_stop        (ctl_stp | ctl_rst),
  .cfg_trig_mode   (cfg_trig_mode),
  .cfg_trig_blocks (cfg_trig_blocks),
  .cfg_block_words ({2'b0, gpio_buf_size[31:2]}),
  .trig_i          (trig_i),
  .s_tdata         ({sto1.TDATA[0][23:16], sto1.TDATA[0][15:8], sto1.TDATA[0][23:16], sto1.TDATA[0][7:0]}),
  .s_tvalid        (sto1.TVALID),
  .s_tready        (sto1.TREADY),
  .s_tlast         (sto1.TLAST),
  .m_tdata         (gate_tdata),
  .m_tvalid        (gate_tvalid),
  .m_tready        (gate_tready),
  .m_tlast         (gate_tlast),
  .drop_samples    (drop_samples),
  .armed           (sts_armed),
  .trig_taken      (sts_trig_taken)
);
////////////////////////////////////////////////////////////
// Name : DMA S2MM
// 
////////////////////////////////////////////////////////////

gpio_dma_s2mm #(
  .AXI_ADDR_BITS  (M_AXI_GPIO_ADDR_BITS),
  .AXI_DATA_BITS  (M_AXI_GPIO_DATA_BITS),
  .AXIS_DATA_BITS (32),
  .AXI_BURST_LEN  (16),
  .REG_ADDR_BITS  (S_AXI_REG_ADDR_BITS),
  .CTRL_ADDR      (8'h8C))
  U_dma_s2mm(
  .m_axi_aclk     (clk),        
  .s_axis_aclk    (clk),      
  .aresetn        (rst_n),  
  .busy           (),
  .intr           (dma_intr),     
  .reg_addr       (reg_addr),          
  .reg_wr_data    (reg_wr_data),       
  .reg_wr_we      (reg_wr_we),   
  .reg_ctrl       (reg_ctrl),
  .reg_sts        (reg_sts),
  .reg_dst_addr1  (gpio_buf1_adr),
  .reg_dst_addr2  (gpio_buf2_adr),
  .reg_buf_size   (gpio_buf_size),
  .reg_diags      (dma_diags),
  .ctl_start_o    (ctl_start_o),
  .ctl_start_ext  (external_trig_val),
  .buf_sel_out    (buf_sel),
  .buf_sel_in     (buf_sel),
  .drop_i         (drop_samples),
  .flush_i        (sts_armed),
  .buf1_lost      (buf1_lost),
  .buf2_lost      (buf2_lost),
  .buf1_wait      (buf1_wait),
  .buf2_wait      (buf2_wait),

  .m_axi_awaddr   (m_axi_gpio_awaddr), 
  .m_axi_awlen    (m_axi_gpio_awlen),  
  .m_axi_awsize   (m_axi_gpio_awsize), 
  .m_axi_awburst  (m_axi_gpio_awburst),
  .m_axi_awprot   (m_axi_gpio_awprot), 
  .m_axi_awcache  (m_axi_gpio_awcache),
  .m_axi_awvalid  (m_axi_gpio_awvalid),
  .m_axi_awready  (m_axi_gpio_awready),
  .m_axi_wdata    (m_axi_gpio_wdata),  
  .m_axi_wstrb    (m_axi_gpio_wstrb),  
  .m_axi_wlast    (m_axi_gpio_wlast),  
  .m_axi_wvalid   (m_axi_gpio_wvalid), 
  .m_axi_wready   (m_axi_gpio_wready), 
  .m_axi_bresp    (m_axi_gpio_bresp),  
  .m_axi_bvalid   (m_axi_gpio_bvalid), 
  .m_axi_bready   (m_axi_gpio_bready), 

  .s_axis_tdata   (gate_tdata),
  .s_axis_tvalid  (gate_tvalid),
  .s_axis_tready  (gate_tready),
  .s_axis_tlast   (gate_tlast)
);  
// only the pattern trigger leaves the block (the DMA start used to be ORed in and looked
// like a logic analyzer trigger to the scope and the DAC)
assign trg_out  = |latrg ;

endmodule

////////////////////////////////////////////////////////////////////////////////
// GPIO input trigger mode and block mode, between the RLE encoder and the DMA.
//
// The stream carries 32 bit words {count, N, count, P}: a word stands for
// count + 1 samples. Without the trigger mode every word passes. In the trigger
// mode the start arms the gate: the words are dropped (their samples go to the
// lost counter of the DMA) until a rising edge of the trigger. A trigger then
// passes N blocks of words (a block is one DMA buffer); a trigger inside a series
// passes the current block and N more, so a trigger in block k ends the series
// with block k+N. After the series the gate is armed again. N = 0 passes
// everything after the trigger. Clearing the trigger mode passes everything.
////////////////////////////////////////////////////////////////////////////////

module gpio_in_gate (
  input  wire        clk,
  input  wire        rst_n,
  // control
  input  wire        ctl_start,        // arms the gate in the trigger mode
  input  wire        ctl_stop,         // stop or reset
  input  wire        cfg_trig_mode,
  input  wire [15:0] cfg_trig_blocks,  // N, blocks per trigger (0: no end)
  input  wire [31:0] cfg_block_words,  // words per DMA buffer
  input  wire        trig_i,
  // streams
  input  wire [31:0] s_tdata,
  input  wire        s_tvalid,
  output wire        s_tready,
  input  wire        s_tlast,
  output wire [31:0] m_tdata,
  output wire        m_tvalid,
  input  wire        m_tready,
  output wire        m_tlast,
  // status
  output reg  [ 8:0] drop_samples,     // samples of the word dropped a clock earlier
  output wire        armed,
  output reg         trig_taken        // a trigger started or extended a series
);

localparam PASS = 2'd0,  // no trigger mode, or N = 0 after the trigger
           WAIT = 2'd1,  // armed
           RUN  = 2'd2;  // writing a series

reg  [ 1:0] state;
reg  [31:0] blk_pos;   // words of the current block passed
reg  [16:0] blk_left;  // blocks left in the series, the current one included
reg         trig_d1;

wire edge_trig = trig_i & ~trig_d1;
wire in_series = (state != WAIT) | edge_trig;
wire take      = s_tvalid & s_tready;
wire pass      = take &  in_series;
wire drop      = take & ~in_series;
wire blk_end   = pass & (blk_pos == cfg_block_words - 1);

assign m_tdata  = s_tdata;
assign m_tlast  = s_tlast;
assign m_tvalid = s_tvalid & in_series;
assign s_tready = in_series ? m_tready : 1'b1;
assign armed    = (state == WAIT);

always @(posedge clk)
  trig_d1 <= trig_i;

always @(posedge clk)
  drop_samples <= drop ? {1'b0, s_tdata[15:8]} + 9'd1 : 9'd0;

always @(posedge clk)
if (~rst_n | ctl_stop) begin
  state      <= PASS;
  blk_pos    <= 32'd0;
  blk_left   <= 17'd0;
  trig_taken <= 1'b0;
end else begin
  trig_taken <= 1'b0;
  if (ctl_start) begin
    state    <= cfg_trig_mode ? WAIT : PASS;
    blk_pos  <= 32'd0;
    blk_left <= 17'd0;
  end else if (~cfg_trig_mode) begin
    state    <= PASS;
  end else begin
    case (state)
      WAIT: if (edge_trig) begin
        trig_taken <= 1'b1;
        state      <= (cfg_trig_blocks == 16'd0) ? PASS : RUN;
        blk_left   <= {1'b0, cfg_trig_blocks};
        blk_pos    <= pass ? 32'd1 : 32'd0;
      end
      RUN: begin
        if (pass)
          blk_pos <= blk_end ? 32'd0 : blk_pos + 32'd1;
        if (edge_trig) begin
          trig_taken <= 1'b1;
          blk_left   <= blk_end ? {1'b0, cfg_trig_blocks} : {1'b0, cfg_trig_blocks} + 17'd1;
        end else if (blk_end) begin
          blk_left <= blk_left - 17'd1;
          if (blk_left == 17'd1)
            state <= WAIT;
        end
      end
      default: ;
    endcase
  end
end

endmodule
