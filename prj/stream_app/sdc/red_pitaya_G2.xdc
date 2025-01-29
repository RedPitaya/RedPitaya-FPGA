### SATA connector
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_o[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_p_i[*]}]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports {daisy_n_i[*]}]

create_clock -period 8.000 -name daisy_clk  [get_ports daisy_p_i[1]]
set_property PULLTYPE PULLUP [get_ports daisy_p_i[1]]
#set_property PULLTYPE PULLDOWN [get_ports daisy_n_i[1]]

set_property PULLTYPE PULLDOWN [get_ports exp_p_io[*]]
set_property PULLTYPE PULLDOWN [get_ports exp_n_io[*]]

### Expansion connector - DIO12-DIO17 - to E3 Conn
# set_property -dict {PACKAGE_PIN Y9  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[8]}]
# set_property -dict {PACKAGE_PIN Y8  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[8]}]
# set_property -dict {PACKAGE_PIN Y12 IOSTANDARD LVCMOS25} [get_ports {exp_p_io[9]}]
# set_property -dict {PACKAGE_PIN Y13 IOSTANDARD LVCMOS25} [get_ports {exp_n_io[9]}]
# set_property -dict {PACKAGE_PIN Y7  IOSTANDARD LVCMOS25} [get_ports {exp_p_io[10]}]
# set_property -dict {PACKAGE_PIN Y6  IOSTANDARD LVCMOS25} [get_ports {exp_n_io[10]}]

set_property IOSTANDARD LVDS_25 [get_ports {exp_e3*[*]}]


#DIO11
set_property PACKAGE_PIN U7  [get_ports {exp_e3p_o[3]}]
set_property PACKAGE_PIN V7  [get_ports {exp_e3n_o[3]}]
#DIO12
set_property PACKAGE_PIN T9  [get_ports {exp_e3p_i[3]}]
set_property PACKAGE_PIN U10 [get_ports {exp_e3n_i[3]}]
#DIO13
set_property PACKAGE_PIN V8  [get_ports {exp_e3p_o[2]}]
set_property PACKAGE_PIN W8  [get_ports {exp_e3n_o[2]}]
#DIO14
set_property PACKAGE_PIN W10 [get_ports {exp_e3p_i[2]}]
set_property PACKAGE_PIN W9  [get_ports {exp_e3n_i[2]}]
#DIO15
set_property PACKAGE_PIN U9  [get_ports {exp_e3p_o[1]}]
set_property PACKAGE_PIN U8  [get_ports {exp_e3n_o[1]}]
#DIO16
set_property PACKAGE_PIN W11 [get_ports {exp_e3p_i[1]}]
set_property PACKAGE_PIN Y11 [get_ports {exp_e3n_i[1]}]
#DIO17
set_property PACKAGE_PIN T5  [get_ports {exp_e3p_o[0]}]
set_property PACKAGE_PIN U5  [get_ports {exp_e3n_o[0]}]
#DIO18
set_property PACKAGE_PIN V11 [get_ports {exp_e3p_i[0]}]
set_property PACKAGE_PIN V10 [get_ports {exp_e3n_i[0]}]


### USB-C DAISY link - C1
set_property -dict {IOSTANDARD LVCMOS25  PACKAGE_PIN W6}   [get_ports {s1_orient_i}]
set_property -dict {IOSTANDARD LVCMOS25  PACKAGE_PIN V6}   [get_ports {s1_link_i}]

set_clock_groups -logically_exclusive -group [get_clocks -include_generated_clocks adc_clk] -group [get_clocks -include_generated_clocks daisy_clk]

set_false_path -from [get_pins {system_wrapper_i/rp_dac/inst/U_dac1/U_dma_mm2s/U_dma_mm2s_ctrl/fifo_re_rin_reg/D }] -to [get_pins system_wrapper_i/rp_dac/inst/U_dac1/U_dma_mm2s/U_dma_mm2s_ctrl/fifo_re_r_reg/D]
set_false_path -from [get_pins {system_wrapper_i/rp_dac/inst/U_dac2/U_dma_mm2s/U_dma_mm2s_ctrl/fifo_re_rin_reg/D }] -to [get_pins system_wrapper_i/rp_dac/inst/U_dac2/U_dma_mm2s/U_dma_mm2s_ctrl/fifo_re_r_reg/D]

# set_false_path -from [get_clocks clk_125_system_clk_gen_0] -to [get_clocks {clk_200_system_clk_gen_0 daisy_clk clk_fpga_2}]
# set_false_path -from [get_clocks clk_200_system_clk_gen_0] -to [get_clocks {clk_125_system_clk_gen_0 daisy_clk clk_fpga_2}]
# set_false_path -from [get_clocks daisy_clk] -to [get_clocks {clk_125_system_clk_gen_0 clk_200_system_clk_gen_0 clk_fpga_2}]
# set_false_path -from [get_clocks clk_fpga_2] -to [get_clocks {clk_125_system_clk_gen_0 clk_200_system_clk_gen_0 daisy_clk}]

set_false_path -from [get_clocks clk_125_system_clk_gen_0] -to [get_clocks {daisy_clk clk_fpga_2}]
set_false_path -from [get_clocks clk_200_system_clk_gen_0] -to [get_clocks {daisy_clk clk_fpga_2}]
set_false_path -from [get_clocks daisy_clk] -to [get_clocks {clk_125_system_clk_gen_0 clk_200_system_clk_gen_0 clk_fpga_2}]
set_false_path -from [get_clocks clk_fpga_2] -to [get_clocks {clk_125_system_clk_gen_0 clk_200_system_clk_gen_0 daisy_clk}]
