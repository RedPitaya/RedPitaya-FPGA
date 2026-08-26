set_property LOC XADC_X0Y0 [get_cells i_ams/XADC_inst]

############################################################################
# Clock constraints                                                        #
############################################################################

#set_false_path -from [get_clocks adc_clk]     -to [get_clocks dac_clk_out]
#set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks ser_clk_out]
#set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks dac_2clk_out]
#set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks adc_clk]
#set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks par_clk]
#set_false_path -from [get_clocks dac_clk_out] -to [get_clocks dac_2clk_out]
#set_false_path -from [get_clocks dac_clk_out] -to [get_clocks dac_2ph_out]

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

# The classic ASG consumes two prefetched pointers on alternating 250 MHz
# clocks.  Its F/F^2 look-ahead cones start from a pair tail that is stable for
# both clocks and are captured only at the pair boundary.
set asg_pair_nets [get_nets -hier -quiet -filter {NAME =~ *i_asg/ch*/pnt_pair_1* || NAME =~ *i_asg/ch*/pnt_pair_2*}]
if {[llength $asg_pair_nets] == 0} {
   error "ASG pair look-ahead timing nets were not found"
}
set_multicycle_path 2 -setup -through $asg_pair_nets
set_multicycle_path 1 -hold  -through $asg_pair_nets
