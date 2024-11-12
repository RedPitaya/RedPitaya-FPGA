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
