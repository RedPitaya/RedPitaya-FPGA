////////////////////////////////////////////////////////////////////////////////
// Module: Red Pitaya top FPGA module
// Author: Iztok Jeras
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module top_tb #(
  // time period
  realtime  TP = 4.0ns,  // 250MHz
  realtime  RP = 100.1ns,  // ~10MHz
  // DUT configuration
  int unsigned DAC_DW = 14, // ADC data width
  int unsigned RSZ = 14  // RAM size is 2**RSZ
);

////////////////////////////////////////////////////////////////////////////////
// IO port signals
////////////////////////////////////////////////////////////////////////////////

// PS connections
wire  [54-1:0] FIXED_IO_mio     ;
wire           FIXED_IO_ps_clk  ;
wire           FIXED_IO_ps_porb ;
wire           FIXED_IO_ps_srstb;
wire           FIXED_IO_ddr_vrn ;
wire           FIXED_IO_ddr_vrp ;
// DDR
wire  [15-1:0] DDR_addr   ;
wire  [ 3-1:0] DDR_ba     ;
wire           DDR_cas_n  ;
wire           DDR_ck_n   ;
wire           DDR_ck_p   ;
wire           DDR_cke    ;
wire           DDR_cs_n   ;
wire  [ 4-1:0] DDR_dm     ;
wire  [32-1:0] DDR_dq     ;
wire  [ 4-1:0] DDR_dqs_n  ;
wire  [ 4-1:0] DDR_dqs_p  ;
wire           DDR_odt    ;
wire           DDR_ras_n  ;
wire           DDR_reset_n;
wire           DDR_we_n   ;

// ADC
logic         [ 2-1:0] adc_dat1;
logic         [ 2-1:0] adc_dat2;
logic                  adc_fr;
logic         [ 2-1:0] adc_odclk;
logic         [ 2-1:0] adc_idclk;

// DAC
logic [2-1:0] [14-1:0] dac_dat;     // DAC combined data
logic         [ 2-1:0] dac_wrt;     // DAC write
logic                  dac_clk;     // DAC clock

// PDM DAC
logic         [ 4-1:0] dac_pwm;     // 1-bit PDM DAC
// XADC
logic         [ 5-1:0] vinp;        // voltages p
logic         [ 5-1:0] vinn;        // voltages n
// Expansion connector
wire          [ 8-1:0] exp_p_io;
wire          [ 8-1:0] exp_n_io;
// Expansion output data/enable
logic         [ 8-1:0] exp_p_od, exp_p_oe;
logic         [ 8-1:0] exp_n_od, exp_n_oe;
// SATA
logic         [ 4-1:0] daisy_p;
logic         [ 4-1:0] daisy_n;

// LED
wire          [ 8-1:0] led;

logic         [ 2-1:0] temp_prot;
logic                  pll_lo;
logic                  pll_hi;
logic                  pll_ref;
logic                  trig;

glbl glbl();

////////////////////////////////////////////////////////////////////////////////
// Clock and reset generation
////////////////////////////////////////////////////////////////////////////////

logic               clk ;
logic               rstn;

// clock
initial        clk = 1'b0;
always #(TP/2) clk = ~clk;

initial        pll_ref = 1'b0;
always #(RP/2) pll_ref = ~pll_ref;

// reset
initial begin
        rstn = 1'b0;
//  ##4;  rstn = 1'b1;
  #40;  rstn = 1'b1;
end

// default clocking 
default clocking cb @ (posedge clk);
  input  rstn;
  input  exp_p_od, exp_p_oe;
  input  exp_n_od, exp_n_oe;
endclocking: cb





////////////////////////////////////////////////////////////////////////////////
// initializtion
////////////////////////////////////////////////////////////////////////////////

initial begin
  exp_p_od = '0;
  exp_n_od = '0;
  exp_p_oe = '0;
  exp_n_oe = '0;
end

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

//initial begin
//  ##6000;
//  $display("ERROR: timeout!");
//  $finish();
//end

initial begin
  ##100;

   top_tc.test_hk                 (0<<20, 32'h55);
   top_tc.test_sata               (5<<20, 32'h55);
   top_tc.test_osc                (1<<20, 32'h40090000, 2);

//   top_tc.test_asg                (2<<20, 32'h40090000, 2);


  ##16000000;
  $finish();
end



////////////////////////////////////////////////////////////////////////////////
// signal generation
////////////////////////////////////////////////////////////////////////////////

localparam int unsigned DWM = 14;
localparam int unsigned CWM = 14;
localparam int unsigned CWF = 16;

always begin
  trig <= 1'b0;
  ##100000;
  trig <= 1'b1;
  ##1200;
  trig <= 1'b0;
end


always begin
  temp_prot <= 2'b00;
  ##50000;
  temp_prot <= 2'b10;
  ##1000;
  temp_prot <= 2'b00;
end


// ADC
model_ad366x i_ad366x
(
  .sela_i  (  4'h1            ), // data select
  .selb_i  (  4'h2            ), // data select
  .dco_i   ( !adc_odclk[1]    ), // data clock   -- reverted in HW
  .dco_o   (  adc_idclk[0]    ), // data clock   -- reverted in HW
  .fr_o    (  adc_fr          ), // frame
  .da_o    (  adc_dat1        ), // data
  .db_o    (  adc_dat2        )  // data
);

wire        [2-1:0] adc_fclk ;
wire [2-1:0][2-1:0] adc_data ;
wire [2-1:0][2-1:0] adc_datb ;

assign adc_idclk[1] =  !adc_idclk[0];
assign adc_fclk     =  {adc_fr,      !adc_fr     } ;  // {p,n}
assign adc_data[0]  =  {adc_dat1[0], !adc_dat1[0]} ;
assign adc_data[1]  =  {adc_dat1[1], !adc_dat1[1]} ;
assign adc_datb[0]  = ~{adc_dat2[0], !adc_dat2[0]} ;  // inverted in HW
assign adc_datb[1]  =  {adc_dat2[1], !adc_dat2[1]} ;


always begin
 #4 dac_clk = 1'b1;
 #4 dac_clk = 1'b0;
end



// XADC
assign vinp = '0;
assign vinn = '0;

// Expansion connector
//assign exp_p_io = 8'h0;
//assign exp_n_io = 8'h0;

// LED


assign #0.2 daisy_p[3] = daisy_p[1] ;
assign #0.2 daisy_n[3] = daisy_n[1] ;
assign #0.2 daisy_p[2] = daisy_p[0] ;
assign #0.2 daisy_n[2] = daisy_n[0] ;






























////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// module under test
red_pitaya_top #(
  .GITH (160'ha0a1a2a3b0b1b2b3c0c1c2c3d0d1d2d3e0e1e2e3)
) top (
  // PS connections
  .FIXED_IO_mio      (FIXED_IO_mio     ),
  .FIXED_IO_ps_clk   (FIXED_IO_ps_clk  ),
  .FIXED_IO_ps_porb  (FIXED_IO_ps_porb ),
  .FIXED_IO_ps_srstb (FIXED_IO_ps_srstb),
  .FIXED_IO_ddr_vrn  (FIXED_IO_ddr_vrn ),
  .FIXED_IO_ddr_vrp  (FIXED_IO_ddr_vrp ),
  // DDR
  .DDR_addr       (DDR_addr   ),
  .DDR_ba         (DDR_ba     ),
  .DDR_cas_n      (DDR_cas_n  ),
  .DDR_ck_n       (DDR_ck_n   ),
  .DDR_ck_p       (DDR_ck_p   ),
  .DDR_cke        (DDR_cke    ),
  .DDR_cs_n       (DDR_cs_n   ),
  .DDR_dm         (DDR_dm     ),
  .DDR_dq         (DDR_dq     ),
  .DDR_dqs_n      (DDR_dqs_n  ),
  .DDR_dqs_p      (DDR_dqs_p  ),
  .DDR_odt        (DDR_odt    ),
  .DDR_ras_n      (DDR_ras_n  ),
  .DDR_reset_n    (DDR_reset_n),
  .DDR_we_n       (DDR_we_n   ),

  // Red Pitaya periphery
  // ADC
  .adc_dclk_i  (adc_idclk ),  // ADC data clock {p,n}
  .adc_fclk_i  (adc_fclk  ),  // ADC frame clock {p,n}
  .adc_data_i  (adc_data  ),  // ADC data {p,n}
  .adc_datb_i  (adc_datb  ),  // ADC data {p,n}
  .adc_dclk_o  (adc_odclk ),  // ADC data clock {p,n}
  .adc_rst_o   (),   // ADC reset
  .adc_pdn_o   (),   // ADC power down
  .adc_sen_o   (),   // ADC serial en
  .adc_sclk_o  (),  // ADC serial clock
  .adc_sdio_io (), // ADC serial data

  // DAC
  .dac_clk_i   (dac_clk),  // DAC clock
  .dac_data_o  (dac_dat[0]),  // DAC data cha
  .dac_datb_o  (dac_dat[1]),  // DAC data chb
  .dac_wrta_o  (dac_wrt[0]),  // DAC write cha
  .dac_wrtb_o  (dac_wrt[1]),  // DAC write cha

  // PDM DAC
  .dac_pwm_o      (dac_pwm),
  // XADC
  .vinp_i         (vinp),
  .vinn_i         (vinn),
  // Expansion connector
  .exp_p_io       (exp_p_io),
  .exp_n_io       (exp_n_io),
  // SATA connector
  .daisy_p_o       ( daisy_p[1:0]  ),  //!< TX data and clock [1]-clock, [0]-data
  .daisy_n_o       ( daisy_n[1:0]  ),  //!< TX data and clock [1]-clock, [0]-data
  .daisy_p_i       ( daisy_p[3:2]  ),  //!< RX data and clock [1]-clock, [0]-data
  .daisy_n_i       ( daisy_n[3:2]  ),  //!< RX data and clock [1]-clock, [0]-data
  // LED
  .led_o          (led)
);

bufif1 bufif_exp_p_io [8-1:0] (exp_p_io, exp_p_od, exp_p_oe);
bufif1 bufif_exp_n_io [8-1:0] (exp_n_io, exp_n_od, exp_n_oe);
// testcases
top_tc top_tc();


////////////////////////////////////////////////////////////////////////////////
// waveforms
////////////////////////////////////////////////////////////////////////////////

initial begin
  $dumpfile("top_tb.vcd");
  $dumpvars(0, top_tb);
end



endmodule: top_tb
