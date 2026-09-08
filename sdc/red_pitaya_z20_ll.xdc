#
# $Id: red_pitaya.xdc 961 2014-01-21 11:40:39Z matej.oblak $
#
# @brief Red Pitaya location constraints.
#
# @Author Matej Oblak
#
# (c) Red Pitaya  http://www.redpitaya.com
#

############################################################################
# IO constraints                                                           #
############################################################################

### ADC

# ADC data
set_property -dict {IOSTANDARD DIFF_SSTL18_I  IOB TRUE }  [get_ports {adc_dat?_i[*][*]}]
set_property -dict {IOSTANDARD DIFF_SSTL18_I  IOB TRUE }  [get_ports {adc_?clk_?[*]}]

set_property PACKAGE_PIN Y6  [get_ports {adc_dclk_i[0]}] ; # ADDCLK_n
set_property PACKAGE_PIN Y7  [get_ports {adc_dclk_i[1]}] ; # ADDCLK_p
set_property PACKAGE_PIN Y8  [get_ports {adc_fclk_i[0]}] ; # ADFCLK_n
set_property PACKAGE_PIN Y9  [get_ports {adc_fclk_i[1]}] ; # ADFCLK_p
set_property PACKAGE_PIN U8  [get_ports {adc_data_i[0][0]}] ; # ADA0_n
set_property PACKAGE_PIN U9  [get_ports {adc_data_i[0][1]}] ; # ADA0_p
set_property PACKAGE_PIN Y11 [get_ports {adc_data_i[1][0]}] ; # ADA1_n
set_property PACKAGE_PIN W11 [get_ports {adc_data_i[1][1]}] ; # ADA1_p
set_property PACKAGE_PIN W8  [get_ports {adc_datb_i[0][0]}] ; # ADB0_n
set_property PACKAGE_PIN V8  [get_ports {adc_datb_i[0][1]}] ; # ADB0_p
set_property PACKAGE_PIN W9  [get_ports {adc_datb_i[1][0]}] ; # ADB1_n
set_property PACKAGE_PIN W10 [get_ports {adc_datb_i[1][1]}] ; # ADB1_p



# ADC CTRL
set_property -dict {IOSTANDARD LVCMOS33  SLEW SLOW  DRIVE 8  PACKAGE_PIN T17}  [get_ports adc_rst_o] ; # ADC_RESET
set_property -dict {IOSTANDARD LVCMOS33  SLEW SLOW  DRIVE 8  PACKAGE_PIN Y14}  [get_ports adc_pdn_o] ; # ADC_PDN

# ADC SPI
set_property -dict {IOSTANDARD LVCMOS18  SLEW SLOW  DRIVE 8  PACKAGE_PIN V5 }  [get_ports adc_sen_o]    ; # ADC_SEN
set_property -dict {IOSTANDARD LVCMOS18  SLEW SLOW  DRIVE 8  PACKAGE_PIN Y12}  [get_ports adc_sclk_o]   ; # ADC_SCLK
set_property -dict {IOSTANDARD LVCMOS18  SLEW SLOW  DRIVE 8  PACKAGE_PIN Y13}  [get_ports adc_sdio_io]  ; # ADC_SDIO





set_property -quiet -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y16} [get_ports -quiet out_sync_o]

### DAC

set_property -dict {IOSTANDARD LVCMOS33  SLEW FAST  DRIVE 8  IOB TRUE}  [get_ports {dac_wrt?_o}]
set_property -dict {IOSTANDARD LVCMOS33  SLEW FAST  DRIVE 8  IOB TRUE}  [get_ports {dac_dat?_o[*]}]

set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN U18 }  [get_ports dac_clk_i ] ; # FPGA-DAC_CLK
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN R19 }  [get_ports dac_wrta_o] ; # DAC_WRT1
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN T20 }  [get_ports dac_wrtb_o] ; # DAC_WRT2

set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN M19 }  [get_ports dac_data_o[ 0]] ; # DDA0
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN M20 }  [get_ports dac_data_o[ 1]] ; # DDA1
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN L19 }  [get_ports dac_data_o[ 2]] ; # DDA2
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN L20 }  [get_ports dac_data_o[ 3]] ; # DDA3
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN K19 }  [get_ports dac_data_o[ 4]] ; # DDA4
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN J19 }  [get_ports dac_data_o[ 5]] ; # DDA5
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN J20 }  [get_ports dac_data_o[ 6]] ; # DDA6
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN H20 }  [get_ports dac_data_o[ 7]] ; # DDA7
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN G19 }  [get_ports dac_data_o[ 8]] ; # DDA8
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN G20 }  [get_ports dac_data_o[ 9]] ; # DDA9
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN F19 }  [get_ports dac_data_o[10]] ; # DDA10
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN F20 }  [get_ports dac_data_o[11]] ; # DDA11
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN D20 }  [get_ports dac_data_o[12]] ; # DDA12
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN D19 }  [get_ports dac_data_o[13]] ; # DDA13

set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN P18 }  [get_ports dac_datb_o[ 0]] ; # DDB0
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN R18 }  [get_ports dac_datb_o[ 1]] ; # DDB1
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN R17 }  [get_ports dac_datb_o[ 2]] ; # DDB2
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN Y17 }  [get_ports dac_datb_o[ 3]] ; # DDB3
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN Y18 }  [get_ports dac_datb_o[ 4]] ; # DDB4
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN W18 }  [get_ports dac_datb_o[ 5]] ; # DDB5
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN Y19 }  [get_ports dac_datb_o[ 6]] ; # DDB6
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN U19 }  [get_ports dac_datb_o[ 7]] ; # DDB7
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN V20 }  [get_ports dac_datb_o[ 8]] ; # DDB8
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN W20 }  [get_ports dac_datb_o[ 9]] ; # DDB9
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN V18 }  [get_ports dac_datb_o[10]] ; # DDB10
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN W19 }  [get_ports dac_datb_o[11]] ; # DDB11
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN U20 }  [get_ports dac_datb_o[12]] ; # DDB12
set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN T19 }  [get_ports dac_datb_o[13]] ; # DDB13


### PWM DAC
set_property -dict {IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12 IOB TRUE}  [get_ports {dac_pwm_o[*]}]
set_property PACKAGE_PIN T11  [get_ports {dac_pwm_o[0]}] ; # AOF0
set_property PACKAGE_PIN V12  [get_ports {dac_pwm_o[1]}] ; # AOF1
set_property PACKAGE_PIN V13  [get_ports {dac_pwm_o[2]}] ; # AOF2
set_property PACKAGE_PIN W14  [get_ports {dac_pwm_o[3]}] ; # AOF3

### XADC
set_property IOSTANDARD LVCMOS33 [get_ports {vinp_i[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vinn_i[*]}]
#AD0
#AD1
#AD8
#AD9
#V_0
set_property PACKAGE_PIN K9  [get_ports {vinp_i[4]}]
set_property PACKAGE_PIN L10 [get_ports {vinn_i[4]}]
set_property PACKAGE_PIN E18 [get_ports {vinp_i[3]}]
set_property PACKAGE_PIN E19 [get_ports {vinn_i[3]}]
set_property PACKAGE_PIN E17 [get_ports {vinp_i[2]}]
set_property PACKAGE_PIN D18 [get_ports {vinn_i[2]}]
set_property PACKAGE_PIN C20 [get_ports {vinp_i[1]}]
set_property PACKAGE_PIN B20 [get_ports {vinn_i[1]}]
set_property PACKAGE_PIN B19 [get_ports {vinp_i[0]}]
set_property PACKAGE_PIN A20 [get_ports {vinn_i[0]}]


### Trigger
#set_property IOSTANDARD LVCMOS18 [get_ports trig_i]
#set_property PACKAGE_PIN N20 [get_ports trig_i]

### PLL
set_property IOSTANDARD LVCMOS33 [get_ports pll_*]
set_property IOSTANDARD LVCMOS33 [get_ports clk_sel_o]
set_property PACKAGE_PIN V17 [get_ports clk_sel_o]
set_property PACKAGE_PIN U17 [get_ports pll_hi_o]
set_property PACKAGE_PIN V15 [get_ports pll_lo_o]

### Temperature protection
#set_property IOSTANDARD LVCMOS33 [get_ports {temp_prot_i[*]}]
#set_property PACKAGE_PIN W6 [get_ports {temp_prot_i[0]}]
#set_property PACKAGE_PIN V7 [get_ports {temp_prot_i[1]}]


### Expansion connector
set_property -dict {IOSTANDARD LVCMOS33  SLEW FAST  DRIVE 8}  [get_ports {exp_?_io[*]}]

set_property PACKAGE_PIN G17 [get_ports exp_p_io[ 0]] ; # DIO0_P
set_property PACKAGE_PIN G18 [get_ports exp_n_io[ 0]] ; # DIO0_N
set_property PACKAGE_PIN H16 [get_ports exp_p_io[ 1]] ; # DIO1_P
set_property PACKAGE_PIN H17 [get_ports exp_n_io[ 1]] ; # DIO1_N
set_property PACKAGE_PIN J18 [get_ports exp_p_io[ 2]] ; # DIO2_P
set_property PACKAGE_PIN H18 [get_ports exp_n_io[ 2]] ; # DIO2_N
set_property PACKAGE_PIN K17 [get_ports exp_p_io[ 3]] ; # DIO3_P
set_property PACKAGE_PIN K18 [get_ports exp_n_io[ 3]] ; # DIO3_N
set_property PACKAGE_PIN L14 [get_ports exp_p_io[ 4]] ; # DIO4_P
set_property PACKAGE_PIN L15 [get_ports exp_n_io[ 4]] ; # DIO4_N
set_property PACKAGE_PIN L16 [get_ports exp_p_io[ 5]] ; # DIO5_P
set_property PACKAGE_PIN L17 [get_ports exp_n_io[ 5]] ; # DIO5_N
set_property PACKAGE_PIN K16 [get_ports exp_p_io[ 6]] ; # DIO6_P
set_property PACKAGE_PIN J16 [get_ports exp_n_io[ 6]] ; # DIO6_N
set_property PACKAGE_PIN M14 [get_ports exp_p_io[ 7]] ; # DIO7_P
set_property PACKAGE_PIN M15 [get_ports exp_n_io[ 7]] ; # DIO7_N
set_property -quiet PACKAGE_PIN M17 [get_ports -quiet exp_p_io[8]]  ; # DIO8_P
set_property -quiet PACKAGE_PIN M18 [get_ports -quiet exp_n_io[8]]  ; # DIO8_N
set_property -quiet PACKAGE_PIN N20 [get_ports -quiet exp_p_io[9]]  ; # DIO9_P
set_property -quiet PACKAGE_PIN P20 [get_ports -quiet exp_n_io[9]]  ; # DIO9_N
set_property -quiet PACKAGE_PIN N18 [get_ports -quiet exp_p_io[10]] ; # DIO10_P
set_property -quiet PACKAGE_PIN P19 [get_ports -quiet exp_n_io[10]] ; # DIO10_N

#set_property PULLDOWN TRUE [get_ports {exp_p_io[0]}]
#set_property PULLDOWN TRUE [get_ports {exp_n_io[0]}]
#set_property PULLUP   TRUE [get_ports {exp_p_io[7]}]
#set_property PULLUP   TRUE [get_ports {exp_n_io[7]}]


### SATA connector
#set_property -dict {IOSTANDARD DIFF_SSTL18_I  IOB TRUE } [get_ports {daisy_?_?[*]}]
#set_property -dict {IOSTANDARD LVCMOS18  IOB TRUE } [get_ports {daisy_?_?[*]}]

set_property PACKAGE_PIN V6  [get_ports {daisy_p_o[0]}] ; # DAISY_IO0_P
set_property PACKAGE_PIN W6  [get_ports {daisy_n_o[0]}] ; # DAISY_IO0_N
set_property PACKAGE_PIN U7  [get_ports {daisy_p_o[1]}] ; # DAISY_IO1_P
set_property PACKAGE_PIN V7  [get_ports {daisy_n_o[1]}] ; # DAISY_IO1_N
set_property PACKAGE_PIN T5  [get_ports {daisy_p_i[0]}] ; # DAISY_IO2_P
set_property PACKAGE_PIN U5  [get_ports {daisy_n_i[0]}] ; # DAISY_IO2_N
set_property PACKAGE_PIN T9  [get_ports {daisy_p_i[1]}] ; # DAISY_IO3_P
set_property PACKAGE_PIN U10 [get_ports {daisy_n_i[1]}] ; # DAISY_IO3_N


### LED
set_property -dict {IOSTANDARD LVCMOS33  SLEW SLOW  DRIVE 4}  [get_ports {led_o[*]}]

set_property PACKAGE_PIN F16 [get_ports {led_o[0]}] ; # LED0
set_property PACKAGE_PIN F17 [get_ports {led_o[1]}] ; # LED1
set_property PACKAGE_PIN G15 [get_ports {led_o[2]}] ; # LED2
set_property PACKAGE_PIN H15 [get_ports {led_o[3]}] ; # LED3
set_property PACKAGE_PIN K14 [get_ports {led_o[4]}] ; # LED4
set_property PACKAGE_PIN G14 [get_ports {led_o[5]}] ; # LED5
set_property PACKAGE_PIN J15 [get_ports {led_o[6]}] ; # LED6
set_property PACKAGE_PIN J14 [get_ports {led_o[7]}] ; # LED7


### I2C1
set_property -quiet -dict {IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 PACKAGE_PIN T15} [get_ports -quiet i2c1_sda_io]
set_property -quiet -dict {IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 PACKAGE_PIN P14} [get_ports -quiet i2c1_scl_io]

############################################################################
# Clock constraints                                                        #
############################################################################

# ADC3664 ADDCLK is the source-synchronous serial interface clock.  In the
# 125 MSPS, 16-bit two-wire mode it runs at 4x the sample rate.  The BUFR /4
# in adc366x_top generates the 125 MHz parallel clock used by the fabric.
create_clock -period 2.000 -name adc_dclk [get_ports {adc_dclk_i[1]}]
create_clock -period 8.000 -name dac_clk [get_ports dac_clk_i]
create_clock -period 4.000 -name rx_clk [get_ports {daisy_p_i[1]}]


create_generated_clock -quiet -name id/dna_clk -source [get_pins -quiet id/dna_clk_reg/C] -divide_by 8 [get_pins -quiet id/dna_clk_reg/Q]
create_generated_clock -quiet -name i_hk/dna_clk -source [get_pins -quiet i_hk/dna_clk_reg/C] -divide_by 16 [get_pins -quiet i_hk/dna_clk_reg/Q]
create_generated_clock -name dac_wrta_o -source [get_pins oddr_dac_wrta/C] -divide_by 1 -invert [get_ports dac_wrta_o]
create_generated_clock -name dac_wrtb_o -source [get_pins oddr_dac_wrtb/C] -divide_by 1 -invert [get_ports dac_wrtb_o]


#set_false_path -from [get_clocks clk_fpga_0]    -to [get_clocks pll_adc_clk]
#set_false_path -from [get_clocks pll_adc_clk]   -to [get_clocks clk_fpga_0]

#set_false_path -from [get_clocks pll_adc_clk2d] -to [get_clocks pll_adc_clk]
#set_false_path -from [get_clocks pll_adc_clk]   -to [get_clocks pll_adc_clk2d]

#set_false_path -from [get_clocks pll_adc_clk2d] -to [get_clocks pll_pwm_clk]
#set_false_path -from [get_clocks pll_adc_10mhz] -to [get_clocks pll_adc_clk2d]

############################################################################
# ADC366x serial LVDS receive interface                                    #
############################################################################
#
# Contract, from the RTL and from the ADC3664 data sheet (TI SBAS888B,
# December 2020, revised July 2022):
#
#   * The link is source synchronous: the ADC forwards its bit clock on
#     ADDCLK (adc_dclk_i) together with the data lanes and the frame clock.
#     adc366x_top clocks the ISERDESE2 directly from that pin through a BUFIO
#     (ser_clk) and derives the parallel clock with a BUFR /4, so there is no
#     PLL in the capture path and every input delay below is relative to
#     adc_dclk.
#   * 125 MSPS in the 16 bit two wire mode is 1000 Mbps per lane, DDR, so
#     ADDCLK runs at 500 MHz (create_clock -period 2.000 above) and one bit
#     lasts 1.000 ns.  Data is edge aligned: the data sheet specifies tCD,
#     "DCLK rising edge to output data delay", not a centred window.
#   * Data sheet numbers for the two wire mode at 125 MSPS (875 Mbps row,
#     the closest specified two wire operating point):
#         tCD  MIN -0.2 ns   NOM 0.1 ns     (data transition vs DCLK edge)
#         tDV  MIN  0.6 ns   NOM 0.8 ns     (data valid per bit)
#     The 1000 Mbps row of the data sheet (1 wire, 16 bit, 62.5 MSPS) gives
#     tCD MIN -0.6 ns and tDV MIN 0.5 ns; see the risk note at the end.
#
# The input delays therefore describe where the data transition sits with
# respect to the ADDCLK edge that produced it:
#
#     -min = tCD(min) = -0.200 ns      earliest transition
#     -max = tCD(max) =  0.100 ns      latest transition
#
# Both DDR edges are constrained (-clock_fall -add_delay).  Board skew between
# ADDCLK and the data lanes is not included: it is not documented in this
# repository, see the risk note.
#
# Written out per port group instead of factored into a procedure: Vivado
# rejects 'proc' in an XDC file (Designutils 20-1307), so red_pitaya_z20_ll_65.xdc
# repeats these constraints after it replaces the adc_dclk object.
set_input_delay -clock [get_clocks adc_dclk]             -min -add_delay -0.200 [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk]             -max -add_delay  0.100 [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -min -add_delay -0.200 [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -max -add_delay  0.100 [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}]

# Capture edge relationship.  The clock reaches the ISERDESE2 through
# IBUFDS + BUFIO, the data through IBUFDS + IDELAYE2, and the two are not
# equal: measured on the routed design, with the IDELAY tap that software
# loads by default (6, see red_pitaya_hk_ll.v),
#
#     pad -> ISERDESE2/CLK    2.136 ns (fast) .. 3.320 ns (slow)
#     pad -> ISERDESE2/DDLY   1.281 ns (fast) .. 2.143 ns (slow)
#
# so the sampling instant sits 0.83 ns (fast) .. 1.21 ns (slow) after the
# ADDCLK edge that launched the bit: the bit is captured by the edge one unit
# interval *before* the one the tool pairs it with by default.  One unit
# interval is half an ADDCLK period, and a hold multicycle of 1 moves the hold
# capture edge by exactly that pair of DDR edges, which restores the real
# relationship.  With the data sheet skew above this leaves +0.386 ns of hold
# margin.
#
# The setup check of the same segment keeps the default pairing, which is two
# unit intervals away from the physical one, so its reported margin is not a
# physical margin; it is kept only as a structural check that nothing but the
# IBUFDS/IDELAYE2 pair sits in front of the deserializer.  The sampling point
# itself is established at run time, per board, by the per lane VAR_LOAD IDELAY
# taps and the fabric bitslip in adc366x_top.
set_multicycle_path -hold 1 \
  -from [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}] \
  -to   [get_pins {i_adc366x/ser_dat[*].ISERDESE2_inst/DDLY}]

# Risk note - data that would turn the numbers above into a verified budget:
#   * tCD / tDV rows for the 16 bit two wire mode at 125 MSPS (1000 Mbps).
#     The rows used are the 875 Mbps two wire ones; the 1000 Mbps row of a
#     different output mode is wider (tCD MIN -0.6 ns), which would consume
#     the whole hold margin.
#   * ADDCLK to data lane skew of the STEMlab 125-14 TI board.
#   * The IDELAY tap value production software actually loads, if it differs
#     from the 25'h6318c6 (six taps per lane) default in red_pitaya_hk_ll.v.
# The interface budget is tight by construction: 1.000 ns unit interval
# against 0.221 ns of ISERDESE2 setup + hold, 0.035 ns clock uncertainty,
# 0.38 ns of corner spread in the BUFIO/IBUFDS clock path and 0.3 ns of ADC
# output skew.  It closes because the taps are calibrated per board, not
# because a fixed set of delays covers every corner.

set_output_delay -clock [get_clocks dac_wrta_o] -min -add_delay -1.500 [get_ports {dac_data_o[*]}]
set_output_delay -clock [get_clocks dac_wrta_o] -max -add_delay 2.000 [get_ports {dac_data_o[*]}]
set_output_delay -clock [get_clocks dac_wrta_o] -min -add_delay -1.400 [get_ports {dac_datb_o[*]}]
set_output_delay -clock [get_clocks dac_wrta_o] -max -add_delay 2.000 [get_ports {dac_datb_o[*]}]




# These are the first stages of the explicit request/acknowledge synchronizers.
# Their source clock varies per slave, so constrain the synchronizer endpoint
# rather than assuming every slave is in the same destination domain.
set_false_path -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_do_csff_reg[0]/D}]
set_false_path -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D}]
# sys[5] is the only slave clocked by pll_pwm_clk.  These are the first
# ASYNC_REG stages that capture the stable write/read qualifiers after the
# request toggle has crossed; the second stages remain timed normally.
set_false_path -to [get_pins {sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/reg_we_csff_reg[0]/D}]
set_false_path -to [get_pins {sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/reg_re_csff_reg[0]/D}]
# First stage of the explicit two-flop PDM reset synchronizer.  The second
# stage and all reset consumers remain timed in pll_pwm_clk.
set_false_path -quiet -to [get_pins -quiet {pdm_rst_sync_reg[0]/D}]
# First stages of the explicit LL clock-domain synchronizers.  Their second
# stages and all downstream logic remain timed in the destination domain.
set_false_path -quiet -to [get_pins -quiet {loop_en_meta_reg/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/genblk4[*].sync_mode_tx_r_reg[0]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/genblk4[*].sync_mode_rx_r_reg[0]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/i_rx/genblk1[*].sync_mode_r_reg[0]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/i_rx/genblk1[*].par_train_r_reg[0]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/i_tx/sync_mode_r_reg[0]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/i_rx/cfg_en_sync_r_reg[0]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/i_rx/cfg_en_sync_r_reg[0]/CLR}]
set_false_path -quiet -to [get_pins -quiet {i_adc366x/cfg_en_par_r_reg[0]/D}]
set_false_path -quiet -to [get_pins -quiet {i_adc366x/cfg_en_par_r_reg[0]/CLR}]
set_false_path -quiet -to [get_pins -quiet {i_adc366x/ser_inv_meta_r_reg[*]/D}]
set_false_path -quiet -to [get_pins -quiet {i_adc366x/cfg_dly_meta_r_reg[*]/D}]
set_false_path -quiet -to [get_pins -quiet {i_adc366x/i_drst/dst_in_csff_reg[0]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/genblk3[*].i_test/tx_dat_rx_meta_reg[*]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/genblk3[*].i_test/stat_clr_rx_meta_reg/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/rxp_dat_sys_meta_reg[*]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/tst_err_cnt_sys_meta_reg[*]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/tst_dat_cnt_sys_meta_reg[*]/D}]
set_false_path -quiet -to [get_pins -quiet {i_daisy/cfg_rx_trained_sys_reg[0]/D}]
set_false_path -quiet -from [get_clocks -quiet pll_adc_clk] -to [get_pins -quiet {i_asg/ch*/inst_axi_dac/dac_rd_clr_r*/D}]
set_false_path -quiet -from [get_clocks -quiet clk_fpga_0] -to [get_pins -quiet {spi_done_csff*/D}]
# The request/acknowledge toggles qualify these bundled buses.  Each source
# register is held stable until the synchronized transaction completes, so the
# data only has to settle within one destination-clock period.  Constrain the
# actual register-to-register bundles instead of hiding the paths from the PS
# clock pins with broad false paths.
set_max_delay -quiet -datapath_only 8.000 \
  -from [get_cells -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_addr_reg[*]}] \
  -to   [get_cells -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr_reg[*]*}]
set_max_delay -quiet -datapath_only 8.000 \
  -from [get_cells -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_wdata_reg[*]}] \
  -to   [get_cells -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.wdata_reg[*]*}]
set_max_delay -quiet -datapath_only 8.000 \
  -from [get_cells -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_rdata_reg[*]}] \
  -to   [get_pins -quiet {ps/axi_slave_gp0/axi\\.RDATA_reg[*]/D}]
set_bus_skew -quiet 6.000 \
  -from [get_pins -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_addr_reg[*]/Q}] \
  -to   [get_pins -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr_reg[*]*/D}]
set_bus_skew -quiet 6.000 \
  -from [get_pins -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_wdata_reg[*]/Q}] \
  -to   [get_pins -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.wdata_reg[*]*/D}]
set_bus_skew -quiet 6.000 \
  -from [get_pins -quiet {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_rdata_reg[*]/Q}] \
  -to   [get_pins -quiet {ps/axi_slave_gp0/axi\\.RDATA_reg[*]/D}]
set_max_delay -quiet -datapath_only 8.000 -from [get_pins -quiet i_hk/i_freq_meter/ref_gate_reg/C] -to [get_pins -quiet {i_hk/i_freq_meter/mes_gate_csff*[0]/D}]
set_false_path -quiet -from [get_pins -quiet {i_adc366x/adc_dat_o*[*]/C}] -to [get_pins -quiet {dac_dat_*[*]/D}]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
