/**
 * @brief Red Pitaya PLL module.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */

module red_pitaya_pll_ll (
  // inputs
  input  logic clk       ,  // clock
  input  logic rstn      ,  // reset - active low
  // output clocks
  output logic clk_adc   ,  // ADC clock - system
  output logic clk_dac_1x,  // DAC clock
  output logic clk_dac_1p,  // DAC clock - 90 phase
  output logic clk_ser   ,  // fast serial clock
  output logic clk_pdm   ,  // PDM clock
  // status outputs
  output logic pll_locked
);

logic clk_fb;
// DAC write strobe phase; CLKOUT3_PHASE below is DAC_CLK_PHASE + PHASE_OFFSET.
// -270 is the centre of the window both LL board types latch correctly in.
// Do not change it from a timing report - see below, the report is wrong here.
//
// Swept in 45 deg steps with OUT looped back to IN, on a STEMlab 65-16 TI v1.3
// and a STEMlab 125-14 TI v1.3, both running the same bitstream. Worst
// deviation of a sample from the line through its neighbours, both channels,
// 10 kHz to 1 MHz:
//
//   total phase       0    -45    -90   -135   -180   -225   -270   -315
//   65-16 TI         ok     ok    bad    bad   marg     ok     ok     ok
//   125-14 TI         -    bad    bad    bad    bad     ok     ok     ok
//
// The two windows overlap on -225..-315, and -270 sits in the middle of the
// overlap with a clean step either side on both boards. -315, the centre of
// the 65-16 window alone, is one step from the bad edge on the 125-14.
//
// At -270 the full loopback suite - sine from 1 kHz to 5 MHz, 0.1 to 2.0 Vpp,
// ramps both ways, triangle, square, both channels - shows no deviation above
// each board's own noise floor, against 21343 and 17704 bad samples on the
// 125-14 at -90.
//
// Static timing used to prefer -90, the middle of the bad zone, because the
// forwarded-clock declaration in sdc/red_pitaya_z20_ll.xdc analysed the wrong
// edge of dac_wrt. That is fixed there, and the analysis now agrees with the
// sweep: -270 closes with setup +0.928 and hold +1.780, -90 fails hold by
// 2.220 ns. The gate would have caught b780bce.
//
// The DAC2904 also requires the DAC CLK rising edge at or before the WRT rising
// edge, within tCW = 0..tPW-2 ns. That one is not constrained and cannot be:
// dac_clk_i to dac_wrt spans 6.94 ns between process corners against an 8 ns
// period, so the relationship sweeps most of the cycle and no phase here keeps
// it inside the 2 ns window. Missing it costs a sample of latency rather than
// data, which is why the boards measure clean either way. The analysis, the
// measured numbers per phase and what it would take to fix are in
// sdc/red_pitaya_z20_ll.xdc next to the dac_data_o constraints.
`define DAC_CLK_PHASE -225
`define PHASE_OFFSET -45

PLLE2_ADV #(
   .BANDWIDTH            ("OPTIMIZED"),
   .COMPENSATION         ("ZHOLD"    ),
   .DIVCLK_DIVIDE        ( 1         ),
   .CLKFBOUT_MULT        ( 8         ),
   .CLKFBOUT_PHASE       ( 0.000     ),
   .CLKOUT0_DIVIDE       ( 2         ), // 500 MHz
   .CLKOUT0_PHASE        ( 0.000     ),
   .CLKOUT0_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT1_DIVIDE       ( 8         ), // 125 MHz
   //.CLKOUT1_PHASE        ( 0.000     ),
   .CLKOUT1_PHASE        ( -45.000     ),
   .CLKOUT1_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT2_DIVIDE       ( 8         ), // 125 MHz -90 deg
   .CLKOUT2_PHASE        ( -90.000   ),
   .CLKOUT2_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT3_DIVIDE       ( 8         ), // 125 MHz -90 deg
   .CLKOUT3_PHASE        ( `DAC_CLK_PHASE + `PHASE_OFFSET ),
   //.CLKOUT3_PHASE        (-135.000   ),
   .CLKOUT3_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT4_DIVIDE       ( 4         ), // 4->250MHz, 2->500MHz
   .CLKOUT4_PHASE        ( 0.000     ),
   .CLKOUT4_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT5_DIVIDE       ( 4         ), // 250 MHz
   .CLKOUT5_PHASE        ( 0.000     ),
   .CLKOUT5_DUTY_CYCLE   ( 0.5       ),
   .CLKIN1_PERIOD        ( 8.000     ),
   .REF_JITTER1          ( 0.010     )
) pll (
   // Output clocks
   .CLKFBOUT     (clk_fb    ),
   .CLKOUT0      (          ),
   .CLKOUT1      (clk_adc   ),
   .CLKOUT2      (clk_dac_1x),
   .CLKOUT3      (clk_dac_1p),
   .CLKOUT4      (clk_ser   ),
   .CLKOUT5      (clk_pdm   ),
   // Input clock control
   .CLKFBIN      (clk_fb    ),
   .CLKIN1       (clk       ),
   .CLKIN2       (1'b0      ),
   // Tied to always select the primary input clock
   .CLKINSEL     (1'b1 ),
   // Ports for dynamic reconfiguration
   .DADDR        (7'h0 ),
   .DCLK         (1'b0 ),
   .DEN          (1'b0 ),
   .DI           (16'h0),
   .DO           (     ),
   .DRDY         (     ),
   .DWE          (1'b0 ),
   // Other control and status signals
   .LOCKED       (pll_locked),
   .PWRDWN       (1'b0      ),
   .RST          (!rstn     )
);

endmodule
