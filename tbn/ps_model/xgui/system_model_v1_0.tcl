# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"

  ipgui::add_param $IPINST -name "GP0_AW"
  ipgui::add_param $IPINST -name "GP0_DW"
  ipgui::add_param $IPINST -name "GP0_IW"
  ipgui::add_param $IPINST -name "HP0_AW"
  ipgui::add_param $IPINST -name "HP0_DW"
  ipgui::add_param $IPINST -name "HP0_IW"
  ipgui::add_param $IPINST -name "HP1_AW"
  ipgui::add_param $IPINST -name "HP1_DW"
  ipgui::add_param $IPINST -name "HP1_IW"
  ipgui::add_param $IPINST -name "HP2_AW"
  ipgui::add_param $IPINST -name "HP2_DW"
  ipgui::add_param $IPINST -name "HP2_IW"
  ipgui::add_param $IPINST -name "HP3_AW"
  ipgui::add_param $IPINST -name "HP3_DW"
  ipgui::add_param $IPINST -name "HP3_IW"

}

proc update_PARAM_VALUE.GP0_AW { PARAM_VALUE.GP0_AW } {
	# Procedure called to update GP0_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GP0_AW { PARAM_VALUE.GP0_AW } {
	# Procedure called to validate GP0_AW
	return true
}

proc update_PARAM_VALUE.GP0_DW { PARAM_VALUE.GP0_DW } {
	# Procedure called to update GP0_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GP0_DW { PARAM_VALUE.GP0_DW } {
	# Procedure called to validate GP0_DW
	return true
}

proc update_PARAM_VALUE.GP0_IW { PARAM_VALUE.GP0_IW } {
	# Procedure called to update GP0_IW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GP0_IW { PARAM_VALUE.GP0_IW } {
	# Procedure called to validate GP0_IW
	return true
}

proc update_PARAM_VALUE.GP0_SZ { PARAM_VALUE.GP0_SZ } {
	# Procedure called to update GP0_SZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GP0_SZ { PARAM_VALUE.GP0_SZ } {
	# Procedure called to validate GP0_SZ
	return true
}

proc update_PARAM_VALUE.HP0_AW { PARAM_VALUE.HP0_AW } {
	# Procedure called to update HP0_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP0_AW { PARAM_VALUE.HP0_AW } {
	# Procedure called to validate HP0_AW
	return true
}

proc update_PARAM_VALUE.HP0_DW { PARAM_VALUE.HP0_DW } {
	# Procedure called to update HP0_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP0_DW { PARAM_VALUE.HP0_DW } {
	# Procedure called to validate HP0_DW
	return true
}

proc update_PARAM_VALUE.HP0_IW { PARAM_VALUE.HP0_IW } {
	# Procedure called to update HP0_IW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP0_IW { PARAM_VALUE.HP0_IW } {
	# Procedure called to validate HP0_IW
	return true
}

proc update_PARAM_VALUE.HP0_SZ { PARAM_VALUE.HP0_SZ } {
	# Procedure called to update HP0_SZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP0_SZ { PARAM_VALUE.HP0_SZ } {
	# Procedure called to validate HP0_SZ
	return true
}

proc update_PARAM_VALUE.HP1_AW { PARAM_VALUE.HP1_AW } {
	# Procedure called to update HP1_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP1_AW { PARAM_VALUE.HP1_AW } {
	# Procedure called to validate HP1_AW
	return true
}

proc update_PARAM_VALUE.HP1_DW { PARAM_VALUE.HP1_DW } {
	# Procedure called to update HP1_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP1_DW { PARAM_VALUE.HP1_DW } {
	# Procedure called to validate HP1_DW
	return true
}

proc update_PARAM_VALUE.HP1_IW { PARAM_VALUE.HP1_IW } {
	# Procedure called to update HP1_IW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP1_IW { PARAM_VALUE.HP1_IW } {
	# Procedure called to validate HP1_IW
	return true
}

proc update_PARAM_VALUE.HP1_SZ { PARAM_VALUE.HP1_SZ } {
	# Procedure called to update HP1_SZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP1_SZ { PARAM_VALUE.HP1_SZ } {
	# Procedure called to validate HP1_SZ
	return true
}

proc update_PARAM_VALUE.HP2_AW { PARAM_VALUE.HP2_AW } {
	# Procedure called to update HP2_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP2_AW { PARAM_VALUE.HP2_AW } {
	# Procedure called to validate HP2_AW
	return true
}

proc update_PARAM_VALUE.HP2_DW { PARAM_VALUE.HP2_DW } {
	# Procedure called to update HP2_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP2_DW { PARAM_VALUE.HP2_DW } {
	# Procedure called to validate HP2_DW
	return true
}

proc update_PARAM_VALUE.HP2_IW { PARAM_VALUE.HP2_IW } {
	# Procedure called to update HP2_IW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP2_IW { PARAM_VALUE.HP2_IW } {
	# Procedure called to validate HP2_IW
	return true
}

proc update_PARAM_VALUE.HP2_SZ { PARAM_VALUE.HP2_SZ } {
	# Procedure called to update HP2_SZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP2_SZ { PARAM_VALUE.HP2_SZ } {
	# Procedure called to validate HP2_SZ
	return true
}

proc update_PARAM_VALUE.HP3_AW { PARAM_VALUE.HP3_AW } {
	# Procedure called to update HP3_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP3_AW { PARAM_VALUE.HP3_AW } {
	# Procedure called to validate HP3_AW
	return true
}

proc update_PARAM_VALUE.HP3_DW { PARAM_VALUE.HP3_DW } {
	# Procedure called to update HP3_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP3_DW { PARAM_VALUE.HP3_DW } {
	# Procedure called to validate HP3_DW
	return true
}

proc update_PARAM_VALUE.HP3_IW { PARAM_VALUE.HP3_IW } {
	# Procedure called to update HP3_IW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP3_IW { PARAM_VALUE.HP3_IW } {
	# Procedure called to validate HP3_IW
	return true
}

proc update_PARAM_VALUE.HP3_SZ { PARAM_VALUE.HP3_SZ } {
	# Procedure called to update HP3_SZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HP3_SZ { PARAM_VALUE.HP3_SZ } {
	# Procedure called to validate HP3_SZ
	return true
}


proc update_MODELPARAM_VALUE.GP0_AW { MODELPARAM_VALUE.GP0_AW PARAM_VALUE.GP0_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GP0_AW}] ${MODELPARAM_VALUE.GP0_AW}
}

proc update_MODELPARAM_VALUE.GP0_DW { MODELPARAM_VALUE.GP0_DW PARAM_VALUE.GP0_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GP0_DW}] ${MODELPARAM_VALUE.GP0_DW}
}

proc update_MODELPARAM_VALUE.GP0_IW { MODELPARAM_VALUE.GP0_IW PARAM_VALUE.GP0_IW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GP0_IW}] ${MODELPARAM_VALUE.GP0_IW}
}

proc update_MODELPARAM_VALUE.GP0_SZ { MODELPARAM_VALUE.GP0_SZ PARAM_VALUE.GP0_SZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GP0_SZ}] ${MODELPARAM_VALUE.GP0_SZ}
}

proc update_MODELPARAM_VALUE.HP0_AW { MODELPARAM_VALUE.HP0_AW PARAM_VALUE.HP0_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP0_AW}] ${MODELPARAM_VALUE.HP0_AW}
}

proc update_MODELPARAM_VALUE.HP0_DW { MODELPARAM_VALUE.HP0_DW PARAM_VALUE.HP0_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP0_DW}] ${MODELPARAM_VALUE.HP0_DW}
}

proc update_MODELPARAM_VALUE.HP0_IW { MODELPARAM_VALUE.HP0_IW PARAM_VALUE.HP0_IW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP0_IW}] ${MODELPARAM_VALUE.HP0_IW}
}

proc update_MODELPARAM_VALUE.HP0_SZ { MODELPARAM_VALUE.HP0_SZ PARAM_VALUE.HP0_SZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP0_SZ}] ${MODELPARAM_VALUE.HP0_SZ}
}

proc update_MODELPARAM_VALUE.HP1_AW { MODELPARAM_VALUE.HP1_AW PARAM_VALUE.HP1_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP1_AW}] ${MODELPARAM_VALUE.HP1_AW}
}

proc update_MODELPARAM_VALUE.HP1_DW { MODELPARAM_VALUE.HP1_DW PARAM_VALUE.HP1_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP1_DW}] ${MODELPARAM_VALUE.HP1_DW}
}

proc update_MODELPARAM_VALUE.HP1_IW { MODELPARAM_VALUE.HP1_IW PARAM_VALUE.HP1_IW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP1_IW}] ${MODELPARAM_VALUE.HP1_IW}
}

proc update_MODELPARAM_VALUE.HP1_SZ { MODELPARAM_VALUE.HP1_SZ PARAM_VALUE.HP1_SZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP1_SZ}] ${MODELPARAM_VALUE.HP1_SZ}
}

proc update_MODELPARAM_VALUE.HP2_AW { MODELPARAM_VALUE.HP2_AW PARAM_VALUE.HP2_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP2_AW}] ${MODELPARAM_VALUE.HP2_AW}
}

proc update_MODELPARAM_VALUE.HP2_DW { MODELPARAM_VALUE.HP2_DW PARAM_VALUE.HP2_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP2_DW}] ${MODELPARAM_VALUE.HP2_DW}
}

proc update_MODELPARAM_VALUE.HP2_IW { MODELPARAM_VALUE.HP2_IW PARAM_VALUE.HP2_IW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP2_IW}] ${MODELPARAM_VALUE.HP2_IW}
}

proc update_MODELPARAM_VALUE.HP2_SZ { MODELPARAM_VALUE.HP2_SZ PARAM_VALUE.HP2_SZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP2_SZ}] ${MODELPARAM_VALUE.HP2_SZ}
}

proc update_MODELPARAM_VALUE.HP3_AW { MODELPARAM_VALUE.HP3_AW PARAM_VALUE.HP3_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP3_AW}] ${MODELPARAM_VALUE.HP3_AW}
}

proc update_MODELPARAM_VALUE.HP3_DW { MODELPARAM_VALUE.HP3_DW PARAM_VALUE.HP3_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP3_DW}] ${MODELPARAM_VALUE.HP3_DW}
}

proc update_MODELPARAM_VALUE.HP3_IW { MODELPARAM_VALUE.HP3_IW PARAM_VALUE.HP3_IW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP3_IW}] ${MODELPARAM_VALUE.HP3_IW}
}

proc update_MODELPARAM_VALUE.HP3_SZ { MODELPARAM_VALUE.HP3_SZ PARAM_VALUE.HP3_SZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HP3_SZ}] ${MODELPARAM_VALUE.HP3_SZ}
}

