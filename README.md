# redpitaya-fpga

This repository contains FPGA projects for the Red Pitaya platform, along with shared sources, constraints, build scripts, and supporting materials.

## Getting Started

- Use Vivado `2025.1`.
- Choose a project from `prj/` and the required `MODEL`; the `MODEL` value must match a `red_pitaya_vivado_<MODEL>.tcl` file.
- Use `open_vivado.bat` or `open_vivado.sh` to open a project quickly.
- Use the root `Makefile` with `PRJ` and `MODEL` for the standard build flow.

Examples:

```bash
./open_vivado.sh v0.94 Z10
```

```bash
make clean PRJ=v0.94
make PRJ=v0.94 MODEL=Z10
```

Build guides:

- Windows: [BUILD_WIN.md](/BUILD_WIN.md)
- Linux: [BUILD_LNX.md](/BUILD_LNX.md)

## Timing check before bitstream generation

Every `red_pitaya_vivado_<MODEL>.tcl` script runs a timing gate after implementation and before `write_bitstream`. The gate reads the worst setup and hold slack from the implemented design and stops the build if either is negative.

This exists because a bitstream that does not meet timing is not merely slow - it is functionally unreliable. A build once shipped images with `WNS = -8.9 ns`, and on hardware the configuration registers of ADC channels 3 and 4 changed value on their own, because a clock-domain crossing had been left unconstrained. Vivado reported `CRITICAL WARNING: [Timing 38-282]` and generated the bitstream anyway, since nothing in the flow inspected the result.

Gate outcomes:

- `TIMING GATE: PASS` - setup and hold both met, the build continues.
- `TIMING NOT MET` - the build stops with an error. The ten worst paths are printed and a full report is written to `prj/<PRJ>/out/timing_gate_FAILED.rpt`.
- `TIMING GATE: NOT VERIFIED` - the design reports no timed paths, so nothing could be checked. Expected for a design without user clock constraints; otherwise look for `Vivado 12-627`, `Vivado 12-4739`, or `Common 17-165` earlier in the log, which mean constraints failed to apply.

### ALLOW_TIMING_FAIL

To generate a bitstream even though timing is not met, pass `ALLOW_TIMING_FAIL` through `DEFINES`:

```bash
make PRJ=v0.94 MODEL=Z20_4 DEFINES=ALLOW_TIMING_FAIL
```

`DEFINES` is forwarded to `-tclargs`, so the gate sees the flag and downgrades the error to a warning:

```
# WARNING: TIMING NOT MET: setup (WNS=-2.473 ns, TNS=-1696.150 ns). Bitstream generation aborted.
# Overridden by ALLOW_TIMING_FAIL - DO NOT SHIP THIS BITSTREAM.
```

Use it only for debugging - for example to get an image for a hardware experiment while a timing problem is still being investigated. A bitstream produced this way must never be released, and CI must not set the flag.

The gate itself is shared by all models and lives in `red_pitaya_vivado_timing_gate.tcl`.


## Repository structure

- `prj/` - project directory; each subdirectory defines a separate build configuration and its own project-specific overrides.
- `rtl/` - shared RTL modules.
- `ip/` - IP blocks and related sources.
- `sdc/` - constraint files for target boards.
- `dts/` - device-tree-related files.
- `tbn/` - test environment and testbenches.
- `doc/` - documentation.

### How projects are organized in `prj/`

Projects in this repository are selected with `PRJ=<name>`. The `PRJ` value must match a directory name inside `prj/`, for example `v0.94`, `stream_app`, `logic`, or `barebones`.

The `MODEL` parameter selects the hardware build variant. It determines which `red_pitaya_vivado_<MODEL>.tcl` script is used for project opening and synthesis.

For synthesis and project opening, Vivado combines shared RTL, constraints, and shared IP helper sources from the repository root with project-local files from `prj/<PRJ>/`.

Typical project subdirectories are:

- `prj/<PRJ>/rtl` - project RTL modules.
- `prj/<PRJ>/ip` - block-design Tcl descriptions and IP/PS configuration for that project.
- `prj/<PRJ>/sdc` - project-specific constraints layered on top of the shared ones.
- `prj/<PRJ>/dts` and variants such as `dts_250`, `dts_4ch` - project device-tree data.
- `prj/<PRJ>/tbn` - project testbenches.
- `prj/<PRJ>/out`, `build`, `sdk`, `.Xil`, `sim` - common generated directories for project artifacts.

Reusable blocks are kept in the root `rtl/`, `ip/`, and `sdc/` directories and are connected from multiple projects.

## Working with projects

In this codebase, a project is represented by a `prj/<PRJ>` directory.

When creating a new project:

- create a new directory under `prj/`; its name becomes the `PRJ` value;
- use `prj/barebones` as the starting point for a new project;
- keep project-local sources and configuration files inside the project directory;
- `rtl/`, `ip/`, and `dts/` are usually required;
- add `sdc/` when the project needs its own constraints;
- add `tbn/` when the project needs its own tests.

The `prj/<PRJ>/ip` directory is usually created either by exporting Tcl from Vivado for an already configured project or by copying a template such as `prj/barebones/ip` and adapting it for the new project.

When modifying an existing project:

- keep project-specific changes in `prj/<PRJ>/rtl`, `prj/<PRJ>/ip`, `prj/<PRJ>/sdc`, `prj/<PRJ>/dts`, and related project files;
- treat shared modules carefully, because the same code may be used by multiple projects and board variants;
- reopen or rebuild the project with the same `PRJ` and `MODEL` to validate the changes.
