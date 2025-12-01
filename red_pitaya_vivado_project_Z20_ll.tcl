################################################################################
# Vivado tcl script for building RedPitaya FPGA in non project mode
#
# Usage:
# vivado -mode batch -source red_pitaya_vivado_project_Z20.tcl -tclargs projectname
################################################################################

set prj_name [lindex $argv 0]
set prj_defs [lindex $argv 1]
puts "Project name: $prj_name"
puts "Defines: $prj_defs"
cd prj/$prj_name
#cd prj/$::argv 0

################################################################################
# define paths
################################################################################

set path_brd ../../brd
set path_rtl rtl
set path_ip      ip
set path_ip_top  ../../ip
set path_bd  project/redpitaya.srcs/sources_1/bd/system/hdl
set path_sdc ../../sdc_ll
set path_sdc_prj sdc

################################################################################
# list board files
################################################################################

set_param board.repoPaths [list $path_brd]
set_param iconstr.diffPairPulltype {opposite}

################################################################################
# setup an in memory project
################################################################################

set part xc7z020clg400-1

create_project -part $part -force redpitaya ./project

################################################################################
# create PS BD (processing system block design)
################################################################################

# file was created from GUI using "write_bd_tcl -force ip/systemZ20.tcl"
# create PS BD
set ::gpio_width 24
set ::hp0_clk_freq 125000000
set ::hp1_clk_freq 125000000
set ::hp2_clk_freq 250000000
set ::hp3_clk_freq 250000000

set_property verilog_define [concat Z20_LL $prj_defs] [current_fileset]

source                            $path_ip/systemZ20_ll.tcl

# generate SDK files
generate_target all [get_files    system.bd]

################################################################################
# read files:
# 1. RTL design sources
# 2. IP database files
# 3. constraints
################################################################################

if {$prj_name != "pyrpl"} {
add_files                         ../../$path_rtl
add_files -fileset constrs_1      $path_sdc/red_pitaya.xdc
}

add_files                         $path_rtl
add_files                         $path_bd

set ip_files [glob -nocomplain $path_ip/*.xci]
if {$ip_files != ""} {
add_files                         $ip_files
}

if {[file isdirectory $path_ip_top/asg_dat_fifo]} {
add_files $path_ip_top/asg_dat_fifo/asg_dat_fifo.xci
}

if {[file isdirectory $path_ip_top/sync_fifo]} {
add_files $path_ip_top/sync_fifo/sync_fifo.xci
}

if {[file isdirectory $path_ip_top/ila_0]} {
add_file $path_ip_top/ila_0/ila_0.xci
upgrade_ip [get_ips ila_0]
synth_ip [get_ips ila_0]
}

add_files -fileset constrs_1      $path_sdc_prj/red_pitaya.xdc

################################################################################
# start gui
################################################################################

import_files -force

update_compile_order -fileset sources_1

set_property top red_pitaya_top [current_fileset]
