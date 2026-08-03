################################################################################
# Vivado tcl script for building RedPitaya FPGA in non project mode
#
# Usage:
# vivado -mode tcl -source red_pitaya_vivado_Z10.tcl -tclargs projectname
################################################################################


puts "Input arfguments: $argv"
foreach item $argv {
   if {[lsearch -all $item "*MODEL*"] >= 0} {
      set list [split $item "="]
      set board_cpu_model [lindex $list 1]
      puts "Board CPU model: $board_cpu_model"
   }

   if {[lsearch -all $item "*RAM*"] >= 0} {
      set list [split $item "="]
      set board_ram_size [lindex $list 1]
      puts "Board RAM size: $board_ram_size"
   }
}

set prj_top "red_pitaya_top"
set prj_dir "build"
# Absolute path to this directory, captured before the cd below changes the
# working directory. Needed later to reliably locate the repository's .git.
set ::RP_ROOT_DIR [file normalize [file dirname [info script]]]

cd prj/fsbl

################################################################################
# install UltraFast Design Methodology from TCL Store
################################################################################

tclapp::install -quiet ultrafast

################################################################################
# define paths
################################################################################

set path_rtl rtl
set path_ip  ip

set path_out out
set path_sdk sdk

file mkdir $path_out
file mkdir $path_sdk

################################################################################
# setup an in memory project
################################################################################

if {$board_cpu_model == "Z10"} {
   set part xc7z010clg400-1
   set ::cpu_part xc7z010clg400-1
   set ::gpio_width 24
}

if {$board_cpu_model == "Z20"} {
   set part xc7z020clg400-1
   set ::cpu_part xc7z020clg400-1
   set ::gpio_width 33
}

if {$board_ram_size == "512"} {
   set ::bus_w_bit "16 Bit"
   set ::dram_w_bit "16 Bits"
}

if {$board_ram_size == "1024"} {
   set ::bus_w_bit "32 Bit"
   set ::dram_w_bit "32 Bits"
}

if {![info exists part]} {
    error "Variable cpu_part not defined"
}


create_project -part $part -force redpitaya $prj_dir

################################################################################
# create PS BD (processing system block design)
################################################################################

# file was created from GUI using "write_bd_tcl -force ip/systemZ10.tcl"
# create PS BD

set ::clk0_freq 125000000
set ::clk1_freq 250000000
set ::clk2_freq 50000000
set ::clk3_freq 200000000

set ::hp0_clk_freq 125000000
set ::hp1_clk_freq 125000000
set ::hp2_clk_freq 250000000
set ::hp3_clk_freq 250000000

source  $path_ip/system.tcl

# generate SDK files

################################################################################
# read files:
# 1. RTL design sources
# 2. IP database files
# 3. constraints
################################################################################

add_files -quiet                  [glob -nocomplain ../../$path_rtl/*_pkg.sv]
add_files -quiet                  [glob -nocomplain       $path_rtl/*_pkg.sv]

add_files                         ../../$path_rtl
add_files                         $path_rtl

################################################################################
# set parameter containing Git hash
################################################################################
# Falls back to a placeholder hash when git is not installed, or when the
# repository has no .git (e.g. it was extracted from a zip archive), so the
# build does not abort just because git information is unavailable.

set gith "0000000000000000000000000000000000000000"
if {[catch {exec git --version}]} {
    puts "WARNING: git executable not found - GITH will use a placeholder value."
} elseif {![file exists [file join $::RP_ROOT_DIR .git]]} {
    puts "WARNING: .git not found in $::RP_ROOT_DIR (repository may have been extracted from a zip archive) - GITH will use a placeholder value."
} elseif {[catch {exec git -C $::RP_ROOT_DIR log -1 --format="%H"} git_hash_result]} {
    puts "WARNING: git log failed ($git_hash_result) - GITH will use a placeholder value."
} else {
    set gith $git_hash_result
}
set_property generic "GITH=160'h$gith" [current_fileset]
set_property top $prj_top [current_fileset]

puts "GIT = $gith"

################################################################################
# run synthesis
# report utilization and timing estimates
# write checkpoint design
################################################################################

update_compile_order -fileset sources_1

launch_runs synth_1
wait_on_run synth_1

set rptFiles [glob -directory ./$prj_dir/redpitaya.runs/synth_1/  *.rpt]
file copy -force $rptFiles ./$path_out/

################################################################################
# generate system definition
################################################################################


set_property platform.default_output_type "sd_card" [current_project]
set_property platform.board_id "redpitaya" [current_project]
set_property platform.name "redpitaya_platform" [current_project]

write_hw_platform -fixed -force -file $path_sdk/red_pitaya.xsa

exit
