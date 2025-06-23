#

KERNELDIR := /lib/modules/$(shell uname -r)/build
MODULEDIR := $(CURDIR)

all :
	$(MAKE) -C $(KERNELDIR) M=$(MODULEDIR)

clean :
	$(MAKE) -C $(KERNELDIR) M=$(MODULEDIR) clean

install : install_udev
# disable for now to not break the system to easily
#	$(MAKE) -C $(KERNELDIR) M=$(MODULEDIR) modules_install

install_udev :
	install -o root -g root -m 0644 99-mudaq.rules /etc/udev/rules.d
	udevadm control --reload

.PHONY : all, clean, install, install_udev
