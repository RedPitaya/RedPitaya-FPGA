# LTC2185 full-rate CMOS: tSKEW = 0..0.6 ns from CLKOUT+ falling edge (pp. 7, 9).
# https://www.analog.com/media/en/technical-documentation/data-sheets/218543f.pdf
# Board skew allowance +/-0.5 ns is unverified: min = 0-0.5, max = 0.6+0.5 ns.
set_input_delay -clock adc_clk -clock_fall -min -0.500 [get_ports {adc_dat_i[*][*]}]
set_input_delay -clock adc_clk -clock_fall -max 1.100 [get_ports {adc_dat_i[*][*]}]
