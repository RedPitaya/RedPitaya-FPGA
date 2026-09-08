set_property -quiet LOC XADC_X0Y0 [get_cells -quiet i_ams/XADC_inst]

############################################################################
# Clock constraints                                                        #
############################################################################

# set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks adc_clk]
# set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks par_clk]

# The v0.94 Z10 ADC is an LTC2145-14 in full-rate CMOS mode.  It is
# source-synchronous: data changes with CLKOUT+'s falling edge and is
# captured on its rising edge.  The DATA-to-CLKOUT skew (tD - tC) is
# specified from 0.0 ns to 0.6 ns.  Keep this board-specific constraint out
# of the shared XDC because other projects can use a different ADC interface.
set_input_delay -clock adc_clk -clock_fall -min 0.000 [get_ports adc_dat_i[*][*]]
set_input_delay -clock adc_clk -clock_fall -max 0.600 [get_ports adc_dat_i[*][*]]

### SATA connector
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_i[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_i[*]}]

set_property PULLTYPE PULLUP [get_ports daisy_p_i[1]]

set_property -quiet -dict {PACKAGE_PIN Y9  IOSTANDARD LVCMOS33} [get_ports -quiet {exp_p_io[8]}]
set_property -quiet -dict {PACKAGE_PIN Y8  IOSTANDARD LVCMOS33} [get_ports -quiet {exp_n_io[8]}]
set_property -quiet -dict {PACKAGE_PIN Y12 IOSTANDARD LVCMOS33} [get_ports -quiet {exp_p_io[9]}]
set_property -quiet -dict {PACKAGE_PIN Y13 IOSTANDARD LVCMOS33} [get_ports -quiet {exp_n_io[9]}]
set_property -quiet -dict {PACKAGE_PIN Y7  IOSTANDARD LVCMOS33} [get_ports -quiet {exp_p_io[10]}]
set_property -quiet -dict {PACKAGE_PIN Y6  IOSTANDARD LVCMOS33} [get_ports -quiet {exp_n_io[10]}]

set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[0].inst_sys_bus_cdc/ctrl_do_reg/C  ]  -to [get_pins sys_bus_interconnect/for_bus[0].inst_sys_bus_cdc/reg_do_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[0].inst_sys_bus_cdc/reg_done_reg/C ]  -to [get_pins sys_bus_interconnect/for_bus[0].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[0].inst_sys_bus_cdc/ctrl_we_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[0].inst_sys_bus_cdc/reg_we_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[0].inst_sys_bus_cdc/ctrl_re_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[0].inst_sys_bus_cdc/reg_re_csff_reg[0]/D    ]

set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[1].inst_sys_bus_cdc/ctrl_do_reg/C  ]  -to [get_pins sys_bus_interconnect/for_bus[1].inst_sys_bus_cdc/reg_do_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[1].inst_sys_bus_cdc/reg_done_reg/C ]  -to [get_pins sys_bus_interconnect/for_bus[1].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[1].inst_sys_bus_cdc/ctrl_we_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[1].inst_sys_bus_cdc/reg_we_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[1].inst_sys_bus_cdc/ctrl_re_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[1].inst_sys_bus_cdc/reg_re_csff_reg[0]/D    ]

set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[2].inst_sys_bus_cdc/ctrl_do_reg/C  ]  -to [get_pins sys_bus_interconnect/for_bus[2].inst_sys_bus_cdc/reg_do_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[2].inst_sys_bus_cdc/reg_done_reg/C ]  -to [get_pins sys_bus_interconnect/for_bus[2].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[2].inst_sys_bus_cdc/ctrl_we_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[2].inst_sys_bus_cdc/reg_we_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[2].inst_sys_bus_cdc/ctrl_re_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[2].inst_sys_bus_cdc/reg_re_csff_reg[0]/D    ]

set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[3].inst_sys_bus_cdc/ctrl_do_reg/C  ]  -to [get_pins sys_bus_interconnect/for_bus[3].inst_sys_bus_cdc/reg_do_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[3].inst_sys_bus_cdc/reg_done_reg/C ]  -to [get_pins sys_bus_interconnect/for_bus[3].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[3].inst_sys_bus_cdc/ctrl_we_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[3].inst_sys_bus_cdc/reg_we_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[3].inst_sys_bus_cdc/ctrl_re_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[3].inst_sys_bus_cdc/reg_re_csff_reg[0]/D    ]

set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[4].inst_sys_bus_cdc/ctrl_do_reg/C  ]  -to [get_pins sys_bus_interconnect/for_bus[4].inst_sys_bus_cdc/reg_do_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[4].inst_sys_bus_cdc/reg_done_reg/C ]  -to [get_pins sys_bus_interconnect/for_bus[4].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[4].inst_sys_bus_cdc/ctrl_we_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[4].inst_sys_bus_cdc/reg_we_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[4].inst_sys_bus_cdc/ctrl_re_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[4].inst_sys_bus_cdc/reg_re_csff_reg[0]/D    ]

set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/ctrl_do_reg/C  ]  -to [get_pins sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/reg_do_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/reg_done_reg/C ]  -to [get_pins sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/ctrl_we_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/reg_we_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/ctrl_re_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[5].inst_sys_bus_cdc/reg_re_csff_reg[0]/D    ]

set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[6].inst_sys_bus_cdc/ctrl_do_reg/C  ]  -to [get_pins sys_bus_interconnect/for_bus[6].inst_sys_bus_cdc/reg_do_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[6].inst_sys_bus_cdc/reg_done_reg/C ]  -to [get_pins sys_bus_interconnect/for_bus[6].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[6].inst_sys_bus_cdc/ctrl_we_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[6].inst_sys_bus_cdc/reg_we_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[6].inst_sys_bus_cdc/ctrl_re_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[6].inst_sys_bus_cdc/reg_re_csff_reg[0]/D    ]

set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[7].inst_sys_bus_cdc/ctrl_do_reg/C  ]  -to [get_pins sys_bus_interconnect/for_bus[7].inst_sys_bus_cdc/reg_do_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[7].inst_sys_bus_cdc/reg_done_reg/C ]  -to [get_pins sys_bus_interconnect/for_bus[7].inst_sys_bus_cdc/ctrl_done_csff_reg[0]/D ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[7].inst_sys_bus_cdc/ctrl_we_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[7].inst_sys_bus_cdc/reg_we_csff_reg[0]/D    ]
set_max_delay -datapath_only 8.000 -from [get_pins sys_bus_interconnect/for_bus[7].inst_sys_bus_cdc/ctrl_re_reg/C ]   -to [get_pins sys_bus_interconnect/for_bus[7].inst_sys_bus_cdc/reg_re_csff_reg[0]/D    ]

set_max_delay -datapath_only 8.000 -from [get_pins ps/axi_slave_gp0/rd_araddr*[*]/C] -to [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr*[*]*/D]
set_max_delay -datapath_only 8.000 -from [get_pins ps/axi_slave_gp0/wr_awaddr*[*]/C] -to [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr*[*]*/D]
set_max_delay -datapath_only 8.000 -from [get_pins ps/axi_slave_gp0/rd_do*/C] -to [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr*[*]*/D]
set_false_path -from [get_pins ps/axi_slave_gp0/wr_wdata*[*]/C] -to [get_pins sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.wdata*[*]*/D]
# Bundled read data is stable from the slave ACK until the synchronized
# completion reaches the AXI slave RDATA register.  These objects are mandatory for this top:
# do not use -quiet here, otherwise an invalid hierarchy pattern can silently
# remove the timing guarantee for the multi-bit transfer.
set_max_delay -datapath_only 8.000 \
  -from [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_rdata_reg[*]/C}] \
  -to [get_pins {ps/axi_slave_gp0/axi\\.RDATA_reg[*]/D}]
set_max_delay -datapath_only 8.000 -from [get_pins i_hk/i_freq_meter/ref_gate_reg/C] -to [get_pins {i_hk/i_freq_meter/mes_gate_csff*[0]/D}]
set_false_path -from [get_pins {adc_dat*[*][*]/C}] -to [get_pins {dac_dat_*[*]/D}]
