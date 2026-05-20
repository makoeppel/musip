# mudaq DKMS package

This is a self-contained DKMS package for the `mudaq` PCIe kernel driver.
It includes the driver source, dmabuf helper headers, udev rules, DKMS metadata, helper scripts, and the register-definition headers required by the build.

## Included register headers

The package includes:

- `registers.h`
- `registers/a10_counters.h`
- `registers/a10_pcie_registers.h`
- `registers/feb_sc_registers.h`
- `registers/lvds_registers.h`
- `registers/mupix_registers.h`
- `registers/mutrig_registers.h`
- `registers/sorter_registers.h`

The driver source has been normalized to include `registers.h` locally instead of depending on `../registers.h` outside the DKMS source tree.

## Install

```bash
tar xzf mudaq-dkms-0.1.1.tar.gz
cd mudaq-dkms-0.1.1
sudo ./install-dkms.sh
```

To choose the DKMS version explicitly:

```bash
sudo ./install-dkms.sh --version 0.1.1
```

Optional fallback autoload mechanisms:

```bash
sudo ./install-dkms.sh --autoload
sudo ./install-dkms.sh --systemd
```

Usually neither fallback is required because the module contains a PCI device alias for `1172:0004`, so the kernel can autoload it after `depmod` when matching hardware is present.

## Verify

```bash
./verify-mudaq.sh
```

Or manually:

```bash
dkms status -m mudaq
modinfo mudaq
lsmod | grep mudaq
lspci -Dnnd 1172:0004
ls -l /dev/mudaq*
dmesg | tail -n 100
```

## Useful operations

```bash
sudo ./reload-mudaq.sh
sudo ./recover-pcie-dkms.sh
sudo ./remove-dkms.sh
```

## Notes

- `99-mudaq.rules` keeps the upstream permissive behavior with `MODE="0666"`. On shared systems, consider changing this to `MODE="0660"` with a dedicated group.
- Secure Boot systems may reject unsigned DKMS modules unless MOK signing is configured.
- The installer fails early if any required source or register header is missing, so DKMS build failures from missing includes should be avoided.
