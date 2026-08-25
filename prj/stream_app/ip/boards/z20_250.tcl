

# Create ports

set m_axi_hk [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_hk ]
set_property -dict [ list \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.FREQ_HZ {125000000} \
    CONFIG.HAS_REGION {0} \
    CONFIG.PROTOCOL {AXI3} \
] $m_axi_hk

set m_axi_trig [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_trig ]
set_property -dict [ list \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.FREQ_HZ {125000000} \
    CONFIG.HAS_REGION {0} \
    CONFIG.PROTOCOL {AXI3} \
] $m_axi_trig

set adc_clk [ create_bd_port -dir I -type clk -freq_hz 250000000 adc_clk ]
set clk_out [ create_bd_port -dir O -type clk -freq_hz 125000000 clk_out ]
set clk_250 [ create_bd_port -dir O -type clk -freq_hz 250000000 clk_250 ]
set clk_10 [ create_bd_port -dir O -type clk -freq_hz 10000000 clk_10]

set dac_dat_a [ create_bd_port -dir O -from 15 -to 0 dac_dat_a ]
set dac_dat_b [ create_bd_port -dir O -from 15 -to 0 dac_dat_b ]

set adc_data_ch1 [ create_bd_port -dir I -from 15 -to 0 adc_data_ch1 ]
set adc_data_ch2 [ create_bd_port -dir I -from 15 -to 0 adc_data_ch2 ]

set rstn_out [ create_bd_port -dir O -type rst rstn_out ]
set frstn_0 [ create_bd_port -dir O -type rst frstn_0 ]
set frstn_1 [ create_bd_port -dir O -type rst frstn_1 ]
set frstn_2 [ create_bd_port -dir O -type rst frstn_2 ]
set frstn_3 [ create_bd_port -dir O -type rst frstn_3 ]

# Create instance: axi_reg, and set properties
set axi_reg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_reg ]
set_property -dict [ list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.NUM_MI {4} \
    CONFIG.S00_HAS_REGSLICE {3} \
    CONFIG.M00_HAS_REGSLICE {3} \
    CONFIG.M01_HAS_REGSLICE {3} \
    CONFIG.M02_HAS_REGSLICE {3} \
    CONFIG.M03_HAS_REGSLICE {3} \
] $axi_reg

# Create instance: clk_gen, and set properties
set clk_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_gen ]
set_property -dict [list \
    CONFIG.ENABLE_CLOCK_MONITOR {false} \
    CONFIG.PRIM_IN_FREQ {250} \
    CONFIG.CLKIN1_JITTER_PS {40.0} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT4_USED {true} \
    CONFIG.CLKOUT5_USED {true} \
    CONFIG.CLK_OUT1_PORT {clk_125} \
    CONFIG.CLK_OUT2_PORT {clk_200} \
    CONFIG.CLK_OUT3_PORT {clk_333} \
    CONFIG.CLK_OUT4_PORT {clk_62_5} \
    CONFIG.CLK_OUT5_PORT {clk_10} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {250} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {333.33333} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {62.5} \
    CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {10.000} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {false} \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.CLKIN1_JITTER_PS {80.0} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {8.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {4} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {3} \
    CONFIG.MMCM_CLKOUT3_DIVIDE {16} \
    CONFIG.MMCM_CLKOUT4_DIVIDE {100} \
    CONFIG.NUM_OUT_CLKS {5} \
    CONFIG.CLKOUT1_JITTER {102.531} \
    CONFIG.CLKOUT1_PHASE_ERROR {85.928} \
    CONFIG.CLKOUT2_JITTER {89.528} \
    CONFIG.CLKOUT2_PHASE_ERROR {85.928} \
    CONFIG.CLKOUT3_JITTER {84.636} \
    CONFIG.CLKOUT3_PHASE_ERROR {85.928} \
    CONFIG.CLKOUT4_JITTER {117.659} \
    CONFIG.CLKOUT4_PHASE_ERROR {85.928} \
    CONFIG.CLKOUT5_JITTER {169.738} \
    CONFIG.CLKOUT5_PHASE_ERROR {85.928} \
] $clk_gen

# Create instance: rp_dac, and set properties
set rp_dac [ create_bd_cell -type ip -vlnv redpitaya.com:user:rp_dac:1.0 rp_dac ]
set_property -dict [ list \
    CONFIG.DAC_DATA_BITS {16} \
    CONFIG.EVENT_SRC_NUM {5} \
    CONFIG.ID_WIDTH {4} \
    CONFIG.M_AXI_DAC_ADDR_BITS {32} \
    CONFIG.M_AXI_DAC_DATA_BITS {64} \
    CONFIG.M_AXI_DAC_DATA_BITS_O {64} \
    CONFIG.TRIG_SRC_NUM {6} \
    CONFIG.S_AXI_REG_ADDR_BITS {20} \
] $rp_dac

# Create instance: xlconstant_0, and set properties
set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
set_property -dict [ list \
CONFIG.CONST_VAL {0} \
] $xlconstant_0

# Create instance: xlconstant_1, and set properties
set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
set_property -dict [ list \
CONFIG.CONST_VAL {0} \
CONFIG.CONST_WIDTH {4} \
] $xlconstant_1

# Create instance: rst_gen, and set properties
set rst_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen ]

# Create instance: rst_gen2, and set properties
set rst_gen2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen2 ]

# Create instance: rst_gen3, and set properties
set rst_gen3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen3 ]

set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]
set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]
set proc_sys_reset_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_3 ]


# Create interface connections
connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins processing_system7/S_AXI_HP0]
connect_bd_intf_net -intf_net axi_reg_M00_AXI [get_bd_intf_pins axi_reg/M00_AXI] [get_bd_intf_pins rp_oscilloscope/s_axi_reg]
connect_bd_intf_net -intf_net axi_reg_M01_AXI [get_bd_intf_pins axi_reg/M01_AXI] [get_bd_intf_pins rp_dac/s_axi_reg]
connect_bd_intf_net -intf_net axi_reg_M02_AXI [get_bd_intf_ports m_axi_trig] [get_bd_intf_pins axi_reg/M02_AXI]
connect_bd_intf_net -intf_net axi_reg_M03_AXI [get_bd_intf_ports m_axi_hk] [get_bd_intf_pins axi_reg/M03_AXI]
connect_bd_intf_net -intf_net processing_system7_DDR [get_bd_intf_ports DDR] [get_bd_intf_pins processing_system7/DDR]
connect_bd_intf_net -intf_net processing_system7_FIXED_IO [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins processing_system7/FIXED_IO]
connect_bd_intf_net -intf_net processing_system7_M_AXI_GP0 [get_bd_intf_pins axi_reg/S00_AXI] [get_bd_intf_pins processing_system7/M_AXI_GP0]
connect_bd_intf_net -intf_net rp_dac_m_axi_dac1 [get_bd_intf_pins processing_system7/S_AXI_HP2] [get_bd_intf_pins rp_dac/m_axi_dac1]
connect_bd_intf_net -intf_net rp_dac_m_axi_dac2 [get_bd_intf_pins processing_system7/S_AXI_HP3] [get_bd_intf_pins rp_dac/m_axi_dac2]
connect_bd_intf_net -intf_net rp_oscilloscope_m_axi_osc1 [get_bd_intf_pins axi_interconnect_0/S00_AXI] [get_bd_intf_pins rp_oscilloscope/m_axi_osc1]
connect_bd_intf_net -intf_net rp_oscilloscope_m_axi_osc2 [get_bd_intf_pins axi_interconnect_0/S01_AXI] [get_bd_intf_pins rp_oscilloscope/m_axi_osc2]

# Create port connections
connect_bd_net -net adc_data_ch1_0_1 [get_bd_ports adc_data_ch1] [get_bd_pins rp_oscilloscope/adc_data_ch1]
connect_bd_net -net adc_data_ch2_0_1 [get_bd_ports adc_data_ch2] [get_bd_pins rp_oscilloscope/adc_data_ch2]
connect_bd_net -net adc_clk_1 [get_bd_ports adc_clk] [get_bd_pins clk_gen/clk_in1]

connect_bd_net -net clkin_125_1  [get_bd_ports clk_out] [get_bd_pins clk_gen/clk_125] [get_bd_pins axi_interconnect_0/ACLK] \
[get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] \
[get_bd_pins axi_reg/ACLK] [get_bd_pins axi_reg/M00_ACLK] [get_bd_pins axi_reg/M01_ACLK] [get_bd_pins axi_reg/S00_ACLK] \
[get_bd_pins processing_system7/M_AXI_GP0_ACLK] [get_bd_pins processing_system7/S_AXI_HP0_ACLK] [get_bd_pins axi_reg/M02_ACLK] \
[get_bd_pins axi_reg/M03_ACLK] \
[get_bd_pins processing_system7/S_AXI_HP1_ACLK] [get_bd_pins rp_oscilloscope/m_axi_osc1_aclk] \
[get_bd_pins rp_oscilloscope/m_axi_osc2_aclk] [get_bd_pins rp_oscilloscope/m_axi_osc3_aclk] [get_bd_pins rp_oscilloscope/m_axi_osc4_aclk] \
[get_bd_pins rp_dac/s_axi_reg_aclk] [get_bd_pins rp_oscilloscope/s_axi_reg_aclk] [get_bd_pins rst_gen/slowest_sync_clk] [get_bd_pins xadc/s_axi_aclk]

connect_bd_net -net clkin_250_1 [get_bd_pins clk_gen/clk_200] [get_bd_pins rp_oscilloscope/clk] [get_bd_ports clk_250] \
[get_bd_pins processing_system7/S_AXI_HP2_ACLK] [get_bd_pins processing_system7/S_AXI_HP3_ACLK] \
[get_bd_pins rp_dac/clk] [get_bd_pins rp_dac/m_axi_dac1_aclk] [get_bd_pins rp_dac/m_axi_dac2_aclk] [get_bd_pins rst_gen2/slowest_sync_clk]

connect_bd_net -net processing_system7_FCLK_CLK0 [get_bd_ports FCLK_CLK0] [get_bd_pins processing_system7/FCLK_CLK0] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net -net processing_system7_FCLK_CLK1 [get_bd_ports FCLK_CLK1] [get_bd_pins processing_system7/FCLK_CLK1] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
connect_bd_net -net processing_system7_FCLK_CLK2 [get_bd_ports FCLK_CLK2] [get_bd_pins processing_system7/FCLK_CLK2] [get_bd_pins rst_gen3/slowest_sync_clk]
connect_bd_net -net processing_system7_FCLK_CLK3 [get_bd_ports FCLK_CLK3] [get_bd_pins processing_system7/FCLK_CLK3] [get_bd_pins proc_sys_reset_3/slowest_sync_clk]
connect_bd_net -net processing_system7_FCLK_RESET0_N [get_bd_ports frstn_0] [get_bd_pins processing_system7/FCLK_RESET0_N] [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net -net processing_system7_FCLK_RESET1_N [get_bd_ports frstn_1] [get_bd_pins processing_system7/FCLK_RESET1_N] [get_bd_pins proc_sys_reset_1/ext_reset_in]

connect_bd_net -net processing_system7_FCLK_RESET2_N [get_bd_ports frstn_2] [get_bd_pins processing_system7/FCLK_RESET2_N] [get_bd_pins rst_gen/ext_reset_in] \
[get_bd_pins rst_gen2/ext_reset_in] [get_bd_pins rst_gen3/ext_reset_in]

connect_bd_net -net processing_system7_FCLK_RESET3_N [get_bd_ports frstn_3] [get_bd_pins processing_system7/FCLK_RESET3_N] [get_bd_pins proc_sys_reset_3/ext_reset_in]
connect_bd_net -net rp_concat_0_event_reset [get_bd_pins rp_concat/event_reset] [get_bd_pins rp_oscilloscope/event_ip_reset]
connect_bd_net -net rp_concat_0_event_start [get_bd_pins rp_concat/event_start] [get_bd_pins rp_oscilloscope/event_ip_start]
connect_bd_net -net rp_concat_0_event_stop [get_bd_pins rp_concat/event_stop] [get_bd_pins rp_oscilloscope/event_ip_stop]
connect_bd_net -net rp_concat_0_event_trig [get_bd_pins rp_concat/event_trig] [get_bd_pins rp_oscilloscope/event_ip_trig]
connect_bd_net -net rp_concat_0_trig [get_bd_pins rp_concat/trig] [get_bd_pins rp_oscilloscope/trig_ip]
connect_bd_net -net In10_0_1 [get_bd_ports In10_0] [get_bd_pins intr_concat/In10]
connect_bd_net -net In11_0_1 [get_bd_ports In11_0] [get_bd_pins intr_concat/In11]
connect_bd_net -net In12_0_1 [get_bd_ports In12_0] [get_bd_pins intr_concat/In12]
connect_bd_net -net In13_0_1 [get_bd_ports In13_0] [get_bd_pins intr_concat/In13]
connect_bd_net -net In1_0_1 [get_bd_ports In1_0] [get_bd_pins intr_concat/In1]
connect_bd_net -net In2_0_1 [get_bd_ports In2_0] [get_bd_pins intr_concat/In2]
connect_bd_net -net In3_0_1 [get_bd_ports In3_0] [get_bd_pins intr_concat/In3]
connect_bd_net -net In4_0_1 [get_bd_ports In4_0] [get_bd_pins intr_concat/In4]
connect_bd_net -net In5_0_1 [get_bd_ports In5_0] [get_bd_pins intr_concat/In5]
connect_bd_net -net In6_0_1 [get_bd_ports In6_0] [get_bd_pins intr_concat/In6]
connect_bd_net -net In7_0_1 [get_bd_ports In7_0] [get_bd_pins intr_concat/In7]
connect_bd_net -net In8_0_1 [get_bd_ports In8_0] [get_bd_pins intr_concat/In8]
connect_bd_net -net In9_0_1 [get_bd_ports In9_0] [get_bd_pins intr_concat/In9]
connect_bd_net -net rp_oscilloscope_0_intr [get_bd_pins intr_concat/In15] [get_bd_pins rp_oscilloscope/intr]
connect_bd_net -net rp_oscilloscope_0_osc1_event_op [get_bd_pins rp_concat/osc1_event_ip] [get_bd_pins rp_oscilloscope/osc1_event_op]
connect_bd_net -net rp_oscilloscope_0_osc1_trig_op [get_bd_pins rp_concat/osc1_trig_ip] [get_bd_pins rp_oscilloscope/osc1_trig_op]
connect_bd_net -net rp_oscilloscope_0_osc2_event_op [get_bd_pins rp_concat/osc2_event_ip] [get_bd_pins rp_oscilloscope/osc2_event_op]
connect_bd_net -net rp_oscilloscope_0_osc2_trig_op [get_bd_pins rp_concat/osc2_trig_ip] [get_bd_pins rp_oscilloscope/osc2_trig_op]
connect_bd_net -net dac_data_ch1_0_1 [get_bd_ports dac_dat_a] [get_bd_pins rp_dac/dac_data_cha_o]
connect_bd_net -net dac_data_ch2_0_1 [get_bd_ports dac_dat_b] [get_bd_pins rp_dac/dac_data_chb_o]

connect_bd_net -net rst_gen_peripheral_aresetn [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_reg/M02_ARESETN] [get_bd_pins axi_reg/M03_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] \
[get_bd_pins axi_interconnect_0/S01_ARESETN] [get_bd_pins axi_reg/M00_ARESETN] [get_bd_pins axi_reg/M01_ARESETN] [get_bd_pins axi_reg/S00_ARESETN] \
[get_bd_pins rp_oscilloscope/m_axi_osc1_aresetn] [get_bd_pins rp_oscilloscope/m_axi_osc2_aresetn] [get_bd_pins rp_oscilloscope/m_axi_osc3_aresetn] \
[get_bd_pins rp_oscilloscope/m_axi_osc4_aresetn] [get_bd_pins rp_dac/s_axi_reg_aresetn] \
[get_bd_pins rp_oscilloscope/rst_n] [get_bd_pins rp_oscilloscope/s_axi_reg_aresetn] \
[get_bd_pins rst_gen/peripheral_aresetn] [get_bd_pins xadc/s_axi_aresetn]

connect_bd_net -net rst_ps7_0_50M_interconnect_aresetn [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_reg/ARESETN] [get_bd_pins rst_gen/interconnect_aresetn]
connect_bd_net [get_bd_ports rstn_out] [get_bd_pins rst_gen/peripheral_aresetn]
connect_bd_net [get_bd_ports clk_10] [get_bd_pins clk_gen/clk_10]
connect_bd_net -net xadc_ip2intc_irpt [get_bd_pins intr_concat/In0] [get_bd_pins xadc/ip2intc_irpt]
connect_bd_net -net xlconcat_0_dout [get_bd_pins intr_concat/dout] [get_bd_pins processing_system7/IRQ_F2P]
connect_bd_net -net xlconstant_0_dout [get_bd_pins rp_concat/la_trig_ip] [get_bd_pins xlconstant_0/dout]
connect_bd_net -net xlconstant_1_dout [get_bd_pins rp_concat/la_event_ip] [get_bd_pins xlconstant_1/dout]
connect_bd_net [get_bd_ports trig_in] [get_bd_pins rp_concat/ext_trig_ip]
connect_bd_net -net rp_oscilloscope_trig_out [get_bd_ports trig_out] [get_bd_pins rp_oscilloscope/trig_out]
connect_bd_net -net slave_mode_in [get_bd_ports daisy_slave] [get_bd_pins rp_oscilloscope/daisy_slave_i]
connect_bd_net -net rp_oscilloscope_0_clksel [get_bd_ports clksel] [get_bd_pins rp_oscilloscope/clksel_o]
connect_bd_net [get_bd_pins rst_gen/dcm_locked] [get_bd_pins clk_gen/locked]
connect_bd_net [get_bd_pins rst_gen2/peripheral_aresetn] [get_bd_pins rp_dac/rst_n] [get_bd_pins rp_dac/m_axi_dac1_aresetn] [get_bd_pins rp_dac/m_axi_dac2_aresetn]
connect_bd_net -net rp_concat_0_event_reset [get_bd_pins rp_dac/event_ip_reset]
connect_bd_net -net rp_concat_0_event_start [get_bd_pins rp_dac/event_ip_start]
connect_bd_net -net rp_concat_0_event_stop [get_bd_pins rp_dac/event_ip_stop]
connect_bd_net -net rp_concat_0_event_trig [get_bd_pins rp_dac/event_ip_trig]
connect_bd_net -net rp_concat_0_trig [get_bd_pins rp_dac/trig_ip]
connect_bd_net -net rp_dac_dac1_event_op [get_bd_pins rp_concat/gen1_event_ip] [get_bd_pins rp_dac/dac1_event_op]
connect_bd_net -net rp_dac_dac1_trig_op [get_bd_pins rp_concat/gen1_trig_ip] [get_bd_pins rp_dac/dac1_trig_op]
connect_bd_net -net rp_dac_dac2_event_op [get_bd_pins rp_concat/gen2_event_ip] [get_bd_pins rp_dac/dac2_event_op]
connect_bd_net -net rp_dac_dac2_trig_op [get_bd_pins rp_concat/gen2_trig_ip] [get_bd_pins rp_dac/dac2_trig_op]
connect_bd_net -net rp_dac_intr [get_bd_pins intr_concat/In14] [get_bd_pins rp_dac/intr]

# Create address segments
assign_bd_address -offset 0x40200000 -range 0x00100000 -target_address_space [get_bd_addr_spaces processing_system7/Data] [get_bd_addr_segs m_axi_trig/Reg] -force
assign_bd_address -offset 0x40300000 -range 0x00100000 -target_address_space [get_bd_addr_spaces processing_system7/Data] [get_bd_addr_segs m_axi_hk/Reg] -force
assign_bd_address -offset 0x40100000 -range 0x00100000 -target_address_space [get_bd_addr_spaces processing_system7/Data] [get_bd_addr_segs rp_dac/s_axi_reg/reg0] -force
assign_bd_address -offset 0x40000000 -range 0x00100000 -target_address_space [get_bd_addr_spaces processing_system7/Data] [get_bd_addr_segs rp_oscilloscope/s_axi_reg/reg0] -force
assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_dac/m_axi_dac1] [get_bd_addr_segs processing_system7/S_AXI_HP2/HP2_DDR_LOWOCM] -force
assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_dac/m_axi_dac2] [get_bd_addr_segs processing_system7/S_AXI_HP3/HP3_DDR_LOWOCM] -force
assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_oscilloscope/m_axi_osc1] [get_bd_addr_segs processing_system7/S_AXI_HP0/HP0_DDR_LOWOCM] -force
assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_oscilloscope/m_axi_osc2] [get_bd_addr_segs processing_system7/S_AXI_HP0/HP0_DDR_LOWOCM] -force


# Restore current instance
current_bd_instance $oldCurInst

set_property PFM.CLOCK { \
    FCLK_CLK0 {id "0" is_default "true" proc_sys_reset "/proc_sys_reset_0"} \
    FCLK_CLK1 {id "1" is_default "false" proc_sys_reset "/proc_sys_reset_1"} \
    FCLK_CLK2 {id "2" is_default "false" proc_sys_reset "/rst_gen3"} \
    FCLK_CLK3 {id "3" is_default "false" proc_sys_reset "/proc_sys_reset_3"} \
} [get_bd_cells /processing_system7]
