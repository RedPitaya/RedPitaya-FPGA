////////////////////////////////////////////////////////////////////////////////
// ADC366x receiver, de-serialize data
// other application modules.
// Authors: Matej Oblak
// (c) Red Pitaya  http://www.redpitaya.com
////////////////////////////////////////////////////////////////////////////////



module adc366x_top
#( parameter LW = 2        , // 2-lane or 1-lane interface
   parameter SW = LW*2 + 1  
)
(
   // serial ports
   input                 ser_clk_i       ,  //!< RX high-speed (LVDS-bit) clock
   input      [ SW-1: 0] ser_dat_i       ,  //!< RX high-speed data/frame
   input      [ SW-1: 0] ser_inv_i       ,  //!< lane invert

   // configuration
   input                 cfg_clk_i       ,  //!< Configuration clock
   input                 cfg_en_i        ,  //!< global module enable
   input      [ 26-1: 0] cfg_dly_i       ,  //!< delay control
   output     [  3-1: 0] cfg_bslip_o     ,

   // parallel ports
   input                 adc_clk_i       ,  //!< parallel clock
   output reg [ 32-1: 0] adc_dat_o       ,  //!< parallel data
   output reg            adc_dv_o           //!< parallel valid
);


genvar GV;
localparam BDIV = 8/LW  ;
localparam PDW  = 16/LW ;

wire ser_clk ;
wire par_clk ;

wire dly_new;

sync #(.DW (1), .PULSE (1) ) i_drst (
  .sclk_i (cfg_clk_i),  .srstn_i (cfg_en_i),  .src_i (cfg_dly_i[25] ),
  .dclk_i (par_clk  ),  .drstn_i (cfg_en_i),  .dst_o (    dly_new  ) );



//---------------------------------------------------------------------------------
//
//  CLOCK
wire ser_clk_in = ser_clk_i; // lanes inverted

BUFIO bufio_inst (
  .O  (  ser_clk      ),  // Clock buffer output
  .I  (  ser_clk_in   )   // Clock buffer input
);


BUFR #(
//  .BUFR_DIVIDE ( BDIV      ),  // Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8" 
  .BUFR_DIVIDE ( "4"       ),  // Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8" 
  .SIM_DEVICE  ( "7SERIES" )   // Must be set to "7SERIES" 
)
BUFR_inst
(
  .O   ( par_clk      ),  // 1-bit output: Clock output port
  .CE  ( 1'b1         ),  // 1-bit input: Active high, clock enable (Divided modes only)
  .CLR ( 1'b0         ),  // 1-bit input: Active high, asynchronous clear (Divided modes only)
  .I   ( ser_clk_in   )   // 1-bit input: Clock buffer input driven by an IBUF, MMCM or local interconnect
);




//---------------------------------------------------------------------------------
//
//  De-serialize - data/frame

reg  [SW*PDW-1: 0] par_out   =  'h0 ;
reg  [     3-1: 0] slip_cnt  = 3'h0 ;

assign cfg_bslip_o = slip_cnt;

generate
for (GV=0; GV < SW; GV=GV+1) begin:ser_dat

  wire           ddly ;
  wire [ 5-1: 0] dlyc ;
  wire [ 8-1: 0] q    ;
  reg  [ 8-1: 0] qq   ;
  reg  [ 8-1: 0] qqq  ;
  reg            rst  ;

  reg  [ 5-1: 0] cur_dly   ;

  always @(posedge par_clk ) begin
    cur_dly <= cfg_dly_i[GV*5 +: 5]  ;
  end

  IDELAYE2 #(
    .CINVCTRL_SEL          ( "FALSE"     ),  // Enable dynamic clock inversion (FALSE, TRUE)
    .DELAY_SRC             ( "IDATAIN"   ),  // Delay input (IDATAIN, DATAIN)
    .HIGH_PERFORMANCE_MODE ( "TRUE"      ),  // Reduced jitter ("TRUE"), Reduced power ("FALSE")
    .IDELAY_TYPE           ( "VAR_LOAD"  ),  // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
    .IDELAY_VALUE          ( 0           ),  // Input delay tap setting (0-31)
    .PIPE_SEL              ( "FALSE"     ),  // Select pipelined mode, FALSE, TRUE
    .REFCLK_FREQUENCY      ( 200.0       ),  // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
    .SIGNAL_PATTERN        ( "DATA"      )   // DATA, CLOCK input signal
  )
   idelay
  (
    .CNTVALUEOUT(  dlyc            ),   // 5-bit output: Counter value output
    .DATAOUT    (  ddly            ),   // 1-bit output: Delayed data output
    .C          (  cfg_clk_i       ),   // 1-bit input: Clock input
    .CE         (  1'b0            ),   // 1-bit input: Active high enable increment/decrement input
    .CINVCTRL   (  1'b0            ),   // 1-bit input: Dynamic clock inversion input
    .CNTVALUEIN (  cur_dly         ),   // 5-bit input: Counter value input
    .DATAIN     (  1'b0            ),   // 1-bit input: Internal delay data input
    .IDATAIN    (  ser_dat_i[GV]   ),   // 1-bit input: Data input from the I/O
    .INC        (  1'b0            ),   // 1-bit input: Increment / Decrement tap delay input
    .LD         (  dly_new         ),   // 1-bit input: Load IDELAY_VALUE input
    .LDPIPEEN   (  1'b1            ),   // 1-bit input: Enable PIPELINE register to load data input
    .REGRST     ( !cfg_en_i        )    // 1-bit input: Active-high reset tap-delay input
  );

//  assign ddly = ser_dat_i[GV];

  always @(posedge par_clk) begin
    qq  <= ser_inv_i[GV] ? ~q[7:0] : q[7:0] ;
    qqq <= qq     ;
    rst <= !cfg_en_i ;
  end

  if (PDW==8) begin
    always @(posedge par_clk) begin
      case (slip_cnt)
        3'h0 : par_out[8*GV +: 8] <= {qqq             } ;
        3'h1 : par_out[8*GV +: 8] <= {qq[  0],qqq[7:1]} ;
        3'h2 : par_out[8*GV +: 8] <= {qq[1:0],qqq[7:2]} ;
        3'h3 : par_out[8*GV +: 8] <= {qq[2:0],qqq[7:3]} ;
        3'h4 : par_out[8*GV +: 8] <= {qq[3:0],qqq[7:4]} ;
        3'h5 : par_out[8*GV +: 8] <= {qq[4:0],qqq[7:5]} ;
        3'h6 : par_out[8*GV +: 8] <= {qq[5:0],qqq[7:6]} ;
        3'h7 : par_out[8*GV +: 8] <= {qq[6:0],qqq[7  ]} ;
      endcase
    end
  end


  // Serdes
  ISERDESE2 #(
    .DATA_RATE("DDR"),           // DDR, SDR
    .DATA_WIDTH(8),              // Parallel data width (2-8,10,14)
    .DYN_CLKDIV_INV_EN("FALSE"), // Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
    .DYN_CLK_INV_EN("TRUE"),    // Enable DYNCLKINVSEL inversion (FALSE, TRUE)        -- INVERTED in HW
    // INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
    .INIT_Q1(1'b0),
    .INIT_Q2(1'b0),
    .INIT_Q3(1'b0),
    .INIT_Q4(1'b0),
    .INTERFACE_TYPE("NETWORKING"),   // MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
    .IOBDELAY("IFD"),           // NONE, BOTH, IBUF, IFD
    .NUM_CE(2),                  // Number of clock enables (1,2)
    .OFB_USED("FALSE"),          // Select OFB path (FALSE, TRUE)
    .SERDES_MODE("MASTER"),      // MASTER, SLAVE
    // SRVAL_Q1 - SRVAL_Q4: Q output values when SR is used (0/1)
    .SRVAL_Q1(1'b0),
    .SRVAL_Q2(1'b0),
    .SRVAL_Q3(1'b0),
    .SRVAL_Q4(1'b0)
  )
  ISERDESE2_inst (
    .O    (            ),                       // 1-bit output: Combinatorial output
    // Q1 - Q8: 1-bit (each) output: Registered data outputs
    .Q1   (   q[7]     ),
    .Q2   (   q[6]     ),
    .Q3   (   q[5]     ),
    .Q4   (   q[4]     ),
    .Q5   (   q[3]     ),
    .Q6   (   q[2]     ),
    .Q7   (   q[1]     ),
    .Q8   (   q[0]     ),
    // SHIFTOUT1, SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
    .SHIFTOUT1( ),
    .SHIFTOUT2( ),
    .BITSLIP  (  1'b0      ),    // 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
                                 // CLKDIV when asserted (active High). Subsequently, the data seen on the Q1
                                 // to Q8 output ports will shift, as in a barrel-shifter operation, one
                                 // position every time Bitslip is invoked (DDR operation is different from
                                 // SDR).

    // CE1, CE2: 1-bit (each) input: Data register clock enable inputs
    .CE1          (  1'b1        ),
    .CE2          (  1'b1        ),
    .CLKDIVP      (  1'b0        ),     // 1-bit input: TBD
    // Clocks: 1-bit (each) input: ISERDESE2 clock input ports
    .CLK          (  ser_clk     ),     // 1-bit input: High-speed clock
    .CLKB         ( !ser_clk     ),     // 1-bit input: High-speed secondary clock
    .CLKDIV       (  par_clk     ),     // 1-bit input: Divided clock
    .OCLK         (  1'b0        ),     // 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY" 
    // Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
    .DYNCLKDIVSEL (  1'b0        ),     // 1-bit input: Dynamic CLKDIV inversion
    .DYNCLKSEL    (  1'b0        ),     // 1-bit input: Dynamic CLK/CLKB inversion
    // Input Data: 1-bit (each) input: ISERDESE2 data input ports
    .D            (  1'b0        ),     // 1-bit input: Data input
    .DDLY         (  ddly        ),     // 1-bit input: Serial data from IDELAYE2
    .OFB          (  1'b0        ),     // 1-bit input: Data feedback from OSERDESE2
    .OCLKB        (  1'b0        ),     // 1-bit input: High speed negative edge output clock
    .RST          (  rst         ),     // 1-bit input: Active high asynchronous reset
    // SHIFTIN1, SHIFTIN2: 1-bit (each) input: Data width expansion input ports
    .SHIFTIN1     (  1'b0        ),
    .SHIFTIN2     (  1'b0        )
  );




end
endgenerate






//---------------------------------------------------------------------------------
//
//  Bitslip logic to adjust to frame clock

wire            bitslip     ;
wire            bitslip_val ;
reg  [  6-1: 0] bitslip_dly = 6'h0 ;
wire [PDW-1: 0] frame       ;


assign frame       = par_out[PDW-1:0];
assign bitslip_val = ((frame === 8'hFF) || (frame === 8'h00))   ; // has to be all 1 or 0
assign bitslip     = bitslip_dly[0]  ;

always @(posedge par_clk) begin
    if (!cfg_en_i) begin
        bitslip_dly <= 6'h0 ;
    end
    else begin
        bitslip_dly <= { bitslip_dly[6-2:0], !bitslip_val && !(|bitslip_dly) } ;
    end
end

always @(posedge par_clk) begin
    if (!cfg_en_i)
      slip_cnt <= 3'h0 ;
    else
      slip_cnt <= slip_cnt + bitslip ;
end






//---------------------------------------------------------------------------------
//
//  Outputs
wire [16-1: 0] rawa ;
wire [16-1: 0] rawb ;
reg  [32-1: 0] par_dat_o ;
wire           par_clk_o ;
reg            par_dv    ;

assign rawa = par_out[PDW+16 +: 16]; // channels were inverted
assign rawb = par_out[PDW    +: 16];

if (PDW==8) begin
 always @(posedge par_clk_o) begin
   par_dv           <= bitslip_val;
   par_dat_o[15: 0] <= {rawa[8],rawa[0],rawa[9],rawa[1],rawa[10],rawa[2],rawa[11],rawa[3],  rawa[12],rawa[4],rawa[13],rawa[5],rawa[14],rawa[6],rawa[15],rawa[7]} ;
   par_dat_o[31:16] <= {rawb[8],rawb[0],rawb[9],rawb[1],rawb[10],rawb[2],rawb[11],rawb[3],  rawb[12],rawb[4],rawb[13],rawb[5],rawb[14],rawb[6],rawb[15],rawb[7]} ;
 end
end

BUFG i_adc_buf   (.O(par_clk_o), .I(par_clk));

//---------------------------------------------------------------------------------
//
//  Sync

always @(posedge adc_clk_i) begin
  adc_dat_o <= par_dat_o ;
  adc_dv_o  <= par_dv    ;//      !par_dv   ? 1'b0 : !adc_dv_o ;
end











endmodule

