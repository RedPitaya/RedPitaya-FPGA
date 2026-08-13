# STEMlab 65-16 TI runs the ADC3664 at 62.5 MSPS.  ADDCLK remains four times
# the sample rate in the 16-bit two-wire mode, so override the 125-14 TI
# default with the 250 MHz physical serial-clock period.
delete_clocks [get_clocks adc_dclk]
create_clock -period 4.000 -name adc_dclk [get_ports {adc_dclk_i[1]}]
