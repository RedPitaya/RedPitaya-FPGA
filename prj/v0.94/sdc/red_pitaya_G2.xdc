set_property LOC XADC_X0Y0 [get_cells i_ams/XADC_inst]

############################################################################
# Clock constraints                                                        #
############################################################################

# set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks adc_clk]
# set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks par_clk]

### SATA connector
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_i[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_i[*]}]

set_property PULLTYPE PULLUP [get_ports daisy_p_i[1]]

### Expansion connector - DIO12-DIO17 - to E3 Conn
set_property -dict {PACKAGE_PIN Y9  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[8]}]
set_property -dict {PACKAGE_PIN Y8  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[8]}]
set_property -dict {PACKAGE_PIN Y12 IOSTANDARD LVCMOS25} [get_ports {exp_p_io[9]}]
set_property -dict {PACKAGE_PIN Y13 IOSTANDARD LVCMOS25} [get_ports {exp_n_io[9]}]
set_property -dict {PACKAGE_PIN Y7  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[10]}]
set_property -dict {PACKAGE_PIN Y6  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[10]}]
set_property -dict {PACKAGE_PIN U7  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[11]}]
set_property -dict {PACKAGE_PIN V7  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[11]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[12]}]
set_property -dict {PACKAGE_PIN U10 IOSTANDARD LVCMOS25} [get_ports {exp_n_io[12]}]
set_property -dict {PACKAGE_PIN V8  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[13]}]
set_property -dict {PACKAGE_PIN W8  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[13]}]
set_property -dict {PACKAGE_PIN W10 IOSTANDARD LVCMOS25} [get_ports {exp_p_io[14]}]
set_property -dict {PACKAGE_PIN W9  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[14]}]
set_property -dict {PACKAGE_PIN U9  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[15]}]
set_property -dict {PACKAGE_PIN U8  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[15]}]
set_property -dict {PACKAGE_PIN W11 IOSTANDARD LVCMOS25} [get_ports {exp_p_io[16]}]
set_property -dict {PACKAGE_PIN Y11 IOSTANDARD LVCMOS25} [get_ports {exp_n_io[16]}]
set_property -dict {PACKAGE_PIN T5  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[17]}]
set_property -dict {PACKAGE_PIN U5  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[17]}]
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS25} [get_ports {exp_p_io[18]}]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS25} [get_ports {exp_n_io[18]}]


### USB-C DAISY link - C1
set_property IOSTANDARD LVCMOS33   PACKAGE_PIN W6   [get_ports {c1_orient_i}]
set_property IOSTANDARD LVCMOS33   PACKAGE_PIN V6   [get_ports {c1_link_i}]


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
