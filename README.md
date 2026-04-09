[![Build Documentation](https://github.com/makoeppel/musip/actions/workflows/docs.yml/badge.svg?branch=main)](https://github.com/makoeppel/musip/actions/workflows/docs.yml)
[![Build and Test Software](https://github.com/makoeppel/musip/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/makoeppel/musip/actions/workflows/tests.yml)
[![Readthedocs](https://app.readthedocs.org/projects/musip/badge/?version=latest)](https://app.readthedocs.org/projects/musip/badge/?version=latest)

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
