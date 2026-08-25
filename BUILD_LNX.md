# Linux / Unix-like build

This guide covers `open_vivado.sh` and `make`-based flows in Linux or Unix-like shells such as `bash`, `zsh`, `Git Bash`, `MSYS2`, or `WSL`.

## Requirements

- Xilinx Vivado `2025.1`
- `make`
- `gcc`
- `dtc`
- `xsct`

On Linux, the Vivado environment is usually prepared by sourcing:

```bash
source ~/Xilinx/2025.1/Vivado/settings64.sh
```

You can also set `XILINX_VIVADO` to your Vivado installation directory.

## Supported models

- `Z10`
- `Z20`
- `Z20_14`
- `Z20_4`
- `Z20_250`
- `Z20_G2`
- `Z20_ll`

## Open a project in Vivado

From a Unix-like shell in the repository root:

```bash
./open_vivado.sh v0.94 Z20_250
```

Examples:

```bash
./open_vivado.sh v0.94 Z10
./open_vivado.sh stream_app Z20_250
```

What the script does:

- checks that `prj/<PROJECT>` exists
- validates `MODEL`
- tries to source Vivado environment settings if needed
- locates the Vivado executable
- checks that `red_pitaya_vivado_<MODEL>.tcl` exists
- runs Vivado directly with `-source red_pitaya_vivado_<MODEL>.tcl -tclargs <PROJECT> DEV_MODE`

Help:

```bash
./open_vivado.sh --help
```

## Build with `make`

Open the project in the GUI:

```bash
make project PRJ=v0.94 MODEL=Z20_250
```

Build the bitstream:

```bash
make PRJ=v0.94 MODEL=Z20_250
```

For STEMlab 65-16 TI, which shares `MODEL=Z20_ll` with STEMlab 125-14 TI,
select the 250 MHz ADC serial clock constraint explicitly:

```bash
make PRJ=<project> MODEL=Z20_ll DEFINES=LL_ADC_65
```

Without `LL_ADC_65`, `Z20_ll` targets STEMlab 125-14 TI and constrains ADC
ADDCLK to 500 MHz.

Build only the device tree:

```bash
make dts PRJ=v0.94 MODEL=Z20_250
```

Clean project artifacts:

```bash
make clean PRJ=v0.94
```

## Useful Make variables

- `PRJ` - project name from the `prj/` directory
- `MODEL` - target board model
- `HWID` - optional hardware ID
- `DEFINES` - additional Verilog defines
- `DTS_VER` - device-tree flow version, default is `2025.1`
- `VIVADO_OPTS` - additional Vivado arguments

Example:

```bash
make project PRJ=stream_app MODEL=Z20_250 DEFINES="FEATURE_X=1"
```

## Common issues

`Vivado was not found`

- source `settings64.sh`
- or set `XILINX_VIVADO`
- check that the `vivado` binary exists and is executable

`project "prj/<name>" not found`

- check the project directory name in `prj/`

`invalid model`

- use only the supported models listed above

`make`, `gcc`, `dtc`, or `xsct` errors

- verify that the required tools are available in `PATH`
