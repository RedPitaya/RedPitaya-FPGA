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

module red_pitaya_top_ll #(
  // identification
  bit [0:5*32-1] GITH = '0,
  // module numbers
  int unsigned MNA = 2,  // number of acquisition modules
  int unsigned MNG = 2,  // number of generator   modules
  parameter    DWE = 8,
  parameter ADC_DW=14
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
  input  logic           [ 2-1:0] adc_dclk_i,  // ADC data clock {p,n}
  input  logic           [ 2-1:0] adc_fclk_i,  // ADC frame clock {p,n}
  input  logic [ 2-1: 0] [ 2-1:0] adc_data_i,  // ADC data {p,n}
  input  logic [ 2-1: 0] [ 2-1:0] adc_datb_i,  // ADC data {p,n}
  output logic           [ 2-1:0] adc_dclk_o,  // ADC data clock {p,n}
  output logic                    adc_rst_o,   // ADC reset
  output logic                    adc_pdn_o,   // ADC power down
  output logic                    adc_sen_o,   // ADC serial en
  output logic                    adc_sclk_o,  // ADC serial clock
  inout  logic                    adc_sdio_io, // ADC serial data

  // DAC
  input  logic          dac_clk_i   ,  // DAC clock
  output logic [14-1:0] dac_data_o  ,  // DAC data cha
  output logic [14-1:0] dac_datb_o  ,  // DAC data chb
  output logic          dac_wrta_o  ,  // DAC write cha
  output logic          dac_wrtb_o  ,  // DAC write cha
  // PWM DAC
  output logic [ 4-1:0] dac_pwm_o  ,  // 1-bit PWM DAC
  // XADC
  input  logic [ 5-1:0] vinp_i     ,  // voltages p
  input  logic [ 5-1:0] vinn_i     ,  // voltages n
  // Expansion connector
  inout  logic [ 8-1:0] exp_p_io   ,
  inout  logic [ 8-1:0] exp_n_io   ,
  // SATA connector
  output logic [ 2-1:0] daisy_p_o  ,  // line 1 is clock capable
  output logic [ 2-1:0] daisy_n_o  ,
  input  logic [ 2-1:0] daisy_p_i  ,  // line 1 is clock capable
  input  logic [ 2-1:0] daisy_n_i  ,
  // PLL
  output logic          clk_sel_o  ,  // 1-internal 0-external
  output logic          pll_hi_o   ,
  output logic          pll_lo_o   ,
  // LED
  output logic [ 8-1:0] led_o
);

////////////////////////////////////////////////////////////////////////////////
// local signals
////////////////////////////////////////////////////////////////////////////////

// GPIO input data width
localparam int unsigned GDW = DWE;
localparam RST_MAX = 64;
logic [4-1:0] fclk ; //[0]-125MHz, [1]-250MHz, [2]-50MHz, [3]-200MHz
logic [4-1:0] frstn;

logic [16-1:0] par_dat;

logic          daisy_trig;
logic [ 3-1:0] daisy_mode;
logic          trig_ext;
logic          trig_output_sel;
logic          trig_asg_out;
logic [ 4-1:0] trig_ext_asg01;

logic [ 3-1:0] bitslip;


// PLL signals
logic                 dac_clk_in;
logic                 pll_adc_dclk;
logic                 pll_adc_clk;
logic                 pll_dac_clk_1x;
logic                 pll_dac_clk_1p;
logic                 pll_ser_clk;
logic                 pll_pwm_clk;
logic                 pll_locked;
logic                 pll_locked_r;
logic                 fpll_locked_r,fpll_locked_r2,fpll_locked_r3;

logic   [16-1:0]      rst_cnt = 'h0;
logic                 rst_after_locked;
logic                 rstn_pll;

// fast serial signals
logic                 ser_clk ;
// PWM clock and reset
logic                 pwm_clk ;
logic                 pwm_rstn;

// ADC clock/reset
logic                 adc_clk;
logic                 adc_rstn;
logic                 adc_clk_daisy;
logic                 scope_trigo;

//CAN
logic                 CAN0_rx, CAN0_tx;
logic                 CAN1_rx, CAN1_tx;
logic                 can_on;
logic [26-1:0]        ser_ddly;
logic [ 5-1:0]        ser_inv;// = 5'h8;


// stream bus type
localparam type SBA_T = logic signed [14-1:0];  // acquire
localparam type SBG_T = logic signed [14-1:0];  // generate

SBA_T [MNA-1:0]          adc_dat;
logic                    adc_dv;

// DAC signals
logic                    dac_clk_1x;
logic                    dac_clk_1p;
logic                    dac_rst;

logic        [14-1:0] dac_dat_a, dac_dat_b;
logic        [14-1:0] dac_a    , dac_b    ;
logic signed [15-1:0] dac_a_sum, dac_b_sum;

// ASG
SBG_T [2-1:0]            asg_dat;

// PID
SBA_T [2-1:0]            pid_dat;

// configuration
logic [2-1:0]            digital_loop;

logic                    hk_spi_cs  ;
logic                    hk_spi_clk ;
logic                    hk_spi_i   ;
logic                    hk_spi_o   ;
logic                    hk_spi_t   ;

// system bus
sys_bus_if   ps_sys      (.clk (fclk[0]), .rstn (frstn[0]));
sys_bus_if   sys [8-1:0] (.clk (adc_clk), .rstn (adc_rstn));

// GPIO interface
gpio_if #(.DW (3*GDW)) gpio ();

// AXI masters
axi_sys_if axi0_sys (.clk(adc_clk    ), .rstn(adc_rstn    ));
axi_sys_if axi1_sys (.clk(adc_clk    ), .rstn(adc_rstn    ));
axi_sys_if axi2_sys (.clk(dac_axi_clk), .rstn(dac_axi_rstn));
axi_sys_if axi3_sys (.clk(dac_axi_clk), .rstn(dac_axi_rstn));
////////////////////////////////////////////////////////////////////////////////
// PLL (clock and reset)
////////////////////////////////////////////////////////////////////////////////

IBUF i_clk (.I (dac_clk_i), .O (dac_clk_in));
assign rstn_pll = frstn[0] & ~(!fpll_locked_r2 && fpll_locked_r3);
red_pitaya_pll_ll pll (
  // inputs
  .clk         (dac_clk_in),  // clock
  .rstn        (rstn_pll  ),  // reset - active low
  // output clocks
  .clk_dclk    (pll_adc_dclk  ),  // ADC DCO clock - 250MHz
  .clk_adc     (pll_adc_clk   ),  // ADC clock - system
  .clk_dac_1x  (pll_dac_clk_1x),  // DAC clock 125MHz
  .clk_dac_1p  (pll_dac_clk_1p),  // DAC clock 125MHz -90DGR
  .clk_ser     (pll_ser_clk   ),  // fast serial clock
  .clk_pdm     (pll_pwm_clk   ),  // PWM clock
  // status outputs
  .pll_locked  (pll_locked)
);

BUFG bufg_adc_clk    (.O (adc_clk   ), .I (pll_adc_clk   ));
BUFG bufg_dac_clk_1x (.O (dac_clk_1x), .I (pll_dac_clk_1x));
BUFG bufg_dac_clk_1p (.O (dac_clk_1p), .I (pll_dac_clk_1p));
BUFG bufg_dac_axi_clk (.O (dac_axi_clk), .I (pll_ser_clk));
BUFG bufg_ser_clk    (.O (ser_clk   ), .I (pll_ser_clk   ));
BUFG bufg_pwm_clk    (.O (pwm_clk   ), .I (pll_pwm_clk   ));

always @(posedge fclk[0]) begin
  fpll_locked_r   <= pll_locked;
  fpll_locked_r2  <= fpll_locked_r;
  fpll_locked_r3  <= fpll_locked_r2;
end

always @(posedge adc_clk) begin
  pll_locked_r      <= pll_locked;
  if ((pll_locked && !pll_locked_r) || rst_cnt > 0) begin // some clk cycles after rising edge of pll_locked
    if (rst_cnt < RST_MAX)
      rst_cnt <= rst_cnt + 1;
    else 
      rst_cnt <= 'h0;
  end else begin
    if (~pll_locked) begin
      rst_cnt <= 'h0;
    end
  end
end

assign rst_after_locked = |rst_cnt;
// ADC reset (active low)
always @(posedge adc_clk)
adc_rstn     <=  frstn[0] & ~rst_after_locked;// & idly_rdy; 

// PWM reset (active low)
always @(posedge pwm_clk)
pwm_rstn     <=  frstn[0] & ~rst_after_locked;// & idly_rdy;




// External PLL

assign clk_sel_o = 1'bz;  // High-Z, controlled from Expansion IO
assign pll_hi_o  = 1'b0;
assign pll_lo_o  = 1'b1;



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
  .SW (20)
) sys_bus_interconnect (
  .pll_locked_i(pll_locked),
  .bus_m (ps_sys),
  .bus_s (sys)
);

// silence unused busses
generate
for (genvar i=6; i<8; i++) begin: for_sys
  sys_bus_stub sys_bus_stub_5_7 (sys[i]);
end: for_sys
endgenerate

//assign par_dat = 16'h0;

assign daisy_trig = |par_dat;
assign trig_ext   = gpio.i[GDW] & ~(daisy_mode[0] & daisy_trig);
////////////////////////////////////////////////////////////////////////////////
// Analog mixed signals (PDM analog outputs)
////////////////////////////////////////////////////////////////////////////////

logic [4-1:0] [8-1:0] pdm_cfg;

red_pitaya_ams i_ams (
  // power test
  .clk_i           (adc_clk ),  // clock
  .rstn_i          (adc_rstn),  // reset - active low
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
  .clk   (adc_clk ),
  .rstn  (adc_rstn),
  // configuration
  .cfg   (pdm_cfg),
  .ena      (1'b1),
  .rng      (8'd255),
  // PWM outputs
  .pdm (dac_pwm_o)
);

////////////////////////////////////////////////////////////////////////////////
// ADC IO
////////////////////////////////////////////////////////////////////////////////

wire          [ 5-1:0] adc_dat_p_in  ;
wire          [ 5-1:0] adc_dat_n_in  ;
wire          [ 5-1:0] adc_ser       ;
wire                   adc_dclk_in   ;
logic [2-1:0] [16-1:0] adc_dat_raw   ;
logic                  adc_dat_rdv   ;


// generating clock for ADC
//ODDR #(.DDR_CLK_EDGE ("SAME_EDGE")) ODDR_dclk (.Q(adc_dclk_out), .C(pll_adc_dclk), .R(!frstn[0]), .D1(1'b1), .D2(1'b0), .CE(1'b1), .S(1'b0)); // lanes inverted!!

assign adc_dat_p_in = {adc_datb_i[1][1], adc_datb_i[0][1], adc_data_i[1][1], adc_data_i[0][1], adc_fclk_i[1]} ;
assign adc_dat_n_in = {adc_datb_i[1][0], adc_datb_i[0][0], adc_data_i[1][0], adc_data_i[0][0], adc_fclk_i[0]} ;

OBUFDS  i_OBUFDS_adc_dco       (.I (pll_adc_dclk ), .O  (adc_dclk_o[1]), .OB (adc_dclk_o[0]));
IBUFGDS i_IBUFGDS_adc_dco      (.I (adc_dclk_i[1]), .IB (adc_dclk_i[0]), .O  (adc_dclk_in)  );
IBUFDS  i_IBUFDS_adc_dat [4:0] (.I (adc_dat_p_in),  .IB (adc_dat_n_in),  .O  (adc_ser)      );

//(* IODELAY_GROUP = adc_inputs *) // Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
IDELAYCTRL i_idelayctrl (.RDY(idly_rdy), .REFCLK(fclk[3]), .RST(!frstn[3]) );



reg       adc_en;
reg [7:0] adc_en_cnt;

always @(posedge fclk[0]) begin
  if (!frstn[0] || !fpll_locked_r3)
    adc_en_cnt <= 8'h0;
  else if (!adc_en_cnt[7])
    adc_en_cnt <= adc_en_cnt + 8'h1;

  adc_en <= adc_en_cnt[7];
end


adc366x_top i_adc366x
(
   // serial ports
  .ser_clk_i       (  adc_dclk_in    ),  //!< RX high-speed (LVDS-bit) clock
  .ser_dat_i       (  adc_ser        ),  //!< RX high-speed data/frame
  .ser_inv_i       (  ser_inv        ),  //!< lane invert

   // configuration
  .cfg_clk_i       (  fclk[0]        ),  //!< Configuration clock
  .cfg_en_i        (  adc_en         ),  //!< global module enable
  .cfg_dly_i       (  ser_ddly       ),  //!< delay control
  .cfg_bslip_o     (  bitslip        ),

   // parallel ports
  .adc_clk_i       (  adc_clk        ),  //!< parallel clock
  .adc_dat_o       (  adc_dat_raw    ),  //!< parallel data
  .adc_dv_o        (  adc_dat_rdv    )   //!< parallel valid
);


// ADC SPI
assign adc_sen_o    = hk_spi_cs;
assign adc_sclk_o   = hk_spi_clk;
assign hk_spi_i     = adc_sdio_io;
assign adc_sdio_io  = hk_spi_t ? 1'bz : hk_spi_o ;

assign adc_rst_o   = 1'b0 ;   // ADC reset
assign adc_pdn_o   = 1'b0 ;   // ADC power down


// optional digital loop
assign adc_dat[0] = digital_loop[0] ? dac_a : adc_dat_raw[0][16-1 -: 14];
assign adc_dat[1] = digital_loop[0] ? dac_b : adc_dat_raw[1][16-1 -: 14];
assign adc_dv     = digital_loop[0] ? 1'b1  : adc_dat_rdv;


////////////////////////////////////////////////////////////////////////////////
// DAC IO
////////////////////////////////////////////////////////////////////////////////

// Sumation of ASG and PID signal perform saturation before sending to DAC 
assign dac_a_sum = asg_dat[0] + pid_dat[0];
assign dac_b_sum = asg_dat[1] + pid_dat[1];

// saturation
assign dac_a = (^dac_a_sum[15-1:15-2]) ? {dac_a_sum[15-1], {13{~dac_a_sum[15-1]}}} : dac_a_sum[14-1:0];
assign dac_b = (^dac_b_sum[15-1:15-2]) ? {dac_b_sum[15-1], {13{~dac_b_sum[15-1]}}} : dac_b_sum[14-1:0];

// output registers + signed to unsigned (also to negative slope)
always @(posedge dac_clk_1x)
begin
  dac_dat_a <= {dac_a[14-1], ~dac_a[14-2:0]};
  dac_dat_b <= {dac_b[14-1], ~dac_b[14-2:0]};
 // Loopback is for demonstration only. We avoid constraining for timing optimizations.
 // Channels inverted in HW
  dac_data_o <= digital_loop[1] ? {adc_dat_raw[1][16-1], ~adc_dat_raw[1][15-1 -: 13]} : dac_dat_b ;
  dac_datb_o <= digital_loop[1] ? {adc_dat_raw[0][16-1], ~adc_dat_raw[0][15-1 -: 13]} : dac_dat_a ;
end

// DDR outputs
ODDR oddr_dac_wrta (.Q(dac_wrta_o), .D1(1'b0  ), .D2(1'b1  ), .C(dac_clk_1p), .CE(1'b1), .R(1'b0 ), .S(1'b0));
ODDR oddr_dac_wrtb (.Q(dac_wrtb_o), .D1(1'b0  ), .D2(1'b1  ), .C(dac_clk_1p), .CE(1'b1), .R(1'b0 ), .S(1'b0));



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

red_pitaya_hk_ll i_hk (
  // system signals
  .clk_i           (adc_clk     ),  // clock
  .rstn_i          (adc_rstn    ),  // reset - active low
  .fclk_i          (fclk[0]     ),  // clock
  .frstn_i         (frstn[0]    ),  // reset - active low
  // LED
  .led_o           ( led_o      ),  // LED output
  // global configuration
  .digital_loop    (digital_loop),
  .daisy_mode_o    (daisy_mode),
  // SPI
  .spi_cs_o        (hk_spi_cs   ),
  .spi_clk_o       (hk_spi_clk  ),
  .spi_miso_i      (hk_spi_i    ),
  .spi_mosi_t      (hk_spi_t    ),
  .spi_mosi_o      (hk_spi_o    ),
  // Expansion connector
  .exp_p_dat_i     (exp_p_in ),  // input data
  .exp_p_dat_o     (exp_p_out),  // output data
  .exp_p_dir_o     (exp_p_dir),  // 1-output enable
  .exp_n_dat_i     (exp_n_in ),
  .exp_n_dat_o     (exp_n_out),
  .exp_n_dir_o     (exp_n_dir),
  .can_on_o        (can_on   ),

  .ser_ddly_o      (ser_ddly[25-1:0]),
  .new_ddly_o      (ser_ddly[26-1]),
  .ser_inv_o       (ser_inv     ),
  .cfg_bslip_i     (  bitslip        ),

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
// LED
////////////////////////////////////////////////////////////////////////////////

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
// oscilloscope
////////////////////////////////////////////////////////////////////////////////


red_pitaya_scope #(
   .ADC_DW(ADC_DW))
i_scope (
  // ADC
  .adc_a_i       (adc_dat[0]  ),  // CH 1
  .adc_b_i       (adc_dat[1]  ),  // CH 2
  .adc_clk_i     (adc_clk     ),  // clock
  .adc_rstn_i    (adc_rstn    ),  // reset - active low
  .trig_ext_i    (trig_ext    ),  // external trigger
  .trig_asg_i    (trig_asg_out),  // ASG trigger
  .trig_ext_asg_o(trig_ext_asg01),
  .trig_ext_asg_i(trig_ext_asg01),
  .daisy_trig_o  (scope_trigo ),
  // AXI0 master                 // AXI1 master
  .axi0_waddr_o  (axi0_sys.waddr ),  .axi1_waddr_o  (axi1_sys.waddr ),
  .axi0_wdata_o  (axi0_sys.wdata ),  .axi1_wdata_o  (axi1_sys.wdata ),
  .axi0_wsel_o   (axi0_sys.wsel  ),  .axi1_wsel_o   (axi1_sys.wsel  ),
  .axi0_wvalid_o (axi0_sys.wvalid),  .axi1_wvalid_o (axi1_sys.wvalid),
  .axi0_wlen_o   (axi0_sys.wlen  ),  .axi1_wlen_o   (axi1_sys.wlen  ),
  .axi0_wfixed_o (axi0_sys.wfixed),  .axi1_wfixed_o (axi1_sys.wfixed),
  .axi0_werr_i   (axi0_sys.werr  ),  .axi1_werr_i   (axi1_sys.werr  ),
  .axi0_wrdy_i   (axi0_sys.wrdy  ),  .axi1_wrdy_i   (axi1_sys.wrdy  ),
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
//  DAC arbitrary signal generator
////////////////////////////////////////////////////////////////////////////////


red_pitaya_asg i_asg (
   // DAC
  .dac_a_o         (asg_dat[0]  ),  // CH 1
  .dac_b_o         (asg_dat[1]  ),  // CH 2
  .dac_clk_i       (adc_clk     ),  // clock
  .dac_rstn_i      (adc_rstn    ),  // reset - active low
  .trig_a_i        (trig_ext    ),
  .trig_b_i        (trig_ext    ),
  .trig_out_o      (trig_asg_out),

  .axi_a_sys       (axi2_sys    ),
  .axi_b_sys       (axi3_sys    ),
  // System bus
  .sys_addr        (sys[2].addr ),
  .sys_wdata       (sys[2].wdata),
  .sys_wen         (sys[2].wen  ),
  .sys_ren         (sys[2].ren  ),
  .sys_rdata       (sys[2].rdata),
  .sys_err         (sys[2].err  ),
  .sys_ack         (sys[2].ack  )
);

////////////////////////////////////////////////////////////////////////////////
//  MIMO PID controller
////////////////////////////////////////////////////////////////////////////////

red_pitaya_pid i_pid (
   // signals
  .clk_i           (adc_clk   ),  // clock
  .rstn_i          (adc_rstn  ),  // reset - active low
  .dat_a_i         (adc_dat[0]),  // in 1
  .dat_b_i         (adc_dat[1]),  // in 2
  .dat_a_o         (pid_dat[0]),  // out 1
  .dat_b_o         (pid_dat[1]),  // out 2
  // System bus
  .sys_addr        (sys[3].addr ),
  .sys_wdata       (sys[3].wdata),
  .sys_wen         (sys[3].wen  ),
  .sys_ren         (sys[3].ren  ),
  .sys_rdata       (sys[3].rdata),
  .sys_err         (sys[3].err  ),
  .sys_ack         (sys[3].ack  )
);

////////////////////////////////////////////////////////////////////////////////
// Daisy test code
////////////////////////////////////////////////////////////////////////////////
//assign daisy_p_o =2'bzz;
//assign daisy_n_o =2'bzz;

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
  .par_clk_i       (  adc_clk                    ),  // data paralel clock
  .par_rstn_i      (  adc_rstn                   ),  // reset - active low
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
  .sys_clk_i       (  adc_clk                    ),  // clock
  .sys_rstn_i      (  adc_rstn                   ),  // reset - active low
  .sys_addr_i      (  sys[5].addr                ),
  .sys_sel_i       (                             ),
  .sys_wdata_i     (  sys[5].wdata               ),
  .sys_wen_i       (  sys[5].wen                 ),
  .sys_ren_i       (  sys[5].ren                 ),
  .sys_rdata_o     (  sys[5].rdata               ),
  .sys_err_o       (  sys[5].err                 ),
  .sys_ack_o       (  sys[5].ack                 )
);

endmodule: red_pitaya_top_ll
