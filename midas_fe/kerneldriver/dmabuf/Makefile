KERNELRELEASE ?= $(shell uname -r)
KERNELDIR ?= /lib/modules/$(KERNELRELEASE)/build
MODULEDIR ?= $(CURDIR)
MODULE_NAME := dmabuf

all:
	$(MAKE) -C $(KERNELDIR) M=$(MODULEDIR) MODULE_NAME=$(MODULE_NAME) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(MODULEDIR) MODULE_NAME=$(MODULE_NAME) clean

.PHONY: all clean
