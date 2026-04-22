[![Build Documentation](https://github.com/makoeppel/musip/actions/workflows/docs.yml/badge.svg?branch=main)](https://github.com/makoeppel/musip/actions/workflows/docs.yml)
[![Build and Test Software](https://github.com/makoeppel/musip/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/makoeppel/musip/actions/workflows/tests.yml)
[![GHDL testbenches](https://github.com/makoeppel/musip/actions/workflows/ghdl.yml/badge.svg)](https://github.com/makoeppel/musip/actions/workflows/ghdl.yml)
[![Readthedocs](https://app.readthedocs.org/projects/musip/badge/?version=latest)](https://musip.readthedocs.io/)

# musip-midas

This is a MIDAS-based frontend for the Mupix11 based quad moduels.

## 📁 Project Structure

- `analyzer/` – Analysis utilities
- `custom/` – Custom pages for MIDAS
- `docs/` – Documentation folder
- `midas_fe/` – Core frontend source code
- `tests/` – Unit tests for the project
- `tools/` – Helper tools and scripts (mainly for the analyzer)
- `.clang-format` – Project-wide code style config
- `mkdocs.yml` – Setup for the documentation

## Build Instructions

### Prerequisites

- CMake ≥ 3.15
- C++17-compatible compiler (e.g. `clang++`, `g++`)
- MIDAS
- Python ≥ 3.7 (for scripts)

### Build

```bash
mkdir build
cd build
cmake ..
make
```

### Linting
Install clang-format and cpplint. The clang-format will clean the changed files while cpplint also gives some more static analysis.

```bash
cd build
make clangformat
make cpplint
```

### Testing
CMake will download googletests to run the tests.

```bash
cd build
./tests/sample_test
./tests/bits_utils_test
```

There are also some test managed with pytest.
```bash
cd tests
pytest
```

### Docs
We use mkdocs and doxygen for generating the documentation. You should have the doxygen package installed on your system, then:

```bash
pip install mkdocs
pip install mkdocs-material
pip install mkdoxy
pip install mkdocs-with-pdf
```

Once all these are installed one can generate the documentation via:
```bash
make doc_mkdocs
make serve_mkdocs
```

## OPQ/SWB Integration Bring-Up

The OPQ/SWB integration flow added in this workspace uses root-level `make` targets.

Current validation status on April 21, 2026:

- the full Siemens Questa install at `/data1/questaone_sim/questasim` is the only supported simulator on this host,
- `mu3e-ip-cores` is now tracked in-repo as the `external/mu3e-ip-cores` git submodule and is the default upstream owner for OPQ packaging and sync,
- the replay generator, the integrated `plain/` and `uvm/` benches, the split OPQ-boundary harness, and the formal seam scaffold all pass on that toolchain,
- the real integrated OPQ merge path is the promoted default in this repo; the former direct-path bypass workaround is retired,
- the promoted randomized screen is the default `make ip-uvm-longrun` 128-case per-lane `0.0..0.5` saturation wrapper, and the current stronger evidence set also includes a clean 256-case rerun in `tb_int/cases/basic/uvm/report/longrun_ext_260422_fixed/summary.json`,
- Intel FE/FSE `vsim` remains unsupported for this flow; all simulation evidence in `tb_int/` is from the full Questa install above.

### Upstream Mu3e IP Signoff Index

The parent repo tracks the upstream `external/mu3e-ip-cores` signoff entry points for the IPs that already publish a master `SIGNOFF.md`. In the table below, `✅` means the pinned upstream commit includes a master signoff dashboard; both `SYN` and `DV` point to that same dashboard so the landing page always follows the current master file rather than stale split-doc paths.

| Upstream IP | Pinned upstream commit | SYN | DV |
|---|---|:---:|:---:|
| `packet_scheduler` | `bf59a0d` | [✅](external/mu3e-ip-cores/packet_scheduler/doc/SIGNOFF.md) | [✅](external/mu3e-ip-cores/packet_scheduler/doc/SIGNOFF.md) |
| `ring-buffer_cam` | `3c512dd` | [✅](external/mu3e-ip-cores/ring-buffer_cam/doc/SIGNOFF.md) | [✅](external/mu3e-ip-cores/ring-buffer_cam/doc/SIGNOFF.md) |
| `mutrig_frame_deassembly` | `8af676e` | [✅](external/mu3e-ip-cores/mutrig_frame_deassembly/doc/SIGNOFF.md) | [✅](external/mu3e-ip-cores/mutrig_frame_deassembly/doc/SIGNOFF.md) |
| `emulator_mutrig` | `e763a56` | [✅](external/mu3e-ip-cores/emulator_mutrig/doc/SIGNOFF.md) | [✅](external/mu3e-ip-cores/emulator_mutrig/doc/SIGNOFF.md) |

If you just want the shortest safe path:

1. Run `make ip-init`
2. Run `make ip-check-license`
3. Run `make ip-tlm-basic-smoke`
4. Run `make ip-compile-basic`
5. Run `make ip-uvm-basic SIM_ARGS="+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out_smoke"`
6. Run `make ip-tlm-basic`
7. Run `make ip-plain-basic`
8. Run `make ip-plain-basic-2env`
9. Run `make ip-uvm-longrun`

Important:

- `make ip-init` now syncs the nested `external/mu3e-ip-cores` submodule tree, rewrites public GitHub SSH URLs to HTTPS for this workspace, and refreshes the musip-local OPQ wrapper from that in-repo upstream source.
- `make ip-tlm-basic-smoke` is the smallest deterministic replay bundle. It is the right first step when you are debugging the OPQ seam.
- `make ip-tlm-basic` exports replay vectors and expected DMA words without running RTL. Use it when you want a deterministic replay bundle for the full case.
- `make ip-lint-rtl` applies a strict style gate to the clean maintained bridge/wrapper files and a hygiene gate to legacy or imported RTL touched by this integration branch.
- `make ip-uvm-basic` is the default RTL/UVM run on this host. It now uses the real integrated merge path by default (`SWB_USE_MERGE=1`).
- `make ip-uvm-basic` accepts `+SWB_CASE_SEED=<n>` for exact random-case replay and `+SWB_HIT_TRACE_PREFIX=<abs-prefix>` to emit per-hit ingress, OPQ, and DMA ledgers plus a summary file.
- `make ip-uvm-longrun` wraps the same harness and writes the default 128-run campaign summary to `tb_int/cases/basic/uvm/report/longrun/summary.json`.
- The current stronger musip-local evidence also includes `python3 tb_int/cases/basic/uvm/run_longrun.py --runs 256 --campaign-seed 260422 --out-dir report/longrun_ext_260422_fixed`, which passes cleanly and writes `tb_int/cases/basic/uvm/report/longrun_ext_260422_fixed/summary.json`.
- The install's `modelsim.ini` maps `altera_mf`, `altera`, `lpm`, and `sgate` to refreshed 2026-built Intel VHDL libraries under `/data1/questaone_sim/questasim/intel_2026/vhdl`. If the Siemens install is replaced, rerun `tools/ip/refresh_questa_intel_libs.sh`.
- `make ip-plain-basic` is the plain mixed-language replay bench. It also uses the integrated merge path by default and validates the DMA result at the per-hit level with `tb_int/cases/basic/plain/check_dma_hits.py`.
- `make ip-plain-basic-2env` is the split seam harness with explicit OPQ boundary scoreboarding. It remains the promoted boundary audit path, but it is no longer the only passing owner in this repo.
- `make ip-formal-boundary` is the boundary-contract scaffold. It proves the OPQ seam packet grammar checker against a small legal packet family.
- To replay the exact smoke bundle in the full UVM harness, run:

```bash
make ip-uvm-basic SIM_ARGS="+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out_smoke"
```

To replay the full deterministic bundle in the full UVM harness, run:

```bash
make ip-uvm-basic SIM_ARGS="+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out"
```

If you want the plain mixed-language replay bench instead, use:

```bash
make ip-plain-basic REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out
```

If you want a seeded random UVM case with exported per-hit ledgers, use:

```bash
make ip-uvm-basic SIM_ARGS="+SWB_FRAMES=2 +SWB_CASE_SEED=12345 +SWB_SAT0=0.10 +SWB_SAT1=0.20 +SWB_SAT2=0.30 +SWB_SAT3=0.40 +SWB_HIT_TRACE_PREFIX=$(pwd)/tb_int/cases/basic/uvm/report/single_seed"
```

If you want the split OPQ boundary harness instead, use:

```bash
make ip-plain-basic-2env REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out
```
