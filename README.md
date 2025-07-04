# musip-midas

This is a MIDAS-based frontend for the Mupix11 based quad moduels.

## 📁 Project Structure

- `midas_fe/` – Core frontend source code
- `analyzer/` – Analysis utilities
- `tools/` – Helper tools and scripts (mainly for the analyzer)
- `custom/` – Custom pages for MIDAS
- `tests/` – Unit tests for the project
- `.clang-format` – Project-wide code style config

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
./tests/runTests
```

### Docs
If doxygen is installed one can build the docs via.

```bash
make doc_doxygen
```
