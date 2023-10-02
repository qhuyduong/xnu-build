KERNEL := development
ROOT := $(PWD)
BUILDROOT := $(PWD)/build
DSTROOT := $(PWD)/dst
FRAMEWORK_ROOT := $(DSTROOT)/System/Library/Frameworks/Kernel.framework/Versions/A

all: patches xnu kernel_collections

patches:
	@for patch in $(shell find $(ROOT)/patches); do \
		if patch -N -s --dry-run < $${patch} > /dev/null 2>&1; then \
			patch < $${patch}; \
		fi; \
	done

$(FRAMEWORK_ROOT)/Headers/AvailabilityVersions.h:
	$(eval SRCROOT := $(ROOT)/AvailabilityVersions)
	@cd $(SRCROOT) && make install -j8 DSTROOT=$(DSTROOT)

$(FRAMEWORK_ROOT)/PrivateHeaders: $(FRAMEWORK_ROOT)/Headers/AvailabilityVersions.h
	$(eval SRCROOT := $(ROOT)/xnu)
	$(eval OBJROOT := $(BUILDROOT)/xnu.obj)
	$(eval SYMROOT := $(BUILDROOT)/xnu.sym)
	@cd $(SRCROOT) && make installhdrs SDKROOT=macosx TARGET_CONFIGS="$(KERNEL) X86_64 NONE" OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(DSTROOT) FAKEROOT=$(DSTROOT)

$(DSTROOT)/usr/local/lib/kernel/libfirehose_kernel.a: $(FRAMEWORK_ROOT)/PrivateHeaders
	$(eval SRCROOT := $(ROOT)/libdispatch)
	$(eval OBJROOT := $(BUILDROOT)/libfirehose_kernel.obj)
	$(eval SYMROOT := $(BUILDROOT)/libfirehose_kernel.sym)
	@cd $(SRCROOT) && xcodebuild install -target libfirehose_kernel -sdk macosx PRODUCT_NAME=firehose_kernel VALID_ARCHS="x86_64" OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(DSTROOT) FAKEROOT=$(DSTROOT)

$(BUILDROOT)/xnu.obj/kernel.$(KERNEL): $(DSTROOT)/usr/local/lib/kernel/libfirehose_kernel.a
	$(eval SRCROOT := $(ROOT)/xnu)
	$(eval OBJROOT := $(BUILDROOT)/xnu.obj)
	$(eval SYMROOT := $(BUILDROOT)/xnu.sym)
	@cd $(SRCROOT) && make install -j8 SDKROOT=macosx TARGET_CONFIGS="$(KERNEL) X86_64 NONE" CONCISE=1 LOGCOLORS=y BUILD_WERROR=0 BUILD_LTO=0 OBJROOT=$(OBJROOT) SYMROOT=$(SYMROOT) DSTROOT=$(DSTROOT) FAKEROOT=$(DSTROOT)

xnu: $(BUILDROOT)/xnu.obj/kernel.$(KERNEL)

kernel_collections:
	@kmutil create -v -V $(KERNEL) -a x86_64 -n boot sys \
		--allow-missing-kdk \
		-B $(DSTROOT)/BootKernelExtensions.kc.$(KERNEL) \
		-S $(DSTROOT)/SystemKernelExtensions.kc.$(KERNEL) \
		-k $(BUILDROOT)/xnu.obj/kernel.$(KERNEL) \
		--elide-identifier com.apple.driver.AppleIntelTGLGraphicsFramebuffer
