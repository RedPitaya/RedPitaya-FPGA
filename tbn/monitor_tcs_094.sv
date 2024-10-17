`include "tb_defines.sv"

module monitor_tcs_094 #(



`ifdef Z20_4ADC
parameter NUM_ADC      = 4,
`else
parameter NUM_ADC      = 2,
`endif
parameter NUM_DAC      = 2
);

wire  [4*12-1:0] axi_wr_adr =  {top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp3.axi_awaddr_i[12-1:0],
                                top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp2.axi_awaddr_i[12-1:0],
                                top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp1.axi_awaddr_i[12-1:0],
                                top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp0.axi_awaddr_i[12-1:0]};

wire  [  64-1:0] axi_wdat [3:0] = {top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp3.axi_wdata_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp2.axi_wdata_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp1.axi_wdata_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp0.axi_wdata_i};

wire  [4*8 -1:0] axi_strb  = {top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp3.axi_wstrb_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp2.axi_wstrb_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp1.axi_wstrb_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp0.axi_wstrb_i};

wire  [4*1 -1:0] axi_wrdy  = {top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp3.axi_wready_o,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp2.axi_wready_o,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp1.axi_wready_o,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp0.axi_wready_o};

wire  [4*1 -1:0] axi_wval  = {top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp3.axi_wvalid_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp2.axi_wvalid_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp1.axi_wvalid_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp0.axi_wvalid_i};

wire  [4*1 -1:0] axi_awrdy = {top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp3.axi_awready_o,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp2.axi_awready_o,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp1.axi_awready_o,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp0.axi_awready_o};

wire  [4*1 -1:0] axi_awval = {top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp3.axi_awvalid_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp2.axi_awvalid_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp1.axi_awvalid_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp0.axi_awvalid_i};

wire  [4*1 -1:0] axi_clk   = {top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp3.axi_clk_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp2.axi_clk_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp1.axi_clk_i,
                              top_tb.red_pitaya_top.ps.system_i.i_s_axi_hp0.axi_clk_i};

`ifdef Z20_4ADC
/*
wire  [  14-1:0] adc_adr [3:0] = {top_tb.red_pitaya_top.i_scope_2_3.adc_wp[14-1:0],
                              top_tb.red_pitaya_top.i_scope_2_3.adc_wp[14-1:0],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_wp[14-1:0],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_wp[14-1:0]};

wire  [  12-1:0] adc_datr [3:0] = {top_tb.red_pitaya_top.i_scope_2_3.adc_b_bram_in,
                              top_tb.red_pitaya_top.i_scope_2_3.adc_a_bram_in,
                              top_tb.red_pitaya_top.i_scope_0_1.adc_b_bram_in,
                              top_tb.red_pitaya_top.i_scope_0_1.adc_a_bram_in};

wire  [4*1 -1:0] adc_we    = {top_tb.red_pitaya_top.i_scope_2_3.adc_we,
                              top_tb.red_pitaya_top.i_scope_2_3.adc_we,
                              top_tb.red_pitaya_top.i_scope_0_1.adc_we,
                              top_tb.red_pitaya_top.i_scope_0_1.adc_we};

wire  [4*1 -1:0] adc_dv    = {top_tb.red_pitaya_top.i_scope_2_3.adc_dv_del,
                              top_tb.red_pitaya_top.i_scope_2_3.adc_dv_del,
                              top_tb.red_pitaya_top.i_scope_0_1.adc_dv_del,
                              top_tb.red_pitaya_top.i_scope_0_1.adc_dv_del};

wire  [4*1 -1:0] adc_clk   = {top_tb.red_pitaya_top.i_scope_2_3.adc_clk_i,
                              top_tb.red_pitaya_top.i_scope_2_3.adc_clk_i,
                              top_tb.red_pitaya_top.i_scope_0_1.adc_clk_i,
                              top_tb.red_pitaya_top.i_scope_0_1.adc_clk_i};

wire [ 4-1:0]  trig_src  = top_tb.red_pitaya_top.i_scope_0_1.set_trig_src;
wire           adc_trig  = top_tb.red_pitaya_top.i_scope_0_1.adc_trig;
wire           axi_trig  = top_tb.red_pitaya_top.i_scope_0_1.axi_a_trig;
wire [32-1:0]  axi_triga = top_tb.red_pitaya_top.i_scope_0_1.set_a_axi_trig;
wire [14-1:0]  adc_triga = top_tb.red_pitaya_top.i_scope_0_1.adc_wp_trig[14-1:0];
wire [14-1:0]  trig_lvl  = top_tb.red_pitaya_top.i_scope_0_1.set_a_tresh;
*/

wire  [  14-1:0] adc_adr [3:0] = {top_tb.red_pitaya_top.i_scope_2_3.adc_wp_act[28-1:14],
                              top_tb.red_pitaya_top.i_scope_2_3.adc_wp_act[14-1: 0],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_wp_act[28-1:14],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_wp_act[14-1: 0]};

wire  [  14-1:0] adc_datr [3:0] = {top_tb.red_pitaya_top.i_scope_2_3.adc_bram_in[28-1:14],
                              top_tb.red_pitaya_top.i_scope_2_3.adc_bram_in[14-1: 0],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_bram_in[28-1:14],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_bram_in[14-1: 0]};

wire  [4*1 -1:0] adc_we    = {top_tb.red_pitaya_top.i_scope_2_3.adc_we[1],
                              top_tb.red_pitaya_top.i_scope_2_3.adc_we[0],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_we[1],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_we[0]};

wire  [4*1 -1:0] adc_dv    = {top_tb.red_pitaya_top.i_scope_2_3.adc_dv_del[1],
                              top_tb.red_pitaya_top.i_scope_2_3.adc_dv_del[0],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_dv_del[1],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_dv_del[0]};

wire  [4*1 -1:0] adc_clk   = {top_tb.red_pitaya_top.i_scope_2_3.adc_clk_i[1],
                              top_tb.red_pitaya_top.i_scope_2_3.adc_clk_i[0],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_clk_i[1],
                              top_tb.red_pitaya_top.i_scope_0_1.adc_clk_i[0]};

wire [ 4-1:0]  trig_src  = top_tb.red_pitaya_top.i_scope_0_1.trg_state[3:0];
wire           adc_trig  = top_tb.red_pitaya_top.i_scope_0_1.adc_trig[0];
wire           axi_trig  = top_tb.red_pitaya_top.i_scope_0_1.axi_trig[0];
wire [32-1:0]  axi_triga = top_tb.red_pitaya_top.i_scope_0_1.axi_wp_trig[32-1:0];
wire [14-1:0]  adc_triga = top_tb.red_pitaya_top.i_scope_0_1.adc_wp_trig[14-1:0];
wire [14-1:0]  trig_lvl  = top_tb.red_pitaya_top.i_scope_0_1.set_tresh[14-1:0];

`else
wire  [  14-1:0] adc_adr [1:0] = {top_tb.red_pitaya_top.i_scope.adc_wp[14-1:0],
                                  top_tb.red_pitaya_top.i_scope.adc_wp[14-1:0]};

wire  [  14-1:0] adc_datr [1:0] = {top_tb.red_pitaya_top.i_scope.adc_b_bram_in,
                                   top_tb.red_pitaya_top.i_scope.adc_a_bram_in};

wire  [2*1 -1:0] adc_we    = {top_tb.red_pitaya_top.i_scope.adc_we,
                              top_tb.red_pitaya_top.i_scope.adc_we};

wire  [2*1 -1:0] adc_dv    = {top_tb.red_pitaya_top.i_scope.adc_dv_del,
                              top_tb.red_pitaya_top.i_scope.adc_dv_del};

wire  [2*1 -1:0] adc_clk   = {top_tb.red_pitaya_top.i_scope.adc_clk_i,
                              top_tb.red_pitaya_top.i_scope.adc_clk_i};

wire [ 4-1:0]  trig_src  = top_tb.red_pitaya_top.i_scope.set_trig_src;
wire [32-1:0]  axi_triga = top_tb.red_pitaya_top.i_scope.set_a_axi_trig;
wire [14-1:0]  adc_triga = top_tb.red_pitaya_top.i_scope.adc_wp_trig[14-1:0];
wire [14-1:0]  trig_lvl  = top_tb.red_pitaya_top.i_scope.set_a_tresh;
wire           adc_trig  = top_tb.red_pitaya_top.i_scope.adc_trig;
wire           axi_trig  = top_tb.red_pitaya_top.i_scope.axi_a_trig;

`endif

wire             dac_rst   =  top_tb.dac_rst;
wire  [  14-1:0] dac_cha   =  top_tb.dac_cha;
wire  [  14-1:0] dac_chb   =  top_tb.dac_chb;

logic          adc_wer;
logic [ 4-1:0] adc_we_cnt = 4'h0;
logic [ 4-1:0] adc_trig_r;
logic [ 4-1:0] axi_trig_r;
logic [ 4-1:0] trig_src_r;
logic [32-1:0] write_cntAXI [3:0] = {32'h1, 32'h1, 32'h1, 32'h1};
logic [32-1:0] write_cntADC [3:0] = {32'h1, 32'h1, 32'h1, 32'h1};
logic [12-1:0] axi_wr_adr_r    [3:0];

const int ch0 = 0;
const int ch1 = 1;
const int ch2 = 2;
const int ch3 = 3;

always @(posedge adc_clk[0]) begin
  adc_trig_r <= {adc_trig_r[2:0],adc_trig};
  adc_wer    <= adc_we[0];
end

always @(posedge axi_clk[0]) begin
  axi_trig_r <= {axi_trig_r[2:0],axi_trig};
  if (adc_trig)
    trig_src_r <= trig_src;
end

genvar GV;
generate
for (GV=0; GV<NUM_ADC; GV++) begin
  always @(posedge adc_clk[GV]) begin
    if (adc_we[GV] && adc_dv[GV]) begin
      write_cntADC[GV] <= write_cntADC[GV] + 1;
    end
  end

  always @(posedge axi_clk[GV]) begin  
    if (axi_wrdy[GV] && axi_wval[GV]) begin
      case (axi_strb[(GV+1)*8-1:GV*8])
        8'h03: write_cntAXI[GV] <= write_cntAXI[GV] + 1;
        8'h0F: write_cntAXI[GV] <= write_cntAXI[GV] + 2;
        8'h3F: write_cntAXI[GV] <= write_cntAXI[GV] + 3;
        8'hFF: write_cntAXI[GV] <= write_cntAXI[GV] + 4;
      endcase
    end

    if (axi_awrdy[GV] && axi_awval[GV])
      axi_wr_adr_r[GV] <= axi_wr_adr[(GV+1)*12-1:GV*12];
  end
end
endgenerate
int AXI_rfile [NUM_ADC-1:0];
int ADC_rfile [NUM_ADC-1:0];
int TRG_rfile [NUM_ADC-1:0];
int DAC_rfile [NUM_DAC-1:0];

string AXI_names [3:0] = {"../../../../resultfileAXI3.txt", 
                          "../../../../resultfileAXI2.txt", 
                          "../../../../resultfileAXI1.txt", 
                          "../../../../resultfileAXI0.txt"};

string ADC_names [3:0] = {"../../../../resultfileADC3.txt", 
                          "../../../../resultfileADC2.txt", 
                          "../../../../resultfileADC1.txt", 
                          "../../../../resultfileADC0.txt"};

string TRG_names [3:0] = {"../../../../resultfileTRG3.txt", 
                          "../../../../resultfileTRG2.txt", 
                          "../../../../resultfileTRG1.txt", 
                          "../../../../resultfileTRG0.txt"};

string DAC_names [3:0] = {"../../../../resultfileDAC3.txt", 
                          "../../../../resultfileDAC2.txt", 
                          "../../../../resultfileDAC1.txt", 
                          "../../../../resultfileDAC0.txt"};

initial begin 
  for (int i=0; i<NUM_ADC; i++) begin
  AXI_rfile[i]=$fopen(AXI_names[i], "w");
  ADC_rfile[i]=$fopen(ADC_names[i], "w");
  end

  for (int i=0; i<NUM_DAC; i++) begin
  DAC_rfile[i]=$fopen(DAC_names[i], "w");
  end


end

task set_monitor (
  int   mon_len
);
  int cnt = 32'h0;
  do begin
    fork
      axi_monitor(`AXI_MON);
      adc_monitor(`ADC_MON);
      dac_monitor(`DAC_MON);
    join
    cnt <= cnt + 1;
  end while (cnt < mon_len);
  for (int i=0; i<NUM_ADC; i++) begin
  $fclose(AXI_rfile[i]);
  $fclose(ADC_rfile[i]);
  end

  for (int i=0; i<NUM_DAC; i++) begin
  $fclose(DAC_rfile[i]);
  end

endtask: set_monitor

task automatic axi_monitor  (
  logic enable
);
    fork
      if (ch0 < NUM_ADC)
        axi_monitor_ch0(enable);

      if (ch1 < NUM_ADC)
        axi_monitor_ch1(enable);

      if (ch2 < NUM_ADC)
        axi_monitor_ch2(enable);

      if (ch3 < NUM_ADC)
        axi_monitor_ch3(enable);

      trig_monitor_axi(enable);
    join  
endtask: axi_monitor

task axi_monitor_ch0  (
  logic enable
);
  int i = ch0;
    //$display("AXI enable: %d, i: %d, %t", enable, i, $time);
    @(posedge axi_clk[i])
      if (axi_wrdy[i] && axi_wval[i] && enable) begin
        //$display("writing AXI file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS0);

        if(axi_strb[i*8+2])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS2);

        if(axi_strb[i*8+6])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS3);
      end
endtask: axi_monitor_ch0

task axi_monitor_ch1  (
  logic enable
);
  int i = ch1;
    //$display("AXI enable: %d, i: %d, %t", enable, i, $time);
    @(posedge axi_clk[i])
      if (axi_wrdy[i] && axi_wval[i] && enable) begin
        //$display("writing AXI file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS0);

        if(axi_strb[i*8+2])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS2);

        if(axi_strb[i*8+6])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS3);
      end
endtask: axi_monitor_ch1

task axi_monitor_ch2  (
  logic enable
);
  int i = ch2;
    //$display("AXI enable: %d, i: %d, %t", enable, i, $time);
    @(posedge axi_clk[i])
      if (axi_wrdy[i] && axi_wval[i] && enable) begin
        //$display("writing AXI file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS0);

        if(axi_strb[i*8+2])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS2);

        if(axi_strb[i*8+6])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS3);
      end
endtask: axi_monitor_ch2

task axi_monitor_ch3  (
  logic enable
);
  int i = ch3;
    //$display("AXI enable: %d, i: %d, %t", enable, i, $time);
    @(posedge axi_clk[i])
      if (axi_wrdy[i] && axi_wval[i] && enable) begin
       // $display("writing AXI file %d,%t",i,$time);
        if(axi_strb[i*8+0])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS0);

        if(axi_strb[i*8+2])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS1);
          
        if(axi_strb[i*8+4])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS2);

        if(axi_strb[i*8+6])
          $fwrite(AXI_rfile[i], `XFORMAT, `XVALS3);
      end
endtask: axi_monitor_ch3

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

      trig_monitor_adc(enable);
    join  
endtask: adc_monitor

task adc_monitor_ch0 (
  logic enable
);
  int i = ch0;
  if (adc_we[i] && adc_dv[i] && enable) begin
    $fwrite(ADC_rfile[i], `AFORMAT, `AVALS);
    //$display("writing ADC file %d,%t",i,$time);
  end
endtask: adc_monitor_ch0


task adc_monitor_ch1 (
  logic enable
);
  int i = ch1;
  if (adc_we[i] && adc_dv[i] && enable) begin
    $fwrite(ADC_rfile[i], `AFORMAT, `AVALS);
    //$display("writing ADC file %d,%t",i,$time);
  end
endtask: adc_monitor_ch1

task adc_monitor_ch2 (
  logic enable
);
  int i = ch2;
  if (adc_we[i] && adc_dv[i] && enable) begin
    $fwrite(ADC_rfile[i], `AFORMAT, `AVALS);
    //$display("writing ADC file %d,%t",i,$time);
  end
endtask: adc_monitor_ch2


task adc_monitor_ch3 (
  logic enable
);
  int i = ch3;
  if (adc_we[i] && adc_dv[i] && enable) begin
    $fwrite(ADC_rfile[i], `AFORMAT, `AVALS);
    //$display("writing ADC file %d,%t",i,$time);
  end
endtask: adc_monitor_ch3

task trig_monitor_axi (
  logic enable
);
  int i = ch0;
  @(posedge axi_clk[i])
  if (axi_trig_r[2] || axi_trig_r[3] && enable) begin
    TRG_rfile[i]=$fopen(TRG_names[i], "a");
    $fwrite(TRG_rfile[i], `TFORMATAXI, `TVALSAXI);
    $display(`TFORMATAXI, `TVALSAXI);
    $fclose(TRG_rfile[i]);
  end
endtask: trig_monitor_axi

task trig_monitor_adc (
  logic enable
);
  int i = ch0;
  @(posedge adc_clk[i])
  if ((adc_trig_r[2] ) && enable) begin
    TRG_rfile[i]=$fopen(TRG_names[i], "a");
    $fwrite(TRG_rfile[i], `TFORMATADC, `TVALSADC);  
    $display(`TFORMATADC, `TVALSADC);
    $fclose(TRG_rfile[i]);
  end
endtask: trig_monitor_adc

task dac_monitor (
  logic enable
);
  @(posedge adc_clk[0])
    if (~dac_rst && enable) begin
      $fwrite(DAC_rfile[0], `DFORMAT, `DVALS);
    end
endtask: dac_monitor

endmodule: monitor_tcs_094

