#!/bin/bash
# Runs the unit testbenches of stream_app in xsim (docker image vivado:2025.1 by default,
# or a local Vivado when xvlog is in PATH). Prints the PASS/FAIL line of every bench.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
FPGA=$(cd "$HERE/../../../.." && pwd)
RTL=$FPGA/prj/stream_app/rtl
WORK=${WORK:-$(mktemp -d)}
IMAGE=${IMAGE:-vivado:2025.1}

script="
set -e
cd $WORK
xvlog $RTL/rtl/rp_oscilloscope/osc_aquire.v > osc.log
xvlog -sv $HERE/osc_acquire_tb.sv >> osc.log
xelab -debug off osc_acquire_tb -s osc_tb >> osc.log
xsim osc_tb -R | grep -E '^(ok|FAIL|PASS)'
xvlog -sv $HERE/osc_acquire_blocks_tb.sv >> osc.log
xelab -debug off osc_acquire_blocks_tb -s blk_tb >> osc.log
xsim blk_tb -R | grep -E '^(ok|FAIL|PASS)'
xvlog -sv $FPGA/rtl/rtl/debounce.sv $RTL/ext_trig_cond_250.sv $HERE/ext_trig_cond_tb.sv > ext.log
# the RTL has no timescale, the bench has one
xelab -debug off -timescale 1ns/1ps -override_timeunit -override_timeprecision ext_trig_cond_tb -s ext_tb >> ext.log
xsim ext_tb -R | grep -E '^(ok|FAIL|PASS)'
# GPIO streaming: the behavioural models of the FIFO IP are generated from copies of the .xci
mkdir -p gip && cp -r $RTL/rtl/rp_gpio/fifo_axi_data $RTL/rtl/rp_gpio/fifo_axi_req gip/
cat > gip/gen.tcl <<'TCL'
create_project -in_memory -part xc7z010clg400-1
set_property target_language Verilog [current_project]
foreach x {fifo_axi_data fifo_axi_req} { read_ip gip/\$x/\$x.xci }
upgrade_ip [get_ips]
generate_target {simulation} [get_ips]
export_simulation -of_objects [get_ips] -simulator xsim -directory gip/export -force
TCL
vivado -mode batch -nojournal -nolog -source gip/gen.tcl > gip.log 2>&1
G=$RTL/rtl/rp_gpio
LIB=\"$FPGA/rtl/rtl/interface/axi4_stream_if.sv $FPGA/rtl/rtl/str_dec.sv $FPGA/rtl/rtl/la_trg.sv $FPGA/rtl/rtl/cts.sv $FPGA/rtl/rtl/old_acq.sv $FPGA/rtl/rtl/rle.sv $FPGA/rtl/rtl/axi4_stream_cnt.sv $FPGA/rtl/rtl/axi4_stream_reg.sv\"
IPS=\"gip/fifo_axi_data/sim/fifo_axi_data.v gip/fifo_axi_req/sim/fifo_axi_req.v gip/export/fifo_axi_data/xsim/glbl.v\"
xvlog -sv \$LIB \$G/gpio_in_top.sv \$G/rle_rev.sv \$G/gpio_out_top.sv $HERE/gpio_in_tb.sv $HERE/gpio_out_tb.sv > gpio.log
xvlog \$G/gpio_dma_s2mm.v \$G/gpio_dma_s2mm_ctrl.v \$G/gpio_dma_s2mm_data_ctrl.v \$G/gpio_dma_s2mm_upsize.v \
      \$G/gpio_dma_mm2s.v \$G/gpio_dma_mm2s_ctrl.v \$G/gpio_dma_mm2s_data_ctrl.v \$G/gpio_dma_mm2s_downsize.v \$IPS >> gpio.log
xelab -relax -debug off -timescale 1ns/1ps -L fifo_generator_v13_2_13 -L unisims_ver -L xpm gpio_in_tb glbl -s gin_tb >> gpio.log
xsim gin_tb -R | grep -E '^(ok|FAIL|PASS)'
xelab -relax -debug off -timescale 1ns/1ps -L fifo_generator_v13_2_13 -L unisims_ver -L xpm gpio_out_tb glbl -s gout_tb >> gpio.log
xsim gout_tb -R | grep -E '^(RLE|refill|wait|trigger|FAIL|PASS)'
# register path of rp_gpio (the bridge IP is modelled in the bench)
xvlog -sv \$LIB \$G/gpio_in_top.sv \$G/rle_rev.sv \$G/gpio_out_top.sv \$G/rp_gpio.sv $FPGA/rtl/rtl/debounce.sv $HERE/rp_gpio_regs_tb.sv > regs.log
xelab -relax -debug off -timescale 1ns/1ps -L fifo_generator_v13_2_13 -L unisims_ver -L xpm rp_gpio_regs_tb glbl -s regs_tb >> regs.log
xsim regs_tb -R | grep -E '^(ok|FAIL|PASS)'
# scope DMA buffer timestamps and the block mode buffers: own directory, the scope FIFO IPs share their names with the GPIO ones
mkdir -p dma/sip && cd dma
cp -r $RTL/rtl/rp_oscilloscope/fifo_axi_data $RTL/rtl/rp_oscilloscope/fifo_axi_req sip/
sed -e 's#gip/#sip/#g' ../gip/gen.tcl > sip/gen.tcl
vivado -mode batch -nojournal -nolog -source sip/gen.tcl > sip.log 2>&1
O=$RTL/rtl/rp_oscilloscope
xvlog -sv $HERE/dma_ts_tb.sv $HERE/dma_blocks_tb.sv $HERE/dma_blocks2_tb.sv > dma.log
xvlog \$O/rp_dma_s2mm.v \$O/rp_dma_s2mm_ctrl.v \$O/rp_dma_s2mm_data_ctrl.v \$O/rp_dma_s2mm_upsize.v \
      sip/fifo_axi_data/sim/fifo_axi_data.v sip/fifo_axi_req/sim/fifo_axi_req.v sip/export/fifo_axi_data/xsim/glbl.v >> dma.log
xelab -debug off -L fifo_generator_v13_2_13 -L unisims_ver -L xpm dma_ts_tb glbl -s dma_tb >> dma.log
xsim dma_tb -R | grep -E '^(ok|FAIL|PASS|KNOWN)'
# block mode, one buffer per trigger: the buffers against the series after an overflow
xelab -debug off -L fifo_generator_v13_2_13 -L unisims_ver -L xpm dma_blocks_tb glbl -s blk_tb >> dma.log
xsim blk_tb -R | grep -E '^(ok|FAIL|PASS|KNOWN)'
# two channels in the block mode, the port of CH2 stalling: the same series in both, buffer by buffer
xelab -debug off -L fifo_generator_v13_2_13 -L unisims_ver -L xpm dma_blocks2_tb glbl -s blk2_tb >> dma.log
xsim blk2_tb -R | grep -E '^(ok|FAIL|PASS|KNOWN)'
# the scope interrupt with two channels, also a buffer apart: every wait ends in an interrupt
xvlog -sv $HERE/irq_tb.sv >> dma.log
xelab -debug off -L fifo_generator_v13_2_13 -L unisims_ver -L xpm irq_tb glbl -s irq_tb >> dma.log
xsim irq_tb -R | grep -E '^(ok|FAIL|PASS|KNOWN)'
"
if command -v xvlog >/dev/null; then
    bash -c "$script"
else
    docker run --rm -v /dev/null:/lib/x86_64-linux-gnu/libudev.so.1:ro -v "$FPGA:$FPGA" -v "$WORK:$WORK" --user "$(id -u):$(id -g)" -e HOME=/tmp "$IMAGE" \
        bash -lc "export PATH=/opt/Xilinx/2025.1/Vivado/bin:\$PATH; $script"
fi
# DAC DMA normal mode (buffer repeated by the DMA), on both RTL variants with that DMA
for v in rtl rtl_250; do
    mkdir -p "$WORK/dac_$v"
    VARIANT=$v WORK="$WORK/dac_$v" "$HERE/dac_loop.sh"
done
