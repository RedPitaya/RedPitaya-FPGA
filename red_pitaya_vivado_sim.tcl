################################################################################
# Vivado tcl script for building RedPitaya FPGA in non project mode
#
# Usage:
# vivado -mode batch -source red_pitaya_vivado_project_Z20.tcl -tclargs projectname
################################################################################

set prj_name [lindex $argv 0]
set model [lindex $argv 1]
set defines [lindex $argv 2]

puts "Project name: $prj_name"
cd prj/$prj_name
#cd prj/$::argv 0

################################################################################
# define paths
################################################################################

set path_brd ../../brd
set path_rtl rtl
set path_ip  ip
set path_bd  sim/redpitaya.srcs/sources_1/bd/system/hdl
set path_sdc ../../sdc
set path_tbn tbn
set path_tbn_top ../../tbn

set path_sdc_prj sdc

################################################################################
# list board files
################################################################################

set_param board.repoPaths [list $path_brd]

################################################################################
# setup an in memory project
################################################################################

set part xc7z020clg400-1

create_project -part $part -force redpitaya ./sim

################################################################################
# create PS BD (processing system block design)
################################################################################

# file was created from GUI using "write_bd_tcl -force ip/systemZ20.tcl"
# create PS BD
set ::gpio_width 24

set def_name "v0.94"
set def_model "Z10_14"

if {($prj_name == "stream_app") || ($prj_name == "stream_app_250") || ($prj_name == "stream_app_4ch")} {
set def_name "STREAMING"
}

if {($model == "Z20_250")} {
set path_rtl rtl_250
}

switch $model {
"Z20" {
    set def_model "Z20_16"
}
"Z20_14" {
    set def_model "Z20_14"
}
"Z20_4" {
    set def_model "Z20_4ADC"
}
"Z20_250" {
    set def_model "Z20_250"
}
default {
    set def_model "Z10_14"
}
}

set repos $path_tbn_top\ $path_ip
set_property ip_repo_paths $repos [current_project]

set defines SIMULATION\ ${def_name}\ ${def_model}
set_property verilog_define $defines [get_filesets sim_1]

set binfiles $path_tbn_top/dac_src_ch1.bin\ $path_tbn_top/adc_src_ch2.bin\ $path_tbn_top/adc_src_ch3.bin\ $path_tbn_top/adc_src_ch0.bin\ $path_tbn_top/dac_src_ch0.bin\ $path_tbn_top/adc_src_ch1.bin\ $path_tbn_top/gpio_src_out.bin
if {($def_name == "STREAMING")} {
    switch $def_model {
    "Z20" {
        source ${path_tbn}/systemZ20_sim.tcl
    }
    "Z20_14" {
        source ${path_tbn}/systemZ20_14_sim.tcl
    }
    "Z20_4" {
        source ${path_tbn}/systemZ20_14_sim.tcl
    }
    "Z20_250" {
        source ${path_tbn}/systemZ20_sim.tcl
    }
    default {
        source ${path_tbn}/systemZ10_sim.tcl
    }
    }
} else {
    switch $def_model {
    "Z20" {
        source ${path_ip}/systemZ20.tcl
    }
    "Z20_14" {
        source ${path_ip}/systemZ20_14.tcl
    }
    "Z20_4" {
        source ${path_ip}/systemZ20_14.tcl
    }
    "Z20_250" {
        source ${path_ip}/systemZ20.tcl
    }
    default {
        source ${path_ip}/systemZ10.tcl
    }
    }
}



# generate SDK files
generate_target all [get_files    system.bd]

################################################################################
# read files:
# 1. RTL design sources
# 2. IP database files
# 3. constraints
################################################################################

add_files                         ../../$path_rtl
add_files                         $path_rtl
add_files                         $path_bd
add_files                         $path_tbn
add_files                         $path_tbn_top
add_files -fileset sim_1 -norecurse $binfiles

set ip_files [glob -nocomplain $path_ip/*.xci]
if {$ip_files != ""} {
add_files                         $ip_files
}

add_files -fileset constrs_1      $path_sdc/red_pitaya.xdc
add_files -fileset constrs_1      $path_sdc_prj/red_pitaya.xdc

################################################################################
# start gui
################################################################################

import_files -force

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top top_tb [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation
