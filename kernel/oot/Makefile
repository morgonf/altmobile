obj-m += q6voice.o
obj-m += q6voice-common.o
obj-m += q6mvm.o
obj-m += q6cvp.o
obj-m += q6cvs.o

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
