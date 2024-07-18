`include "tb_defines.sv"

module adc_driver #(
  parameter N_SAMP  = 1000,
  parameter FILERD  = 0,
  parameter SINE    = 0,
  parameter CNT_SHFT= 0,
  parameter DW      = 14
)(
   // ADC
   input  [ 2-1: 0] adc_clk_i    ,
   input  [ 2-1: 0] adc_rstn_i   ,
   input  [16-1: 0] adc_data_in0 ,
   input  [16-1: 0] adc_data_in1 ,
   input  [16-1: 0] adc_data_in2 ,
   input  [16-1: 0] adc_data_in3 ,

   output logic [4-1:0][16-1:0] adc_drv_o     , 
   output logic [4-1:0][ 7-1:0] adc_drv_ddr_o , 
   output logic [4-1:0][ 7-1:0] adc_drv_p_o   , 
   output logic [4-1:0][ 7-1:0] adc_drv_n_o
);

integer SHIFT_CNT = 1 << CNT_SHFT;

wire [14-1:0] adc_data1;
wire [14-1:0] adc_data2;
wire [14-1:0] adc_data3;
wire [14-1:0] adc_data4;

wire test_filerd = FILERD == 1;
wire test_sine   = SINE   == 1;

assign adc_data1 = test_filerd ? read_data1[16-1:2] : (test_sine ? buf_rd0 : adc_data_in0);
assign adc_data2 = test_filerd ? read_data2[16-1:2] : (test_sine ? buf_rd1 : adc_data_in1);
assign adc_data3 = test_filerd ? read_data3[16-1:2] : (test_sine ? buf_rd2 : adc_data_in2);
assign adc_data4 = test_filerd ? read_data4[16-1:2] : (test_sine ? buf_rd3 : adc_data_in3);

reg  [14-1:0] adc_data1_inv;
reg  [14-1:0] adc_data2_inv;
reg  [14-1:0] adc_data3_inv;
reg  [14-1:0] adc_data4_inv;

wire [14-1:0] adc_data1_diag = {adc_data1_inv[14-1], ~adc_data1_inv[14-2:0]};
wire [14-1:0] adc_data2_diag = {adc_data2_inv[14-1], ~adc_data2_inv[14-2:0]};
wire [14-1:0] adc_data3_diag = {adc_data3_inv[14-1], ~adc_data3_inv[14-2:0]};
wire [14-1:0] adc_data4_diag = {adc_data4_inv[14-1], ~adc_data4_inv[14-2:0]};

reg  [ 7-1:0] adc_data1_h, adc_data1_l;
reg  [ 7-1:0] adc_data2_h, adc_data2_l;
reg  [ 7-1:0] adc_data3_h, adc_data3_l;
reg  [ 7-1:0] adc_data4_h, adc_data4_l;

assign adc_drv_o[0] = {adc_data1_inv,{16-DW{adc_data1_inv[14-1]}}};
assign adc_drv_o[1] = {adc_data2_inv,{16-DW{adc_data2_inv[14-1]}}};
assign adc_drv_o[2] = {adc_data3_inv,{16-DW{adc_data3_inv[14-1]}}};
assign adc_drv_o[3] = {adc_data4_inv,{16-DW{adc_data4_inv[14-1]}}};

always @(posedge adc_clk_i[0]) begin
  adc_data1_inv <= {adc_data1[14-1], ~adc_data1[14-2:0]};
  adc_data2_inv <= {adc_data2[14-1], ~adc_data2[14-2:0]};
end

always @(posedge adc_clk_i[1]) begin
  adc_data3_inv <= {adc_data3[14-1], ~adc_data3[14-2:0]};
  adc_data4_inv <= {adc_data4[14-1], ~adc_data4[14-2:0]};
end

genvar GV;
generate
for (GV = 0; GV < 7; GV = GV + 1) begin : adc_encode

  assign adc_drv_ddr_o[0][GV] = ~adc_clk_i[0] ? adc_data1_inv[2*GV+1] : adc_data1_inv[2*GV];
  assign adc_drv_ddr_o[1][GV] = ~adc_clk_i[0] ? adc_data2_inv[2*GV+1] : adc_data2_inv[2*GV];
  assign adc_drv_ddr_o[2][GV] = ~adc_clk_i[1] ? adc_data3_inv[2*GV+1] : adc_data3_inv[2*GV];
  assign adc_drv_ddr_o[3][GV] = ~adc_clk_i[1] ? adc_data4_inv[2*GV+1] : adc_data4_inv[2*GV];
/*
always @(adc_clk_i[0]) begin
  if (adc_clk_i[0] == 1'b1) begin
    adc_drv_ddr_o[0][GV] <= adc_data1_inv[2*GV+1];
    adc_drv_ddr_o[1][GV] <= adc_data2_inv[2*GV+1];
  end else begin
    adc_drv_ddr_o[0][GV] <= adc_data1_inv[2*GV];
    adc_drv_ddr_o[1][GV] <= adc_data2_inv[2*GV];
  end
end

always @(adc_clk_i[1] == 1'b1) begin
  if (adc_clk_i[1]) begin
    adc_drv_ddr_o[2][GV] <= adc_data3_inv[2*GV];
    adc_drv_ddr_o[3][GV] <= adc_data4_inv[2*GV];
  end else begin
    adc_drv_ddr_o[2][GV] <= adc_data3_inv[2*GV+1];
    adc_drv_ddr_o[3][GV] <= adc_data4_inv[2*GV+1];
  end
end
*/

  assign adc_drv_p_o[0][GV]   =  adc_drv_ddr_o[0][GV];
  assign adc_drv_p_o[1][GV]   =  adc_drv_ddr_o[1][GV];
  assign adc_drv_p_o[2][GV]   =  adc_drv_ddr_o[2][GV];
  assign adc_drv_p_o[3][GV]   =  adc_drv_ddr_o[3][GV];
  assign adc_drv_n_o[0][GV]   = ~adc_drv_ddr_o[0][GV];
  assign adc_drv_n_o[1][GV]   = ~adc_drv_ddr_o[1][GV];
  assign adc_drv_n_o[2][GV]   = ~adc_drv_ddr_o[2][GV];
  assign adc_drv_n_o[3][GV]   = ~adc_drv_ddr_o[3][GV];

  always @(*) begin
    if (adc_clk_i[0]) begin
      adc_data1_h[GV] <= adc_data1_inv[2*GV];
      adc_data2_h[GV] <= adc_data2_inv[2*GV];
    end
    if (~adc_clk_i[0]) begin
      adc_data1_l[GV] <= adc_data1_inv[2*GV+1];
      adc_data2_l[GV] <= adc_data2_inv[2*GV+1];
    end
    if (adc_clk_i[1]) begin
      adc_data3_h[GV] <= adc_data3_inv[2*GV];
      adc_data4_h[GV] <= adc_data4_inv[2*GV];
    end
    if (~adc_clk_i[1]) begin
      adc_data3_l[GV] <= adc_data3_inv[2*GV+1];
      adc_data4_l[GV] <= adc_data4_inv[2*GV+1];
    end
  end
end 
endgenerate


integer file1, readi1;
integer file2, readi2;
integer file3, readi3;
integer file4, readi4;

reg [15:0] mem_adc1[0:N_SAMP];
reg [15:0] mem_adc2[0:N_SAMP];
reg [15:0] mem_adc3[0:N_SAMP];
reg [15:0] mem_adc4[0:N_SAMP];

reg signed [15:0] read_data1;
reg signed [15:0] read_data2;
reg signed [15:0] read_data3;
reg signed [15:0] read_data4;

reg [32-1:0] filerd_cnt0, filerd_cnt1;
initial begin
  filerd_cnt0 = 32'h0;
  filerd_cnt1 = 32'h0;
end

initial begin
  file1  = $fopen(`ADC_SRC_CH0,"r");
  $display("Loaded file 1 %d ", file1);
  readi1 = $fread(mem_adc1[0],file1);
  $display("Loaded %0d entries for file 1 \n", readi1);
  $fclose(file1);
end

initial begin
  file2  = $fopen(`ADC_SRC_CH1,"r");
  $display("Loaded file 2 %d ", file2);
  readi2 = $fread(mem_adc2[0],file2);
  $display("Loaded %0d entries for file 2 \n", readi2);
  $fclose(file2);
end

initial begin
  file3  = $fopen(`ADC_SRC_CH2,"r");
  $display("Loaded file 3 %d ", file3);
  readi3 = $fread(mem_adc3[0],file3);
  $display("Loaded %0d entries for file 3 \n", readi3);
  $fclose(file3);
end

initial begin
  file4  = $fopen(`ADC_SRC_CH3,"r");
  $display("Loaded file 4 %d ", file4);
  readi4 = $fread(mem_adc4[0],file4);
  $display("Loaded %0d entries for file 4 \n", readi4);
  $fclose(file4);
end

always @(posedge adc_clk_i[0]) begin
  if (filerd_cnt0 >= N_SAMP || adc_rstn_i[0]==0)
    filerd_cnt0 <= 32'h0;
  else 
    filerd_cnt0 <= filerd_cnt0 + 1;

  read_data1 <= {mem_adc1[filerd_cnt0][7:0], mem_adc1[filerd_cnt0][15:8]};
  read_data2 <= {mem_adc2[filerd_cnt0][7:0], mem_adc2[filerd_cnt0][15:8]};
end

always @(posedge adc_clk_i[1]) begin
  if (filerd_cnt1 >= N_SAMP || adc_rstn_i[1]==0)
    filerd_cnt1 <= 32'h0;
  else 
    filerd_cnt1 <= filerd_cnt1 + 1;

  read_data3 <= {mem_adc3[filerd_cnt1][7:0], mem_adc3[filerd_cnt1][15:8]};
  read_data4 <= {mem_adc4[filerd_cnt1][7:0], mem_adc4[filerd_cnt1][15:8]};
end

reg [16-1:0] buffer [0:125-1] = {0,206,411,615,818,1019,1217,1412,1603,1790,1973,2151,2324,2490,2650,2804,2950,3089,3221,3344,3458,3564,3661,3749,3827,3896,3954,4003,4041,
                                4070,4088,4096,4093,4080,4057,4023,3980,3926,3862,3789,3706,3614,3512,3402,3283,3156,3021,2878,2728,2571,2408,2238,2063,1882,1697,1508,1315,
                                1118,919,717,513,309,103,-103,-309,-513,-717,-919,-1118,-1315,-1508,-1697,-1882,-2063,-2238,-2408,-2571,-2728,-2878,-3021,-3156,-3283,-3402,
                                -3512,-3614,-3706,-3789,-3862,-3926,-3980,-4023,-4057,-4080,-4093,-4096,-4088,-4070,-4041,-4003,-3954,-3896,-3827,-3749,-3661,-3564,-3458,
                                -3344,-3221,-3089,-2950,-2804,-2650,-2490,-2324,-2151,-1973,-1790,-1603,-1412,-1217,-1019,-818,-615,-411,-206};
reg [16-1:0] buf_rp0 = 16'd0;
reg [16-1:0] buf_rp1 = 16'd30;
reg [16-1:0] buf_rp2 = 16'd60;
reg [16-1:0] buf_rp3 = 16'd90;

wire [16-1:0] buf_rd0, buf_rd1, buf_rd2, buf_rd3;

always @(posedge adc_clk_i[0]) begin
  if (buf_rp0<124*SHIFT_CNT)
    buf_rp0 <= buf_rp0 +1;
  else
    buf_rp0 <= 'd0;

  if (buf_rp1<124*SHIFT_CNT)
    buf_rp1 <= buf_rp1 +1;
  else
    buf_rp1 <= 'd0;
end

always @(posedge adc_clk_i[1]) begin
  if (buf_rp2<124*SHIFT_CNT)
    buf_rp2 <= buf_rp2 +1;
  else
    buf_rp2 <= 'd0;

  if (buf_rp3<124*SHIFT_CNT)
    buf_rp3 <= buf_rp3 +1;
  else
    buf_rp3 <= 'd0;
end

assign buf_rd0=buffer[buf_rp0[16-1:CNT_SHFT]];
assign buf_rd1=buffer[buf_rp1[16-1:CNT_SHFT]];
assign buf_rd2=buffer[buf_rp2[16-1:CNT_SHFT]];
assign buf_rd3=buffer[buf_rp3[16-1:CNT_SHFT]];
endmodule