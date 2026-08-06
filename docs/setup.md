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

Normally this should not be needed but for rare cases:

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
$ cat /usr/local/lib/systemd/system/mhttpd@.service
[Unit]
Description=mhttpd for experiment %I
Wants=network.target

[Service]
Type=forking
Environment="PATH=/opt/root/bin:/usr/share/Modules/bin:/bin:/usr/bin:/usr/ucb:/usr/local/bin:/home/musip/bin:/usr/local/sbin:/usr/sbin:/opt/puppetlabs/bin:/home/musip/midas/bin:/home/musip/intelFPGA/21.1/quartus/bin:/home/musip/intelFPGA/21.1/quartus/bin:/home/musip/intelFPGA/21.1/quartus/sopc_builder/bin:/home/musip/intelFPGA/21.1/quartus/../nios2eds/bin:/home/musip/intelFPGA/21.1/quartus/../nios2eds/sdk2/bin:/home/musip/intelFPGA/21.1/quartus/../nios2eds/bin/gnu/H-x86_64-pc-linux-gnu/bin:/home/musip/intelFPGA/21.1/quartus/../hls/bin"
Environment="QSYS_ROOTDIR=/home/musip/intelFPGA/21.1/quartus/sopc_builder/bin"
Environment="ROOTSYS=/opt/root"
Environment="LD_LIBRARY_PATH=/opt/root/lib"
Environment="DYLD_LIBRARY_PATH=/opt/root/lib"
Environment="SHLIB_PATH=/opt/root/lib"
Environment="LIBPATH=/opt/root/lib"
Environment="PYTHONPATH=/opt/root/lib:/home/musip/midas/python"
Environment="CMAKE_PREFIX_PATH=/opt/root"
Environment="JUPYTER_PATH=/opt/root/etc/notebook"
Environment="JUPYTER_CONFIG_PATH=/opt/root/etc/notebook"
Environment="ROOT_INCLUDE_PATH="
Environment="MIDASSYS=/home/musip/midas"
Environment="MIDAS_EXPTAB=/home/musip/musip/online/exptab"
Environment="MIDAS_EXPT_NAME=Musip"
Environment="MIDAS_WORK=/home/musip/midas_nemu"
Environment="ALTERAPATH=/home/musip/intelFPGA/21.1"
Environment="QUARTUS_ROOTDIR=/home/musip/intelFPGA/21.1/quartus"
Environment="ALTERAD_LICENSE_FILE=27001@localhost"
Environment="QUARTUS_64BIT=1"
Environment="SOPC_KIT_NIOS2=/home/musip/intelFPGA/21.1/quartus/../nios2eds"
ExecStart=/home/musip/midas/bin/mhttpd -e %I -D
User=musip
Group=musip
WorkingDirectory=~
ExecStart=/home/musip/midas/bin/mhttpd -e %I -D

[Install]
WantedBy=default.target
```
If SELinux is active, than the service will probably not start unless a policy is added. On RHEL9 install `selinux-policy-devel` and with
```
$ cat my-mhttpd.te

module my-mhttpd 1.0;

require {
        type user_home_t;
        type init_t;
        type unconfined_t;
        type ephemeral_port_t;
        class file { append create execute execute_no_trans map open read write };
        class sem { associate setattr };
        class tcp_socket name_connect;
}

#============= init_t ==============

#!!!! This avc can be allowed using the boolean 'nis_enabled'
allow init_t ephemeral_port_t:tcp_socket name_connect;

#!!!! This avc is allowed in the current policy
allow init_t unconfined_t:sem { associate setattr };

#!!!! This avc is allowed in the current policy
allow init_t user_home_t:file { append create execute execute_no_trans map open read write };
```
Compile and load the policy via
```
$ make -f /usr/share/selinux/devel/Makefile my-mhttpd.pp
$ semodule -i my-mhttpd.pp
```

Now you can start and enable the unit:
```
$ systemctl start mhttpd@Musip.service
$ systemctl enable mhttpd@Musip.service
```

To allow the `musip` user to start/stop/etc. the service, add the following policy file:
```
$ cat /etc/polkit-1/rules.d/60-musip-systemd-mhttpd.rules
// Allow musip to manage mhttpd@.service;
// fall back to implicit authorization otherwise.
polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "mhttpd@Musip.service" &&
            subject.user == "musip") {
                return polkit.Result.YES;
        }
});
```
