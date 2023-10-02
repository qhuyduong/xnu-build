KERNEL := development
ROOT := $(PWD)
BUILDROOT := $(PWD)/build
DSTROOT := $(PWD)/dst

.PHONY: availabilityversions patches xnu

patches:
	@for patch in $(shell find $(ROOT)/patches); do \
		if patch -N -s --dry-run < $${patch} > /dev/null 2>&1; then \
			patch < $${patch}; \
		fi; \
	done

availabilityversions:
	$(eval SRCROOT := $(ROOT)/AvailabilityVersions)
	@cd $(SRCROOT) && make install -j8 DSTROOT=$(DSTROOT)

xnu_headers: availabilityversions
	$(eval SRCROOT := $(ROOT)/xnu)
	$(eval OBJROOT := $(BUILDROOT)/xnu.obj)
	$(eval SYMROOT := $(BUILDROOT)/xnu.sym)
	@cd $(SRCROOT) && make installhdrs SDKROOT=macosx TARGET_CONFIGS="$(KERNEL) X86_64 NONE" OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(DSTROOT) FAKEROOT=$(DSTROOT)

libfirehose_kernel:
	$(eval SRCROOT := $(ROOT)/libdispatch)
	$(eval OBJROOT := $(BUILDROOT)/libfirehose_kernel.obj)
	$(eval SYMROOT := $(BUILDROOT)/libfirehose_kernel.sym)
	@cd $(SRCROOT) && xcodebuild install -target libfirehose_kernel -sdk macosx PRODUCT_NAME=firehose_kernel VALID_ARCHS="X86_64" OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(DSTROOT) FAKEROOT=$(DSTROOT)

xnu:
	$(eval SRCROOT := $(ROOT)/xnu)
	$(eval OBJROOT := $(BUILDROOT)/xnu.obj)
	$(eval SYMROOT := $(BUILDROOT)/xnu.sym)
	@cd $(SRCROOT) && make install -j8 SDKROOT=macosx TARGET_CONFIGS="$(KERNEL) X86_64 NONE" CONCISE=1 LOGCOLORS=y BUILD_WERROR=0 BUILD_LTO=0 OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(DSTROOT) FAKEROOT=$(DSTROOT)
