`include "tb_defines.sv"

module monitor_tcs_strm #(



`ifdef Z20_4ADC
parameter NUM_ADC      = 4,
`else
parameter NUM_ADC      = 2,
`endif
parameter NUM_DAC      = 2,
parameter NUM_GPIO_IN  = 1,
parameter NUM_GPIO_OUT = 1,
parameter NUM_GPIO     = NUM_GPIO_IN+NUM_GPIO_OUT,
parameter NUM_IN       = 5
);




const int ch0  = `CH0;
const int ch1  = `CH1;
const int ch2  = `CH2;
const int ch3  = `CH3;
const int gpio = `GPIO;


wire  [32-1:0] axi_wr_adr [NUM_IN-1:0];

assign axi_wr_adr [`GPIO] = `AXI_GPIO_LOC.axi_awaddr_i[32-1:0];
assign axi_wr_adr [`CH3]  = `AXI_OSC23_LOC.axi_awaddr_i[32-1:0];
assign axi_wr_adr [`CH2]  = `AXI_OSC23_LOC.axi_awaddr_i[32-1:0];
assign axi_wr_adr [`CH1]  = `AXI_OSC01_LOC.axi_awaddr_i[32-1:0];
assign axi_wr_adr [`CH0]  = `AXI_OSC01_LOC.axi_awaddr_i[32-1:0];

wire  [  64-1:0] axi_wdat [NUM_IN-1:0];

assign axi_wdat [`GPIO] = `AXI_GPIO_LOC.axi_wdata_i;
assign axi_wdat [`CH3]  = `AXI_OSC23_LOC.axi_wdata_i;
assign axi_wdat [`CH2]  = `AXI_OSC23_LOC.axi_wdata_i;
assign axi_wdat [`CH1]  = `AXI_OSC01_LOC.axi_wdata_i;
assign axi_wdat [`CH0]  = `AXI_OSC01_LOC.axi_wdata_i;

wire  [NUM_IN*8 -1:0] axi_strb  = {`AXI_GPIO_LOC.axi_wstrb_i,
                              `AXI_OSC23_LOC.axi_wstrb_i,
                              `AXI_OSC23_LOC.axi_wstrb_i,
                              `AXI_OSC01_LOC.axi_wstrb_i,
                              `AXI_OSC01_LOC.axi_wstrb_i};

wire  [NUM_IN*1 -1:0] axi_wrdy  = {`AXI_GPIO_LOC.axi_wready_o,
                              `AXI_OSC23_LOC.axi_wready_o,
                              `AXI_OSC23_LOC.axi_wready_o,
                              `AXI_OSC01_LOC.axi_wready_o,
                              `AXI_OSC01_LOC.axi_wready_o};

wire  [NUM_IN*1 -1:0] axi_wval  = {`AXI_GPIO_LOC.axi_wvalid_i,
                              `AXI_OSC23_LOC.axi_wvalid_i,
                              `AXI_OSC23_LOC.axi_wvalid_i,
                              `AXI_OSC01_LOC.axi_wvalid_i,
                              `AXI_OSC01_LOC.axi_wvalid_i};

wire  [NUM_IN*1 -1:0] axi_awrdy = {`AXI_GPIO_LOC.axi_awready_o,
                              `AXI_OSC23_LOC.axi_awready_o,
                              `AXI_OSC23_LOC.axi_awready_o,
                              `AXI_OSC01_LOC.axi_awready_o,
                              `AXI_OSC01_LOC.axi_awready_o};

wire  [NUM_IN*1 -1:0] axi_awval = {`AXI_GPIO_LOC.axi_awvalid_i,
                              `AXI_OSC23_LOC.axi_awvalid_i,
                              `AXI_OSC23_LOC.axi_awvalid_i,
                              `AXI_OSC01_LOC.axi_awvalid_i,
                              `AXI_OSC01_LOC.axi_awvalid_i};

wire  [NUM_IN*1 -1:0] adc_clk   = {`AXI_GPIO_LOC.axi_clk_i,
                              `AXI_OSC23_LOC.axi_clk_i,
                              `AXI_OSC23_LOC.axi_clk_i,
                              `AXI_OSC01_LOC.axi_clk_i,
                              `AXI_OSC01_LOC.axi_clk_i};


wire  [NUM_IN*1 -1:0] axi_wid;

assign axi_wid [`GPIO] = `AXI_GPIO_LOC.axi_wid_i;
assign axi_wid [`CH3]  = `AXI_OSC23_LOC.axi_wid_i;
assign axi_wid [`CH2]  = `AXI_OSC23_LOC.axi_wid_i;
assign axi_wid [`CH1]  = `AXI_OSC01_LOC.axi_wid_i;
assign axi_wid [`CH0]  = `AXI_OSC01_LOC.axi_wid_i;

wire  [4*1 -1:0] axi_adc_en;

wire             adc_rst   = ~`IP_SCOPE_LOC.rst_n;
wire             gpio_val  =  `IP_GPIO_LOC.sto.TVALID; 
wire             gpio_p    =  `IP_GPIO_LOC.gpiop_o; 
wire             gpio_n    =  `IP_GPIO_LOC.gpion_o; 

`ifdef Z20_4ADC
wire  [2*1 -1:0] dac_val   = 2'h0;
wire             dac_clk   = 1'b0;
wire             dac_rst   = 1'b0;
`else
wire  [2*1 -1:0] dac_val   = {`IP_DAC_LOC.U_dac2.U_osc_calib.dac_rvalid_i,
                              `IP_DAC_LOC.U_dac1.U_osc_calib.dac_rvalid_i};
wire             dac_clk   =  `IP_DAC_LOC.clk;
wire             dac_rst   = ~`IP_DAC_LOC.rst_n;
`endif

wire  [  14-1:0] dac_cha   =  top_tb.dac_cha;
wire  [  14-1:0] dac_chb   =  top_tb.dac_chb;

logic               adc_trig = 1'b0;
logic [NUM_ADC-1:0] adc_trig_r;
logic [NUM_ADC-1:0] axi_trig_r;
logic [NUM_ADC-1:0] trig_src_r;
logic [     32-1:0] axi_wr_adr_r [NUM_IN-1:0];
logic [      8-1:0] dac_val_sr0;
logic [      8-1:0] dac_val_sr1;
logic [      8-1:0] gpio_val_sr;

localparam wid_const = 5'b01010;

always @(posedge adc_clk[0]) begin
  adc_trig_r <= {adc_trig_r[2:0],adc_trig};
end

genvar GV;
generate
for (GV=0; GV<NUM_IN; GV++) begin
  always @(posedge adc_clk[GV]) begin  
    if (axi_awrdy[GV] && axi_awval[GV])
      axi_wr_adr_r[GV] <= axi_wr_adr[GV];
    else if (axi_wrdy[GV] && axi_wval[GV])
      axi_wr_adr_r[GV] <= axi_wr_adr_r[GV] + 32'h8;
  end
  assign axi_adc_en[GV] = (axi_wid[GV] == wid_const[GV]);
end
endgenerate

always @(posedge dac_clk) begin
  dac_val_sr0 <= {dac_val_sr0[6:0], dac_val[0]};
  dac_val_sr1 <= {dac_val_sr1[6:0], dac_val[1]};
end

always @(posedge adc_clk[`GPIO]) begin
  gpio_val_sr <= {gpio_val_sr[6:0], gpio_val};
end

int ADC_rfile  [NUM_ADC -1:0];
int DAC_rfile  [NUM_DAC -1:0];
int GPIO_rfile [NUM_GPIO-1:0];

int STRM_ADC_rfile [NUM_ADC-1:0];


string ADC_names[3:0] = {"../../../../resultfileSTRM_ADC3.txt", 
                         "../../../../resultfileSTRM_ADC2.txt", 
                         "../../../../resultfileSTRM_ADC1.txt", 
                         "../../../../resultfileSTRM_ADC0.txt"};

string DAC_names[3:0] = {"../../../../resultfileSTRM_DAC3.txt", 
                         "../../../../resultfileSTRM_DAC2.txt", 
                         "../../../../resultfileSTRM_DAC1.txt", 
                         "../../../../resultfileSTRM_DAC0.txt"};

string GPIO_names[1:0] = {"../../../../resultfileSTRM_GPIOIN.txt", 
                          "../../../../resultfileSTRM_GPIOOUT.txt"};

initial begin 
  for (int i=0; i<NUM_ADC; i++) begin
  ADC_rfile[i]=$fopen(ADC_names[i], "w");
  end

  for (int i=0; i<NUM_DAC; i++) begin
  DAC_rfile[i]=$fopen(DAC_names[i], "w");
  end

  for (int i=0; i<NUM_GPIO; i++) begin
  GPIO_rfile[i]=$fopen(GPIO_names[i], "w");
  end


end

task set_monitor (
  int   mon_len
);
  int cnt = 32'h0;
  do begin
    fork
      adc_monitor(`ADC_MON);
      dac_monitor(`DAC_MON);
      gpio_monitor(`GPIO_MON);
    join
    cnt <= cnt + 1;
  end while (cnt < mon_len);
  for (int i=0; i<NUM_ADC; i++) begin
  $fclose(ADC_rfile[i]);
  end

  for (int i=0; i<NUM_DAC; i++) begin
  $fclose(DAC_rfile[i]);
  end

  for (int i=0; i<NUM_GPIO; i++) begin
  $fclose(GPIO_rfile[i]);
  end

endtask: set_monitor


task automatic adc_monitor  (
  logic enable
);
    fork
      if (ch0 < NUM_ADC)
        adc_monitor_ch0(enable);

      if (ch1 < NUM_ADC)
        adc_monitor_ch1(enable);

      if (ch2 < NUM_ADC)
        adc_monitor_ch2(enable);

      if (ch3 < NUM_ADC)
        adc_monitor_ch3(enable);

      //trig_monitor_adc(enable);
    join  
endtask: adc_monitor

task automatic gpio_monitor  (
  logic enable
);
    fork
      gpio_monitor_in(enable);
      gpio_monitor_out(enable);
    join  
endtask: gpio_monitor

task adc_monitor_ch0  (
  logic enable
);
  int i = `CH0;
    //$display("AXI enable: %d, i: %d, %t", enable, i, $time);
    @(posedge adc_clk[i])
      if (axi_adc_en[i] && axi_wrdy[i] && axi_wval[i] && enable) begin
        //$display("writing AXI file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS0);

        if(axi_strb[i*8+2])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS2);

        if(axi_strb[i*8+6])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS3);
      end
endtask: adc_monitor_ch0

task adc_monitor_ch1  (
  logic enable
);
  int i = `CH1;
    //$display("AXI enable: %d, i: %d, %t", enable, i, $time);
    @(posedge adc_clk[i])
      if (axi_adc_en[i] && axi_wrdy[i] && axi_wval[i] && enable) begin
        //$display("writing AXI file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS0);

        if(axi_strb[i*8+2])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS2);

        if(axi_strb[i*8+6])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS3);
      end
endtask: adc_monitor_ch1

task adc_monitor_ch2  (
  logic enable
);
  int i = `CH2;
    //$display("AXI enable: %d, i: %d, %t", enable, i, $time);
    @(posedge adc_clk[i])
      if (axi_adc_en[i] && axi_wrdy[i] && axi_wval[i] && enable) begin
        //$display("writing AXI file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS0);

        if(axi_strb[i*8+2])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS2);

        if(axi_strb[i*8+6])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS3);
      end
endtask: adc_monitor_ch2

task adc_monitor_ch3  (
  logic enable
);
  int i = `CH3;
    $display("AXI enable: %d, i: %d, %t", enable, i, $time);
    @(posedge adc_clk[i])
      if (axi_adc_en[i] && axi_wrdy[i] && axi_wval[i] && enable) begin
        $display("writing AXI file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS0);

        if(axi_strb[i*8+2])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS2);

        if(axi_strb[i*8+6])
          $fwrite(ADC_rfile[i], `XFORMAT, `XVALS3);
      end
endtask: adc_monitor_ch3

task gpio_monitor_in  (
  logic enable
);
  int i = `GPIO_IN;
    //$display("GPIO enable: %d, i: %d, %t", enable, i, $time);
    @(posedge adc_clk[i])
      if (axi_wrdy[i] && axi_wval[i] && enable) begin
        $display("writing GPIO file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(GPIO_rfile[i], `GIFORMAT, `GIVALS0);

        if(axi_strb[i*8+2])
          $fwrite(GPIO_rfile[i], `GIFORMAT, `GIVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(GPIO_rfile[i], `GIFORMAT, `GIVALS2);

        if(axi_strb[i*8+6])
          $fwrite(GPIO_rfile[i], `GIFORMAT, `GIVALS3);
      end
endtask: gpio_monitor_in
/*
task trig_monitor_adc (
  logic enable
);
  int i = ch0;
  @(posedge adc_clk)
  if ((adc_trig_r[2] ) && enable) begin
    TRG_rfile[i]=$fopen(TRG_names[i], "a");
    $fwrite(TRG_rfile[i], `TFORMATADC, `TVALSADC);  
    $display(`TFORMATADC, `TVALSADC);
    $fclose(TRG_rfile[i]);
  end
endtask: trig_monitor_adc
*/
task dac_monitor (
  logic enable
);
  @(posedge dac_clk)
    if (~dac_rst && enable && dac_val_sr0[6]) begin
      $fwrite(DAC_rfile[0], `DFORMAT, `DVALS);
    end
endtask: dac_monitor


task gpio_monitor_out (
  logic enable
);
  int i = `GPIO_OUT;
    @(posedge adc_clk[`GPIO])
    if (~adc_rst && enable && gpio_val_sr[0]) begin
      $fwrite(GPIO_rfile[i], `GOFORMAT, `GOVALS);
    end
endtask: gpio_monitor_out

endmodule: monitor_tcs_strm

