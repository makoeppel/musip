# SPDX-License-Identifier: GPL-2.0
# DKMS-friendly Makefile for the mudaq kernel module.

KERNELRELEASE ?= $(shell uname -r)
KERNELDIR ?= /lib/modules/$(KERNELRELEASE)/build
MODULEDIR ?= $(CURDIR)

all:
	$(MAKE) -C $(KERNELDIR) M=$(MODULEDIR) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(MODULEDIR) clean

install_udev:
	install -o root -g root -m 0644 99-mudaq.rules /etc/udev/rules.d/99-mudaq.rules
	udevadm control --reload-rules
	udevadm trigger --subsystem-match=misc || true

.PHONY: all clean install_udev
