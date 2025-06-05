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
set_property PACKAGE_PIN V10 [get_ports {adc_dclk_o[0]}] ; # ADDCLKIN_n
set_property PACKAGE_PIN V11 [get_ports {adc_dclk_o[1]}] ; # ADDCLKIN_p

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





set_property -dict {IOSTANDARD LVCMOS33   PACKAGE_PIN Y16 }  [get_ports out_sync_o] ; 

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
set_property PACKAGE_PIN M17 [get_ports exp_p_io[ 8]] ; # DIO8_P
set_property PACKAGE_PIN M18 [get_ports exp_n_io[ 8]] ; # DIO8_N
set_property PACKAGE_PIN N20 [get_ports exp_p_io[ 9]] ; # DIO9_P
set_property PACKAGE_PIN P20 [get_ports exp_n_io[ 9]] ; # DIO9_N
set_property PACKAGE_PIN N18 [get_ports exp_p_io[10]] ; # DIO10_P
set_property PACKAGE_PIN P19 [get_ports exp_n_io[10]] ; # DIO10_N

#set_property PULLDOWN TRUE [get_ports {exp_p_io[0]}]
#set_property PULLDOWN TRUE [get_ports {exp_n_io[0]}]
#set_property PULLUP   TRUE [get_ports {exp_p_io[7]}]
#set_property PULLUP   TRUE [get_ports {exp_n_io[7]}]


### SATA connector
#set_property -dict {IOSTANDARD DIFF_SSTL18_I  IOB TRUE } [get_ports {daisy_?_?[*]}]
set_property -dict {IOSTANDARD LVCMOS18  IOB TRUE } [get_ports {daisy_?_?[*]}]

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
set_property -dict {IOSTANDARD LVCMOS33  SLEW FAST  DRIVE 8  PACKAGE_PIN T15}  [get_ports i2c1_sda_io] ; # 
set_property -dict {IOSTANDARD LVCMOS33  SLEW FAST  DRIVE 8  PACKAGE_PIN P14}  [get_ports i2c1_scl_io] ; # 

############################################################################
# Clock constraints                                                        #
############################################################################

create_clock -period 8.000 -name adc_dclk [get_ports {adc_dclk_i[1]}]
create_clock -period 8.000 -name dac_clk [get_ports dac_clk_i]
create_clock -period 4.000 -name rx_clk [get_ports {daisy_p_i[1]}]

create_generated_clock -name i_hk/dna_clk -source [get_pins pll/pll/CLKOUT1] -divide_by 16 [get_pins i_hk/dna_clk_reg/Q]
#create_generated_clock -name {adc_dclk_o[1]} -source [get_pins ODDR_dclk/C] -divide_by 1 [get_ports {adc_dclk_o[1]}]
create_generated_clock -name dac_wrta_o -source [get_pins oddr_dac_wrta/C] -divide_by 1 -invert [get_ports dac_wrta_o]
create_generated_clock -name dac_wrtb_o -source [get_pins oddr_dac_wrtb/C] -divide_by 1 -invert [get_ports dac_wrtb_o]


#set_false_path -from [get_clocks clk_fpga_0]    -to [get_clocks pll_adc_clk]
#set_false_path -from [get_clocks pll_adc_clk]   -to [get_clocks clk_fpga_0]

#set_false_path -from [get_clocks pll_adc_clk2d] -to [get_clocks pll_adc_clk]
#set_false_path -from [get_clocks pll_adc_clk]   -to [get_clocks pll_adc_clk2d]

#set_false_path -from [get_clocks pll_adc_clk2d] -to [get_clocks pll_pwm_clk]
#set_false_path -from [get_clocks pll_adc_10mhz] -to [get_clocks pll_adc_clk2d]

set_input_delay -clock [get_clocks adc_dclk] -clock_fall -min -add_delay 0.000 [get_ports {adc_data_i[0][*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -max -add_delay 0.300 [get_ports {adc_data_i[0][*]}]
set_input_delay -clock [get_clocks adc_dclk] -min -add_delay 0.000 [get_ports {adc_data_i[0][*]}]
set_input_delay -clock [get_clocks adc_dclk] -max -add_delay 0.300 [get_ports {adc_data_i[0][*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -min -add_delay 0.000 [get_ports {adc_data_i[1][*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -max -add_delay 0.300 [get_ports {adc_data_i[1][*]}]
set_input_delay -clock [get_clocks adc_dclk] -min -add_delay 0.000 [get_ports {adc_data_i[1][*]}]
set_input_delay -clock [get_clocks adc_dclk] -max -add_delay 0.300 [get_ports {adc_data_i[1][*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -min -add_delay 0.000 [get_ports {adc_datb_i[0][*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -max -add_delay 0.300 [get_ports {adc_datb_i[0][*]}]
set_input_delay -clock [get_clocks adc_dclk] -min -add_delay 0.000 [get_ports {adc_datb_i[0][*]}]
set_input_delay -clock [get_clocks adc_dclk] -max -add_delay 0.300 [get_ports {adc_datb_i[0][*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -min -add_delay 0.000 [get_ports {adc_datb_i[1][*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -max -add_delay 0.300 [get_ports {adc_datb_i[1][*]}]
set_input_delay -clock [get_clocks adc_dclk] -min -add_delay 0.000 [get_ports {adc_datb_i[1][*]}]
set_input_delay -clock [get_clocks adc_dclk] -max -add_delay 0.300 [get_ports {adc_datb_i[1][*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -min -add_delay 0.000 [get_ports {adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -max -add_delay 0.300 [get_ports {adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk] -min -add_delay 0.000 [get_ports {adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk] -max -add_delay 0.300 [get_ports {adc_fclk_i[*]}]


set_output_delay -clock [get_clocks dac_wrta_o] -min -add_delay -1.500 [get_ports {dac_data_o[*]}]
set_output_delay -clock [get_clocks dac_wrta_o] -max -add_delay 2.000 [get_ports {dac_data_o[*]}]
set_output_delay -clock [get_clocks dac_wrta_o] -min -add_delay -1.400 [get_ports {dac_datb_o[*]}]
set_output_delay -clock [get_clocks dac_wrta_o] -max -add_delay 2.000 [get_ports {dac_datb_o[*]}]




set_false_path -from [get_clocks clk_fpga_0] -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_do_csff*/D}]
set_false_path -from [get_clocks clk_fpga_0] -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_do_write_csff*/D}]
set_false_path -from [get_clocks clk_fpga_0] -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_do_read_csff*/D}]
set_false_path -from [get_clocks pll_adc_clk] -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_done_csff*/D}]
set_false_path -from [get_clocks pll_adc_clk] -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_done_csff*/D}]
set_false_path -from [get_clocks pll_adc_clk] -to [get_pins {i_asg/ch*/inst_axi_dac/dac_rd_clr_r*/D}]
set_false_path -from [get_clocks clk_fpga_0] -to [get_pins {spi_done_csff*/D}]
set_max_delay -datapath_only 8.000 -from [get_pins ps/axi_slave_gp0/rd_araddr*[*]/C] -to [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr*[*]*/D]
set_max_delay -datapath_only 8.000 -from [get_pins ps/axi_slave_gp0/wr_awaddr*[*]/C] -to [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr*[*]*/D]
set_max_delay -datapath_only 8.000 -from [get_pins ps/axi_slave_gp0/rd_do*/C] -to [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr*[*]*/D]
set_false_path -from [get_pins ps/axi_slave_gp0/wr_wdata*[*]/C] -to [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.wdata*[*]*/D]
set_false_path -from [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_rdata*[*]*/C] -to [get_pins ps/axi_slave_gp0/axi\\.RDATA*[*]*/D]
set_max_delay -datapath_only 8.000 -from [get_pins i_hk/i_freq_meter/ref_gate_reg/C] -to [get_pins {i_hk/i_freq_meter/mes_gate_csff*[0]/D}]
set_false_path -from [get_pins {i_adc366x/adc_dat_o*[*]/C}] -to [get_pins {dac_dat_*[*]/D}]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]



