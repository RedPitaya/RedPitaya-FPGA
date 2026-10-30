#!/bin/bash
# Runs dac_loop_tb (DAC DMA normal mode) in xsim, docker image vivado:2025.1 by default
# or a local Vivado when xvlog is in PATH. Prints the ok/FAIL/PASS lines of the bench.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
FPGA=$(cd "$HERE/../../../.." && pwd)
RTL=$FPGA/prj/stream_app/rtl
WORK=${WORK:-$(mktemp -d)}
IMAGE=${IMAGE:-vivado:2025.1}
VARIANT=${VARIANT:-rtl}

script="
set -e
cd $WORK
mkdir -p dip && cp -r $RTL/$VARIANT/rp_dac/fifo_axi_data_dac dip/
cat > dip/gen.tcl <<'TCL'
create_project -in_memory -part xc7z010clg400-1
set_property target_language Verilog [current_project]
read_ip dip/fifo_axi_data_dac/fifo_axi_data_dac.xci
upgrade_ip [get_ips]
generate_target {simulation} [get_ips]
export_simulation -of_objects [get_ips] -simulator xsim -directory dip/export -force
TCL
vivado -mode batch -nojournal -nolog -source dip/gen.tcl > dip.log 2>&1
D=$RTL/$VARIANT/rp_dac
xvlog -sv $HERE/dac_loop_tb.sv > dac.log || { grep ERROR dac.log; exit 1; }
xvlog \$D/rp_dma_mm2s.v \$D/rp_dma_mm2s_ctrl.v \$D/rp_dma_mm2s_data_ctrl.v \$D/rp_dma_mm2s_downsize.v \
      dip/fifo_axi_data_dac/sim/fifo_axi_data_dac.v dip/export/fifo_axi_data_dac/xsim/glbl.v >> dac.log || { grep ERROR dac.log; exit 1; }
xelab -debug off -L fifo_generator_v13_2_13 -L unisims_ver -L xpm dac_loop_tb glbl -s dac_tb >> dac.log || { grep ERROR dac.log; exit 1; }
xsim dac_tb -R | grep -E '^(ok|FAIL|PASS)'
"
if command -v xvlog >/dev/null; then
    bash -c "$script"
else
    docker run --rm -v /dev/null:/lib/x86_64-linux-gnu/libudev.so.1:ro -v "$FPGA:$FPGA" -v "$WORK:$WORK" --user "$(id -u):$(id -g)" -e HOME=/tmp "$IMAGE" \
        bash -lc "export PATH=/opt/Xilinx/2025.1/Vivado/bin:\$PATH; $script"
fi
