#
# (C) Red Pitaya 2013-2025
#
# Red Pitaya FPGA/SoC Makefile
#

PRJ   ?= v0.94
MODEL ?= Z10
FPGA_VERSION ?= z10_125
HWID  ?= ""
DEFINES ?= ""
DTS_VER ?= 2025.1
DTS_IP_PATH ?= dts
VIVADO_OPTS ?=
PROJECT_DIRS := $(wildcard prj/*)
PROJECT_NAMES := $(notdir $(PROJECT_DIRS))

# build artefacts
FPGA_BIN    = prj/$(PRJ)/out/red_pitaya.bin
FSBL_ELF    = prj/$(PRJ)/sdk/fsbl.elf
MEMTEST_ELF = prj/$(PRJ)/sdk/dram_test/executable.elf
DEVICE_TREE = prj/$(PRJ)/sdk/dts/system.dts
XSA 		= prj/$(PRJ)/sdk/red_pitaya.xsa

DEVICETREE_UB_PATH = prj/fsbl/sdk/dts
DEVICETREE_UB =  prj/fsbl/out/devicetree_uboot.dtb
DEVICETREE_UB_PATCH = prj/fsbl/dts

VIVADO = vivado -nojournal -mode batch

.PHONY: all project sim clean clean-all

all: $(FPGA_BIN) $(DEVICE_TREE) $(DTREE_DIR)

clean-all:
	@echo "Cleaning all projects in prj/: $(PROJECT_NAMES)"
	@for project in $(PROJECT_NAMES); do \
		echo "Cleaning project: $$project"; \
		rm -rf out .Xil .srcs sdk project sim; \
		rm -rf prj/$$project/out prj/$$project/.Xil prj/$$project/.srcs prj/$$project/sdk prj/$$project/project; \
		rm -rf prj/$$project/build; \
		rm -rf prj/$$project/.gen; \
		rm -rf prj/$$project/build-fsbl; \
	done
	@echo "All projects cleaned"

clean:
	rm -rf out .Xil .srcs sdk project sim
	rm -rf prj/$(PRJ)/out prj/$(PRJ)/.Xil prj/$(PRJ)/.srcs prj/$(PRJ)/sdk prj/$(PRJ)/project
	rm -rf prj/$(PRJ)/build
	rm -rf prj/$(PRJ)/.gen
	rm -rf prj/$(PRJ)/build-fsbl

sim:
	vivado -source red_pitaya_vivado_sim.tcl -tclargs $(PRJ) $(MODEL) $(DEFINES)

project:
ifneq ($(HWID),"")
	vivado $(VIVADO_OPTS) -source red_pitaya_vivado_$(MODEL).tcl -tclargs $(PRJ) $(DEFINES) HWID=$(HWID) DEV_MODE
else
	vivado $(VIVADO_OPTS) -source red_pitaya_vivado_$(MODEL).tcl -tclargs $(PRJ) $(DEFINES) DEV_MODE
endif

$(FPGA_BIN):
ifneq ($(HWID),"")
	$(VIVADO) -source red_pitaya_vivado_$(MODEL).tcl -tclargs $(PRJ) $(DEFINES) HWID=$(HWID)
else
	$(VIVADO) -source red_pitaya_vivado_$(MODEL).tcl -tclargs $(PRJ) $(DEFINES)
endif
	./synCheck.sh $(PRJ)

$(XSA): $(FPGA_BIN)

$(FSBL_ELF): $(XSA)
	xsct red_pitaya_hsi_fsbl.tcl $(PRJ)

ifeq ($(PRJ),barebones)
    ifeq ($(FPGA_VERSION),z20_250_1_0)
        DTS_PATH := dts_250
    else ifeq ($(FPGA_VERSION),z20_250)
        DTS_PATH := dts_250
    else ifeq ($(FPGA_VERSION),z20_250a)
        DTS_PATH := dts_250a
    else
        DTS_PATH := dts
    endif
endif

ifeq ($(PRJ),stream_app)
    ifeq ($(FPGA_VERSION),z20_125_4ch)
        DTS_IP_PATH := dts_4ch
    else ifeq ($(FPGA_VERSION),z20_250)
        DTS_IP_PATH := dts_250
    else ifeq ($(FPGA_VERSION),z20_250_1_0)
        DTS_IP_PATH := dts_250
    endif
endif

ifeq ($(PRJ),v0.94)
    ifeq ($(FPGA_VERSION),z20_125_4ch)
        DTS_IP_PATH := dts_4ch
    endif
endif

$(DEVICE_TREE): $(XSA)
	xsct red_pitaya_hsi_dts.tcl  $(PRJ) DTS_VER=$(DTS_VER) MODEL=$(MODEL)

ifeq ($(PRJ),barebones)
	cp -rf prj/$(PRJ)/dts prj/$(PRJ)/sdk
	cp -f prj/$(PRJ)/sdk/dts/system-top.dts prj/$(PRJ)/sdk/dts/system-top.dts.tmp
	cat prj/$(PRJ)/sdk/dts/fpga.dts >> prj/$(PRJ)/sdk/dts/system-top.dts.tmp
	gcc -I dts/$(DTS_PATH) -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o prj/$(PRJ)/sdk/dts/system-top.dts.full.tmp prj/$(PRJ)/sdk/dts/system-top.dts.tmp
	dtc -@ -I dts -O dtb -o prj/$(PRJ)/out/dts/dtraw.dtb -i dts/$(DTS_PATH) prj/$(PRJ)/sdk/dts/system-top.dts.full.tmp
	dtc -I dtb -O dts --sort -o prj/$(PRJ)/out/dts/dtraw.dtbs prj/$(PRJ)/out/dts/dtraw.dtb
	dtc dts/$(DTS_PATH)/led-system.dtso -I dts -O dtb -o prj/$(PRJ)/out/dts/led-system.dtbo
endif

	PL_PATH=prj/$(PRJ)/out/dts/out/dts/redpitaya_platform/ps7_cortexa9_0/device_tree_domain/bsp/pl.dtsi; \
    echo "Path to pl.dtsi:  $$PL_PATH"; \
	if [ -f "$$PL_PATH" ]; then \
		sed -i 's/.bin/fpga.bin/g' $$PL_PATH; \
		grep -qxF '/include/ "pl_patch.dtsi"' $$PL_PATH || echo '/include/ "pl_patch.dtsi"' >> $$PL_PATH; \
		dtc -I dts -O dtb -i prj/$(PRJ)/$(DTS_IP_PATH) -o prj/$(PRJ)/out/fpga.dtbo $$PL_PATH; \
		dtc -I dtb -O dts --sort -o prj/$(PRJ)/out/fpga.dtso prj/$(PRJ)/out/fpga.dtbo; \
    else \
        echo "Missing pl.dtsi [SKIP]"; \
    fi


dts: $(DEVICE_TREE)

fsbl: fsbl_dts

# The FSBL is built once, for the 16-bit DDR bus, and learns at run time
# whether the board carries the second DDR chip. The 1 GB configuration is
# carried as a register delta extracted from a throw-away 1 GB build, so the
# two never drift apart.
FSBL_APP     = prj/fsbl/build-fsbl/redpitaya_platform/zynq_fsbl
FSBL_SRC     = prj/fsbl/src
FSBL_REF_1GB = prj/fsbl/ps7_init_1024.c
GNU_ARM_BIN ?= $(dir $(XILINX_VIVADO))gnu/aarch32/lin/gcc-arm-none-eabi/bin

fsbl_build:
	# reference pass: only the generated PS init tables are kept
	$(VIVADO) -source red_pitaya_vivado_fsbl.tcl -tclargs MODEL=$(MODEL) RAM=1024 DTS_VER=$(DTS_VER)
	xsct red_pitaya_hsi_fsbl.tcl fsbl
	cp $(FSBL_APP)/ps7_init.c $(FSBL_REF_1GB)
	# real pass
	$(VIVADO) -source red_pitaya_vivado_fsbl.tcl -tclargs MODEL=$(MODEL) RAM=512 DTS_VER=$(DTS_VER)
	xsct red_pitaya_hsi_fsbl.tcl fsbl
	python3 scripts/gen_ddr_patch.py \
		--ps7-512 $(FSBL_APP)/ps7_init.c \
		--ps7-1024 $(FSBL_REF_1GB) \
		--out $(FSBL_APP)/rp_ddr_1gb_patch.c
	cp $(FSBL_SRC)/*.c $(FSBL_SRC)/*.h $(FSBL_APP)/
	sed -i 's|^LN_FLAGS := |LN_FLAGS := -Wl,--wrap=ps7_init |' $(FSBL_APP)/Makefile
	PATH=$(GNU_ARM_BIN):$$PATH $(MAKE) -C $(FSBL_APP)
	cp $(FSBL_APP)/fsbl.elf prj/fsbl/out/fsbl.elf

# Host-side checks: the delta really turns the 512 MB tables into the 1 GB
# ones, and the environment parser handles the blobs it will meet.
fsbl_test:
	python3 prj/fsbl/test/gen_ref.py $(FSBL_REF_1GB) prj/fsbl/test/ref.c
	gcc -std=c99 -Wall -Wextra -Iprj/fsbl/test -I$(FSBL_SRC) -Iprj/fsbl/test/stub \
		$(FSBL_APP)/ps7_init.c $(FSBL_SRC)/rp_ddr_patch.c \
		$(FSBL_APP)/rp_ddr_1gb_patch.c prj/fsbl/test/ref.c \
		prj/fsbl/test/test_patch.c -o prj/fsbl/test/test_patch
	prj/fsbl/test/test_patch
	gcc -std=c99 -Wall -Wextra -Wno-unused-function -DRP_HW_REV_HOST_TEST \
		-I$(FSBL_SRC) $(FSBL_SRC)/rp_hw_rev.c prj/fsbl/test/test_env.c \
		-o prj/fsbl/test/test_env
	prj/fsbl/test/test_env

fsbl_dts: fsbl_build
	echo $@
	xsct red_pitaya_hsi_fsbl_dts.tcl fsbl
	grep -qxF '/include/ "redpitaya.dtsi"' $(DEVICETREE_UB_PATH)/system-top.dts || echo '/include/ "redpitaya.dtsi"' >> $(DEVICETREE_UB_PATH)/system-top.dts;
	gcc -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o $(DEVICETREE_UB_PATH)/system-top.dts.tmp $(DEVICETREE_UB_PATH)/system-top.dts
	dtc -@ -I dts -O dtb -i $(DEVICETREE_UB_PATCH) -o $(DEVICETREE_UB) $(DEVICETREE_UB_PATH)/system-top.dts.tmp
