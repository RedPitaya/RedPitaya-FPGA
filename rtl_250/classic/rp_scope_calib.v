`timescale 1ns / 1ps

module rp_scope_calib
  #(parameter DBITS = 16)(
  input  wire                     adc_clk_i,
  input  wire                     adc_rstn_i,

  input  wire [DBITS-1:0]         calib_dat_i,
  input  wire                     calib_din_tvalid_i,

  output reg  [DBITS-1:0]         calib_dat_o,
  output reg                      calib_dout_tvalid_o,
      
  // Config
  input  wire [DBITS-1:0]         cfg_calib_offset_i, 
  input  wire [15:0]              cfg_calib_gain_i  
);

localparam CALC1_BITS = DBITS+1;

localparam CALC2_BITS = 2*DBITS-2;
localparam CALC3_BITS = 2*CALC2_BITS+2;
localparam CALC_MAX   = (2**(DBITS-1))-1;
localparam CALC_MIN   = -(2**(DBITS-1));

localparam C_START    = CALC1_BITS-1;
localparam C_END      = C_START+CALC1_BITS-1;

reg signed  [DBITS-1:0]           adc_data, adc_data_reg;
reg signed  [DBITS-1:0]           offset, offset_reg;
reg signed  [15:0]                gain, gain_reg;     

reg  signed [DBITS:0]             offset_calc;
wire                              offs_max, offs_min;
wire signed [DBITS:0]             offset_calc_limit;

reg  signed [CALC3_BITS-1:0]      gain_calc;
reg  signed [CALC3_BITS-1:0]      gain_calc_r;
wire                              gain_max, gain_min;
wire signed [DBITS-1:0]           gain_calc_limit;

reg                               s_axis_tvalid_p1;
reg                               s_axis_tvalid_p2;

initial begin
    //$display ("DBITS=%0d (CALC3_BITS-C_START-1)=%0d (CALC3_BITS)-C_END)=%0d ", DBITS, (CALC3_BITS-C_START-1), ((CALC3_BITS)-C_END));
    //$display ("DBITS=%0d CALC3_BITS=%0d C_START=%0d C_END=%0d ", DBITS, CALC3_BITS, C_START, C_END);
end
// DBG
//always @(gain_calc)
//begin
    //$display ("\n");
    //$display ("gain_calc=%0b", gain_calc);
    //$display ("gain_calc[(CALC3_BITS-C_START-1):((CALC3_BITS)-C_END)]=%0b", gain_calc[(CALC3_BITS-C_START-1):((CALC3_BITS)-C_END)]);
    //$display ("offset_calc=%0b", offset_calc);
    //$display ("offs_max=%0b, offs_min=%0b, offset_calc[DBITS:DBITS-1]=%0b", offs_max, offs_min, offset_calc[DBITS:DBITS-1]);
    //$display ("DBITS=%0d (CALC3_BITS-C_START-1)=%0d (CALC3_BITS)-C_END)=%0d ", DBITS, (CALC3_BITS-C_START-1), ((CALC3_BITS)-C_END));
    //$display ("DBITS=%0d CALC3_BITS=%0d C_START=%0d C_END=%0d ", DBITS, CALC3_BITS, C_START, C_END);
    //$display ("DBITS=%0d adc_data=%0d, offset=%0d, gain=%0d, adc_data+offset=%0d, gain_calc[(CALC3_BITS-C_START-1):((CALC3_BITS)-C_END)]=%0d ", DBITS, adc_data, offset, gain, adc_data+offset, gain_calc[(CALC3_BITS-C_START-1):((CALC3_BITS)-C_END)]);
    ////$display ("\n");
//end
////////////////////////////////////////////////////////////
// Input data registration
// 
////////////////////////////////////////////////////////////
always @(posedge adc_clk_i)
begin
  if (adc_rstn_i == 1'b0) begin
    adc_data_reg <= 'h0;
    adc_data     <= 'h0;

    offset_reg <= 'h0;
    offset     <= 'h0;

    gain_reg <= 'h0;
    gain     <= 'h0;    
  end else begin
    adc_data_reg <= calib_dat_i;
    adc_data <= adc_data_reg;

    offset_reg <= cfg_calib_offset_i;
    offset <= offset_reg;

    gain_reg <= cfg_calib_gain_i;
    gain <= gain_reg;
  end
end
////////////////////////////////////////////////////////////
// Name : Gain Calculation
// 
////////////////////////////////////////////////////////////

always @(posedge adc_clk_i)
begin
  if (adc_rstn_i == 1'b0) begin
    gain_calc_r <= 'h0;
    gain_calc   <= 'h0;
  end else begin

    //gain_calc_r <= $signed({offset_calc_limit,{15{1'b0}}}) * {{15{1'b0}},gain};
    gain_calc_r <= ($signed({offset_calc_limit,{15{1'b0}}}) * $signed({{15{1'b0}},gain})) >>> (30);
    gain_calc   <= gain_calc_r; // output of multiplier needs to be registered to avoid timing issues
  end
end

//assign gain_max = (gain_calc[CALC3_BITS-1:CALC3_BITS-2] == 2'b01);
//assign gain_min = (gain_calc[CALC3_BITS-1:CALC3_BITS-2] == 2'b10);
assign gain_max = gain_calc>CALC_MAX ? 1:0;
assign gain_min = gain_calc<CALC_MIN ? 1:0;

//assign gain_calc_limit = gain_max ? CALC_MAX : (gain_min ? CALC_MIN : gain_calc[(CALC3_BITS-C_START-1):((CALC3_BITS)-C_END)]);
//assign gain_calc_limit = gain_max ? CALC_MAX : (gain_min ? CALC_MIN : gain_calc[(CALC3_BITS-C_START-1):((CALC3_BITS)-C_END)]);
assign gain_calc_limit = gain_max ? CALC_MAX : (gain_min ? CALC_MIN : gain_calc);


////////////////////////////////////////////////////////////
// Name : Offset Calculation
// 
////////////////////////////////////////////////////////////

always @(posedge adc_clk_i)
begin
  if (adc_rstn_i == 1'b0)
    offset_calc <= 'h0;
  else
    offset_calc <= $signed(adc_data) + $signed(offset);  
end

//assign offs_max = (offset_calc[16:15] == 2'b01);
//assign offs_min = (offset_calc[16:15] == 2'b10);
assign offs_max = (offset_calc[DBITS:DBITS-1] == 2'b01);
assign offs_min = (offset_calc[DBITS:DBITS-1] == 2'b10);

assign offset_calc_limit = offs_max ? CALC_MAX : (offs_min ? CALC_MIN : offset_calc);

////////////////////////////////////////////////////////////
// Name : Master AXI-S TDATA
// 
////////////////////////////////////////////////////////////

always @(posedge adc_clk_i)
begin
  if (adc_rstn_i == 1'b0)
    calib_dat_o <= 'h0;
  else
    calib_dat_o <= gain_calc_limit[DBITS-1:0];  
end

////////////////////////////////////////////////////////////
// Name : Master AXI-S TVALID
// 
////////////////////////////////////////////////////////////

always @(posedge adc_clk_i)
begin
  if (adc_rstn_i == 1'b0) begin
    s_axis_tvalid_p1  <= 1'b0;
    s_axis_tvalid_p2  <= 1'b0;
    calib_dout_tvalid_o     <= 1'b0;   
  end else begin
    s_axis_tvalid_p1  <= calib_din_tvalid_i;
    s_axis_tvalid_p2  <= s_axis_tvalid_p1;
    calib_dout_tvalid_o     <= s_axis_tvalid_p2;   
  end
end

endmodule
