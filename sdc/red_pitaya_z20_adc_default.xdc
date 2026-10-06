# Legacy constraint for other Z20 projects; not a validated LTC2185 board timing budget.
set_input_delay -clock adc_clk 6.000 [get_ports adc_dat_i[*][*]]
