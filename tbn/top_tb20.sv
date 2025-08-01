////////////////////////////////////////////////////////////////////////////////
// Module: Red Pitaya top FPGA module
// Author: Iztok Jeras
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

`include "tb_defines.sv"

module top_tb #(

  `ifdef Z20_16
  parameter ADC_DW        = 16,
  parameter MNG           = 1,
  parameter TRIG_ACT_LVL  = 0,
  parameter NUM_ADC       = 2,
  parameter DWE           = 11,
  parameter CLKA_PER      = 8138,
  realtime  TP            = 8.138ns,  // 122.88 MHz
  `define   rp_top        red_pitaya_top_Z20
  `endif

  `ifdef Z20_14
  parameter ADC_DW        = 14,
  parameter MNG           = 1,
  parameter TRIG_ACT_LVL  = 0,
  parameter NUM_ADC       = 2,
  parameter DWE           = 11,
  parameter CLKA_PER      = 8000,
  realtime  TP            = 8.0ns,  // 125 MHz
  `define   rp_top        red_pitaya_top
  `endif

  `ifdef Z10_14
  parameter ADC_DW        = 14,
  parameter MNG           = 1,
  parameter TRIG_ACT_LVL  = 0,
  parameter NUM_ADC       = 2,
  parameter DWE           = 8,
  parameter CLKA_PER      = 8000,
  realtime  TP            = 8.0ns,  // 125 MHz
  `define   rp_top        red_pitaya_top
  `endif

  `ifdef Z20_4ADC
  parameter ADC_DW        = 12,
  parameter MNG           = 1,
  parameter TRIG_ACT_LVL  = 0,
  parameter NUM_ADC       = 4,
  parameter DWE           = 11,
  parameter CLKA_PER      = 8000,
  realtime  TP            = 8.0ns,  // 125 MHz
  `define   rp_top        red_pitaya_top_4ADC
  `endif

  `ifdef Z20_250
  parameter ADC_DW        = 14,
  parameter MNG           = 2,
  parameter TRIG_ACT_LVL  = 1,
  parameter NUM_ADC       = 2,
  parameter DWE           = 9,
  parameter CLKA_PER      = 4000,
  realtime  TP            = 4.0ns,  // 250 MHz
  `define   rp_top        red_pitaya_top
  `endif

  `ifdef Z20_G2
  parameter ADC_DW        = 14,
  parameter MNG           = 2,
  parameter TRIG_ACT_LVL  = 1,
  parameter NUM_ADC       = 2,
  parameter DWE           = 11,
  parameter CLKA_PER      = 8000,
  realtime  TP            = 8.0ns,  // 125 MHz
  `define   rp_top        red_pitaya_top
  `endif

  `ifdef Z20_LL
  parameter ADC_DW        = 14,
  parameter MNG           = 2,
  parameter TRIG_ACT_LVL  = 1,
  parameter NUM_ADC       = 2,
  parameter DWE           = 8,
  parameter CLKA_PER      = 8000,
  realtime  TP            = 8.0ns,  // 125 MHz
  realtime  ADC_TP        = 16.0ns, // 65 MHz
  `define   rp_top        red_pitaya_top
  `endif

  parameter N_SAMP        = 131072-1, // size of ADC buffer file

  parameter ADC_TRIG      = `AP_TRIG_ADC,   // which trigger source for ADC
  parameter DAC_TRIG      = `SW_TRIG_DAC,   // which trigger source for DAC
  parameter CYCLES        = 3,             // how many ADC cycles (triggers) are handled
  parameter DEC           = 32'h1,          // decimation
  parameter R_TRIG        =  1'b1,          // read and save trigger values
  parameter ADC_MODE      = `MODE_NORMAL,     // normal, axi0, axi1, fast
  parameter ACK_DELAY     = 500,            // delay in ack after interrupt (DMA streaming)
  parameter ARM_DELAY     = 200,           // delay in sending SW trigger after arming

  parameter MON_LEN       = 100000,         // how many samples are acquired before monitor file is closed
  parameter DAC_BUF_WRITE = 0,        // write the DAC buffer or not
  realtime  DEL           = 1.0ns,    // delay between clk0 and clk1
  realtime  RP            = 100.1ns,  // ~10MHz
  realtime  TP_250        = 4.0ns     // daisy clk 250 MHz
  // DUT configuration




);

////////////////////////////////////////////////////////////////////////////////
// IO port signals
////////////////////////////////////////////////////////////////////////////////

logic [4-1:0][16-1:0] adc_drv     ; 
logic [4-1:0][ 7-1:0] adc_drv_ddr ; 
logic [4-1:0][ 7-1:0] adc_drv_p   ; 
logic [4-1:0][ 7-1:0] adc_drv_n   ;

// ADC
logic [ 2-1:0] [ 2-1:0] adcll_dat1;
logic [ 2-1:0] [ 2-1:0] adcll_dat2;
logic          [ 2-1:0] adcll_fclk;
logic          [ 2-1:0] adcll_odclk;
logic          [ 2-1:0] adcll_idclk;

// DAC
logic [2-1:0][14-1:0] dac_dat;     // DAC combined data
logic                 dac_clk;     // DAC clock
logic                 dac_rst;     // DAC reset
logic [2-1:0]         dac_wrt;
logic                 dac_sel;
logic        [14-1:0] dac_cha;
logic        [14-1:0] dac_chb;

// PDM DAC
logic         [ 4-1:0] dac_pwm;     // 1-bit PDM DAC
// XADC
//logic         [ 5-1:0] vinp;        // voltages p
//logic         [ 5-1:0] vinn;        // voltages n
// Expansion connector
// wire          [ 9-1:0] exp_p_io;
// wire          [ 9-1:0] exp_n_io;
// wire                   exp_9_io;
// // Expansion output data/enable
// logic         [ 9-1:0] exp_p_od, exp_p_oe;
// logic         [ 9-1:0] exp_n_od, exp_n_oe;
// logic                  exp_9_od, exp_9_oe;

// SATA
//logic         [ 4-1:0] daisy_p;
//logic         [ 4-1:0] daisy_n;

// LED
wire          [ 8-1:0] led;
logic         [ 2-1:0] temp_prot;
logic                  pll_ref_hi;
logic                  pll_ref_lo;

logic                  intr;
logic                  clk0;
logic                  clk1;
logic                  clk_65;
logic                  clk_250 ;
reg                    trig_ext;
logic                  rstn;

wire [ 1:0] clko;

wire  [DWE-1:0] gpio_p;
wire  [DWE-1:0] gpio_n;
wire            gpio_9;
logic [DWE-1:0] gpio_p_drv;
logic [DWE-1:0] gpio_n_drv;
logic [DWE-1:0] gpio_p_dir;
logic [DWE-1:0] gpio_n_dir;
logic           gpio_9_drv;
logic [DWE-1:0] gpio_p_driver;
logic [DWE-1:0] gpio_n_driver;
logic           gpio_9_driver;
wire  [DWE-1:0] gpio_p_rec;
wire  [DWE-1:0] gpio_n_rec;
wire            gpio_9_rec;

logic [32-1:0 ] ext_trig_cnt;

logic           d_clko_p ;
logic           d_clko_n ;
logic           d_trigo_p;
logic           d_trigo_n;
logic           d_clki_p ;
logic           d_clki_n ;
logic           d_trigi_p;
logic           d_trigi_n;

logic           e3_clko_p ;
logic           e3_clko_n ;
logic [  3-1:0] e3_dato_p ;
logic [  3-1:0] e3_dato_n ;
logic           e3_clki_p ;
logic           e3_clki_n ;
logic [  3-1:0] e3_dati_p ;
logic [  3-1:0] e3_dati_n ;

logic           s1_link ;
logic           s1_orient ;

////////////////////////////////////////////////////////////////////////////////
// Clock and reset generation
////////////////////////////////////////////////////////////////////////////////

initial #3.6ns clk0 = 1'b0;
always #(TP/2) clk0 = ~clk0;

initial #3.6ns clk_65 = 1'b0;
always #(ADC_TP/2)   clk_65 = ~clk_65;

initial            clk_250 = 1'b0;
always #(TP_250/2) clk_250 = ~clk_250;

always clk1 = #DEL clk0;

//--------------------------------------------------------------------------------------------

// default clocking 
default clocking cb @ (posedge clk0);
  input  rstn;
  //input  exp_p_od, exp_p_oe;
  //input  exp_n_od, exp_n_oe;
endclocking: cb

// reset
initial begin
        rstn = 1'b0;
  ##4;  rstn = 1'b1;
end

/*initial begin
  top_tb.red_pitaya_top.rstn_in = 1'b0;
  ##40; top_tb.red_pitaya_top.rstn_in = 1'b1;
end
*/
initial begin
  gpio_p_driver = {DWE{1'bz}};
  gpio_n_driver = {DWE{1'bz}};
  gpio_9_driver =      1'bz  ;
  trig_ext      = ~`TRIG_ACT_LVL;
  ext_trig_cnt  = 32'h0;
end
`ifdef Z10_14
initial begin
    $display("Testing Z10_14!");
end
`endif
////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

wire adc_rstn;
`ifndef Z20_4ADC
assign adc_rstn = red_pitaya_top.adc_rstn;
`else
assign adc_rstn = red_pitaya_top.adc_rstn_01;
`endif

int BASE =  `BASE_OFS;
int ADR, ADR2, ADR3;
initial begin
  ##500;
   // top_tc.daisy_trigs();
   //top_tc.test_hk                 (32'h40000000, 32'h0);
   //top_tc.test_sata               (5<<20, 32'h55);

  do begin
    repeat(1000) @(posedge clk0);
  end while (adc_rstn != 1'b1);
  #1000;
   //top_tc.test_asg                (32'h40200000, 32'h0, 2);
  fork
`ifdef STREAMING
    $display("Testing streaming!");
    //ADR = 32'h40000000 + (`STRM_SCOPE_REG_OFS << `OFS_SHIFT);
    ADR = 32'h40000000 + (`STRM_ASG_REG_OFS   << `OFS_SHIFT);

    monitor_tcs_strm.set_monitor(MON_LEN);
    begin
      //top_tc20_strm.scope_test(ADR, CYCLES, ACK_DELAY);
      top_tc20_strm.test_dac(ADR, CYCLES, ACK_DELAY);
      //top_tc20_strm.test_gpio(ADR, CYCLES, ACK_DELAY);

    end    
`else

  `ifdef LOGIC
    $display("Testing Logic Analyzer!");
    top_tc20.test_la (32'h40300000);
    top_tc20.test_la_automatic (32'h40300000);
  `else
    $display("Testing normal acq mode!");

    ADR  = `BASE_OFS + `SCOPE1_REG_OFS << `OFS_SHIFT;
    ADR2 = `BASE_OFS + `SCOPE2_REG_OFS << `OFS_SHIFT;
    ADR3 = `BASE_OFS + `EXP_E3_REG_OFS << `OFS_SHIFT;
    monitor_tcs_094.set_monitor(MON_LEN);
    begin
      //top_tc20.daisy_trigs();
      //top_tc20.init_adc_02(ADR);
      //top_tc20.init_dac(ADR2, DAC_BUF_WRITE);
      //top_tc20.test_sata(ADR3);

       //top_tc20.init_adc_23(ADR2);     
      //top_tc20.test_osc(ADR,  ADC_TRIG, CYCLES, DEC, ARM_DELAY, R_TRIG, ADC_MODE);
       //top_tc20.test_osc(ADR2, ADC_TRIG, CYCLES, DEC, ARM_DELAY, R_TRIG, ADC_MODE);
      //top_tc20.test_osc_common(ADR,  ADC_TRIG, CYCLES, DEC, ARM_DELAY, R_TRIG, ADC_MODE);
      // top_tc20.test_osc_common(ADR2, ADC_TRIG, CYCLES, DEC, ARM_DELAY, R_TRIG, ADC_MODE);
      //top_tc20.custom_test(ADR2, ADR);
      top_tc20.custom_adcconf(ADR);
      //top_tc20.custom_adcconf(ADR2);

      //#1000;
      //top_tc20.test_dac2(ADR2);
    end
    `endif
`endif

  join
   //top_tc.test_osc                (32'h40200000, OSC1_EVENT);


  ##1600000000;
  $finish();
end

// wire [4-1:0] trg_01 = top_tb.red_pitaya_top.i_scope_0_1.adc_trig;
// wire [4-1:0] trg_23 = top_tb.red_pitaya_top.i_scope_2_3.adc_trig;
// wire [4-1:0] trg_xord;
// assign trg_xord = trg_01 ^ trg_23;

////////////////////////////////////////////////////////////////////////////////
// signal generation
////////////////////////////////////////////////////////////////////////////////

always begin
  temp_prot <= 2'b00;
  ##50000;
  temp_prot <= 2'b10;
  ##1000;
  temp_prot <= 2'b00;
end


reg signed [13:0] cnter1;
reg signed [13:0] cnter2;
reg signed [13:0] cnter3;
reg signed [13:0] cnter4;

always @(clk0) begin
    if (rstn==0)
        cnter1 <= -1000;
    else if (cnter1>=1000 && clk0==1)
        cnter1 <= -1000;
    else if (clk0 == 1)
        cnter1 <= cnter1 + 1; 


    if (rstn==0)
        cnter2 <= -500;
    else if (cnter2>=1000 && clk0==1)
        cnter2 <= -1000;
    else if (clk0 == 1)
        cnter2 <= cnter2 + 1; 
end

always @(clk1) begin
    if (rstn==0)
        cnter3 <= 1000;
    else if (cnter3>=1000 && clk1==1)
        cnter3 <= -1000;
    else if (clk1 == 1)
        cnter3 <= cnter3 + 1; 


    if (rstn==0)
        cnter4 <= 500;
    else if (cnter4>=1000 && clk1==1)
        cnter4 <= -1000;
    else if (clk1 == 1)
        cnter4 <= cnter4 + 1; 
end


reg [15:0] trigcnt;
reg  trigr;

always @(clk0) begin

    if (rstn==0)
        trigcnt <= 16'b0;
    else if (trigcnt==16'd25000 && clk0==1) begin //200 us 
        trigcnt <= 13'b0;
        trigr <= 1'b1;
    end else if (clk0 == 1) begin
        trigcnt <= trigcnt + 13'b1; 
        trigr <= 1'b0;
    end
end

adc_driver #(
  .N_SAMP (N_SAMP),
  .FILERD (`FILERD),
  .SINE   (`SINE),
  .DW     (ADC_DW)
) 
tb_adc_drv
(
 `ifdef Z20_LL
   .adc_clk_i    ({clk_65,clk_65}),
 `else
   .adc_clk_i    ({clk1,clk0}),
 `endif
   .adc_rstn_i   ({rstn,rstn}),
   .adc_data_in0 (cnter1     ),
   .adc_data_in1 (cnter2     ),
   .adc_data_in2 (cnter3     ),
   .adc_data_in3 (cnter4     ),

   .adcll_dclk_i (adcll_idclk),
   .adcll_fclk_o (adcll_fclk ),
   .adcll_data_o (adcll_dat1 ),
   .adcll_datb_o (adcll_dat2 ),
   .adcll_dclk_o (adcll_odclk),

   .adc_drv_o     (adc_drv    ), 
   .adc_drv_ddr_o (adc_drv_ddr), 
   .adc_drv_p_o   (adc_drv_p  ), 
   .adc_drv_n_o   (adc_drv_n  )
);

dac_driver #(

) 
tb_dac_drv
(
  .adc_clk_i (clk0    ),
  .dac_dat_i (dac_dat ),
  .dac_wrt_i (dac_wrt ),
  .dac_sel_i (dac_sel ),
  .dac_clk_i (dac_clk ),
  .dac_rst_i (dac_rst ),

  .dac_a_o   (dac_cha ), 
  .dac_b_o   (dac_chb )
);

`ifndef STREAMING
  `ifdef LOGIC
assign gpio_p_dir =  8'h0;
assign gpio_n_dir =  8'h0;
  `else
assign gpio_p_dir =  top_tb.red_pitaya_top.exp_p_dtr;
assign gpio_n_dir =  top_tb.red_pitaya_top.exp_n_dtr;
  `endif
`endif

always @(posedge clk0) begin
  gpio_p_driver[7:6] <= gpio_n_rec[7:6];
end

// always @(posedge clk0) begin //
//   if (ext_trig_cnt < 15000) begin
//     ext_trig_cnt <= ext_trig_cnt + 1;
//   end else begin
//     ext_trig_cnt <= 32'h0;
//   end
//   if (ext_trig_cnt > 14900 && ext_trig_cnt < 15000) begin
//     trig_ext <= 1'b1;
//   end else begin
//     trig_ext <= 1'b0;
//   end
// end

initial
begin:trig_gen
  forever
  begin
    #((10000 + ({$random} % 100)) / 2) trig_ext = 1'b1 ;
    #100                               trig_ext = 1'b0 ;
  end
end




assign gpio_p_drv = {gpio_p_driver[DWE-1:1], trig_ext};
assign gpio_n_drv =  gpio_n_driver;
assign gpio_9_drv =  gpio_9_driver;

assign gpio_p = gpio_p_drv;
assign gpio_n = gpio_n_drv;
assign gpio_9 = gpio_9_drv;

assign gpio_p_rec = gpio_p;
assign gpio_n_rec = gpio_n;
assign gpio_9_rec = gpio_9;

IOBUF i_iobufp [DWE-1:0] (.O(gpio_p_rec), .IO(gpio_p), .I(gpio_p_drv), .T(gpio_p_dir) );
IOBUF i_iobufn [DWE-1:0] (.O(gpio_n_rec), .IO(gpio_n), .I(gpio_n_drv), .T(gpio_n_dir) );

wire adc_clk0, adc_clk1;
wire daisy_250;

wire [ 2-1:0] inclk0 = {~adc_clk0,adc_clk0};
wire [ 2-1:0] inclk1 = {~adc_clk1,adc_clk1};

wire pll_in_clk  = `MASTER  ?  clk0     : clko[0] & ~clko[1];
wire daisy_clk   = `MASTER  ?  1'b0     : daisy_250;

wire daisy_clkin = `LOCALM  ?  clk_250  : d_clko_p  && ~d_clko_n;
wire daisy_trig  = `LOCALM  ? ~trig_ext : d_trigo_p && ~d_trigo_n;

logic [NUM_ADC-1:0] strm_adc_en;
logic [      2-1:0] strm_dac_en;

`ifdef STREAMING
assign strm_adc_en = top_tb.monitor_tcs_strm.axi_adc_en;
//assign strm_dac_en = top_tb.monitor_tcs_strm.axi_dac_en;
`else
assign strm_adc_en = {NUM_ADC{1'b0}};
//assign strm_dac_en =          2'h0  ;
`endif


clk_gen #(
  .CLKA_PERIOD  (  CLKA_PER ),
  .CLKA_JIT     (  10     ),
  .DEL          (  15     ) // in percent
)
i_clgen_model
(
  .clk_i  ( pll_in_clk ) ,
  //.clk_o  ( adc_clk0   )
  .clka_o  ( adc_clk0   )
);

clk_gen #(
  .CLKA_PERIOD  (  CLKA_PER   ),
  .CLKA_JIT     (  0      ),
  .DEL          (  25      ) // in percent
)
i_clgen_model2
(
  .clk_i  ( clk1 ) ,
  .clk_o  ( adc_clk1    )
);

clk_gen #(
  .CLKA_PERIOD  (  4000   ),
  .CLKA_JIT     (  5      ),
  .DEL          (  1      ) // in percent
)
i_clgen_model3
(
  .clk_i  ( daisy_clkin ) ,
  .clk_o  ( daisy_250   )
);

assign d_clki_p  =  daisy_clk;
assign d_clki_n  = ~daisy_clk;
assign d_trigi_p =  daisy_trig;
assign d_trigi_n = ~daisy_trig;

integer E3DEL = 100 ;
always @ * begin
  e3_clki_p <= #E3DEL e3_clko_p;
  e3_clki_n <= #E3DEL e3_clko_n;
  e3_dati_p <= #E3DEL e3_dato_p;
  e3_dati_n <= #E3DEL e3_dato_n;
  s1_link   <= 1'b0;
  s1_orient <= 1'b0;
end
////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

`rp_top
#() 
red_pitaya_top
(
  .daisy_p_o    ({d_clko_p,d_trigo_p}),
  .daisy_n_o    ({d_clko_n,d_trigo_n}),
  .daisy_p_i    ({d_clki_p,d_trigi_p}),
  .daisy_n_i    ({d_clki_n,d_trigi_n}),
  // PWM DAC
  .dac_pwm_o    (dac_pwm),  // 1-bit PWM DAC
  // Expansion connector
  .exp_p_io     (gpio_p),
  .exp_n_io     (gpio_n),
  // SATA connector
  `ifdef Z20_4ADC
  .adc_dat_i    (adc_drv_ddr),
  .adc_clk_i    ({inclk1, inclk0}),   
  .pll_hi_o     (pll_ref_hi),     
  .pll_lo_o     (pll_ref_lo),  
  `elsif Z20_250
  .adc_dat_p_i  (adc_drv_p[2-1:0]),
  .adc_dat_n_i  (adc_drv_n[2-1:0]),
  .adc_clk_i    (inclk0),   
  .pll_hi_o     (pll_ref_hi),     
  .pll_lo_o     (pll_ref_lo),  
  .dac_dat_o    (dac_dat),
  .dac_reset_o  (dac_rst),
  .exp_9_io     (gpio_9),
  `elsif Z20_LL
  // ADC
  .adc_dclk_i  (adcll_odclk ),  // ADC data clock {p,n}
  .adc_fclk_i  (adcll_fclk  ),  // ADC frame clock {p,n}
  .adc_data_i  (adcll_dat1  ),  // ADC data {p,n}
  .adc_datb_i  (adcll_dat2  ),  // ADC data {p,n}
  .adc_dclk_o  (adcll_idclk ),  // ADC data clock {p,n}
  .adc_rst_o   (),   // ADC reset
  .adc_pdn_o   (),   // ADC power down
  .adc_sen_o   (),   // ADC serial en
  .adc_sclk_o  (),  // ADC serial clock
  .adc_sdio_io (), // ADC serial data

  // DAC
  .dac_clk_i   (inclk0),  // DAC clock
  // channels A and B are inverted in hardware
  .dac_data_o  (dac_dat[1]),  // DAC data cha
  .dac_datb_o  (dac_dat[0]),  // DAC data chb
  .dac_wrta_o  (dac_wrt[1]),  // DAC write cha
  .dac_wrtb_o  (dac_wrt[0]),  // DAC write chab
  `else        
  .dac_dat_o    (dac_dat[0]),
  .dac_wrt_o    (dac_wrt),
  .dac_sel_o    (dac_sel),
  .dac_clk_o    (dac_clk),
  .dac_rst_o    (dac_rst),

  .adc_dat_i    (adc_drv[NUM_ADC-1:0]),
  .adc_clk_i    (inclk0),
  .adc_clk_o    (clko),
  `endif

  `ifdef Z20_G2
  .exp_e3p_o    ({e3_clko_p,e3_dato_p}),
  .exp_e3n_o    ({e3_clko_n,e3_dato_n}),
  .exp_e3p_i    ({e3_clki_p,e3_dati_p}),
  .exp_e3n_i    ({e3_clki_n,e3_dati_n}),
  .s1_link_i    (s1_link),
  .s1_orient_i  (s1_orient),
  `endif
  // LED
  .led_o(led));


// testcases


`ifdef STREAMING
top_tc20_strm top_tc20_strm();
monitor_tcs_strm monitor_tcs_strm();
`else
  `ifdef LOGIC
  top_tc20 top_tc20();
  `else
  monitor_tcs_094 monitor_tcs_094();
  top_tc20 top_tc20();
  `endif
`endif

////////////////////////////////////////////////////////////////////////////////
// waveforms
////////////////////////////////////////////////////////////////////////////////


endmodule: top_tb
