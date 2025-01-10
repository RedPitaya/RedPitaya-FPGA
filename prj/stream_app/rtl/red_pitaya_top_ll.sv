//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
//Date        : Thu Oct 17 12:18:07 2019
//Host        : Jon-PC running 64-bit major release  (build 9200)
//Command     : generate_target system_wrapper.bd
//Design      : system_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module red_pitaya_top_ll #(
  // identification
  bit [0:5*32-1] GITH = '0,
  // module numbers
  int unsigned MNA = 2,  // number of acquisition modules
  int unsigned MNG = 2   // number of generator   modules
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

localparam RST_MAX = 64;

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


// DAC signals
logic                    dac_clk_1x;
logic                    dac_clk_2x;
logic                    dac_clk_2p;
logic                    dac_rst;

logic [4-1:0] fclk ; //[0]-125MHz, [1]-250MHz, [2]-50MHz, [3]-200MHz
logic [4-1:0] frstn;

logic          clksel;
logic [16-1:0] dac_dat_a, dac_dat_b;

// SPI to ADC not instantiated. ADC setup will be done by loading v0.94
// Will be added if required.
logic                    hk_spi_cs  = 1'b0; 
logic                    hk_spi_clk = 1'b0; 
logic                    hk_spi_i   ;
logic                    hk_spi_o   = 1'b0;
logic                    hk_spi_t   = 1'b0;

wire trig_out;
wire gpio_trig;
wire clk_125;
wire trig_ext;

localparam            ADC_IDLY = 5'h2;
logic [26-1:0]        ser_ddly = {1'b0,{5{ADC_IDLY}}};
logic [ 5-1:0]        ser_inv  = 5'h8;
logic                 bitslip;

////////////////////////////////////////////////////////////////////////////////
// PLL (clock and reset)
////////////////////////////////////////////////////////////////////////////////
assign dac_pwm_o = 4'h0;

reg [32-1:0] led_cnt;
reg          clk_rec_blnk='h0;

always @(posedge clk_125) //shows FPGA is loaded and has a clock
begin
  if (~rstn_0) begin
    led_cnt <= 32'h0;
    clk_rec_blnk <= 'h0;
  end else begin 
    if (led_cnt < 32'd62500000)
      led_cnt <= led_cnt + 'h1;
    else begin
      led_cnt <= 32'h0;
      clk_rec_blnk <= ~clk_rec_blnk;
    end
  end
end


IBUF i_clk (.I (dac_clk_i), .O (dac_clk_in));
assign rstn_pll = rstn_0 & ~(!fpll_locked_r2 && fpll_locked_r3);
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

// DAC reset (active high)
always @(posedge dac_clk_1x)
dac_rst  <= ~rstn_0 | ~rst_after_locked;

wire [ 4-1:0] loopback_sel_ch1, loopback_sel_ch2;
reg  [16-1:0] adc_dat_ch1,      adc_dat_ch2;
//reg  [16-1:0] adc_dat_ch1_r,    adc_dat_ch2_r;
reg  [14-1:0] dac_dat_a_o,      dac_dat_b_o;

always @(posedge dac_clk_1x)
begin
  dac_data_o <= {dac_dat_b[16-1], ~dac_dat_b[16-2:2]};
  dac_datb_o <= {dac_dat_a[16-1], ~dac_dat_a[16-2:2]};
end

// DDR outputs
ODDR oddr_dac_wrta (.Q(dac_wrta_o), .D1(1'b0  ), .D2(1'b1  ), .C(dac_clk_1p), .CE(1'b1), .R(1'b0 ), .S(1'b0));
ODDR oddr_dac_wrtb (.Q(dac_wrtb_o), .D1(1'b0  ), .D2(1'b1  ), .C(dac_clk_1p), .CE(1'b1), .R(1'b0 ), .S(1'b0));


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
  fpll_locked_r   <= pll_locked;
  fpll_locked_r2  <= fpll_locked_r;
  fpll_locked_r3  <= fpll_locked_r2;
end

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


always @(posedge clk_125) begin
  //adc_dat_ch1_r <= adc_dat_i[0];
  //adc_dat_ch2_r <= adc_dat_i[1];
  if (loopback_sel_ch1[1])
    adc_dat_ch1 <= {dac_dat_a[16-1],     ~dac_dat_a[16-2:2]};
  else
    adc_dat_ch1 <= adc_dat_raw[0][16-1 -: 14];

  if (loopback_sel_ch2[1])
    adc_dat_ch2 <= {dac_dat_b[16-1],     ~dac_dat_b[16-2:2]};
  else
    adc_dat_ch2 <= adc_dat_raw[1][16-1 -: 14];
end

reg [10-1:0] daisy_cnt      =  'h0;
reg          daisy_slave    = 1'b0;

always @(posedge adc_clk_daisy) begin // if there is a clock present on the daisy chain connector, the board will be treated as a slave
  if (~rstn_0) begin
    daisy_cnt     <= 'h0;
    daisy_slave <= 1'b0;
  end else begin 
    daisy_cnt <= daisy_cnt + 'h1;
    if (&daisy_cnt)
      daisy_slave <= 1'b1;
  end
end

assign led_o = {5'h0,daisy_slave,~rstn_0,clk_rec_blnk};

// ADC cannot be clocked by the daisy chained clock
// ODDR i_adc_clk_p ( .Q(adc_clk_o[0]), .D1(1'b1), .D2(1'b0), .C(adc_clk_daisy), .CE(1'b1), .R(1'b0), .S(1'b0));
// ODDR i_adc_clk_n ( .Q(adc_clk_o[1]), .D1(1'b0), .D2(1'b1), .C(adc_clk_daisy), .CE(1'b1), .R(1'b0), .S(1'b0));


// External PLL

assign clk_sel_o = 1'bz;  // High-Z, controlled from Expansion IO
assign pll_hi_o  = 1'b0;
assign pll_lo_o  = 1'b1;

////////////////////////////////////////////////////////////////////////////////
// DAC IO
////////////////////////////////////////////////////////////////////////////////

  //system_wrapper system_wrapper_i
  system system_wrapper_i
       (.DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .FCLK_CLK0         (fclk[0]      ),
        .FCLK_CLK1         (fclk[1]      ),
        .FCLK_CLK2         (fclk[2]      ),
        .FCLK_CLK3         (fclk[3]      ),
        .FCLK_RESET0_N     (frstn[0]     ),
        .FCLK_RESET1_N     (frstn[1]     ),
        .FCLK_RESET2_N     (frstn[2]     ),
        .FCLK_RESET3_N     (frstn[3]     ),
        .trig_in(external_trig),
        .gpio_trig(gpio_trig),
        .trig_out(trig_out),
        .clksel(clksel),
        .daisy_slave(daisy_slave),
        .adc_clk(dac_clk_in),
        .clk_out(clk_125),
        .rstn_out(rstn_0),
        .dac_dat_a(dac_dat_a),
        .dac_dat_b(dac_dat_b),
        .gpio_p(exp_p_io),
        .gpio_n(exp_n_io),
        .loopback_sel({loopback_sel_ch2,loopback_sel_ch1}),
        .adc_data_ch1(adc_dat_ch1),
        .adc_data_ch2(adc_dat_ch2));

OBUFDS #(.IOSTANDARD ("DIFF_HSTL18_I"), .SLEW ("FAST")) i_OBUF_trig
(
  .O  ( daisy_p_o[0]  ),
  .OB ( daisy_n_o[0]  ),
  .I  ( trig_out      )
);

OBUFDS #(.IOSTANDARD ("DIFF_HSTL18_I"), .SLEW ("FAST")) i_OBUF_clk
(
  .O  ( daisy_p_o[1]  ),
  .OB ( daisy_n_o[1]  ),
  .I  ( dac_clk_in    )
);

// IBUFDS #() i_IBUF_clkadc
// (
//   .I  ( adc_clk_i[1]  ),
//   .IB ( adc_clk_i[0]  ),
//   .O  ( adc_clk_in    )
// );

IBUFDS #(.IOSTANDARD ("DIFF_HSTL18_I")) i_IBUF_clkdaisy
(
  .I  ( daisy_p_i[1]  ),
  .IB ( daisy_n_i[1]  ),
  .O  ( adc_clk_daisy )
);

IBUFDS #(.IOSTANDARD ("DIFF_HSTL18_I")) i_IBUFDS_trig
(
  .I  ( daisy_p_i[0]  ),
  .IB ( daisy_n_i[0]  ),
  .O  ( trig_ext      )
);


assign external_trig = trig_ext | gpio_trig;

endmodule