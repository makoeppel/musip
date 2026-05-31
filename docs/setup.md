# Setup

## Prerequisites

* openSUSE Leap 15.6 (recommended)
* Root access required
* Minimum:
  * 32 GB RAM (required for Arria 10 firmware compilation)
  * SSD storage
  * PCIe slot with at least x8 electrical connectivity

* Arria 10 (A10) board installed with:
  * PCIe power connected
  * USB connected
  * Clock source connected (or SMA loopback for testing)

---

## OS Installation

### Recommended Settings

* Filesystem: **ext4**
* Install on SSD
* Disable snapshots
* Do not create swap
* Create user: `mu3e`
* Configure root password

---

## Repository Setup

Add repositories:

```bash
sudo zypper addrepo <repo-url> <alias>
sudo zypper refresh
sudo zypper dup --allow-vendor-change
```

Recommended repositories:

* science
* network
* vscode

---

## Required Packages

Install all required packages before proceeding.

### General

```bash
sudo zypper install git cmake kernel-devel htop tmux gcc12 gcc12-c++ python
```

### Additional Components

Install packages required for:

* ROOT
* MIDAS
* Kernel driver
* Geant4
* Quartus
* VS Code

(Refer to package lists in the full documentation if dependencies are missing.)

---

## Clone Repositories and install

### MIDAS

```bash
git clone git@bitbucket.org:tmidas/midas.git
cd midas
git submodule update --init --recursive

mkdir build
cd build

cmake ..
make install
```


### Musip

```bash
git clone git@github.com:makoeppel/musip.git
cd musip
```

---

## ROOT Installation

```bash
git clone --branch latest-stable --depth=1 https://github.com/root-project/root.git ~/root_src

mkdir -p ~/compiled_software/root_build
cd ~/compiled_software/root_build
```

Configure and build:

```bash
cmake \
  -DCMAKE_INSTALL_PREFIX=/opt/root \
  -DCMAKE_CXX_STANDARD=17 \
  -DLLVM_CXX_STD=c++17 \
  -Dxrootd=OFF \
  -DCMAKE_C_COMPILER=/usr/bin/gcc-12 \
  ~/root_src

make -j12
```

Verify:

```bash
root
root-config --cflags
```

Expected:

```text
-std=c++17
```

---

## Configure `.bashrc`

Required sections:

### Quartus

```bash
export ALTERAPATH="$HOME/programs/intelFPGA/18.1"
export QUARTUS_ROOTDIR=${ALTERAPATH}/quartus
export PATH=$PATH:${ALTERAPATH}/quartus/bin
```

Set license server:

```bash
export LM_LICENSE_FILE="<license-server>"
```

### ROOT

```bash
source /opt/root/bin/thisroot.sh
```

### MIDAS

```bash
export MIDASSYS=$HOME/midas
export MIDAS_EXPTAB=$HOME/online/online/exptab
export MIDAS_EXPT_NAME=Mu3e
export PATH=$PATH:$MIDASSYS/bin
```

### Online

```bash
source $HOME/online/build/set_env.sh
```

Reload:

```bash
source ~/.bashrc
```

---

## Geant4 (Optional)

Install only if required for simulation work.

Typical workflow:

```bash
mkdir ~/geant4_src
mkdir ~/compiled_software/geant4_build

ccmake <geant4-source>
make -j<N>
make install
```

Enable:

```bash
source geant4.sh
```

Test using example `B1`.

---

## Quartus Installation

Recommended version:

* Quartus Prime Pro 18.1

Requirements:

* ≥32 GB RAM
* ≥32 GB free disk space

Install:

```bash
mkdir ~/programs
cd ~/programs

tar -xvf Quartus-18.1*.tar
./setup.sh
```

Install support for:

* Arria 10
* Arria V
* MAX10

Verify:

```bash
quartus
```

---

## FPGA Preparation

### Compile MAX10 Firmware

```bash
cd ~/online/fe_board/fe_max10

make flow
make app
```

Verify output files exist:

```text
quartus-build/SEED_1/output_files/top.sof
quartus-build/generated/software/app/main.elf
```

---

## Udev Rules

### USB Blaster

Create:
```bash
/etc/udev/rules.d/51-usbblaster.rules
```

with:
```bash
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6002", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6003", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666"
```

Create:
```bash
sudo nano 99-mudaq.rules
```

with:
```bash
KERNEL=="mudaq*", OWNER="root", GROUP="users", MODE="0666"
```

Reload:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Verify:
```bash
jtagconfig
```

Ff your a10 dev board is properly connected you should see something like this:
```bash
        1) PCIe40 [1-13]
            02E660DD   10AX115H1(.|E2|ES)/10AX115H2/..
            020A40DD   5M(1270ZF324|2210Z)/EPM2210
```
---

## A10 Firmware Build

Select board:

```bash
cd ~/online/switching_pc/a10_board
```

or

```bash
cd ~/online/switching_pc/a10_board_ddr4
```

or

```bash
cd ~/online/switching_pc/a10_lhcb
```

Build:

```bash
make
make flow
make app
```

Upload:

```bash
make pgm
make app_upload
```

Open terminal:

```bash
make terminal
```

You should see the FPGA menu.

!!! note

    Some systems need to be rebooted to get the PCIe working.
    Therefore, reboot the system and run `sudo ./recover_pcie.sh`.

---

## Build Kernel Driver

```bash
cd ~/musip/midas_fe/kerneldriver
make
```

Load:

```bash
sudo ./recover_pcie.sh
```

Expected:

```text
loaded 'mudaq'
```

---

## Verify PCIe Communication

```bash
cd ~/musip/build/tools

./rw rr 0x1
```

Then:

```bash
./dmatest 2 0 1 0x1 5 0
```
And then press `1` in the menu followed by `q`.

Inspect:

```bash
less memory_content.txt
```

Non-zero data confirms successful communication.

---

## DAQ Startup Procedure

### First-Time Setup

```bash
odbinit -s 100MB
```

### Load Firmware

```bash
cd ~/musip/firmware/a10_board
make pgm
make app_upload
```

### Load Driver

```bash
cd ~/musip/midas_fe/kerneldriver
sudo ./recover_pcie.sh
```

---

## Essential Frontends

Start in this order:

1. `mhttpd`
2. `mlogger`
3. `quads_config_fe`
4. `readout_fe`
5. `quadana`

---

## Quick Validation Checklist

* [ ] ROOT starts successfully
* [ ] `root-config --cflags` reports C++17
* [ ] Quartus launches
* [ ] `jtagconfig` detects hardware
* [ ] FPGA menu appears via `make terminal`
* [ ] `lspci` shows Altera device
* [ ] `recover_pcie.sh` loads `mudaq`
* [ ] `rw rr 0x1` returns firmware hash
* [ ] DMA test produces valid data
* [ ] MIDAS available at `localhost:8080`

Once all checks pass, the DAQ machine is operational.
