ifeq ($(CONFIG_PLATFORM_I386_PC), y)
ccflags-y += -DCONFIG_LITTLE_ENDIAN
ccflags-y += -DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT

ccflags-y += -DCONFIG_RADIO_WORK
#ccflags-y += -DCONFIG_CONCURRENT_MODE

ifeq ($(CONFIG_SDIO_HCI), y)
ccflags-y += -DRTW_WKARD_SDIO_TX_USE_YIELD
endif
SUBARCH := $(shell uname -m | sed -e s/i.86/i386/)
ARCH ?= $(SUBARCH)
CROSS_COMPILE ?=
KVER  := $(shell uname -r)
KSRC := /lib/modules/$(KVER)/build
MODDESTDIR := /lib/modules/$(KVER)/kernel/drivers/net/wireless/
INSTALL_PREFIX :=
STAGINGMODDIR := /lib/modules/$(KVER)/kernel/drivers/staging
ifeq ($(CONFIG_PCI_HCI), y)
ccflags-y += -DCONFIG_PLATFORM_OPS
_PLATFORM_FILES := platform/platform_linux_pc_pci.o
OBJS += $(_PLATFORM_FILES)
endif
_PLATFORM_FILES += platform/platform_ops.o
endif
