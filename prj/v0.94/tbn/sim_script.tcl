set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse {/home/juretrnovec/RPdev/RP30/redpitaya-fpga/redpitaya-fpga/prj/v0.94/tbn/top_tb.sv /home/juretrnovec/RPdev/RP30/redpitaya-fpga/redpitaya-fpga/prj/v0.94/tbn/top_tc.sv}
add_files -fileset sim_1 -norecurse /home/juretrnovec/RPdev/RP30/redpitaya-fpga/redpitaya-fpga/tbn
set_property verilog_define {SIMULATION} [get_filesets sim_1]
set_property top top_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property SOURCE_SET sources_1 [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation