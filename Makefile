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
STATE_DIR=$(WORKSPACE)/$(ARCH)/state

$(info Architecture: $(ARCH) ($(ALTARCH)))
$(info Workspace: $(WORKSPACE))

workspace : $(WORKSPACE)

$(WORKSPACE) :
	mkdir -p "$(WORKSPACE)"
	mkdir -p "$(STATE_DIR)"

iso_download $(ISO_IMAGE) : | $(WORKSPACE)
	mkdir -p "$(ISO_IMAGE_DEST)"
	wget -O "$(ISO_IMAGE_DEST)/$(ISO_NAME)" -c "$(ISO_URL)/$(ISO_NAME)"
	wget -O "$(ISO_IMAGE_DEST)/SHA256SUMS.temp" -c "$(ISO_URL)/SHA256SUMS"
	grep "$(ISO_NAME)" "$(ISO_IMAGE_DEST)/SHA256SUMS.temp" > "$(ISO_IMAGE_DEST)/SHA256SUMS"
	$(RM) "$(ISO_IMAGE_DEST)/SHA256SUMS.temp"
	cd "$(ISO_IMAGE_DEST)" && sha256sum -c SHA256SUMS
	mv "$(ISO_IMAGE_DEST)/$(ISO_NAME)" "$(ISO_IMAGE)"

iso_content $(STATE_DIR)/iso_exctracted : $(ISO_IMAGE)
	mkdir -p "$(ISO_CONTENT)"
	7z x -o"$(ISO_CONTENT)" -aos "$(ISO_IMAGE)"
	touch "$(STATE_DIR)/iso_exctracted"

iso_clean :
	$(RM) "$(ISO_IMAGE)"
	$(RM) -r "$(ISO_IMAGE_DEST)"
	$(RM) "$(STATE_DIR)/iso_exctracted"

#TODO: generic unsquash/squash with magic make variables ($@ etc.)
rootfs_unsquash $(ROOTFS) : $(STATE_DIR)/iso_exctracted
	$(RM) -r "$(ROOTFS)"
	unsquashfs -f -d "$(ROOTFS)" "$(SQUASHFS_SOURCE)"
	touch "$(STATE_DIR)/rootfs_extracted"

rootfs_prepare : $(ROOTFS) : $(STATE_DIR)/rootfs_extracted
	mkdir -p "$(ROOTFS)/remaster"
	cp -Lr "$(CURDIR)"/config/copy_to_rootfs_remaster_dir/* "$(ROOTFS)/remaster"

rootfs_clean :
	$(RM) -r "$(ROOTFS)"
	$(RM) "$(STATE_DIR)/rootfs_extracted"

initrd_unpack $(STATE_DIR)/initrd_extracted : $(STATE_DIR)/iso_exctracted
	mkdir -p "$(INITRD)"
	cd "$(INITRD)" && lzma -d < "$(INITRD_SOURCE)" | cpio -i
	touch "$(STATE_DIR)/initrd_extracted"

initrd_clean :
	$(RM) -r "$(INITRD)"
	$(RM) "$(INITRD_TARGET)"
	$(RM) "$(STATE_DIR)/initrd_extracted"
	$(RM) "$(STATE_DIR)/initrd_remastered"

initrd_remaster $(STATE_DIR)/initrd_remastered : $(STATE_DIR)/initrd_extracted
	$(CURDIR)/scripts/remaster_initrd.sh "$(CURDIR)" "$(INITRD)"
	touch "$(STATE_DIR)/initrd_remastered"

initrd_pack $(INITRD_TARGET) : $(STATE_DIR)/initrd_remastered
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
