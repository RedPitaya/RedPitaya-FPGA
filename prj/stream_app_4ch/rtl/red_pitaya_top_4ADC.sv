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
//`define SER_DLY

module red_pitaya_top_4ADC #(
  // identification
  bit [0:5*32-1] GITH = '0,
  // module numbers
  int unsigned MNA =  4, // number of acquisition modules
  int unsigned DWE = 8
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

// GPIO parameter
localparam int unsigned GDW = 8+8;
localparam IDW = 12;
localparam AW  = 20;

logic [4-1:0] fclk ; //[0]-125MHz, [1]-250MHz, [2]-50MHz, [3]-200MHz
logic [4-1:0] frstn;
logic         idly_rdy;

// PLL signals
logic [  2-1: 0]      adc_clk_in;
logic                 trig_out;
logic                 clk_125_0, clk_125_1;

//logic                 adc_clk_out;
//logic [  2-1: 0]      pll_adc_clk;
//logic                 pll_ser_clk;
//logic                 pll_pwm_clk;
logic                 rstn_125_0, rstn_125_1;
logic                 rstn_saxi;
logic [  2-1: 0]      pll_locked;
logic                 adc_10mhz;
logic                 spi_done; // ADC setup finished
wire external_trig;
wire trig_ext;

// fast serial signals
logic                 ser_clk ;
// PWM clock and reset
logic                 pwm_clk ;
logic                 pwm_rstn;

logic                 clksel;
//logic [4-1:0] fclk_clk ;
//logic [4-1:0] fclk_rstn;
//SPI CS
logic                 spi_cs;
assign spi_csa_o    = spi_cs; // only writes, no reads
assign spi_csb_o    = spi_cs;

// ADC clock/reset
//logic       clk_125_0 , clk_125_1 ;
//logic       adc_rstn_01, adc_rstn_23;

// stream bus type
localparam type SBA_T = logic signed [14-1:0];
SBA_T [MNA-1:0]          adc_dat, adc_dat_r;

// configuration
logic                    digital_loop;

// system bus
//sys_bus_if   ps_sys      (.clk (clk_125_0), .rstn (rstn_125_0));
//sys_bus_if   sys [8-1:0] (.clk (clk_125_0), .rstn (rstn_125_0));
//sys_bus_if   sys_adc_23  (.clk (clk_125_1), .rstn (rstn_125_1));
////////////////////////////////////////////////////////////////////////////////
// PLL (clock and reset)
////////////////////////////////////////////////////////////////////////////////

// diferential clock input
IBUFDS i_clk_01 (.I (adc_clk_i[0][1]), .IB (adc_clk_i[0][0]), .O (adc_clk_in[0]));  // differential clock input
IBUFDS i_clk_23 (.I (adc_clk_i[1][1]), .IB (adc_clk_i[1][0]), .O (adc_clk_in[1]));  // differential clock input

red_pitaya_pll_4adc pll_01 (
  // inputs
  .clk         (adc_clk_in[0]),  // clock
  .rstn        (spi_done  ),  // reset - active low
  // output clocks
  .clk_10mhz   (pll_adc_10mhz ),  // ADC divided to 10MHz
  // status outputs
  .pll_locked  (pll_locked[0])
);

BUFG bufg_adc_10MHz  (.O (adc_10mhz ), .I (pll_adc_10mhz ));

logic [32-1:0] locked_pll_cnt, locked_pll_cnt_r, locked_pll_cnt_r2 ;
always @(posedge fclk[0]) begin
  if (~frstn[0])
    locked_pll_cnt <= 'h0;
  else if (~pll_locked)
    locked_pll_cnt <= locked_pll_cnt + 'h1;
end

always @(posedge clk_125_0) begin
  locked_pll_cnt_r  <= locked_pll_cnt;
  locked_pll_cnt_r2 <= locked_pll_cnt_r;
end

wire [2-1:0] adc_clks;
assign adc_clks={clk_125_1, clk_125_0};

axi4_if #(.DW (32), .AW (AW), .IW (IDW), .LW (4)) axi_gp (.ACLK (fclk[2]), .ARESETn (rstn_saxi));
sys_bus_if   ps_sys      (.clk (fclk[2]), .rstn (rstn_saxi));

axi4_slave #(
  .DW (32),
  .AW (AW),
  .IW (IDW)
) axi_slave_gp0 (
  // AXI bus
  .axi       (axi_gp),
  // system read/write channel
  .bus       (ps_sys)
);

reg [32-1:0] led_cnt;
reg          clk_rec_blnk='h0;

always @(posedge clk_125_0) //shows FPGA is loaded and has a clock
begin
  if (~rstn_125_0) begin
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

reg [32-1:0] led_cnt2;
reg          clk_rec_blnk2='h0;
always @(posedge clk_125_0) //shows FPGA is loaded and has a clock
begin
  if (~rstn_125_0) begin
    led_cnt2 <= 32'h0;
    clk_rec_blnk2 <= 'h0;
  end else begin 
    if (led_cnt2 < 32'd62500000)
      led_cnt2 <= led_cnt2 + 'h1;
    else begin
      led_cnt2 <= 32'h0;
      clk_rec_blnk2 <= ~clk_rec_blnk2;
    end
  end
end

reg [32-1:0] val_cnt;
always @(posedge fclk[2]) //shows FPGA is loaded and has a clock
begin
  if (~frstn[2]) begin
    val_cnt <= 32'h0;
  end else begin 
    if (axi_gp.RVALID) begin
      val_cnt <= val_cnt + 'h1;
    end
  end
end

assign led_o = {5'h0,clk_rec_blnk2,~rstn_125_0,clk_rec_blnk};
wire adc_clk_out = clk_125_0;

/*reg [10-1:0] daisy_cnt      =  'h0;
reg          daisy_slave    = 1'b0;

always @(posedge clk_125_0) begin // if there is a clock present on the daisy chain connector, the board will be treated as a slave
  if (~rstn_125_0) begin
    daisy_cnt     <= 'h0;
    daisy_slave <= 1'b0;
  end else begin 
    daisy_cnt <= daisy_cnt + 'h1;
    if (&daisy_cnt)
      daisy_slave <= 1'b1;
  end
end*/

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

always @(posedge clk_125_0) begin
  adc_dat_r[0] <= {adc_dat_raw[0][14-1], ~adc_dat_raw[0][14-2:0]};
  adc_dat_r[1] <= {adc_dat_raw[1][14-1], ~adc_dat_raw[1][14-2:0]};

  adc_dat  [0] <= adc_dat_r[0];
  adc_dat  [1] <= adc_dat_r[1];
end

always @(posedge clk_125_0) begin
  adc_dat_r[2] <= {adc_dat_raw[2][14-1], ~adc_dat_raw[2][14-2:0]};
  adc_dat_r[3] <= {adc_dat_raw[3][14-1], ~adc_dat_raw[3][14-2:0]};

  adc_dat  [2] <= adc_dat_r[2];
  adc_dat  [3] <= adc_dat_r[3];
end

////////////////////////////////////////////////////////////////////////////////
//  House Keeping
////////////////////////////////////////////////////////////////////////////////

logic [DWE-1: 0] exp_p_in , exp_n_in ;
logic [DWE-1: 0] exp_p_out, exp_n_out;
logic [DWE-1: 0] exp_p_dir, exp_n_dir;

red_pitaya_hk_4adc #(.DWE(DWE)) i_hk (
  // system signals
  .clk_i           (fclk[2] ),  // clock
  .rstn_i          (rstn_saxi),  // reset - active low
  .fclk_i          (fclk[0] ),  // clock
  .frstn_i         (frstn[0]),  // reset - active low
  .spi_done_o      (spi_done),  // PLL reset
  // LED
  //.led_o           (led_o       ),  // LED output
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
  .diag_i          (locked_pll_cnt_r2),

  // Expansion connector
  .exp_p_dat_i     (exp_p_in ),  // input data
  .exp_p_dat_o     (exp_p_out),  // output data
  .exp_p_dir_o     (exp_p_dir),  // 1-output enable
  .exp_n_dat_i     (exp_n_in ),
  .exp_n_dat_o     (exp_n_out),
  .exp_n_dir_o     (exp_n_dir),
   // System bus
  .sys_addr        (ps_sys.addr ),
  .sys_wdata       (ps_sys.wdata),
  .sys_wen         (ps_sys.wen  ),
  .sys_ren         (ps_sys.ren  ),
  .sys_rdata       (ps_sys.rdata),
  .sys_err         (ps_sys.err  ),
  .sys_ack         (ps_sys.ack  )
);

////////////////////////////////////////////////////////////////////////////////
//  System
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
        // FCLKs
        .FCLK_CLK0         (fclk[0]      ),
        .FCLK_CLK1         (fclk[1]      ),
        .FCLK_CLK2         (fclk[2]      ),
        .FCLK_CLK3         (fclk[3]      ),
        .FCLK_RESET0_N     (frstn[0]     ),
        .FCLK_RESET1_N     (frstn[1]     ),
        .FCLK_RESET2_N     (frstn[2]     ),
        .FCLK_RESET3_N     (frstn[3]     ),
     //   .HK_AXI_ACLK    (axi_gp.ACLK   ),
      //  .HK_AXI_ARESETn (axi_gp.ARESETn),
        .HK_AXI_arvalid (axi_gp.ARVALID),
        .HK_AXI_awvalid (axi_gp.AWVALID),
        .HK_AXI_bready  (axi_gp.BREADY ),
        .HK_AXI_rready  (axi_gp.RREADY ),
        .HK_AXI_wlast   (axi_gp.WLAST  ),
        .HK_AXI_wvalid  (axi_gp.WVALID ),
        .HK_AXI_arid    (axi_gp.ARID   ),
        .HK_AXI_awid    (axi_gp.AWID   ),
        .HK_AXI_wid     (axi_gp.WID    ),
        .HK_AXI_arburst (axi_gp.ARBURST),
        .HK_AXI_arlock  (axi_gp.ARLOCK ),
        .HK_AXI_arsize  (axi_gp.ARSIZE ),
        .HK_AXI_awburst (axi_gp.AWBURST),
        .HK_AXI_awlock  (axi_gp.AWLOCK ),
        .HK_AXI_awsize  (axi_gp.AWSIZE ),
        .HK_AXI_arprot  (axi_gp.ARPROT ),
        .HK_AXI_awprot  (axi_gp.AWPROT ),
        .HK_AXI_araddr  (axi_gp.ARADDR ),
        .HK_AXI_awaddr  (axi_gp.AWADDR ),
        .HK_AXI_wdata   (axi_gp.WDATA  ),
        .HK_AXI_arcache (axi_gp.ARCACHE),
        .HK_AXI_arlen   (axi_gp.ARLEN  ),
        .HK_AXI_arqos   (axi_gp.ARQOS  ),
        .HK_AXI_awcache (axi_gp.AWCACHE),
        .HK_AXI_awlen   (axi_gp.AWLEN  ),
        .HK_AXI_awqos   (axi_gp.AWQOS  ),
        .HK_AXI_wstrb   (axi_gp.WSTRB  ),
        .HK_AXI_arready (axi_gp.ARREADY),
        .HK_AXI_awready (axi_gp.AWREADY),
        .HK_AXI_bvalid  (axi_gp.BVALID ),
        .HK_AXI_rlast   (axi_gp.RLAST  ),
        .HK_AXI_rvalid  (axi_gp.RVALID ),
        .HK_AXI_wready  (axi_gp.WREADY ),
        .HK_AXI_bid     (axi_gp.BID    ),
        .HK_AXI_rid     (axi_gp.RID    ),
        .HK_AXI_bresp   (axi_gp.BRESP  ),
        .HK_AXI_rresp   (axi_gp.RRESP  ),
        .HK_AXI_rdata   (axi_gp.RDATA  ),

        .trig_in        (external_trig),
        .trig_out       (trig_out),
        .gpio_trig      (gpio_trig),
        .adc_clk0       (adc_clk_in[0]),
        .adc_clk1       (adc_clk_in[1]),
        .clk_out125_0   (clk_125_0),
        .clk_out125_1   (clk_125_1),
        .rstn_out_0     (rstn_125_0),
        .rstn_out_1     (rstn_125_1),
        .rstn_saxi      (rstn_saxi),
        .clksel         (clksel),
        //.daisy_slave    (daisy_slave),
        .daisy_slave    (1'b0),
        .gpio_p         (exp_p_io),
        .gpio_n         (exp_n_io),
        .spi_done       (spi_done),
        .adc_data_ch1   (adc_dat[0]),
        .adc_data_ch2   (adc_dat[1]),
        .adc_data_ch3   (adc_dat[2]),
        .adc_data_ch4   (adc_dat[3]));
/*
OBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18"), .SLEW ("FAST")) i_OBUF_trig
(
  .O  ( daisy_p_o[0]  ),
  .OB ( daisy_n_o[0]  ),
  .I  ( trig_out      )
);

OBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18"), .SLEW ("FAST")) i_OBUF_clk
(
  .O  ( daisy_p_o[1]  ),
  .OB ( daisy_n_o[1]  ),
  .I  ( adc_clk_in[0] )
);

IBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18")) i_IBUF_clkdaisy
(
  .I  ( daisy_p_i[1]  ),
  .IB ( daisy_n_i[1]  ),
  .O  ( adc_clk_daisy )
);

IBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18")) i_IBUFDS_trig
(
  .I  ( daisy_p_i[0]  ),
  .IB ( daisy_n_i[0]  ),
  .O  ( trig_ext      )
);

*/

OBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18"), .SLEW ("FAST")) i_OBUF_trig
(
  .O  ( daisy_p_o[0]  ),
  .OB ( daisy_n_o[0]  ),
  .I  ( 1'b0          )
);

OBUFDS #(.IOSTANDARD ("DIFF_HSTL_I_18"), .SLEW ("FAST")) i_OBUF_clk
(
  .O  ( daisy_p_o[1]  ),
  .OB ( daisy_n_o[1]  ),
  .I  ( 1'b0          )
);

assign external_trig = trig_ext | gpio_trig;

endmodule