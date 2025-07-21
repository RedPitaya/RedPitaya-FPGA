`timescale 1ns / 1ps

module osc_filter
  #(parameter DW = 16)(
  input  wire         clk,  
  input  wire         rst_n,    
  // Slave AXI-S
  input  wire [DW-1:0]  s_axis_tdata,
  input  wire         s_axis_tvalid,
  output wire         s_axis_tready,
  // Master AXI-
  output reg  [DW-1:0]  m_axis_tdata,
  output wire         m_axis_tvalid,
  input  wire         m_axis_tready,
  // Confi
  input  wire         cfg_bypass,
  input  wire [18-1:0]  cfg_coeff_aa, 
  input  wire [25-1:0]  cfg_coeff_bb, 
  input  wire [25-1:0]  cfg_coeff_kk, 
  input  wire [25-1:0]  cfg_coeff_pp  
);

////////////////////////////////////////////////////////////////////////////////
// local signals
////////////////////////////////////////////////////////////////////////////////
/*
wire signed [15:0]  din; 
reg         [15:0]  tdata_pipe [0:3];
reg         [3:0]   tvalid_pipe;
wire signed [17:0]  coeff_aa;
wire signed [24:0]  coeff_bb;
wire signed [24:0]  coeff_kk;
wire signed [24:0]  coeff_pp;

wire signed [39-1:0]  bb_mult; // DIN + coeff_bb = 39->41
wire signed [33-1:0]  r2_sum; // r1reg = 33->35
reg  signed [33-1:0]  r1_reg; // r02reg+1 = 33->35
reg  signed [23-1:0]  r2_reg; // r2sum-10 = 23->25
reg  signed [32-1:0]  r01_reg; // DIN + 18 = 32->34
reg  signed [28-1:0]  r02_reg; // BB mult - 10 = 28->30

wire signed [41-1:0]  aa_mult; // r3reg_dsp1 + coeff_aa = 41->43
wire signed [48-1:0]  r3_sum; // r2reg+25+1 = 49->51
reg  signed [23-1:0]  r3_reg_dsp1; // r3_sum-25 = 23->25
reg  signed [23-1:0]  r3_reg_dsp2; // r3_sum-25 = 23->25
reg  signed [23-1:0]  r3_reg_dsp3; // r3_sum-25 = 23->25

wire signed [40-1:0]  pp_mult; // r4_reg + coeff_pp = 40->42
wire signed [16-1:0]  r4_sum; // r3shr+1
reg  signed [15-1:0]  r4_reg; // r3sum-33-1
reg  signed [15-1:0]  r3_shr; // r3sum-33-1

wire signed [40-1:0]  kk_mult;
reg  signed [14-1:0]  r5_reg;
*/

wire signed [DW-1:0]  din; 
reg         [DW-1:0]  tdata_pipe [0:3];
reg         [3:0]     tvalid_pipe;
wire signed [18-1:0]  coeff_aa;
wire signed [25-1:0]  coeff_bb;
wire signed [25-1:0]  coeff_kk;
wire signed [25-1:0]  coeff_pp;

wire signed [(DW+25)-1:0]  bb_mult; // DIN + coeff_bb = 39->41
wire signed [35-1:0]  r2_sum; // r1reg = 33->35
reg  signed [35-1:0]  r1_reg; // r02reg+1 = 33->35
reg  signed [25-1:0]  r2_reg; // r2sum-10 = 23->25
reg  signed [(DW+18)-1:0]  r01_reg; // DIN + 18 = 32->34
reg  signed [30-1:0]  r02_reg; // BB mult - 10 = 28->30

wire signed [41-1:0]  aa_mult; // r3reg_dsp1 + coeff_aa = 41->43
wire signed [48-1:0]  r3_sum; // r2reg+25+1 = 49->51
(* use_dsp="yes" *) reg  signed [23-1:0]  r3_reg_dsp1; // r3_sum-25 = 23->25
(* use_dsp="yes" *) reg  signed [23-1:0]  r3_reg_dsp2; // r3_sum-25 = 23->25
reg  signed [23-1:0]  r3_reg_dsp3; // r3_sum-25 = 23->25

wire signed [40-1:0]  pp_mult; // r4_reg + coeff_pp = 40->42
wire signed [18-1:0]  r4_sum; // r3shr+1
reg  signed [17-1:0]  r4_reg; // r3sum-33-1
reg  signed [17-1:0]  r3_shr; // r3sum-33-1

reg  signed [42-1:0]  kk_mult;
reg  signed [DW-1:0]  r5_reg;
reg                   bypass_reg;
wire                  bypass_dis;

assign s_axis_tready  = 1;
// convert to signed 
assign din            = s_axis_tdata;
assign coeff_aa       = cfg_coeff_aa;
assign coeff_bb       = cfg_coeff_bb;
assign coeff_kk       = cfg_coeff_kk;
assign coeff_pp       = cfg_coeff_pp;
//assign m_axis_tdata   = (cfg_bypass == 1'b0) ? r5_reg : din;
//assign m_axis_tdata   = r1_reg[35:20];

assign m_axis_tvalid  = tvalid_pipe[3];


assign bb_mult = din * coeff_bb;
assign r2_sum  = r01_reg + r1_reg;

always @(posedge clk)
begin
  bypass_reg <= cfg_bypass;
end

assign bypass_dis     = bypass_reg && ~cfg_bypass;

always @(posedge clk)
begin
 if ((rst_n == 1'b0) || bypass_dis) begin
    r1_reg  <= 'h0;
    r2_reg  <= 'h0;
    r01_reg <= 'h0;
    r02_reg <= 'h0;
  end else begin
    r1_reg  <= r02_reg - r01_reg;
    r2_reg  <= r2_sum >>> 10;
    r01_reg <= din <<< 18;
    r02_reg <= bb_mult >>> 10;
  end
end

//---------------------------------------------------------------------------------
//  IIR 1

assign aa_mult = r3_reg_dsp1 * coeff_aa;
assign r3_sum  = (r2_reg <<< 23) + (r3_reg_dsp2 <<< 25) - aa_mult;

always @(posedge clk)
begin
 if ((rst_n == 1'b0) || bypass_dis) begin
   r3_reg_dsp1 <= 'h0;
   r3_reg_dsp2 <= 'h0;
   r3_reg_dsp3 <= 'h0;          
 end else begin
   r3_reg_dsp1 <= r3_sum >>> 25;
   r3_reg_dsp2 <= r3_sum >>> 25;
   r3_reg_dsp3 <= r3_sum >>> 31;
 end
end

//---------------------------------------------------------------------------------
//  IIR 2

assign pp_mult = r4_reg * coeff_pp;
assign r4_sum  = r3_shr + (pp_mult >>> 16);

always @(posedge clk)
begin
 if ((rst_n == 1'b0) || bypass_dis) begin
   r3_shr <= 'h0;   
   r4_reg <= 'h0;     
 end else begin
   r3_shr <= r3_reg_dsp3;
   r4_reg <= r4_sum;
 end    
end

//---------------------------------------------------------------------------------
//  Scaling

//assign kk_mult = r4_reg * coeff_kk;


always @(posedge clk)
   kk_mult <= r4_reg * coeff_kk;

always @(posedge clk)
begin
 if ((rst_n == 1'b0) || bypass_dis) begin
   r5_reg <= 'h0;   
 end else begin
    if ((kk_mult >>> 24) > $signed({1'b0,{(DW-1){1'b1}}})) begin
      //r5_reg <= 16'h7FFF;
      r5_reg <= {1'b0,{(DW-1){1'b1}}};
    end else begin
      if ((kk_mult >>> 24) < $signed({1'b1,{(DW-1){1'b0}}})) begin 
        //r5_reg <= 16'h8000;
        r5_reg <= {1'b1,{(DW-1){1'b0}}};
      end else  begin
        r5_reg <= kk_mult >>> 24;
      end
    end
  end
end

always @(posedge clk)
begin
  if (cfg_bypass)
    m_axis_tdata <= din;
  else
    m_axis_tdata <= $unsigned(r5_reg);
end

always @(posedge clk)
begin
 tdata_pipe[0] <= din;
 tdata_pipe[1] <= tdata_pipe[0];
 tdata_pipe[2] <= tdata_pipe[1];  
 tdata_pipe[3] <= tdata_pipe[2];   
end

always @(posedge clk)
begin
  if (rst_n == 0)
    tvalid_pipe <= 'h0;
  else begin
    tvalid_pipe[0] <= s_axis_tvalid;
    tvalid_pipe[1] <= tvalid_pipe[0];
    tvalid_pipe[2] <= tvalid_pipe[1];
    tvalid_pipe[3] <= tvalid_pipe[2];    
  end
end

endmodule
