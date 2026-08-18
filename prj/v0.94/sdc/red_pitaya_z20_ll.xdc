set_property LOC XADC_X0Y0 [get_cells i_ams/XADC_inst]

############################################################################
### SATA connector
############################################################################
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_i[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_i[*]}]

set_property PULLTYPE PULLUP [get_ports daisy_p_i[1]]
#
############################################################################
# Clock constraints                                                        #
############################################################################

set_false_path -from [get_clocks adc_clk]     -to [get_clocks dac_clk_out]
set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks ser_clk_out]
set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks dac_2clk_out]
set_false_path -from [get_clocks dac_clk_out] -to [get_clocks dac_2clk_out]
set_false_path -from [get_clocks dac_clk_out] -to [get_clocks dac_2ph_out]

set_false_path -from [get_clocks clk_fpga_0] -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/reg_do_csff*/D}]
set_false_path -from [get_clocks pll_adc_clk] -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_done_csff*/D}]
set_false_path -from [get_clocks pll_adc_clk] -to [get_pins {sys_bus_interconnect/for_bus[*].inst_sys_bus_cdc/ctrl_done_csff*/D}]
set_false_path -from [get_clocks pll_adc_clk] -to [get_pins {i_asg/ch*/inst_axi_dac/dac_rd_clr_r*/D}]
set_false_path -from [get_clocks clk_fpga_0] -to [get_pins {spi_done_csff*/D}]
set_max_delay -datapath_only 8.000 -from [get_pins i_hk/i_freq_meter/ref_gate_reg/C] -to [get_pins {i_hk/i_freq_meter/mes_gate_csff*[0]/D}]
set_false_path -from [get_pins {i_adc366x/adc_dat_o*[*]/C}] -to [get_pins {dac_dat_*[*]/D}]

############################################################################
### ADC366x  
############################################################################

#set_max_delay -datapath_only 4.000 -from [get_pins i_adc366x/par_dat_o[*]/Q] -to [get_pins i_adc366x/adc_dat_o[*]/D]
#set_max_delay -datapath_only 4.000 -from [get_pins i_adc366x/par_dv/Q] -to [get_pins i_adc366x/adc_dv_o/D]
set_max_delay -datapath_only 4.000 -from [get_pins i_adc366x/par_dv_reg/C] -to [get_pins i_adc366x/adc_dv_o_reg/D]
set_max_delay -datapath_only 4.000 -from [get_pins i_adc366x/par_dat_o_reg[*]/C] -to [get_pins i_adc366x/adc_dat_o_reg[*]/D]
set_bus_skew -from [get_cells i_adc366x/par_dat_o_reg*] -to [get_cells i_adc366x/adc_dat_o_reg*] 8.000
set_max_delay -datapath_only -from [get_cells i_adc366x/par_dat_o_reg*] -to [get_cells i_adc366x/adc_dat_o_reg*] 8.000

############################################################################
### v0.94/Z20_LL local CDC endpoints
############################################################################

set_false_path -to [get_pins scope_rstn_meta_reg/CLR]
set_false_path -quiet -to [get_pins -quiet par_bus_rstn_sync_reg[0]/CLR]
set_false_path -quiet -to [get_pins -quiet par_axi_rstn_sync_reg[0]/CLR]
set_false_path -quiet -to [get_pins -quiet pid_rstn_sync_reg[0]/CLR]
set_false_path -quiet -to [get_pins -quiet loop_rstn_sync_reg[0]/CLR]
set_false_path -to [get_pins i_trig_asg_sync/dst_in_csff_reg[0]/D]

# Continuous sample buses are registered at the source.  Bound both total
# flight time and inter-bit skew instead of waiving their first capture stage.
set_max_delay -datapath_only 6.000 -from [get_cells loop_a_src_reg*] -to [get_cells loop_a_meta_reg*]
set_max_delay -datapath_only 6.000 -from [get_cells loop_b_src_reg*] -to [get_cells loop_b_meta_reg*]
set_max_delay -datapath_only 6.000 -from [get_cells pid_a_src_reg*]  -to [get_cells pid_a_meta_reg*]
set_max_delay -datapath_only 6.000 -from [get_cells pid_b_src_reg*]  -to [get_cells pid_b_meta_reg*]
set_bus_skew 6.000 -from [get_cells loop_a_src_reg*] -to [get_cells loop_a_meta_reg*]
set_bus_skew 6.000 -from [get_cells loop_b_src_reg*] -to [get_cells loop_b_meta_reg*]
set_bus_skew 6.000 -from [get_cells pid_a_src_reg*]  -to [get_cells pid_a_meta_reg*]
set_bus_skew 6.000 -from [get_cells pid_b_src_reg*]  -to [get_cells pid_b_meta_reg*]
