################################################################################
# HSI tcl script for building RedPitaya DTS (device tree)
#
# Usage:
# hsi -mode tcl -source red_pitaya_hsi_dts.tcl -tclargs projectname
################################################################################


set prj_name [lindex $argv 0]
cd prj/$prj_name

set path_sdk sdk

hsi open_hw_design $path_sdk/red_pitaya.sysdef

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


hsi set_repo_path ../../../tmp/device-tree-xlnx-xilinx-v$ver/

hsi create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0

hsi set_property CONFIG.kernel_version $ver [hsi get_os]
hsi set_property CONFIG.dt_overlay true [hsi get_os]

hsi generate_target -dir $path_sdk/dts

exit
