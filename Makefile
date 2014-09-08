CONFIG_FILE_DEFAULTS=$(CURDIR)/config/Makefile.conf.defaults
CONFIG_FILE=$(CURDIR)/config/Makefile.conf

include $(CONFIG_FILE_DEFAULTS)
include $(CONFIG_FILE)

ifndef ARCH
  ARCH=$(PRIMARY_ARCH)
endif

#some tools and targets need alternative architecture names,
#so lets infer them
ALTARCH=$(ARCH)
ifeq ($(ARCH),x86_64)
  ALTARCH=amd64
endif
ifeq ($(ARCH),i686)
  ALTARCH=i386
endif

ISO_IMAGE_DEST=$(WORKSPACE)/$(ARCH)/iso
ISO_IMAGE=$(ISO_IMAGE_DEST)/image.iso
ISO_NAME=$(ISO_FLAVOR)-$(ISO_VERSION)-desktop-$(ALTARCH).iso
ISO_URL=$(ISO_BASE_URL)/$(ISO_RELEASE)/release
ISO_CONTENT=$(ISO_IMAGE_DEST)/content

CASPER_SOURCE_DIR=$(ISO_CONTENT)/casper
INITRD_SOURCE=$(CASPER_SOURCE_DIR)/initrd.lz
SQUASHFS_SOURCE=$(CASPER_SOURCE_DIR)/filesystem.squashfs

ROOTFS=$(WORKSPACE)/$(ARCH)/rootfs
INITRD=$(WORKSPACE)/$(ARCH)/initrd
INITRD_TARGET=$(WORKSPACE)/$(ARCH)/initrd.lz

$(info Architecture: $(ARCH) ($(ALTARCH)))
$(info Workspace: $(WORKSPACE))

workspace : $(WORKSPACE)

$(WORKSPACE) :
	mkdir -p $(WORKSPACE)

iso_download $(ISO_IMAGE) : | $(WORKSPACE)
	mkdir -p "$(ISO_IMAGE_DEST)"
	wget -O "$(ISO_IMAGE_DEST)/$(ISO_NAME)" -c "$(ISO_URL)/$(ISO_NAME)"
	wget -O "$(ISO_IMAGE_DEST)/SHA256SUMS.temp" -c "$(ISO_URL)/SHA256SUMS"
	grep "$(ISO_NAME)" "$(ISO_IMAGE_DEST)/SHA256SUMS.temp" > "$(ISO_IMAGE_DEST)/SHA256SUMS"
	$(RM) "$(ISO_IMAGE_DEST)/SHA256SUMS.temp"
	cd "$(ISO_IMAGE_DEST)" && sha256sum -c SHA256SUMS
	mv "$(ISO_IMAGE_DEST)/$(ISO_NAME)" "$(ISO_IMAGE)"

iso_content $(INITRD_SOURCE) $(SQUASHFS_SOURCE) : $(ISO_IMAGE)
	mkdir -p "$(ISO_CONTENT)"
	7z x -o"$(ISO_CONTENT)" -aos "$(ISO_IMAGE)"

iso_clean :
	$(RM) "$(ISO_IMAGE)"
	$(RM) -r "$(ISO_IMAGE_DEST)"

#TODO: generic unsquash/squash with magic make variables ($@ etc.)
rootfs_unsquash $(ROOTFS) : | $(SQUASHFS_SOURCE)
	$(RM) -r "$(ROOTFS)"
	unsquashfs -f -d "$(ROOTFS)" "$(SQUASHFS_SOURCE)"

rootfs_prepare : $(ROOTFS)
	mkdir -p "$(ROOTFS)/remaster"
	cp -Lr "$(CURDIR)"/config/copy_to_rootfs_remaster_dir/* "$(ROOTFS)/remaster"

rootfs_clean :
	$(RM) -r "$(ROOTFS)"

initrd_unpack : | $(INITRD_SOURCE)
	mkdir -p "$(INITRD)"
	cd "$(INITRD)" && lzma -d < "$(INITRD_SOURCE)" | cpio -i

initrd_clean :
	$(RM) -r "$(INITRD)"
	$(RM) "$(INITRD_TARGET)"

initrd_remaster :
	$(CURDIR)/scripts/remaster_initrd.sh "$(CURDIR)" "$(INITRD)"

initrd_pack :
	cd "$(INITRD)" && find | cpio -H newc -o | lzma -z > "$(INITRD_TARGET)"

config $(CONFIG_FILE) :
	$(info Generating configuration $(CONFIG_FILE))
	echo -n "" > $(CONFIG_FILE)
	echo "PRIMARY_ARCH=$(PRIMARY_ARCH)" >> "$(CONFIG_FILE)"
	echo "SECONDARY_ARCH=$(SECONDARY_ARCH)" >> "$(CONFIG_FILE)"
	echo "WORKSPACE=$(WORKSPACE)" >> "$(CONFIG_FILE)"

config_clean :
	$(RM) $(CONFIG_FILE)

.PHONY : config config_clean iso_clean initrd_clean rootfs_clean
