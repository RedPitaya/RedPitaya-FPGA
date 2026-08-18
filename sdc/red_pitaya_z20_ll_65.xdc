# STEMlab 65-16 TI runs the ADC3664 at 62.5 MSPS.  ADDCLK remains four times
# the sample rate in the 16-bit two-wire mode, so override the 125-14 TI
# default with the 250 MHz physical serial-clock period.
delete_clocks [get_clocks adc_dclk]
create_clock -period 4.000 -name adc_dclk [get_ports {adc_dclk_i[1]}]

# delete_clocks dropped every constraint attached to the previous adc_dclk,
# including the ADC366x input delays.  Apply them again for the new clock
# object.  Values and their derivation: see red_pitaya_z20_ll.xdc; tCD is a
# property of the ADC output stage and does not scale with the bit rate, so the
# same numbers hold at 250 MHz ADDCLK.  The hold multicycle is attached to
# ports and pins, not to the clock, so it survives delete_clocks.
set_input_delay -clock [get_clocks adc_dclk]             -min -add_delay -0.200 [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk]             -max -add_delay  0.100 [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -min -add_delay -0.200 [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}]
set_input_delay -clock [get_clocks adc_dclk] -clock_fall -max -add_delay  0.100 [get_ports {adc_data_i[*][*] adc_datb_i[*][*] adc_fclk_i[*]}]
