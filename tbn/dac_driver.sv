`include "tb_defines.sv"

module dac_driver #()
(
   // ADC
  input                           adc_clk_i ,
  input  logic [2-1:0] [14-1:0]  dac_dat_i , // DAC combined data
  input  logic                    dac_clk_i , // DAC clock
  input  logic                    dac_rst_i , // DAC reset
  input  logic                    dac_wrt_i , // DAC write enable
  input  logic                    dac_sel_i , // DAC channel select

  output logic           [14-1:0] dac_a_o   ,
  output logic           [14-1:0] dac_b_o
);

reg [14-1:0] dac_cha_prev;
reg [14-1:0] dac_chb_prev;

localparam N_SAMP = `DAC_SAMPS-1;
reg [15:0] mem_dac1[0:N_SAMP];
reg [15:0] mem_dac2[0:N_SAMP];
reg [15:0] mem_gpio[0:N_SAMP];

integer file1, readi1;
integer file2, readi2;
integer file3, readi3;

initial begin
  file1  = $fopen(`DAC_SRC_CH0,"r");
  $display("Loaded DAC file 1 %d ", file1);
  readi1 = $fread(mem_dac1[0],file1);
  $display("Loaded %0d entries for DAC file 1 \n", readi1);
  $fclose(file1);
end

initial begin
  file2  = $fopen(`DAC_SRC_CH1,"r");
  $display("Loaded DAC file 2 %d ", file2);
  readi2 = $fread(mem_dac2[0],file2);
  $display("Loaded %0d entries for DAC file 2 \n", readi2);
  $fclose(file2);
end

initial begin
  file3  = $fopen(`GPIO_SRC_OUT,"r");
  $display("Loaded GPIO file %d ", file3);
  readi3 = $fread(mem_gpio,file3);
  $display("Loaded %0d entries for GPIO file \n", readi3);
  $fclose(file3);
end

`ifdef Z20_250
always @(posedge adc_clk_i) begin
  if (dac_rst_i) begin
    dac_a_o <= 'h0;
    dac_b_o <= 'h0;
  end
    dac_a_o <= dac_dat_i[0];
    dac_b_o <= dac_dat_i[1]; 

    dac_cha_prev <= dac_a_o;
    dac_chb_prev <= dac_b_o;
end
`else
always @(posedge dac_clk_i) begin
    if (~dac_wrt_i) begin
        if (~dac_sel_i)
            dac_a_o <= {dac_dat_i[0][14-1],~dac_dat_i[0][14-2:0]};
        else 
            dac_b_o <= {dac_dat_i[0][14-1],~dac_dat_i[0][14-2:0]};  
    end
    dac_cha_prev <= dac_a_o;
    dac_chb_prev <= dac_b_o;
end
`endif

/*
wire port1_en  = dac_wrt &  dac_sel;
wire port2_en  = dac_wrt & ~dac_sel;
wire port_sync = dac_clk & ~dac_rst;

reg [14-1:0] port1, port2;
reg [14-1:0] port1_o, port2_o;

always @(posedge port1_en)
  port1 <= dac_dat;

always @(posedge port2_en)
  port2 <= dac_dat;

always @(posedge dac_clk) begin
  port1_o <= ~port1;
  port2_o <= ~port2;
end
*/

wire cha_test = (dac_cha_prev - dac_a_o) > 1 ? 1'b0 : 1'b1;
wire chb_test = (dac_chb_prev - dac_b_o) > 1 ? 1'b0 : 1'b1;


endmodule