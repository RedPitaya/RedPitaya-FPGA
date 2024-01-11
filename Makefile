#
# Authors: Matej Oblak, Iztok Jeras
# (C) Red Pitaya 2013-2015
#
# Red Pitaya FPGA/SoC Makefile
#
# Produces:
#   3. FPGA bit file.
#   1. FSBL (First stage bootloader) ELF binary.
#   2. Memtest (stand alone memory test) ELF binary.
#   4. Linux device tree source (dts).

PRJ   ?= logic
MODEL ?= Z10
HWID  ?= ""
DEFINES ?= ""
DTS_VER ?= 2017.2

# build artefacts
FPGA_BIT    = prj/$(PRJ)/out/red_pitaya.bit
FPGA_BIN    = prj/$(PRJ)/out/red_pitaya.bit.bin
FSBL_ELF    = prj/$(PRJ)/sdk/fsbl/executable.elf
MEMTEST_ELF = prj/$(PRJ)/sdk/dram_test/executable.elf
DEVICE_TREE = prj/$(PRJ)/sdk/dts/system.dts

# Vivado from Xilinx provides IP handling, FPGA compilation
# hsi (hardware software interface) provides software integration
# both tools are run in batch mode with an option to avoid log/journal files
VIVADO = vivado -nojournal -mode batch
HSI    = hsi    -nolog -nojournal -mode batch
BOOTGEN= bootgen -image prj/$(PRJ)/out/red_pitaya.bif -arch zynq -process_bitstream bin
#HSI    = hsi    -nolog -mode batch

.PHONY: all clean project sim

all: $(FPGA_BIT) $(FSBL_ELF) $(DEVICE_TREE) $(FPGA_BIN)

# TODO: clean should go into each project
clean:
	rm -rf out .Xil .srcs sdk project sim
	rm -rf prj/$(PRJ)/out prj/$(PRJ)/.Xil prj/$(PRJ)/.srcs prj/$(PRJ)/sdk prj/$(PRJ)/project

sim: 
	vivado -source red_pitaya_vivado_sim.tcl -tclargs $(PRJ) $(MODEL) $(DEFINES)

project:
ifneq ($(HWID),"")
	vivado -source red_pitaya_vivado_project_$(MODEL).tcl -tclargs $(PRJ) $(DEFINES) HWID=$(HWID)
else
	vivado -source red_pitaya_vivado_project_$(MODEL).tcl -tclargs $(PRJ) $(DEFINES)
endif

$(FPGA_BIT):
ifneq ($(HWID),"")
	$(VIVADO) -source red_pitaya_vivado_$(MODEL).tcl -tclargs $(PRJ) $(DEFINES) HWID=$(HWID)
else
	$(VIVADO) -source red_pitaya_vivado_$(MODEL).tcl -tclargs $(PRJ) $(DEFINES)
endif
	./synCheck.sh

$(FSBL_ELF): $(FPGA_BIT)
	xsct red_pitaya_hsi_fsbl.tcl $(PRJ)

$(DEVICE_TREE): $(FPGA_BIT)
	xsct red_pitaya_hsi_dts.tcl  $(PRJ) DTS_VER=$(DTS_VER)

$(FPGA_BIN): $(FPGA_BIT)
	@echo all:{$(FPGA_BIT)} > prj/$(PRJ)/out/red_pitaya.bif
	$(BOOTGEN)
