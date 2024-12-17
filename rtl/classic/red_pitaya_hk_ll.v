/**
 * $Id: red_pitaya_hk.v 961 2014-01-21 11:40:39Z matej.oblak $
 *
 * @brief Red Pitaya house keeping.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */

/**
 * GENERAL DESCRIPTION:
 *
 * House keeping module takes care of system identification.
 *
 *
 * This module takes care of system identification via DNA readout at startup and
 * ID register which user can define at compile time.
 *
 * Beside that it is currently also used to test expansion connector and for
 * driving LEDs.
 * 
 */

module red_pitaya_hk_ll #(
  parameter DWL = 8, // data width for LED
  parameter DWE = 8, // data width for extension
  parameter [57-1:0] DNA = 57'h0823456789ABCDE
)(
  // system signals
  input                clk_i      ,  // clock
  input                rstn_i     ,  // reset - active low

  input                fclk_i     ,  // clock
  input                frstn_i    ,  // reset - active low

  // LED
  output reg [DWL-1:0] led_o      ,  // LED output
  // global configuration
  output reg [  2-1:0] digital_loop,
  //SPI
  output               spi_cs_o,
  output               spi_clk_o,
  input                spi_miso_i,
  output               spi_mosi_t,
  output               spi_mosi_o,

  output reg [ 25-1:0] ser_ddly_o,  // data delay
  output reg           new_ddly_o,  // data delay load
  //output reg [  5-1:0] ser_inv_o ,  // lane invert

  // Expansion connector
  input      [DWE-1:0] exp_p_dat_i,  // exp. con. input data
  output reg [DWE-1:0] exp_p_dat_o,  // exp. con. output data
  output reg [DWE-1:0] exp_p_dir_o,  // exp. con. 1-output enable
  input      [DWE-1:0] exp_n_dat_i,  //
  output reg [DWE-1:0] exp_n_dat_o,  //
  output reg [DWE-1:0] exp_n_dir_o,  //
  output reg           can_on_o   ,

  // System bus
  input      [ 32-1:0] sys_addr   ,  // bus address
  input      [ 32-1:0] sys_wdata  ,  // bus write data
  input                sys_wen    ,  // bus write enable
  input                sys_ren    ,  // bus read enable
  output reg [ 32-1:0] sys_rdata  ,  // bus read data
  output reg           sys_err    ,  // bus error indicator
  output reg           sys_ack       // bus acknowledge signal
);

//---------------------------------------------------------------------------------
//
//  Read device DNA

wire           dna_dout ;
reg            dna_clk  ;
reg            dna_read ;
reg            dna_shift;
reg  [ 9-1: 0] dna_cnt  ;
reg  [57-1: 0] dna_value;
reg            dna_done ;

always @(posedge clk_i)
if (rstn_i == 1'b0) begin
  dna_clk   <=  1'b0;
  dna_read  <=  1'b0;
  dna_shift <=  1'b0;
  dna_cnt   <=  9'd0;
  dna_value <= 57'd0;
  dna_done  <=  1'b0;
end else begin
  if (!dna_done)
    dna_cnt <= dna_cnt + 1'd1;

  dna_clk <= dna_cnt[2] ;
  dna_read  <= (dna_cnt < 9'd10);
  dna_shift <= (dna_cnt > 9'd18);

  if ((dna_cnt[2:0]==3'h0) && !dna_done)
    dna_value <= {dna_value[57-2:0], dna_dout};

  if (dna_cnt > 9'd465)
    dna_done <= 1'b1;
end

// parameter specifies a sample 57-bit DNA value for simulation
DNA_PORT #(.SIM_DNA_VALUE (DNA)) i_DNA (
  .DOUT  ( dna_dout   ), // 1-bit output: DNA output data.
  .CLK   ( dna_clk    ), // 1-bit input: Clock input.
  .DIN   ( 1'b0       ), // 1-bit input: User data input pin.
  .READ  ( dna_read   ), // 1-bit input: Active high load DNA, active low read input.
  .SHIFT ( dna_shift  )  // 1-bit input: Active high shift enable input.
);

//---------------------------------------------------------------------------------
//
//  Desing identification

wire [32-1: 0] id_value;

assign id_value[31: 4] = 28'h0; // reserved
assign id_value[ 3: 0] =  4'h3; // board type  3 - low latency
                                //             2 - 250MHz
                                //             1 - release 1

//---------------------------------------------------------------------------------
//
//  SPI

reg           spi_do         ;
wire          spi_bsy        ;
reg  [ 15: 0] spi_wr_h       ;
reg  [ 15: 0] spi_wr_l       ;
wire [ 15: 0] spi_rd_l       ;

spi_master i_spi_adc
(
    // SPI ports
  .spi_cs_o           (spi_cs_o),
  .spi_clk_o          (spi_clk_o),
  .spi_miso_i         (spi_miso_i),
  .spi_mosi_t         (spi_mosi_t),
  .spi_mosi_o         (spi_mosi_o),

    // settings & status
  .clk_i              (clk_i),
  .rst_i              (rstn_i),

  .spi_start_i        (spi_do),

  .dat_wr_h_i         (spi_wr_h),  // data to write high part
  .dat_wr_l_i         (spi_wr_l),  // data to write low part
  .dat_rd_l_o         (spi_rd_l),  // data readed on low part

  .cfg_rw_i           (spi_wr_h[15]),  // config - 1-read 0-write
  .cfg_cs_act_i       (1'b1),  // config - active cs - ONLY ONE CS CAN BE ACTIVE FOR CORRECT READING !!
  .cfg_h_lng_i        (5'd16),  // config - h part length
  .cfg_l_lng_i        (5'd8),  // config - l part length
  .cfg_clk_presc_i    (8'd255),  // config - clk_i/presc -> spi_clk_o
  .cfg_clk_wr_edg_i   (1'b1),  // config - sent data on clock: 1-falling edge 0-rising edge
  .cfg_clk_rd_edg_i   (1'b1),  // config - read data on clock: 1-rising edge 0-falling edge
  .cfg_clk_idle_i     (1'b1),  // config - clock leven on idle
  .sts_spi_busy_o     (spi_bsy)   // status - spi state machine busy
);


//---------------------------------------------------------------------------------
//
//  Frequency meter
wire [32-1: 0] fmtr_freq  ;

freq_meter #(
  .GCL  ( 32'd15625000 ), // Gate counter length - 1/8 of s, 125000000/8
  .GCS  (  3           )  // Gate counter sections (1<<GCS)
) i_freq_meter
(
  // measured clock
  .mes_clk_i     (  clk_i        ),
  .mes_rstn_i    (  rstn_i       ),
  // reference clock
  .ref_clk_i     (  fclk_i       ),
  .ref_rstn_i    (  frstn_i      ),
  // result
  .freq_o        (  fmtr_freq    ),  // @ mes_clk_i
  .freq_ref_o    (               )   // @ ref_clk_i
);

//---------------------------------------------------------------------------------
//
// FPGA ready signal - device is out of reset
reg fpga_rdy;
always @(posedge clk_i) begin
if (rstn_i == 1'b0)
  fpga_rdy <= 1'b0;
else
  fpga_rdy <= 1'b1;
end

//---------------------------------------------------------------------------------
//
//  System bus connection

always @(posedge clk_i)
if (rstn_i == 1'b0) begin
  digital_loop <= 2'h0;
  led_o        <= {DWL{1'b0}};
  exp_p_dat_o  <= {DWE{1'b0}};
  exp_p_dir_o  <= {DWE{1'b0}};
  exp_n_dat_o  <= {DWE{1'b0}};
  exp_n_dir_o  <= {DWE{1'b0}};
  can_on_o     <= 1'b0;
  //ser_inv_o    <= 5'h8;
end else if (sys_wen) begin
  if (sys_addr[19:0]==20'h0c)   digital_loop <= sys_wdata[1:0];

  if (sys_addr[19:0]==20'h10)   exp_p_dir_o  <= sys_wdata[DWE-1:0];
  if (sys_addr[19:0]==20'h14)   exp_n_dir_o  <= sys_wdata[DWE-1:0];
  if (sys_addr[19:0]==20'h18)   exp_p_dat_o  <= sys_wdata[DWE-1:0];
  if (sys_addr[19:0]==20'h1C)   exp_n_dat_o  <= sys_wdata[DWE-1:0];

  if (sys_addr[19:0]==20'h30)   led_o        <= sys_wdata[DWL-1:0];
  if (sys_addr[19:0]==20'h34)   can_on_o     <= sys_wdata[      0];

  if (sys_addr[19:0]==20'h40)   ser_ddly_o   <= sys_wdata[ 25-1:0];
  //if (sys_addr[19:0]==20'h44)   ser_inv_o    <= sys_wdata[  5-1:0];

  if (sys_addr[19:0]==20'h50)   spi_wr_h     <= sys_wdata[ 16-1:0];
  if (sys_addr[19:0]==20'h54)   spi_wr_l     <= sys_wdata[ 16-1:0];
end


always @(posedge clk_i)
begin
  spi_do     <= (sys_addr[19:0]==20'h54) & sys_wen;
  new_ddly_o <= (sys_addr[19:0]==20'h40) & sys_wen;
end



wire sys_en;
assign sys_en = sys_wen | sys_ren;

always @(posedge clk_i)
if (rstn_i == 1'b0) begin
  sys_err <= 1'b0;
  sys_ack <= 1'b0;
end else begin
  sys_err <= 1'b0;

  casez (sys_addr[19:0])
    20'h00000: begin sys_ack <= sys_en;  sys_rdata <= {                id_value          }; end
    20'h00004: begin sys_ack <= sys_en;  sys_rdata <= {                dna_value[32-1: 0]}; end
    20'h00008: begin sys_ack <= sys_en;  sys_rdata <= {{64- 57{1'b0}}, dna_value[57-1:32]}; end
    20'h0000c: begin sys_ack <= sys_en;  sys_rdata <= {{32-  2{1'b0}}, digital_loop      }; end

    20'h00010: begin sys_ack <= sys_en;  sys_rdata <= {{32-DWE{1'b0}}, exp_p_dir_o}       ; end
    20'h00014: begin sys_ack <= sys_en;  sys_rdata <= {{32-DWE{1'b0}}, exp_n_dir_o}       ; end
    20'h00018: begin sys_ack <= sys_en;  sys_rdata <= {{32-DWE{1'b0}}, exp_p_dat_o}       ; end
    20'h0001C: begin sys_ack <= sys_en;  sys_rdata <= {{32-DWE{1'b0}}, exp_n_dat_o}       ; end
    20'h00020: begin sys_ack <= sys_en;  sys_rdata <= {{32-DWE{1'b0}}, exp_p_dat_i}       ; end
    20'h00024: begin sys_ack <= sys_en;  sys_rdata <= {{32-DWE{1'b0}}, exp_n_dat_i}       ; end

    20'h00030: begin sys_ack <= sys_en;  sys_rdata <= {{32-DWL{1'b0}}, led_o}             ; end
    20'h00034: begin sys_ack <= sys_en;  sys_rdata <= {{32-1{1'b0}},   can_on_o}          ; end

    20'h00040: begin sys_ack <= sys_en;  sys_rdata <= {{32- 25{1'b0}}, ser_ddly_o}        ; end
    //20'h00044: begin sys_ack <= sys_en;  sys_rdata <= {{32-  5{1'b0}}, ser_inv_o}         ; end

    20'h00050: begin sys_ack <= sys_en;  sys_rdata <= {16'h0,spi_wr_h}                    ; end
    20'h00054: begin sys_ack <= sys_en;  sys_rdata <= {16'h0,spi_wr_l}                    ; end
    20'h00058: begin sys_ack <= sys_en;  sys_rdata <= {15'h0,spi_bsy,  spi_rd_l}          ; end

    20'h00100: begin sys_ack <= sys_en;  sys_rdata <= {{32-  1{1'b0}}, fpga_rdy}          ; end
    20'h00104: begin sys_ack <= sys_en;  sys_rdata <= {                fmtr_freq}         ; end

      default: begin sys_ack <= sys_en;  sys_rdata <=  32'h0                              ; end
  endcase
end

endmodule
