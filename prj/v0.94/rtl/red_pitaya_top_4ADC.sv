////////////////////////////////////////////////////////////////////////////////
// Red Pitaya TOP module. It connects external pins and PS part with
// other application modules.
// Authors: Matej Oblak, Iztok Jeras
// (c) Red Pitaya  http://www.redpitaya.com
////////////////////////////////////////////////////////////////////////////////

/**
 * GENERAL DESCRIPTION:
 *
 * Top module connects PS part with rest of Red Pitaya applications.
 *
 *                   /-------\
 *   PS DDR <------> |  PS   |      AXI <-> custom bus
 *   PS MIO <------> |   /   | <------------+
 *   PS CLK -------> |  ARM  |              |
 *                   \-------/              |
 *                                          |
 *                            /-------\     |
 *                         -> | SCOPE | <---+
 *                         |  \-------/     |
 *                         |                |
 *            /--------\   |   /-----\      |
 *   ADC ---> |        | --+-> |     |      |
 *            | ANALOG |       | PID | <----+
 *   DAC <--- |        | <---- |     |      |
 *            \--------/   ^   \-----/      |
 *                         |                |
 *                         |  /-------\     |
 *                         -- |  ASG  | <---+
 *                            \-------/     |
 *                                          |
 *             /--------\                   |
 *    RX ----> |        |                   |
 *   SATA      | DAISY  | <-----------------+
 *    TX <---- |        |
 *             \--------/
 *               |    |
 *               |    |
 *               (FREE)
 *
 * Inside analog module, ADC data is translated from unsigned neg-slope into
 * two's complement. Similar is done on DAC data.
 *
 * Scope module stores data from ADC into RAM, arbitrary signal generator (ASG)
 * sends data from RAM to DAC. MIMO PID uses ADC ADC as input and DAC as its output.
 *
 * Daisy chain connects with other boards with fast serial link. Data which is
 * send and received is at the moment undefined. This is left for the user.
 */

module red_pitaya_top_4ADC #(
  // identification
  bit [0:5*32-1] GITH = '0,
  // module numbers
  parameter MNA =  4, // number of acquisition modules
  parameter DWE = 11
)(
  // PS connections
  inout  logic [54-1:0] FIXED_IO_mio     ,
  inout  logic          FIXED_IO_ps_clk  ,
  inout  logic          FIXED_IO_ps_porb ,
  inout  logic          FIXED_IO_ps_srstb,
  inout  logic          FIXED_IO_ddr_vrn ,
  inout  logic          FIXED_IO_ddr_vrp ,
  // DDR
  inout  logic [15-1:0] DDR_addr   ,
  inout  logic [ 3-1:0] DDR_ba     ,
  inout  logic          DDR_cas_n  ,
  inout  logic          DDR_ck_n   ,
  inout  logic          DDR_ck_p   ,
  inout  logic          DDR_cke    ,
  inout  logic          DDR_cs_n   ,
  inout  logic [ 4-1:0] DDR_dm     ,
  inout  logic [32-1:0] DDR_dq     ,
  inout  logic [ 4-1:0] DDR_dqs_n  ,
  inout  logic [ 4-1:0] DDR_dqs_p  ,
  inout  logic          DDR_odt    ,
  inout  logic          DDR_ras_n  ,
  inout  logic          DDR_reset_n,
  inout  logic          DDR_we_n   ,

  // Red Pitaya periphery

  // ADC
  input  logic [MNA-1:0] [ 7-1:0] adc_dat_i,  // ADC data
  input  logic [  2-1:0] [ 2-1:0] adc_clk_i,  // ADC clock {p,n}
  //output logic           [ 2-1:0] adc_clk_o,  // optional ADC clock source (unused) [0] = p; [1] = n
  //output logic                    adc_cdcs_o, // ADC clock duty cycle stabilizer

  // SPI interface to ADC
  output                spi_csa_o  ,
  output                spi_csb_o  ,
  output                spi_clk_o  ,
  output                spi_mosi_o ,
  // PLL control
  output logic          pll_hi_o   ,
  output logic          pll_lo_o   ,
  // PWM DAC
  output logic [ 4-1:0] dac_pwm_o  ,  // 1-bit PWM DAC
  // XADC
  input  logic [ 5-1:0] vinp_i     ,  // voltages p
  input  logic [ 5-1:0] vinn_i     ,  // voltages n
  // Expansion connector
  inout  logic [DWE-1:0] exp_p_io  ,
  inout  logic [DWE-1:0] exp_n_io  ,
  // SATA connector
  output logic [ 2-1:0] daisy_p_o  ,  // line 1 is clock capable
  output logic [ 2-1:0] daisy_n_o  ,
  input  logic [ 2-1:0] daisy_p_i  ,  // line 1 is clock capable
  input  logic [ 2-1:0] daisy_n_i  ,
  // LED
  inout  logic [ 8-1:0] led_o
);

////////////////////////////////////////////////////////////////////////////////
// local signals
////////////////////////////////////////////////////////////////////////////////

// GPIO input data width
localparam int unsigned GDW = 11;
localparam RST_MAX = 64;

logic [4-1:0] fclk ; //[0]-125MHz, [1]-250MHz, [2]-50MHz, [3]-200MHz
logic [4-1:0] frstn;
logic         idly_rdy;

logic [16-1:0] par_dat;

logic          daisy_trig;
logic [ 3-1:0] daisy_mode;
logic          trig_ext;
logic          trig_output_sel;
logic [ 4-1:0] trig_ext_asg01;



// PLL signals
logic [  2-1: 0]      adc_clk_in;
logic [  2-1: 0]      pll_adc_clk;
logic                 pll_ser_clk;
logic                 pll_adc_10mhz;
logic                 pll_pwm_clk;
logic [  2-1: 0]      pll_locked;
logic                 adc_10mhz;
logic                 spi_done; // ADC setup finished

(* ASYNC_REG = "TRUE" *)
logic                 spi_done_csff = 1'b0;
(* ASYNC_REG = "TRUE" *)
logic                 spi_done_adc  = 1'b0;

logic [  2-1: 0]      pll_locked_r;
logic [  2-1: 0]      fpll_locked_r,fpll_locked_r2,fpll_locked_r3;

logic   [16-1:0]      rst_cnt0 = 'h0;
logic   [16-1:0]      rst_cnt1 = 'h0;

logic [  2-1: 0]      rst_after_locked;
logic [  2-1: 0]      rstn_pll;

// fast serial signals
logic                 ser_clk ;
// PWM clock and reset
logic                 pwm_clk ;
logic                 pwm_rstn;
logic                 trig_asg_out;

//SPI CS
logic                 spi_cs;
assign spi_csa_o    = spi_cs; // only writes, no reads
assign spi_csb_o    = spi_cs;

// ADC clock/reset
logic       adc_clk_01 , adc_clk_23 ;
logic       adc_rstn_01 = 1'b0;
logic       adc_rstn_23 = 1'b0;

// stream bus type
localparam type SBA_T = logic signed [14-1:0];
SBA_T [MNA-1:0]          adc_dat_t;
(* ASYNC_REG = "TRUE" *)
SBA_T [MNA-1:0]          adc_dat, adc_dat_r;

// configuration
logic                 digital_loop;
logic                 adc_clk_daisy;
logic                 scope_trigo;

//CAN
logic                 CAN0_rx, CAN0_tx;
logic                 CAN1_rx, CAN1_tx;
logic                 can_on;


// system bus
sys_bus_if   ps_sys      (.clk (fclk[0]   ), .rstn (frstn[0]   ));
sys_bus_if   sys [8-1:0] (.clk (adc_clk_01), .rstn (adc_rstn_01));
// GPIO interface
gpio_if #(.DW (3*GDW)) gpio ();

// AXI masters
axi_sys_if axi0_sys (.clk(adc_clk_01    ), .rstn(adc_rstn_01    ));
axi_sys_if axi1_sys (.clk(adc_clk_01    ), .rstn(adc_rstn_01    ));
axi_sys_if axi2_sys (.clk(adc_clk_01    ), .rstn(adc_rstn_01    ));
axi_sys_if axi3_sys (.clk(adc_clk_01    ), .rstn(adc_rstn_01    ));
////////////////////////////////////////////////////////////////////////////////
// PLL (clock and reset)
////////////////////////////////////////////////////////////////////////////////

// diferential clock input
IBUFDS i_clk_01 (.I (adc_clk_i[0][1]), .IB (adc_clk_i[0][0]), .O (adc_clk_in[0]));  // differential clock input
IBUFDS i_clk_23 (.I (adc_clk_i[1][1]), .IB (adc_clk_i[1][0]), .O (adc_clk_in[1]));  // differential clock input

assign rstn_pll[0] = spi_done & frstn[0] & ~(!fpll_locked_r2[0] && fpll_locked_r3[0]);
assign rstn_pll[1] = spi_done & frstn[0] & ~(!fpll_locked_r2[1] && fpll_locked_r3[1]);

red_pitaya_pll_4adc pll_01 (
  // inputs
  .clk         (adc_clk_in[0]),  // clock
  .rstn        (rstn_pll[0]  ),  // reset - active low
  // output clocks
  .clk_adc     (pll_adc_clk[0]),  // ADC clock
  .clk_10mhz   (pll_adc_10mhz ),  // ADC divided to 10MHz
  .clk_ser     (pll_ser_clk   ),  // fast serial clock
  .clk_pdm     (pll_pwm_clk   ),  // PWM clock
  // status outputs
  .pll_locked  (pll_locked[0])
);

red_pitaya_pll_4adc pll_23 (
  // inputs
  .clk         (adc_clk_in[1]),  // clock
  .rstn        (rstn_pll[1]  ),  // reset - active low
  // output clocks
  .clk_adc     (pll_adc_clk[1]),  // ADC clock
  // status outputs
  .pll_locked  (pll_locked[1])
);


BUFG bufg_adc_clk_01 (.O (adc_clk_01), .I (pll_adc_clk[0]));
BUFG bufg_adc_clk_23 (.O (adc_clk_23), .I (pll_adc_clk[1]));
BUFG bufg_adc_10MHz  (.O (adc_10mhz ), .I (pll_adc_10mhz ));
BUFG bufg_ser_clk    (.O (ser_clk   ), .I (pll_ser_clk   ));
BUFG bufg_pwm_clk    (.O (pwm_clk   ), .I (pll_pwm_clk   ));


always @(posedge fclk[0]) begin
  fpll_locked_r[0]   <= pll_locked[0];
  fpll_locked_r2[0]  <= fpll_locked_r[0];
  fpll_locked_r3[0]  <= fpll_locked_r2[0];

  fpll_locked_r[1]   <= pll_locked[1];
  fpll_locked_r2[1]  <= fpll_locked_r[1];
  fpll_locked_r3[1]  <= fpll_locked_r2[1];
end

always @(posedge adc_clk_01) begin
  pll_locked_r[0] <= pll_locked[0];
  if ((pll_locked[0] && !pll_locked_r[0]) || rst_cnt0 > 0) begin // some clk cycles after rising edge of pll_locked
    if (rst_cnt0 < RST_MAX)
      rst_cnt0 <= rst_cnt0 + 1;
    else 
      rst_cnt0 <= 'h0;
  end else begin
    if (~pll_locked[0]) begin
      rst_cnt0 <= 'h0;
    end
  end
end

always @(posedge adc_clk_23) begin
  pll_locked_r[1] <= pll_locked[1];
  if ((pll_locked[1] && !pll_locked_r[1]) || rst_cnt1 > 0) begin // some clk cycles after rising edge of pll_locked
    if (rst_cnt1 < RST_MAX)
      rst_cnt1 <= rst_cnt1 + 1;
    else 
      rst_cnt1 <= 'h0;
  end else begin
    if (~pll_locked[1]) begin
      rst_cnt1 <= 'h0;
    end
  end
end

assign rst_after_locked[0] = |rst_cnt0;
assign rst_after_locked[1] = |rst_cnt1;

wire [2-1:0] adc_clks;
assign adc_clks={adc_clk_23, adc_clk_01};

always @(posedge adc_clk_01) begin
  spi_done_csff <= spi_done;
  spi_done_adc  <= spi_done_csff;
end

// ADC reset (active low)
always @(*) begin
 adc_rstn_01 <=  frstn[0] & spi_done_adc & ~rst_after_locked[0];
 adc_rstn_23 <=  frstn[0] & spi_done_adc & ~rst_after_locked[1];
end

// PWM reset (active low)
always @(posedge pwm_clk)
  pwm_rstn   <=  frstn[0] & spi_done & ~rst_after_locked[0];


assign daisy_trig = |par_dat;
assign trig_ext   = gpio.i[GDW] & ~(daisy_mode[0] & daisy_trig);

////////////////////////////////////////////////////////////////////////////////
//  Connections to PS
////////////////////////////////////////////////////////////////////////////////

red_pitaya_ps ps (
  .FIXED_IO_mio       (  FIXED_IO_mio                ),
  .FIXED_IO_ps_clk    (  FIXED_IO_ps_clk             ),
  .FIXED_IO_ps_porb   (  FIXED_IO_ps_porb            ),
  .FIXED_IO_ps_srstb  (  FIXED_IO_ps_srstb           ),
  .FIXED_IO_ddr_vrn   (  FIXED_IO_ddr_vrn            ),
  .FIXED_IO_ddr_vrp   (  FIXED_IO_ddr_vrp            ),
  // DDR
  .DDR_addr      (DDR_addr    ),
  .DDR_ba        (DDR_ba      ),
  .DDR_cas_n     (DDR_cas_n   ),
  .DDR_ck_n      (DDR_ck_n    ),
  .DDR_ck_p      (DDR_ck_p    ),
  .DDR_cke       (DDR_cke     ),
  .DDR_cs_n      (DDR_cs_n    ),
  .DDR_dm        (DDR_dm      ),
  .DDR_dq        (DDR_dq      ),
  .DDR_dqs_n     (DDR_dqs_n   ),
  .DDR_dqs_p     (DDR_dqs_p   ),
  .DDR_odt       (DDR_odt     ),
  .DDR_ras_n     (DDR_ras_n   ),
  .DDR_reset_n   (DDR_reset_n ),
  .DDR_we_n      (DDR_we_n    ),
  // system signals
  .fclk_clk_o    (fclk        ),
  .fclk_rstn_o   (frstn       ),
  // ADC analog inputs
  .vinp_i        (vinp_i      ),
  .vinn_i        (vinn_i      ),
  // CAN0
  .CAN0_rx       (CAN0_rx     ),
  .CAN0_tx       (CAN0_tx     ),
  // CAN1
  .CAN1_rx       (CAN1_rx     ),
  .CAN1_tx       (CAN1_tx     ),
  // GPIO
  .gpio          (gpio),
  // system read/write channel
  .bus           (ps_sys      ),
  // AXI masters

  .axi0_sys      (axi0_sys    ),
  .axi1_sys      (axi1_sys    ),
  .axi2_sys      (axi2_sys    ),
  .axi3_sys      (axi3_sys    )
);

////////////////////////////////////////////////////////////////////////////////
// system bus decoder & multiplexer (it breaks memory addresses into 8 regions)
////////////////////////////////////////////////////////////////////////////////
sys_bus_interconnect #(
  .SN (8),
  .SW (20),
  .SYNC_IN_BUS   (1),
  .SYNC_OUT_BUS1 (2),
  .SYNC_OUT_BUS2 (2),
  .SYNC_OUT_BUS3 (2),
  .SYNC_OUT_BUS4 (2),
  .SYNC_OUT_BUS5 (2),
  .SYNC_OUT_BUS6 (2),
  .SYNC_REG_OFS1 (0),
  .SYNC_REG_OFS2 (4),
  .SYNC_REG_OFS3 (16),
  .SYNC_REG_OFS4 (20),
  .SYNC_REG_OFS5 (40),
  .SYNC_REG_OFS6 (148)
) sys_bus_interconnect (
  .pll_locked_i(&pll_locked),
  .bus_m (ps_sys),
  .bus_s (sys)
);

sys_bus_stub sys_bus_stub_3 (sys[3]);
generate
for (genvar i=6; i<8; i++) begin: for_sys
  sys_bus_stub sys_bus_stub_5_7 (sys[i]);
end: for_sys
endgenerate

////////////////////////////////////////////////////////////////////////////////
// ADC IO
////////////////////////////////////////////////////////////////////////////////

// DDR inputs
// falling edge: odd bits    rising edge: even bits   
// 0: CH1 falling edge data  1: CH1 rising edge data
// 2: CH2 falling edge data  3: CH2 rising edge data
// 4: CH3 falling edge data  5: CH3 rising edge data
// 6: CH4 falling edge data  7: CH4 rising edge data

// delay input ADC signals
logic [4*7-1:0] idly_rst ;
logic [4*7-1:0] idly_ce  ;
logic [4*7-1:0] idly_inc ;
logic [4*7-1:0] [5-1:0] idly_cnt ;
logic [4-1:0] [14-1:0] adc_dat_raw;

//(* IODELAY_GROUP = "adc_inputs" *) // Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
IDELAYCTRL i_idelayctrl (
  .RDY(idly_rdy),   // 1-bit output: Ready output
  .REFCLK(fclk[3]), // 1-bit input: Reference clock input
  .RST(!frstn[3])   // 1-bit input: Active high reset input
);

genvar GV;
genvar GVC;
genvar GVD;

generate
for (GVC = 0; GVC < 4; GVC = GVC + 1) begin : channels
  for (GV = 0; GV < 7; GV = GV + 1) begin : adc_decode
    logic          adc_dat_idly;
    logic [ 2-1:0] adc_dat_ddr;


   //(* IODELAY_GROUP = "adc_inputs" *)
   IDELAYE2 #(
      .DELAY_SRC("IDATAIN"),           // Delay input (IDATAIN, DATAIN)
      .HIGH_PERFORMANCE_MODE("TRUE"),  // Reduced jitter ("TRUE"), Reduced power ("FALSE")
      .IDELAY_TYPE("VARIABLE"),        // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
      .IDELAY_VALUE(4),                // Input delay tap setting (0-31)
      .PIPE_SEL("FALSE"),              // Select pipelined mode, FALSE, TRUE
      .REFCLK_FREQUENCY(200.0),        // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
      .SIGNAL_PATTERN("DATA")          // DATA, CLOCK input signal
   )
   i_dly (
      .CNTVALUEOUT  ( idly_cnt[GV+GVC*7]    ),  // 5-bit output: Counter value output
      .DATAOUT      ( adc_dat_idly          ),  // 1-bit output: Delayed data output
      .C            ( adc_clk_in[GVC/2]     ),  // 1-bit input: Clock input
      .CE           ( idly_ce[GV+GVC*7]     ),  // 1-bit input: Active high enable increment/decrement input
      .CINVCTRL     ( 1'b0                  ),  // 1-bit input: Dynamic clock inversion input
      .CNTVALUEIN   ( 5'h0                  ),  // 5-bit input: Counter value input
      .DATAIN       ( 1'b0                  ),  // 1-bit input: Internal delay data input
      .IDATAIN      ( adc_dat_i[GVC][GV]    ),  // 1-bit input: Data input from the I/O
      .INC          ( idly_inc[GV+GVC*7]    ),  // 1-bit input: Increment / Decrement tap delay input
      .LD           ( idly_rst[GV+GVC*7]    ),  // 1-bit input: Load IDELAY_VALUE input
      .LDPIPEEN     ( 1'b0                  ),  // 1-bit input: Enable PIPELINE register to load data input
      .REGRST       ( 1'b0                  )   // 1-bit input: Active-high reset tap-delay input
   );
  
    IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) iddr_adc_dat_0 (.D(adc_dat_idly), .Q1({adc_dat_ddr[1]}), .Q2({adc_dat_ddr[0]}), .C(adc_clks[GVC/2]), .CE(1'b1), .R(1'b0), .S(1'b0));
    assign adc_dat_raw[GVC][2*GV  ] = adc_dat_ddr[0];
    assign adc_dat_raw[GVC][2*GV+1] = adc_dat_ddr[1];
  end 
end
endgenerate

always @(posedge adc_clk_01) begin // to have a register-to-register point for timing constraints
  adc_dat_t[0] <= adc_dat_raw[0];
  adc_dat_t[1] <= adc_dat_raw[1];
end

always @(posedge adc_clk_23) begin
  adc_dat_t[2] <= adc_dat_raw[2];
  adc_dat_t[3] <= adc_dat_raw[3];
end

always @(posedge adc_clk_01) begin
  adc_dat_r[0] <= {adc_dat_t[0][14-1], ~adc_dat_t[0][14-2:0]};
  adc_dat_r[1] <= {adc_dat_t[1][14-1], ~adc_dat_t[1][14-2:0]};

  adc_dat  [0] <= adc_dat_r[0];
  adc_dat  [1] <= adc_dat_r[1];
end

// should here be adc_clk_23
always @(posedge adc_clk_23) begin
  adc_dat_r[2] <= {adc_dat_t[2][14-1], ~adc_dat_t[2][14-2:0]};
  adc_dat_r[3] <= {adc_dat_t[3][14-1], ~adc_dat_t[3][14-2:0]};

  adc_dat  [2] <= adc_dat_r[2];
  adc_dat  [3] <= adc_dat_r[3];
end

////////////////////////////////////////////////////////////////////////////////
//  House Keeping
////////////////////////////////////////////////////////////////////////////////

logic [DWE-1: 0] exp_p_in ,  exp_n_in ;
logic [DWE-1: 0] exp_p_out,  exp_n_out;
logic [DWE-1: 0] exp_p_dir,  exp_n_dir;
logic [DWE-1: 0] exp_p_otr,  exp_n_otr;
logic [DWE-1: 0] exp_p_dtr,  exp_n_dtr;
logic [DWE-1: 0] exp_p_alt,  exp_n_alt;
logic [DWE-1: 0] exp_p_altr, exp_n_altr;
logic [DWE-1: 0] exp_p_altd, exp_n_altd;

red_pitaya_hk_4adc #(.DWE(DWE)) i_hk (
  // system signals
  .clk_i           (adc_clk_01 ),  // clock
  .rstn_i          (adc_rstn_01),  // reset - active low
  .fclk_i          (fclk[0] ),  // clock
  .frstn_i         (frstn[0]),  // reset - active low
  .spi_done_o      (spi_done),  // PLL reset
  // LED
  .led_o           (led_o       ),  // LED output
  .daisy_mode_o    (daisy_mode),

  // idelay control
  .idly_rst_o      (idly_rst    ),
  .idly_ce_o       (idly_ce     ),
  .idly_inc_o      (idly_inc    ),
  .idly_cnt_i      ({idly_cnt[21],idly_cnt[14],idly_cnt[7],idly_cnt[0]}),

  .spi_cs_o        (spi_cs     ),
  .spi_clk_o       (spi_clk_o  ),
  .spi_mosi_o      (spi_mosi_o ),

  // global configuration
  .digital_loop    (digital_loop),
  .pll_sys_i       (adc_10mhz   ),    // system clock
  .pll_ref_i       (adc_10mhz   ),    // reference clock
  .pll_hi_o        (pll_hi_o    ),    // PLL high
  .pll_lo_o        (pll_lo_o    ),    // PLL low
  .can_on_o        (can_on   ),

  // Expansion connector
  .exp_p_dat_i     (exp_p_in ),  // input data
  .exp_p_dat_o     (exp_p_out),  // output data
  .exp_p_dir_o     (exp_p_dir),  // 1-output enable
  .exp_n_dat_i     (exp_n_in ),
  .exp_n_dat_o     (exp_n_out),
  .exp_n_dir_o     (exp_n_dir),
   // System bus
  .sys_addr        (sys[0].addr ),
  .sys_wdata       (sys[0].wdata),
  .sys_wen         (sys[0].wen  ),
  .sys_ren         (sys[0].ren  ),
  .sys_rdata       (sys[0].rdata),
  .sys_err         (sys[0].err  ),
  .sys_ack         (sys[0].ack  )
);

////////////////////////////////////////////////////////////////////////////////
// Analog mixed signals (PDM analog outputs)
////////////////////////////////////////////////////////////////////////////////

logic [4-1:0] [8-1:0] pdm_cfg;

red_pitaya_ams i_ams (
  // power test
  .clk_i           (adc_clk_01 ),  // clock
  .rstn_i          (adc_rstn_01),  // reset - active low
  // PWM configuration
  .dac_a_o         (pdm_cfg[0]),
  .dac_b_o         (pdm_cfg[1]),
  .dac_c_o         (pdm_cfg[2]),
  .dac_d_o         (pdm_cfg[3]),
  // System bus
  .sys_addr        (sys[4].addr ),
  .sys_wdata       (sys[4].wdata),
  .sys_wen         (sys[4].wen  ),
  .sys_ren         (sys[4].ren  ),
  .sys_rdata       (sys[4].rdata),
  .sys_err         (sys[4].err  ),
  .sys_ack         (sys[4].ack  )
);

red_pitaya_pdm pdm (
  // system signals
  .clk   (adc_clk_01 ),
  .rstn  (adc_rstn_01),
  // configuration
  .cfg   (pdm_cfg),
  .ena      (1'b1),
  .rng      (8'd255),
  // PWM outputs
  .pdm (dac_pwm_o)
);

////////////////////////////////////////////////////////////////////////////////
// GPIO
////////////////////////////////////////////////////////////////////////////////

assign trig_output_sel = daisy_mode[2] ? trig_asg_out : scope_trigo;

assign exp_p_alt  = {DWE{1'b0}};
assign exp_n_alt  = {{DWE-8{1'b0}},  can_on,  can_on, 5'h0, daisy_mode[1]  };

assign exp_p_altr = {DWE{1'b0}};
assign exp_n_altr = {{DWE-8{1'b0}}, CAN0_tx, CAN1_tx, 5'h0, trig_output_sel};

assign exp_p_altd = {DWE{1'b0}};
assign exp_n_altd = {{DWE-8{1'b0}},   1'b1,   1'b1, 5'h0, 1'b1};

genvar GM;
generate
for(GM = 0 ; GM < DWE ; GM = GM + 1) begin : gpios
  assign exp_p_otr[GM] = exp_p_alt[GM] ? exp_p_altr[GM] : exp_p_out[GM];
  assign exp_n_otr[GM] = exp_n_alt[GM] ? exp_n_altr[GM] : exp_n_out[GM];

  assign exp_p_dtr[GM] = exp_p_alt[GM] ? exp_p_altd[GM] : exp_p_dir[GM];
  assign exp_n_dtr[GM] = exp_n_alt[GM] ? exp_n_altd[GM] : exp_n_dir[GM];
end
endgenerate

IOBUF i_iobufp [DWE-1:0] (.O(exp_p_in), .IO(exp_p_io), .I(exp_p_otr), .T(~exp_p_dtr) );
IOBUF i_iobufn [DWE-1:0] (.O(exp_n_in), .IO(exp_n_io), .I(exp_n_otr), .T(~exp_n_dtr) );

assign gpio.i[2*GDW-1:  GDW] = exp_p_in[GDW-1:0];
assign gpio.i[3*GDW-1:2*GDW] = exp_n_in[GDW-1:0];

assign CAN0_rx = can_on & exp_p_in[7];
assign CAN1_rx = can_on & exp_p_in[6];

////////////////////////////////////////////////////////////////////////////////
// oscilloscope CH0 and CH1
////////////////////////////////////////////////////////////////////////////////
wire [ 4-1:0] trig_ch_0_1;
wire [ 4-1:0] trig_ch_2_3;
wire [16-1:0] trg_state_ch_0_1;
wire [16-1:0] trg_state_ch_2_3;
wire [16-1:0] adc_state_ch_0_1;
wire [16-1:0] adc_state_ch_2_3;
wire [16-1:0] axi_state_ch_0_1;
wire [16-1:0] axi_state_ch_2_3;

rp_scope_com #(
  .CHN(0),
  .N_CH(2),
  .DW(14),
  .RSZ(14)) 
  i_scope_0_1 (
  // ADC
  .adc_dat_i     ({adc_dat[1], adc_dat[0]}  ),
  .adc_clk_i     ({2{adc_clk_01}}  ),  // clock
  .adc_rstn_i    ({2{adc_rstn_01}} ),  // reset - active low
  .trig_ext_i    (trig_ext    ),  // external trigger
  .trig_asg_i    (trig_asg_out),  // ASG trigger
  .trig_ch_o     (trig_ch_0_1 ),  // output trigger to ADC for other 2 channels
  .trig_ch_i     (trig_ch_2_3 ),  // input ADC trigger from other 2 channels
  .trig_ext_asg_o(trig_ext_asg01),
  .trig_ext_asg_i(trig_ext_asg01),
  .daisy_trig_o  (scope_trigo ),
  .adc_state_o   (adc_state_ch_0_1),
  .adc_state_i   (adc_state_ch_2_3),
  .axi_state_o   (axi_state_ch_0_1),
  .axi_state_i   (axi_state_ch_2_3),
  .trg_state_o   (trg_state_ch_0_1),
  .trg_state_i   (trg_state_ch_2_3),
  // AXI0 master                 // AXI1 master
  .axi_waddr_o  ({axi1_sys.waddr,  axi0_sys.waddr} ),
  .axi_wdata_o  ({axi1_sys.wdata,  axi0_sys.wdata} ),
  .axi_wsel_o   ({axi1_sys.wsel,   axi0_sys.wsel}  ),
  .axi_wvalid_o ({axi1_sys.wvalid, axi0_sys.wvalid}),
  .axi_wlen_o   ({axi1_sys.wlen,   axi0_sys.wlen}  ),
  .axi_wfixed_o ({axi1_sys.wfixed, axi0_sys.wfixed}),
  .axi_werr_i   ({axi1_sys.werr,   axi0_sys.werr}  ),
  .axi_wrdy_i   ({axi1_sys.wrdy,   axi0_sys.wrdy}  ),
  // System bus
  .sys_addr      (sys[1].addr ),
  .sys_wdata     (sys[1].wdata),
  .sys_wen       (sys[1].wen  ),
  .sys_ren       (sys[1].ren  ),
  .sys_rdata     (sys[1].rdata),
  .sys_err       (sys[1].err  ),
  .sys_ack       (sys[1].ack  )
);

////////////////////////////////////////////////////////////////////////////////
// oscilloscope CH2 and CH3
////////////////////////////////////////////////////////////////////////////////
rp_scope_com #(
  .CHN(1),
  .N_CH(2),
  .DW(14),
  .RSZ(14)) 
  i_scope_2_3(  // ADC
  .adc_dat_i     ({adc_dat[3], adc_dat[2]}  ),
  .adc_clk_i     ({2{adc_clk_23}}  ),  // clock
  .adc_rstn_i    ({2{adc_rstn_23}} ),  // reset - active low
  .trig_ext_i    (trig_ext    ),  // external trigger
  .trig_asg_i    (trig_asg_out),  // ASG trigger
  .trig_ch_o     (trig_ch_2_3 ),  // output trigger to ADC for other 2 channels
  .trig_ch_i     (trig_ch_0_1 ),  // input ADC trigger from other 2 channels
  .trig_ext_asg_i(trig_ext_asg01),
  .adc_state_o   (adc_state_ch_2_3),
  .adc_state_i   (adc_state_ch_0_1),
  .axi_state_o   (axi_state_ch_2_3),
  .axi_state_i   (axi_state_ch_0_1),
  .trg_state_o   (trg_state_ch_2_3),
  .trg_state_i   (trg_state_ch_0_1),
  // AXI2 master                 // AXI3 master
  .axi_waddr_o  ({axi3_sys.waddr,  axi2_sys.waddr} ),
  .axi_wdata_o  ({axi3_sys.wdata,  axi2_sys.wdata} ),
  .axi_wsel_o   ({axi3_sys.wsel,   axi2_sys.wsel}  ),
  .axi_wvalid_o ({axi3_sys.wvalid, axi2_sys.wvalid}),
  .axi_wlen_o   ({axi3_sys.wlen,   axi2_sys.wlen}  ),
  .axi_wfixed_o ({axi3_sys.wfixed, axi2_sys.wfixed}),
  .axi_werr_i   ({axi3_sys.werr,   axi2_sys.werr}  ),
  .axi_wrdy_i   ({axi3_sys.wrdy,   axi2_sys.wrdy}  ),
  // System bus
  .sys_addr      (sys[2].addr ),
  .sys_wdata     (sys[2].wdata),
  .sys_wen       (sys[2].wen  ),
  .sys_ren       (sys[2].ren  ),
  .sys_rdata     (sys[2].rdata),
  .sys_err       (sys[2].err  ),
  .sys_ack       (sys[2].ack  )
);

////////////////////////////////////////////////////////////////////////////////
// Daisy test code
////////////////////////////////////////////////////////////////////////////////

wire daisy_rx_rdy ;
wire dly_clk = fclk[3]; // 200MHz clock from PS - used for IDELAY (optionaly)
wire [16-1:0] par_dati = daisy_mode[0] ? {16{trig_output_sel}} : 16'h1234;
wire          par_dvi  = daisy_mode[0] ? 1'b0 : daisy_rx_rdy;

red_pitaya_daisy i_daisy (
   // SATA connector
  .daisy_p_o       (  daisy_p_o                  ),  // line 1 is clock capable
  .daisy_n_o       (  daisy_n_o                  ),
  .daisy_p_i       (  daisy_p_i                  ),  // line 1 is clock capable
  .daisy_n_i       (  daisy_n_i                  ),
   // Data
  .ser_clk_i       (  ser_clk                    ),  // high speed serial
  .dly_clk_i       (  dly_clk                    ),  // delay clock
   // TX
  .par_clk_i       (  adc_clk_01                 ),  // data paralel clock
  .par_rstn_i      (  adc_rstn_01                ),  // reset - active low
  .par_rdy_o       (  daisy_rx_rdy               ),
  .par_dv_i        (  par_dvi                    ),
  .par_dat_i       (  par_dati                   ),
   // RX
  .par_clk_o       ( adc_clk_daisy               ),
  .par_rstn_o      (                             ),
  .par_dv_o        (                             ),
  .par_dat_o       ( par_dat                     ),

  .sync_mode_i     (  daisy_mode[0]              ),
  .debug_o         (/*led_o*/                    ),
   // System bus
  .sys_clk_i       (  adc_clk_01                 ),  // clock
  .sys_rstn_i      (  adc_rstn_01                ),  // reset - active low
  .sys_addr_i      (  sys[5].addr                ),
  .sys_sel_i       (                             ),
  .sys_wdata_i     (  sys[5].wdata               ),
  .sys_wen_i       (  sys[5].wen                 ),
  .sys_ren_i       (  sys[5].ren                 ),
  .sys_rdata_o     (  sys[5].rdata               ),
  .sys_err_o       (  sys[5].err                 ),
  .sys_ack_o       (  sys[5].ack                 )
);


endmodule: red_pitaya_top_4ADC
