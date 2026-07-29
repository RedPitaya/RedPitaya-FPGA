################################################################################
# Vivado tcl script for building RedPitaya FPGA in non project mode
#
# Usage:
# vivado -mode tcl -source red_pitaya_vivado_Z20.tcl -tclargs projectname
################################################################################

set prj_name [lindex $argv 0]
set prj_defs [lindex $argv 1]
set prj_top "red_pitaya_top_Z20"
set prj_dir "build"
set prj_board "z20"
puts "Project name: $prj_name"
puts "Defines: $prj_defs"
# Absolute path to this directory, captured before the cd below changes the
# working directory.  Needed to source red_pitaya_vivado_timing_gate.tcl later:
# by then the cwd is prj/<name>, so a relative path would resolve inside it.
set ::RP_ROOT_DIR [file normalize [file dirname [info script]]]

cd prj/$prj_name
#cd prj/$::argv 0

set dev_mode 0
foreach item $argv {
  if {[lsearch -all $item "*DEV_MODE*"] >= 0} {
    set dev_mode 1
  }
}

################################################################################
# install UltraFast Design Methodology from TCL Store
################################################################################

tclapp::install -quiet ultrafast

################################################################################
# define paths
################################################################################

set path_brd ../../brd
set path_rtl rtl/rtl
set path_rtl_prj rtl
set path_ip      ip
set path_ip_top  ../../ip/ip
set path_bd  $prj_dir/redpitaya.gen/sources_1/bd/system/hdl
set path_bd_src  $prj_dir/redpitaya.srcs/sources_1/bd/system
set path_sdc ../../sdc
set path_sdc_prj sdc

set path_out out
set path_sdk sdk

file mkdir $path_out
file mkdir $path_sdk

################################################################################
# list board files
################################################################################

set_param board.repoPaths [list $path_brd]
set_param iconstr.diffPairPulltype {opposite}

################################################################################
# setup an in memory project
################################################################################

set part xc7z020clg400-1
set ::cpu_part xc7z020clg400-1
set ::bus_w_bit "16 Bit"
set ::dram_w_bit "16 Bits"

create_project -part $part -force redpitaya $prj_dir

################################################################################
# create PS BD (processing system block design)
################################################################################

# file was created from GUI using "write_bd_tcl -force ip/systemZ20.tcl"
# create PS BD
set ::gpio_width 33
set ::clk0_freq 125000000
set ::clk1_freq 250000000
set ::clk2_freq 50000000
set ::clk3_freq 200000000

set ::gp0_clk_freq 125000000
set ::hp0_clk_freq 125000000
set ::hp1_clk_freq 125000000
set ::hp2_clk_freq 250000000
set ::hp3_clk_freq 250000000

if {$prj_name == "stream_app"} {
   set ::stream_app_rtl $path_rtl_prj/rtl
   set ::stream_app_adc_clk 122880000
   set ::stream_app_dac_data_bit 15
   set ::stream_app_adc_count 2
   set ::stream_app_adc_bits 16
}

if {$prj_name == "logic"} {
   set ::logic_freq 122880000
}

set_property verilog_define [concat Z20_122 Z20_xx $prj_defs] [current_fileset]
source $path_ip/system.tcl

# generate SDK files
generate_target all [get_files    system.bd]
make_wrapper -files [get_files *.bd] -top

write_hwdef -force       -file    $path_sdk/red_pitaya.hwdef

################################################################################
# read files:
# 1. RTL design sources
# 2. IP database files
# 3. constraints
################################################################################


if {$prj_name != "pyrpl"} {
   add_files -fileset sources_1      ../../$path_rtl
   add_files -fileset constrs_1      $path_sdc/red_pitaya_z20.xdc
}

add_files  -fileset sources_1 -norecurse $path_rtl_prj
add_files                               $path_bd

set ip_files [glob -nocomplain $path_ip/*.xci]
if {$ip_files != ""} {
add_files                         $ip_files
}

if {[file isdirectory $path_ip_top/asg_dat_fifo]} {
source ${path_ip_top}/asg_dat_fifo/asg_dat_fifo.tcl
}

if {[file isdirectory $path_ip_top/sync_fifo]} {
source ${path_ip_top}/sync_fifo/sync_fifo.tcl
}

if {[file exists $path_sdc_prj/red_pitaya_z20.xdc]} {
   add_files -fileset constrs_1      $path_sdc_prj/red_pitaya_z20.xdc
}

################################################################################
# ser parameter containing Git hash
################################################################################

set gith [exec git log -1 --format="%H"]
set_property generic "GITH=160'h$gith" [current_fileset]
set_property top $prj_top [current_fileset]

################################################################################
# run synthesis
# report utilization and timing estimates
# write checkpoint design
################################################################################

update_compile_order -fileset sources_1

if {$dev_mode == 1} {return}

launch_runs synth_1
wait_on_run synth_1

set rptFiles [glob -directory ./$prj_dir/redpitaya.runs/synth_1/  *.rpt]
file copy -force $rptFiles ./$path_out/

################################################################################
# run placement and logic optimization
# report utilization and timing estimates
# write checkpoint design
################################################################################

launch_runs impl_1
wait_on_run impl_1

set rptFiles [glob -directory ./$prj_dir/redpitaya.runs/impl_1/  *.rpt]
foreach file $rptFiles {
   file copy -force $file ./$path_out/
}
################################################################################
# generate a bitstream
################################################################################

#launch_runs impl_1 -to_step write_bitstream
#wait_on_run impl_1

open_run impl_1

# Refuse to emit a bitstream that does not meet timing.
# Override for a deliberate experimental build: make ... DEFINES=ALLOW_TIMING_FAIL
source [file join $::RP_ROOT_DIR red_pitaya_vivado_timing_gate.tcl]
rp_check_timing $path_out

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
write_bitstream -force            $path_out/red_pitaya
write_cfgmem -format BIN -interface SMAPx32 -disablebitswap -loadbit "up 0x0 $path_out/red_pitaya.bit" -file $path_out/red_pitaya.bin


################################################################################
# generate system definition
################################################################################


set_property platform.default_output_type "sd_card" [current_project]
set_property platform.board_id "redpitaya" [current_project]
set_property platform.name "redpitaya_platform" [current_project]
set_property platform.design_intent.embedded true [current_project]
set_property platform.design_intent.external_host false [current_project]
set_property platform.design_intent.datacenter false [current_project]
set_property platform.design_intent.server_managed false [current_project]

write_hw_platform -force -file $path_sdk/red_pitaya.xsa

exit
