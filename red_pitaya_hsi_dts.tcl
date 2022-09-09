################################################################################
# HSI tcl script for building RedPitaya DTS (device tree)
#
# Usage:
# hsi -mode tcl -source red_pitaya_hsi_dts.tcl -tclargs projectname
################################################################################


set prj_name [lindex $argv 0]
cd prj/$prj_name

set path_sdk sdk

open_hw_design $path_sdk/red_pitaya.sysdef

set ver 2017.2

foreach item $argv {
  puts "Input arfguments: $argv"
  if {[lsearch -all $item "*DTS_VER*"] >= 0} {
    set param [split $item "="]
    if {[lindex $param 1] ne ""} {
      set ver [lindex $param 1]
    }
  }
}
puts "DTS version: $ver"


set_repo_path ../../../tmp/device-tree-xlnx-xilinx-v$ver/

create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0

set_property CONFIG.kernel_version $ver [get_os]

generate_target -dir $path_sdk/dts

exit
