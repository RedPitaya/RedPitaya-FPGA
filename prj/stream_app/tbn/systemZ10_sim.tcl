
################################################################
# This is a generated script based on design: system
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2020.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source system_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7z010clg400-1
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name system

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
update_ip_catalog
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:processing_system7:5.5\
redpitaya.com:user:rp_concat:1.0\
redpitaya.com:user:rp_dac:1.0\
redpitaya.com:user:rp_gpio:1.0\
redpitaya.com:user:rp_oscilloscope:1.16\
xilinx.com:ip:proc_sys_reset:5.0\
user.org:user:system_model:1.0\
xilinx.com:ip:xadc_wiz:3.3\
xilinx.com:ip:xlconstant:1.1\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set DDR [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR ]

  set FIXED_IO [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO ]


  # Create ports
  set FCLK_CLK0 [ create_bd_port -dir O -type clk FCLK_CLK0 ]
  set FCLK_CLK1 [ create_bd_port -dir O -type clk FCLK_CLK1 ]
  set FCLK_CLK2 [ create_bd_port -dir O -type clk FCLK_CLK2 ]
  set FCLK_CLK3 [ create_bd_port -dir O -type clk FCLK_CLK3 ]
  set FCLK_RESET0_N [ create_bd_port -dir O -type rst FCLK_RESET0_N ]
  set FCLK_RESET1_N [ create_bd_port -dir O -type rst FCLK_RESET1_N ]
  set FCLK_RESET2_N [ create_bd_port -dir O -type rst FCLK_RESET2_N ]
  set FCLK_RESET3_N [ create_bd_port -dir O -type rst FCLK_RESET3_N ]
  set In10_0 [ create_bd_port -dir I -from 0 -to 0 In10_0 ]
  set In11_0 [ create_bd_port -dir I -from 0 -to 0 In11_0 ]
  set In12_0 [ create_bd_port -dir I -from 0 -to 0 In12_0 ]
  set In13_0 [ create_bd_port -dir I -from 0 -to 0 In13_0 ]
  set In1_0 [ create_bd_port -dir I -from 0 -to 0 In1_0 ]
  set In2_0 [ create_bd_port -dir I -from 0 -to 0 In2_0 ]
  set In3_0 [ create_bd_port -dir I -from 0 -to 0 In3_0 ]
  set In4_0 [ create_bd_port -dir I -from 0 -to 0 In4_0 ]
  set In5_0 [ create_bd_port -dir I -from 0 -to 0 In5_0 ]
  set In6_0 [ create_bd_port -dir I -from 0 -to 0 In6_0 ]
  set In7_0 [ create_bd_port -dir I -from 0 -to 0 In7_0 ]
  set In8_0 [ create_bd_port -dir I -from 0 -to 0 In8_0 ]
  set In9_0 [ create_bd_port -dir I -from 0 -to 0 In9_0 ]
  set adc_clk [ create_bd_port -dir I -type clk -freq_hz 125000000 adc_clk ]
  set adc_data_ch1 [ create_bd_port -dir I -from 13 -to 0 adc_data_ch1 ]
  set adc_data_ch2 [ create_bd_port -dir I -from 13 -to 0 adc_data_ch2 ]
  set clk_out [ create_bd_port -dir O -type clk clk_out ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {125000000} \
 ] $clk_out
  set clksel [ create_bd_port -dir O clksel ]
  set dac_dat_a [ create_bd_port -dir O -from 15 -to 0 dac_dat_a ]
  set dac_dat_b [ create_bd_port -dir O -from 15 -to 0 dac_dat_b ]
  set daisy_slave [ create_bd_port -dir I daisy_slave ]
  set gpio_n [ create_bd_port -dir IO -from 7 -to 0 gpio_n ]
  set gpio_p [ create_bd_port -dir IO -from 7 -to 0 gpio_p ]
  set gpio_trig [ create_bd_port -dir O gpio_trig ]
  set loopback_sel [ create_bd_port -dir O -from 7 -to 0 loopback_sel ]
  set rstn_out [ create_bd_port -dir O -from 0 -to 0 -type rst rstn_out ]
  set trig_in [ create_bd_port -dir I trig_in ]
  set trig_out [ create_bd_port -dir O trig_out ]

  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property -dict [ list \
   CONFIG.NUM_MI {1} \
   CONFIG.NUM_SI {2} \
   CONFIG.S00_HAS_DATA_FIFO {1} \
   CONFIG.S01_HAS_DATA_FIFO {1} \
 ] $axi_interconnect_0

  # Create instance: axi_interconnect_2, and set properties
  set axi_interconnect_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_2 ]
  set_property -dict [ list \
   CONFIG.NUM_MI {1} \
   CONFIG.NUM_SI {2} \
 ] $axi_interconnect_2

  # Create instance: axi_reg, and set properties
  set axi_reg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_reg ]
  set_property -dict [ list \
   CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
   CONFIG.M00_HAS_REGSLICE {3} \
   CONFIG.M01_HAS_REGSLICE {3} \
   CONFIG.M02_HAS_REGSLICE {3} \
   CONFIG.NUM_MI {3} \
   CONFIG.S00_HAS_REGSLICE {3} \
 ] $axi_reg

  # Create instance: clk_gen, and set properties
  set clk_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_gen ]
  set_property -dict [ list \
   CONFIG.CLKIN1_JITTER_PS {80.0} \
   CONFIG.CLKOUT1_JITTER {119.348} \
   CONFIG.CLKOUT1_PHASE_ERROR {96.948} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125} \
   CONFIG.CLKOUT2_JITTER {104.759} \
   CONFIG.CLKOUT2_PHASE_ERROR {96.948} \
   CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {250} \
   CONFIG.CLKOUT2_USED {true} \
   CONFIG.CLKOUT3_JITTER {99.263} \
   CONFIG.CLKOUT3_PHASE_ERROR {96.948} \
   CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {333.33333} \
   CONFIG.CLKOUT3_USED {true} \
   CONFIG.CLKOUT4_JITTER {137.150} \
   CONFIG.CLKOUT4_PHASE_ERROR {96.948} \
   CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {62.5} \
   CONFIG.CLKOUT4_USED {true} \
   CONFIG.CLK_OUT1_PORT {clk_125} \
   CONFIG.CLK_OUT2_PORT {clk_200} \
   CONFIG.CLK_OUT3_PORT {clk_333} \
   CONFIG.CLK_OUT4_PORT {clk_62_5} \
   CONFIG.ENABLE_CLOCK_MONITOR {false} \
   CONFIG.MMCM_CLKFBOUT_MULT_F {8.000} \
   CONFIG.MMCM_CLKIN1_PERIOD {8.000} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {8.000} \
   CONFIG.MMCM_CLKOUT1_DIVIDE {4} \
   CONFIG.MMCM_CLKOUT2_DIVIDE {3} \
   CONFIG.MMCM_CLKOUT3_DIVIDE {16} \
   CONFIG.NUM_OUT_CLKS {4} \
   CONFIG.PRIMITIVE {MMCM} \
   CONFIG.PRIM_IN_FREQ {125} \
   CONFIG.USE_LOCKED {true} \
   CONFIG.USE_RESET {false} \
 ] $clk_gen

  # Create instance: intr_concat, and set properties
  set intr_concat [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 intr_concat ]
  set_property -dict [ list \
   CONFIG.NUM_PORTS {16} \
 ] $intr_concat

  # Create instance: processing_system7_0, and set properties
  set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]
  set_property -dict [ list \
   CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
   CONFIG.PCW_FPGA_FCLK1_ENABLE {0} \
   CONFIG.PCW_FPGA_FCLK2_ENABLE {0} \
   CONFIG.PCW_FPGA_FCLK3_ENABLE {0} \
 ] $processing_system7_0

  # Create instance: rp_concat, and set properties
  set rp_concat [ create_bd_cell -type ip -vlnv redpitaya.com:user:rp_concat:1.0 rp_concat ]
  set_property -dict [ list \
   CONFIG.EVENT_SRC_NUM {5} \
   CONFIG.TRIG_SRC_NUM {6} \
 ] $rp_concat

  # Create instance: rp_dac, and set properties
  set rp_dac [ create_bd_cell -type ip -vlnv redpitaya.com:user:rp_dac:1.0 rp_dac ]
  set_property -dict [ list \
   CONFIG.DAC_DATA_BITS {16} \
   CONFIG.EVENT_SRC_NUM {5} \
   CONFIG.ID_WIDTH {4} \
   CONFIG.M_AXI_DAC_ADDR_BITS {32} \
   CONFIG.M_AXI_DAC_DATA_BITS {64} \
   CONFIG.M_AXI_DAC_DATA_BITS_O {64} \
   CONFIG.S_AXI_REG_ADDR_BITS {20} \
   CONFIG.TRIG_SRC_NUM {6} \
 ] $rp_dac

  # Create instance: rp_gpio, and set properties
  set rp_gpio [ create_bd_cell -type ip -vlnv redpitaya.com:user:rp_gpio:1.0 rp_gpio ]

  # Create instance: rp_oscilloscope, and set properties
  set rp_oscilloscope [ create_bd_cell -type ip -vlnv redpitaya.com:user:rp_oscilloscope:1.16 rp_oscilloscope ]
  set_property -dict [ list \
   CONFIG.ADC_DATA_BITS {14} \
   CONFIG.EVENT_SRC_NUM {5} \
   CONFIG.ID_WIDTHS {12} \
   CONFIG.NUM_CHANNELS {2} \
   CONFIG.S_AXI_REG_ADDR_BITS {20} \
   CONFIG.TRIG_SRC_NUM {6} \
 ] $rp_oscilloscope

  # Create instance: rst_gen, and set properties
  set rst_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen ]

  # Create instance: rst_gen2, and set properties
  set rst_gen2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen2 ]

  # Create instance: rst_gen3, and set properties
  set rst_gen3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen3 ]

  # Create instance: system_model, and set properties
  set system_model [ create_bd_cell -type ip -vlnv user.org:user:system_model:1.0 system_model ]
  set_property -dict [ list \
   CONFIG.HP1_IW {5} \
 ] $system_model

  # Create instance: xadc, and set properties
  set xadc [ create_bd_cell -type ip -vlnv xilinx.com:ip:xadc_wiz:3.3 xadc ]
  set_property -dict [ list \
   CONFIG.CHANNEL_ENABLE_VAUXP0_VAUXN0 {true} \
   CONFIG.CHANNEL_ENABLE_VAUXP1_VAUXN1 {true} \
   CONFIG.CHANNEL_ENABLE_VAUXP8_VAUXN8 {true} \
   CONFIG.CHANNEL_ENABLE_VAUXP9_VAUXN9 {true} \
   CONFIG.CHANNEL_ENABLE_VP_VN {true} \
   CONFIG.ENABLE_RESET {false} \
   CONFIG.EXTERNAL_MUX_CHANNEL {VP_VN} \
   CONFIG.INTERFACE_SELECTION {Enable_AXI} \
   CONFIG.SEQUENCER_MODE {Off} \
   CONFIG.SINGLE_CHANNEL_SELECTION {TEMPERATURE} \
   CONFIG.XADC_STARUP_SELECTION {independent_adc} \
 ] $xadc

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {14} \
 ] $xlconstant_0

  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {14} \
 ] $xlconstant_1

set_property -dict [list CONFIG.FREQ_HZ {12500000}] [get_bd_pins system_model/FCLK_CLK0]
set_property -dict [list CONFIG.FREQ_HZ {25000000}] [get_bd_pins system_model/FCLK_CLK1]
set_property -dict [list CONFIG.FREQ_HZ {5000000}] [get_bd_pins system_model/FCLK_CLK2]
set_property -dict [list CONFIG.FREQ_HZ {20000000}] [get_bd_pins system_model/FCLK_CLK3]

  # Create interface connections
  connect_bd_intf_net -intf_net system_model_M_AXI_GP0 [get_bd_intf_pins axi_reg/S00_AXI] [get_bd_intf_pins system_model/M_AXI_GP0]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins system_model/S_AXI_HP0]
  connect_bd_intf_net -intf_net axi_interconnect_2_M00_AXI [get_bd_intf_pins axi_interconnect_2/M00_AXI] [get_bd_intf_pins system_model/S_AXI_HP1]
  connect_bd_intf_net -intf_net rp_dac_m_axi_dac1 [get_bd_intf_pins rp_dac/m_axi_dac1] [get_bd_intf_pins system_model/S_AXI_HP2]
  connect_bd_intf_net -intf_net rp_dac_m_axi_dac2 [get_bd_intf_pins rp_dac/m_axi_dac2] [get_bd_intf_pins system_model/S_AXI_HP3]
  connect_bd_intf_net -intf_net axi_reg_M00_AXI [get_bd_intf_pins axi_reg/M00_AXI] [get_bd_intf_pins rp_oscilloscope/s_axi_reg]
  connect_bd_intf_net -intf_net axi_reg_M01_AXI [get_bd_intf_pins axi_reg/M01_AXI] [get_bd_intf_pins rp_dac/s_axi_reg]
  connect_bd_intf_net -intf_net axi_reg_M02_AXI [get_bd_intf_pins axi_reg/M02_AXI] [get_bd_intf_pins rp_gpio/s_axi_reg]
  connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins processing_system7_0/FIXED_IO]
  connect_bd_intf_net -intf_net rp_gpio_axi_gpio_in [get_bd_intf_pins axi_interconnect_2/S00_AXI] [get_bd_intf_pins rp_gpio/axi_gpio_in]
  connect_bd_intf_net -intf_net rp_gpio_axi_gpio_out [get_bd_intf_pins axi_interconnect_2/S01_AXI] [get_bd_intf_pins rp_gpio/axi_gpio_out]
  connect_bd_intf_net -intf_net rp_oscilloscope_m_axi_osc1 [get_bd_intf_pins axi_interconnect_0/S00_AXI] [get_bd_intf_pins rp_oscilloscope/m_axi_osc1]
  connect_bd_intf_net -intf_net rp_oscilloscope_m_axi_osc2 [get_bd_intf_pins axi_interconnect_0/S01_AXI] [get_bd_intf_pins rp_oscilloscope/m_axi_osc2]
  connect_bd_intf_net -intf_net system_model_DDR [get_bd_intf_ports DDR] [get_bd_intf_pins system_model/DDR]


set_property -dict [list CONFIG.CLK_DOMAIN {system_system_model_0_3_FCLK_CLK2} CONFIG.FREQ_HZ {50000000}] [get_bd_intf_pins system_model/M_AXI_GP0] [get_bd_intf_pins rp_oscilloscope/s_axi_reg] [get_bd_intf_pins rp_dac/s_axi_reg] [get_bd_intf_pins rp_gpio/s_axi_reg]
set_property -dict [list CONFIG.CLK_DOMAIN {clk_gen_clk_out1} CONFIG.FREQ_HZ {125000000}] [get_bd_intf_pins system_model/S_AXI_HP0] [get_bd_intf_pins rp_oscilloscope/m_axi_osc1] [get_bd_intf_pins rp_oscilloscope/m_axi_osc2]
set_property -dict [list CONFIG.CLK_DOMAIN {clk_gen_clk_out1} CONFIG.FREQ_HZ {125000000}] [get_bd_intf_pins system_model/S_AXI_HP1] [get_bd_intf_pins rp_gpio/axi_gpio_in] [get_bd_intf_pins rp_gpio/axi_gpio_out] [get_bd_intf_pins rp_oscilloscope/m_axi_osc3] [get_bd_intf_pins rp_oscilloscope/m_axi_osc4]
set_property -dict [list CONFIG.CLK_DOMAIN {clk_gen_clk_out1} CONFIG.FREQ_HZ {250000000}] [get_bd_intf_pins system_model/S_AXI_HP2] [get_bd_intf_pins rp_dac/m_axi_dac1]
set_property -dict [list CONFIG.CLK_DOMAIN {clk_gen_clk_out1} CONFIG.FREQ_HZ {250000000}] [get_bd_intf_pins system_model/S_AXI_HP3] [get_bd_intf_pins rp_dac/m_axi_dac2]


  # Create port connections
  connect_bd_net -net ARESETN_1 [get_bd_pins axi_reg/ARESETN] [get_bd_pins axi_reg/M00_ARESETN] [get_bd_pins axi_reg/M01_ARESETN] [get_bd_pins axi_reg/M02_ARESETN] [get_bd_pins axi_reg/S00_ARESETN] [get_bd_pins rp_dac/s_axi_reg_aresetn] [get_bd_pins rp_gpio/s_axi_reg_aresetn] [get_bd_pins rp_oscilloscope/s_axi_reg_aresetn] [get_bd_pins rst_gen3/interconnect_aresetn]
  connect_bd_net -net In10_0_1 [get_bd_ports In10_0] [get_bd_pins intr_concat/In10]
  connect_bd_net -net In11_0_1 [get_bd_ports In11_0] [get_bd_pins intr_concat/In11]
  connect_bd_net -net In12_0_1 [get_bd_ports In12_0] [get_bd_pins intr_concat/In12]
  connect_bd_net -net In1_0_1 [get_bd_ports In1_0] [get_bd_pins intr_concat/In1]
  connect_bd_net -net In2_0_1 [get_bd_ports In2_0] [get_bd_pins intr_concat/In2]
  connect_bd_net -net In3_0_1 [get_bd_ports In3_0] [get_bd_pins intr_concat/In3]
  connect_bd_net -net In4_0_1 [get_bd_ports In4_0] [get_bd_pins intr_concat/In4]
  connect_bd_net -net In5_0_1 [get_bd_ports In5_0] [get_bd_pins intr_concat/In5]
  connect_bd_net -net In6_0_1 [get_bd_ports In6_0] [get_bd_pins intr_concat/In6]
  connect_bd_net -net In7_0_1 [get_bd_ports In7_0] [get_bd_pins intr_concat/In7]
  connect_bd_net -net In8_0_1 [get_bd_ports In8_0] [get_bd_pins intr_concat/In8]
  connect_bd_net -net In9_0_1 [get_bd_ports In9_0] [get_bd_pins intr_concat/In9]
  connect_bd_net -net M00_ARESETN_1 [get_bd_ports rstn_out] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/S01_ARESETN] [get_bd_pins axi_interconnect_2/ARESETN] [get_bd_pins axi_interconnect_2/M00_ARESETN] [get_bd_pins axi_interconnect_2/S00_ARESETN] [get_bd_pins axi_interconnect_2/S01_ARESETN] [get_bd_pins rp_dac/rst_n] [get_bd_pins rp_gpio/m_axi_gpio_in_aresetn] [get_bd_pins rp_gpio/m_axi_gpio_out_aresetn] [get_bd_pins rp_gpio/rst_n] [get_bd_pins rp_oscilloscope/m_axi_osc1_aresetn] [get_bd_pins rp_oscilloscope/m_axi_osc2_aresetn] [get_bd_pins rp_oscilloscope/m_axi_osc3_aresetn] [get_bd_pins rp_oscilloscope/m_axi_osc4_aresetn] [get_bd_pins rp_oscilloscope/rst_n] [get_bd_pins rst_gen/peripheral_aresetn]
  connect_bd_net -net Net [get_bd_ports gpio_p] [get_bd_pins rp_gpio/exp_p_io]
  connect_bd_net -net Net1 [get_bd_ports gpio_n] [get_bd_pins rp_gpio/exp_n_io]
  connect_bd_net -net adc_clk_1 [get_bd_ports adc_clk] [get_bd_pins clk_gen/clk_in1]
  connect_bd_net -net adc_data_ch1_0_1 [get_bd_ports adc_data_ch1] [get_bd_pins rp_oscilloscope/adc_data_ch1]
  connect_bd_net -net adc_data_ch2_0_1 [get_bd_ports adc_data_ch2] [get_bd_pins rp_oscilloscope/adc_data_ch2]
  connect_bd_net -net clk_gen_adc_clk [get_bd_ports clk_out] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] [get_bd_pins axi_interconnect_2/ACLK] [get_bd_pins axi_interconnect_2/M00_ACLK] [get_bd_pins axi_interconnect_2/S00_ACLK] [get_bd_pins axi_interconnect_2/S01_ACLK] [get_bd_pins clk_gen/clk_125] [get_bd_pins rp_dac/clk] [get_bd_pins rp_gpio/clk] [get_bd_pins rp_gpio/m_axi_gpio_in_aclk] [get_bd_pins rp_gpio/m_axi_gpio_out_aclk] [get_bd_pins rp_oscilloscope/clk] [get_bd_pins rp_oscilloscope/m_axi_osc1_aclk] [get_bd_pins rp_oscilloscope/m_axi_osc2_aclk] [get_bd_pins rp_oscilloscope/m_axi_osc3_aclk] [get_bd_pins rp_oscilloscope/m_axi_osc4_aclk] [get_bd_pins rst_gen/slowest_sync_clk] [get_bd_pins system_model/S_AXI_HP0_aclk] [get_bd_pins system_model/S_AXI_HP1_aclk] [get_bd_pins xadc/s_axi_aclk]
  connect_bd_net -net clk_gen_clk_200 [get_bd_pins clk_gen/clk_200] [get_bd_pins rp_dac/m_axi_dac1_aclk] [get_bd_pins rp_dac/m_axi_dac2_aclk] [get_bd_pins rst_gen2/slowest_sync_clk] [get_bd_pins system_model/S_AXI_HP2_aclk] [get_bd_pins system_model/S_AXI_HP3_aclk]
  connect_bd_net -net clk_gen_clk_62_5 [get_bd_ports FCLK_CLK2] [get_bd_pins axi_reg/ACLK] [get_bd_pins axi_reg/M00_ACLK] [get_bd_pins axi_reg/M01_ACLK] [get_bd_pins axi_reg/M02_ACLK] [get_bd_pins axi_reg/S00_ACLK] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] [get_bd_pins rp_dac/s_axi_reg_aclk] [get_bd_pins rp_gpio/s_axi_reg_aclk] [get_bd_pins rp_oscilloscope/s_axi_reg_aclk] [get_bd_pins rst_gen3/slowest_sync_clk] [get_bd_pins system_model/FCLK_CLK2] [get_bd_pins system_model/M_AXI_GP0_ACLK]
  connect_bd_net -net clk_gen_locked [get_bd_pins clk_gen/locked] [get_bd_pins rst_gen/dcm_locked] [get_bd_pins rst_gen2/dcm_locked]
  connect_bd_net -net dac_data_ch1_0_1 [get_bd_ports dac_dat_a] [get_bd_pins rp_dac/dac_data_cha_o]
  connect_bd_net -net dac_data_ch2_0_1 [get_bd_ports dac_dat_b] [get_bd_pins rp_dac/dac_data_chb_o]
  connect_bd_net -net intr_concat_dout [get_bd_pins intr_concat/dout] [get_bd_pins system_model/IRQ_F2P]
  connect_bd_net -net loopback_sel_scope [get_bd_ports loopback_sel] [get_bd_pins rp_oscilloscope/loopback_sel]
  connect_bd_net -net rp_concat_0_event_reset [get_bd_pins rp_concat/event_reset] [get_bd_pins rp_dac/event_ip_reset] [get_bd_pins rp_gpio/event_ip_reset] [get_bd_pins rp_oscilloscope/event_ip_reset]
  connect_bd_net -net rp_concat_0_event_start [get_bd_pins rp_concat/event_start] [get_bd_pins rp_dac/event_ip_start] [get_bd_pins rp_gpio/event_ip_start] [get_bd_pins rp_oscilloscope/event_ip_start]
  connect_bd_net -net rp_concat_0_event_stop [get_bd_pins rp_concat/event_stop] [get_bd_pins rp_dac/event_ip_stop] [get_bd_pins rp_gpio/event_ip_stop] [get_bd_pins rp_oscilloscope/event_ip_stop]
  connect_bd_net -net rp_concat_event_trig [get_bd_pins rp_concat/event_trig] [get_bd_pins rp_dac/event_ip_trig] [get_bd_pins rp_gpio/event_ip_trig] [get_bd_pins rp_oscilloscope/event_ip_trig]
  connect_bd_net -net rp_concat_ext_trig_ip [get_bd_ports trig_in] [get_bd_pins rp_concat/ext_trig_ip]
  connect_bd_net -net rp_concat_trig [get_bd_pins rp_concat/trig] [get_bd_pins rp_dac/trig_ip] [get_bd_pins rp_gpio/trig_ip] [get_bd_pins rp_oscilloscope/trig_ip]
  connect_bd_net -net rp_dac_dac1_event_op [get_bd_pins rp_concat/gen1_event_ip] [get_bd_pins rp_dac/dac1_event_op]
  connect_bd_net -net rp_dac_dac1_trig_op [get_bd_pins rp_concat/gen1_trig_ip] [get_bd_pins rp_dac/dac1_trig_op]
  connect_bd_net -net rp_dac_dac2_event_op [get_bd_pins rp_concat/gen2_event_ip] [get_bd_pins rp_dac/dac2_event_op]
  connect_bd_net -net rp_dac_dac2_trig_op [get_bd_pins rp_concat/gen2_trig_ip] [get_bd_pins rp_dac/dac2_trig_op]
  connect_bd_net -net rp_dac_intr [get_bd_pins intr_concat/In14] [get_bd_pins rp_dac/intr]
  connect_bd_net -net rp_gpio_gpio_trig_o [get_bd_ports gpio_trig] [get_bd_pins rp_gpio/gpio_trig_o]
  connect_bd_net -net rp_gpio_intr [get_bd_pins intr_concat/In13] [get_bd_pins rp_gpio/intr]
  connect_bd_net -net rp_gpio_la_event_op [get_bd_pins rp_concat/la_event_ip] [get_bd_pins rp_gpio/la_event_op]
  connect_bd_net -net rp_gpio_la_trig_op [get_bd_pins rp_concat/la_trig_ip] [get_bd_pins rp_gpio/la_trig_op]
  connect_bd_net -net rp_oscilloscope_0_clksel [get_bd_ports clksel] [get_bd_pins rp_oscilloscope/clksel_o]
  connect_bd_net -net rp_oscilloscope_0_intr [get_bd_pins intr_concat/In15] [get_bd_pins rp_oscilloscope/intr]
  connect_bd_net -net rp_oscilloscope_0_osc1_event_op [get_bd_pins rp_concat/osc1_event_ip] [get_bd_pins rp_oscilloscope/osc1_event_op]
  connect_bd_net -net rp_oscilloscope_0_osc1_trig_op [get_bd_pins rp_concat/osc1_trig_ip] [get_bd_pins rp_oscilloscope/osc1_trig_op]
  connect_bd_net -net rp_oscilloscope_0_osc2_event_op [get_bd_pins rp_concat/osc2_event_ip] [get_bd_pins rp_oscilloscope/osc2_event_op]
  connect_bd_net -net rp_oscilloscope_0_osc2_trig_op [get_bd_pins rp_concat/osc2_trig_ip] [get_bd_pins rp_oscilloscope/osc2_trig_op]
  connect_bd_net -net rp_oscilloscope_trig_out [get_bd_ports trig_out] [get_bd_pins rp_oscilloscope/trig_out]
  connect_bd_net -net rst_gen2_peripheral_aresetn [get_bd_pins rp_dac/m_axi_dac1_aresetn] [get_bd_pins rp_dac/m_axi_dac2_aresetn] [get_bd_pins rst_gen2/peripheral_aresetn]
  connect_bd_net -net slave_mode_in [get_bd_ports daisy_slave] [get_bd_pins rp_oscilloscope/daisy_slave_i]
  connect_bd_net -net system_model_0_FCLK_RESET2_N [get_bd_ports FCLK_RESET2_N] [get_bd_pins rst_gen/ext_reset_in] [get_bd_pins rst_gen2/ext_reset_in] [get_bd_pins rst_gen3/ext_reset_in] [get_bd_pins system_model/FCLK_RESET2_N]
  connect_bd_net -net system_model_FCLK_CLK0 [get_bd_ports FCLK_CLK0] [get_bd_pins system_model/FCLK_CLK0]
  connect_bd_net -net system_model_FCLK_CLK1 [get_bd_ports FCLK_CLK1] [get_bd_pins system_model/FCLK_CLK1]
  connect_bd_net -net system_model_FCLK_CLK3 [get_bd_ports FCLK_CLK3] [get_bd_pins system_model/FCLK_CLK3]
  connect_bd_net -net system_model_FCLK_RESET0_N [get_bd_ports FCLK_RESET0_N] [get_bd_pins system_model/FCLK_RESET0_N]
  connect_bd_net -net system_model_FCLK_RESET1_N [get_bd_ports FCLK_RESET1_N] [get_bd_pins system_model/FCLK_RESET1_N]
  connect_bd_net -net system_model_FCLK_RESET3_N [get_bd_ports FCLK_RESET3_N] [get_bd_pins system_model/FCLK_RESET3_N]
  connect_bd_net -net xadc_ip2intc_irpt [get_bd_pins intr_concat/In0] [get_bd_pins xadc/ip2intc_irpt]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins rp_oscilloscope/adc_data_ch3] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins rp_oscilloscope/adc_data_ch4] [get_bd_pins xlconstant_1/dout]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_dac/m_axi_dac1] [get_bd_addr_segs system_model/S_AXI_HP2/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_dac/m_axi_dac2] [get_bd_addr_segs system_model/S_AXI_HP3/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_gpio/axi_gpio_in] [get_bd_addr_segs system_model/S_AXI_HP1/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_gpio/axi_gpio_out] [get_bd_addr_segs system_model/S_AXI_HP1/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_oscilloscope/m_axi_osc1] [get_bd_addr_segs system_model/S_AXI_HP0/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces rp_oscilloscope/m_axi_osc2] [get_bd_addr_segs system_model/S_AXI_HP0/reg0] -force
  assign_bd_address -offset 0x40100000 -range 0x00100000 -target_address_space [get_bd_addr_spaces system_model/M_AXI_GP0] [get_bd_addr_segs rp_dac/s_axi_reg/reg0] -force
  assign_bd_address -offset 0x40200000 -range 0x00100000 -target_address_space [get_bd_addr_spaces system_model/M_AXI_GP0] [get_bd_addr_segs rp_gpio/s_axi_reg/reg0] -force
  assign_bd_address -offset 0x40000000 -range 0x00100000 -target_address_space [get_bd_addr_spaces system_model/M_AXI_GP0] [get_bd_addr_segs rp_oscilloscope/s_axi_reg/reg0] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################


common::send_gid_msg -ssname BD::TCL -id 2052 -severity "CRITICAL WARNING" "This Tcl script was generated from a block design that is out-of-date/locked. It is possible that design <$design_name> may result in errors during construction."

create_root_design ""


