### SATA connector
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_i[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_i[*]}]

create_clock -period 8.000 -name daisy_clk  [get_ports daisy_p_i[1]]
set_property PULLTYPE PULLUP [get_ports daisy_p_i[1]]
#set_property PULLTYPE PULLDOWN [get_ports daisy_n_i[1]]

set_clock_groups -logically_exclusive -group [get_clocks -include_generated_clocks adc_clk] -group [get_clocks -include_generated_clocks daisy_clk]


# set_false_path -from [get_clocks clk_125_system_clk_gen_0] -to [get_clocks {clk_200_system_clk_gen_0 daisy_clk clk_fpga_2}]
# set_false_path -from [get_clocks clk_200_system_clk_gen_0] -to [get_clocks {clk_125_system_clk_gen_0 daisy_clk clk_fpga_2}]
# set_false_path -from [get_clocks daisy_clk] -to [get_clocks {clk_125_system_clk_gen_0 clk_200_system_clk_gen_0 clk_fpga_2}]
# set_false_path -from [get_clocks clk_fpga_2] -to [get_clocks {clk_125_system_clk_gen_0 clk_200_system_clk_gen_0 daisy_clk}]

set_false_path -from [get_clocks clk_125_system_clk_gen_0] -to [get_clocks {daisy_clk clk_fpga_2}]
set_false_path -from [get_clocks clk_200_system_clk_gen_0] -to [get_clocks {daisy_clk clk_fpga_2}]
set_false_path -from [get_clocks daisy_clk] -to [get_clocks {clk_125_system_clk_gen_0 clk_200_system_clk_gen_0 clk_fpga_2}]
set_false_path -from [get_clocks clk_fpga_2] -to [get_clocks {clk_125_system_clk_gen_0 clk_200_system_clk_gen_0 daisy_clk}]
