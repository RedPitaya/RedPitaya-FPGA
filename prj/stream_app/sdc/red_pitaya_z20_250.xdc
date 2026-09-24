### SATA connector
set_property IOSTANDARD LVCMOS18 [get_ports {daisy_p_o[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {daisy_n_o[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {daisy_p_i[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {daisy_n_i[*]}]

create_generated_clock -name i_hk/dna_clk -source [get_pins system_wrapper_i/system_i/clk_gen/clk_125] -divide_by 8 [get_pins i_hk/dna_clk_reg/Q]
create_clock -period 8.000 -name daisy_clk  [get_ports daisy_p_i[1]]
set_property PULLTYPE PULLUP [get_ports daisy_p_i[1]]

set_false_path -from [get_clocks clk_fpga_0]               -to [get_clocks clk_125_system_clk_gen_0]
set_false_path -from [get_clocks clk_125_system_clk_gen_0] -to [get_clocks clk_fpga_0]

set_false_path -from [get_clocks clk_125_system_clk_gen_0] -to [get_clocks clk_200_system_clk_gen_0]
set_false_path -from [get_clocks clk_200_system_clk_gen_0] -to [get_clocks clk_125_system_clk_gen_0]

set_false_path -from [get_clocks clk_125_system_clk_gen_0] -to [get_clocks pll_ref]
set_false_path -from [get_clocks pll_ref]                  -to [get_clocks clk_125_system_clk_gen_0]
set_false_path -from [get_clocks clk_10_system_clk_gen_0]  -to [get_clocks clk_125_system_clk_gen_0]
set_clock_groups -asynchronous -group [get_clocks adc_clk] -group [get_clocks clk_125_system_clk_gen_0]
set_clock_groups -asynchronous -group [get_clocks adc_clk] -group [get_clocks clk_200_system_clk_gen_0]

# The frequency meter gate crosses from the reference clock into the measured
# clock domain through a synchronizer, so only the data path needs bounding.
set_max_delay -datapath_only 8.000 -from [get_pins i_hk/i_freq_meter/ref_gate_reg/C] -to [get_pins {i_hk/i_freq_meter/mes_gate_csff*[0]/D}]
