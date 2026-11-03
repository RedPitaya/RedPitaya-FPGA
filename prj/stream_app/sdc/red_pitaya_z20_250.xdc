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

# clk_125 and clk_200 (250 MHz) come from one MMCM: the crossings between them are timed

set_false_path -from [get_clocks clk_125_system_clk_gen_0] -to [get_clocks pll_ref_i]
set_false_path -from [get_clocks pll_ref_i]                -to [get_clocks clk_125_system_clk_gen_0]
set_false_path -from [get_clocks clk_10_system_clk_gen_0]  -to [get_clocks clk_125_system_clk_gen_0]
set_clock_groups -asynchronous -group [get_clocks adc_clk] -group [get_clocks clk_125_system_clk_gen_0]
set_clock_groups -asynchronous -group [get_clocks adc_clk] -group [get_clocks clk_200_system_clk_gen_0]

# The frequency meter gate crosses from the reference clock into the measured
# clock domain through a synchronizer, so only the data path needs bounding.
set_max_delay -datapath_only 8.000 -from [get_pins i_hk/i_freq_meter/ref_gate_reg/C] -to [get_pins {i_hk/i_freq_meter/mes_gate_csff*[0]/D}]

# Register reads of the scope in the ADC clock (scope_cfg): the read address is loaded a clock
# before the read acknowledge, which reaches the bus clock through sync_rw_single (a register in
# the ADC clock, two in the bus clock) at least four ADC clocks later; the read data register is
# taken every clock. The path from the address through the read mux may take two clocks (it was
# the second worst path at 250 MHz, 5 LUT levels, mostly routing).
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ */U_scope_cfg/reg_ofs_adc_reg*}] -to [get_cells -hier -filter {NAME =~ */U_scope_cfg/reg_rdat_adc_r_reg*}]
set_multicycle_path -hold 1  -from [get_cells -hier -filter {NAME =~ */U_scope_cfg/reg_ofs_adc_reg*}] -to [get_cells -hier -filter {NAME =~ */U_scope_cfg/reg_rdat_adc_r_reg*}]
