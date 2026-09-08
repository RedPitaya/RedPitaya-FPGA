#
# $Id: red_pitaya_4adc.xdc 961 2014-01-21 11:40:39Z matej.oblak $
#
# @brief Red Pitaya location constraints.
#
# @Author Matej Oblak
#
# (c) Red Pitaya  http://www.redpitaya.com
#


############################################################################
# Clock constraints                                                        #
############################################################################

#NET "adc_clk" TNM_NET = "adc_clk";
#TIMESPEC TS_adc_clk = PERIOD "adc_clk" 125 MHz;


create_clock -period 8.000 -name adc_clk_01 [get_ports {adc_clk_i[0][1]}]
create_clock -period 8.000 -name adc_clk_23 [get_ports {adc_clk_i[1][1]}]
create_clock -period 4.000 -name rx_clk [get_ports {daisy_p_i[1]}]

set_false_path -from [get_clocks par_clk] -to [get_clocks pll_adc_clk_0]
set_false_path -from [get_clocks pll_adc_clk_0] -to [get_clocks par_clk]
set_false_path -from [get_clocks par_clk] -to [get_clocks pll_adc_clk_1]
set_false_path -from [get_clocks pll_adc_clk_1] -to [get_clocks par_clk]
# set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks adc_clk_01]
# set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks adc_clk_23]
set_false_path -from [get_clocks adc_clk_01] -to [get_clocks pll_ser_clk]
#set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks par_clk]

#IDLY inputs can be async
set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks pll_adc_clk_0]
set_false_path -from [get_clocks pll_adc_clk_0] -to [get_clocks clk_fpga_0]
# Same cut for the second ADC PLL, which was missing.  pll_23 -> pll_adc_clk_1
# clocks i_scope_2_3 (CH3/CH4); without these two lines every sys-bus crossing
# of that instance is timed as synchronous, giving WNS -8.9 ns / TNS -9318 ns
# concentrated on i_scope_2_3/i_cfg/sys_rdata_reg[*].
# NOTE: pll_adc_clk_0 <-> pll_adc_clk_1 is deliberately NOT cut - a single
# oscillator feeds both PLLs, and the two scope instances exchange trig_ch_*
# and the 16-bit adc_state/axi_state/trg_state buses without synchronisers.
set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks pll_adc_clk_1]
set_false_path -from [get_clocks pll_adc_clk_1] -to [get_clocks clk_fpga_0]
########################

set_false_path -from [get_clocks pll_adc_clk_0] -to [get_clocks pll_adc_10mhz]
set_false_path -from [get_clocks pll_adc_10mhz] -to [get_clocks pll_adc_clk_0]
set_false_path -from [get_clocks adc_clk_23] -to [get_clocks pll_adc_clk_0]

set_false_path -from [get_clocks pll_adc_clk] -to [get_pins {i_asg/ch*/inst_axi_dac/dac_rd_clr_r*/D}]
set_false_path -from [get_clocks clk_fpga_0] -to [get_pins {spi_done_csff*/D}]
set_max_delay -datapath_only 8.000 -from [get_pins adc_dat_t*[2][*]/C] -to [get_pins adc_dat_r_reg*[2][*]/D]
set_max_delay -datapath_only 8.000 -from [get_pins adc_dat_t*[3][*]/C] -to [get_pins adc_dat_r_reg*[3][*]/D]
set_max_delay -datapath_only 8.000 -from [get_pins ps/axi_slave_gp0/rd_araddr*[*]/C] -to [get_pins sys_bus_interconnect/*.inst_sys_bus_cdc/bus_m\\.addr*[*]*/D]
set_max_delay -datapath_only 8.000 -from [get_pins ps/axi_slave_gp0/wr_awaddr*[*]/C] -to [get_pins sys_bus_interconnect/*.inst_sys_bus_cdc/bus_m\\.addr*[*]*/D]
# The read-data bus is bundled with the synchronized completion handshake.  It
# is stable from the slave ACK until the AXI slave captures it in RDATA, so constrain the
# data path to one ctrl-clock period independently of the unrelated ADC clock
# phase.  Keep these lookups strict: a hierarchy change must not silently drop
# the CDC timing guarantee.
set_max_delay -datapath_only 8.000 \
  -from [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_rdata_reg[*]/C}] \
  -to [get_pins {ps/axi_slave_gp0/axi\\.RDATA_reg[*]/D}]
# Address and write data are latched before the request toggle crosses the
# clock boundary.  Bound the bundled data paths so they settle before the
# synchronized request can be acted upon in the destination domain.
set_max_delay -datapath_only 8.000 \
  -from [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_addr_reg[*]/C}] \
  -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.addr_reg[*]/D}]
set_max_delay -datapath_only 8.000 \
  -from [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_wdata_reg[*]/C}] \
  -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/bus_m\\.wdata_reg[*]/D}]
set_max_delay -datapath_only 8.000 -from [get_pins i_hk/i_freq_meter/ref_gate_reg/C] -to [get_pins {i_hk/i_freq_meter/mes_gate_csff*[0]/D}]



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
