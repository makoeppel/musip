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

If you just want the shortest safe path:

1. Run `make ip-init`
2. Run `make ip-check-license`
3. Run `make ip-tlm-basic`
4. Read `tb_int/cases/basic/ref/out/summary.json`
5. Run `make ip-lint-rtl`
6. Run `make ip-compile-plain`
7. Run `make ip-compile-plain-2env`
8. Run `make ip-compile-basic`

Important:

- `make ip-tlm-basic` is the current workaround flow. It does not need the blocked `vsim` runtime.
- `make ip-lint-rtl` applies a strict style gate to the clean maintained bridge/wrapper files and a hygiene gate to legacy or imported RTL touched by this integration branch.
- `make ip-plain-basic` is the quartus-system-style plain mixed-language replay bench. It avoids UVM and only needs a standard mixed-language Mentor runtime once that binary exists.
- `make ip-plain-basic-2env` is the split workaround path: a VHDL-only post-OPQ datapath plus a DPI-backed 2-env UVM harness at the OPQ seam.
- `make ip-uvm-basic` is the real RTL/UVM run, but it still requires a full Mentor/Questa runtime binary.
- Once that runtime exists, you can replay the exact fallback case in RTL with:

```bash
make ip-uvm-basic SIM_ARGS="+SWB_REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out"
```

If you only have standard mixed-language simulation and not the verification/UVM feature set, use:

```bash
make ip-plain-basic REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out
```

If you want the split OPQ-seam workaround instead, use:

```bash
make ip-plain-basic-2env REPLAY_DIR=$(pwd)/tb_int/cases/basic/ref/out
```
