KERNEL := development
ROOT := $(shell pwd)
BUILD := $(ROOT)/build
DIST := $(ROOT)/dist
KDK := /Library/Developer/KDKs/KDK_13.5_22G74.kdk
FRAMEWORK := $(BUILD)/System/Library/Frameworks/Kernel.framework/Versions/A
MNT := $(ROOT)/mnt

ifeq ($(KERNEL), release)
	KCSUFFIX =
else
	KCSUFFIX = .$(KERNEL)
endif

.PHONY: patches xnu kernel_collections

all: xnu kernel_collections

$(FRAMEWORK)/Headers/AvailabilityVersions.h:
	@echo "Installing AvailabilityVersions"
	$(eval SRCROOT := $(ROOT)/AvailabilityVersions)
	@cd $(SRCROOT) && make install -j8 DSTROOT=$(BUILD)

$(FRAMEWORK)/PrivateHeaders: $(FRAMEWORK)/Headers/AvailabilityVersions.h
	@echo "Installing XNU headers"
	$(eval SRCROOT := $(ROOT)/xnu)
	$(eval OBJROOT := $(BUILD)/xnu.obj)
	$(eval SYMROOT := $(BUILD)/xnu.sym)
	@cd $(SRCROOT) && make installhdrs SDKROOT=macosx TARGET_CONFIGS="$(KERNEL) X86_64 NONE" OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(BUILD) FAKEROOT=$(BUILD)

$(BUILD)/usr/local/lib/kernel/libfirehose_kernel.a: $(FRAMEWORK)/PrivateHeaders
	@echo "Building libfirehose_kernel"
	$(eval SRCROOT := $(ROOT)/libdispatch)
	$(eval OBJROOT := $(BUILD)/libfirehose_kernel.obj)
	$(eval SYMROOT := $(BUILD)/libfirehose_kernel.sym)
	@cd $(SRCROOT) && xcodebuild install -target libfirehose_kernel -sdk macosx PRODUCT_NAME=firehose_kernel VALID_ARCHS="x86_64" OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(BUILD) FAKEROOT=$(BUILD)

xnu: $(BUILD)/usr/local/lib/kernel/libfirehose_kernel.a
	@echo "Building XNU kernel"
	$(eval SRCROOT := $(ROOT)/xnu)
	$(eval OBJROOT := $(BUILD)/xnu.obj)
	$(eval SYMROOT := $(BUILD)/xnu.sym)
	@cd $(SRCROOT) && make install -j8 SDKROOT=macosx TARGET_CONFIGS="$(KERNEL) X86_64 NONE" CONCISE=1 LOGCOLORS=y BUILD_WERROR=0 BUILD_LTO=0 OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(BUILD) FAKEROOT=$(BUILD)
	@ditto $(BUILD)/xnu.obj/kernel$(KCSUFFIX) $(DIST)/System/Library/Kernels/

kernel_collections:
	@echo "Building kernel collections"
	@kmutil create -v -V $(KERNEL) -a x86_64 -n boot sys \
		--allow-missing-kdk --kdk $(KDK) \
		-B $(BUILD)/BootKernelExtensions.kc$(KCSUFFIX) \
		-S $(BUILD)/SystemKernelExtensions.kc$(KCSUFFIX) \
		-k $(BUILD)/xnu.obj/kernel$(KCSUFFIX) \
		--elide-identifier com.apple.driver.AppleIntelTGLGraphicsFramebuffer
	@ditto $(BUILD)/BootKernelExtensions.kc$(KCSUFFIX) $(DIST)/System/Library/KernelCollections/
	@ditto $(BUILD)/SystemKernelExtensions.kc$(KCSUFFIX) $(DIST)/System/Library/KernelCollections/

install:
	@ditto $(DIST) $(MNT)
