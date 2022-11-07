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
  output logic clk_dclk  ,  // ADC DCO clock
  output logic clk_adc   ,  // ADC clock - system
  output logic clk_dac_1x,  // DAC clock
  output logic clk_dac_1p,  // DAC clock - 90 phase
  output logic clk_ser   ,  // fast serial clock
  output logic clk_pdm   ,  // PDM clock
  // status outputs
  output logic pll_locked
);

logic clk_fb;

PLLE2_ADV #(
   .BANDWIDTH            ("OPTIMIZED"),
   .COMPENSATION         ("ZHOLD"    ),
   .DIVCLK_DIVIDE        ( 1         ),
   .CLKFBOUT_MULT        ( 16        ),
   .CLKFBOUT_PHASE       ( 0.000     ),
   .CLKOUT0_DIVIDE       ( 4         ),  // 500MHz
   .CLKOUT0_PHASE        ( 0.000     ),
   .CLKOUT0_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT1_DIVIDE       ( 16        ),
   .CLKOUT1_PHASE        ( 0.000     ),
   .CLKOUT1_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT2_DIVIDE       ( 16        ),
   .CLKOUT2_PHASE        ( 0.000     ),
   .CLKOUT2_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT3_DIVIDE       ( 16        ),
   .CLKOUT3_PHASE        (-45.000    ),
   .CLKOUT3_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT4_DIVIDE       ( 8         ),  // 8->250MHz, 4->500MHz
   .CLKOUT4_PHASE        ( 0.000     ),
   .CLKOUT4_DUTY_CYCLE   ( 0.5       ),
   .CLKOUT5_DIVIDE       ( 8         ),
   .CLKOUT5_PHASE        ( 0.000     ),
   .CLKOUT5_DUTY_CYCLE   ( 0.5       ),
   .CLKIN1_PERIOD        ( 8.000     ),
   .REF_JITTER1          ( 0.010     )
) pll (
   // Output clocks
   .CLKFBOUT     (clk_fb    ),
   .CLKOUT0      (clk_dclk  ),
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
