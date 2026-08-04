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
* Create user: `musip`
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

(Refer to package lists in the full documentation if dependencies are missing.)

---

## Clone Repositories and install

### MIDAS

```bash
git clone https://bitbucket.org/tmidas/midas.git
cd midas
git submodule update --init --recursive

mkdir build
cd build

cmake ..
make install
```


### Musip

```bash
git clone https://gitea.psi.ch/MuSiP/musip.git
```

---

## ROOT Installation

```bash
git clone https://github.com/root-project/root.git
git checkout -b v6-40-00-patches origin/v6-40-00-patches

mkdir -p ~/compiled_software/root_build
cd ~/compiled_software/root_build
```

Configure, build and install:

```bash
mkdir build
cmake -Dbuiltin_ftgl=off -Dbuiltin_glow=off -Dfftw3=on -Dmathmore=on -Dunfold=on -Dunuran=on -During=on -DPHYTHON_EXECUTABLE=/usr/bin/python3.14 -DCMAKE_C_FLAGS='-march=x86-64-v3' -DCMAKE_CXX_FLAGS='-march=x86-64-v3' -DCMAKE_INSTALL_PREFIX=/opt/root ../root
chrt -b 0 cmake --build . -- -j96
sudo cmake -P cmake_install.cmake
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
# Alias to enable ROOT
alias setupROOT='DIR=`pwd`; cd /opt/root; source bin/thisroot.sh; cd $DIR'
setupROOT
```

### MIDAS

```bash
export MIDASSYS=$HOME/midas
export MIDAS_EXPTAB=$HOME/musip/online/exptab
export MIDAS_EXPT_NAME=Mu3e
export PATH=$PATH:$MIDASSYS/bin
```

### Online

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

* Quartus Prime Standard 21.1.1

Requirements:

* ≥32 GB RAM
* ≥32 GB free disk space

Install:

```bash
mkdir ~/programs
cd ~/programs

tar xf Quartus-21.1.1.850-linux.tar
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
cd ~/musip/firmware/a10_board
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

DKMS is used to manage the kernel driver, so that only needs to be installed once

```bash
cd ~/musip/midas_fe/kerneldriver
sudo ./install.sh
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

## Make mhttpd autostart

One can use `systemd` to autostart `mhttpd` on system start. For that, create the following unit:
```
$ cat .config/systemd/user/mhttpd@.service
[Unit]
Description=mhttpd for experiment %I
Wants=network.target

[Service]
Type=forking
Environment=FIXME
ExecStart=/home/musip/midas/bin/mhttpd -e %I -D

[Install]
WantedBy=default.target
```

To set the correct environmont, parse your `.bashrc`/`.zshrc` via
```
$ env -i -- $SHELL --login -c "source .zshrc.local && env" | grep -vE '^(_|SHLVL|PWD|OLDPWD)=' | sed -e 's/^/Environment="/;s/$/"/'
```
And add these lines in the systemd unit. Start and enable the unit
```
$ systemctl --user start mhttpd@Musip.service
$ systemctl --user enable mhttpd@Musip.service
```
And enable lingering, so that the service always gets started regardless of the user being logged in or not:
```
$ loginctl enable-linger
```
