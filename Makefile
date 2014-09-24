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

ARCH_DIR=$(WORKSPACE)/$(ARCH)
PRIMARY_ARCH_DIR=$(WORKSPACE)/$(PRIMARY_ARCH)
SECONDARY_ARCH_DIR=$(WORKSPACE)/$(SECONDARY_ARCH)
COMMON_DIR=$(WORKSPACE)/commom

ISO_IMAGE_DEST=/iso
ISO_IMAGE=$(ISO_IMAGE_DEST)/image.iso
ISO_NAME=$(ISO_FLAVOR)-$(ISO_VERSION)-desktop-$(ALTARCH).iso
ISO_URL=$(ISO_BASE_URL)/$(ISO_RELEASE)/release
ISO_CONTENT=$(ISO_IMAGE_DEST)/content

CASPER_SOURCE_DIR=$(ISO_CONTENT)/casper
INITRD_SOURCE=$(CASPER_SOURCE_DIR)/initrd.lz
SQUASHFS_SOURCE=$(CASPER_SOURCE_DIR)/filesystem.squashfs
APT_CACHE_DIR=$(WORKSPACE)/apt_cache

ROOTFS=/rootfs
INITRD=/initrd
INITRD_TARGET=/initrd.lz
STATE_DIR=/state
LXC_DIR=/lxc_container
CHECKSUMS=/rootfs.md5sums


$(info Architecture: $(ARCH) ($(ALTARCH)))
$(info Workspace: $(WORKSPACE))

workspace: $(WORKSPACE)

$(WORKSPACE) $(ARCH_DIR) $(ARCH_DIR)$(STATE_DIR):
	mkdir -p "$(WORKSPACE)"
	mkdir -p "$(ARCH_DIR)"
	mkdir -p "$(ARCH_DIR)$(STATE_DIR)"

iso_download $(ARCH_DIR)$(ISO_IMAGE): | $(ARCH_DIR)
	mkdir -p "$(ARCH_DIR)$(ISO_IMAGE_DEST)"
	wget -O "$(ARCH_DIR)$(ISO_IMAGE_DEST)/$(ISO_NAME)" -c "$(ISO_URL)/$(ISO_NAME)"
	wget -O "$(ARCH_DIR)$(ISO_IMAGE_DEST)/SHA256SUMS.temp" -c "$(ISO_URL)/SHA256SUMS"
	grep "$(ARCH_DIR)$(ISO_NAME)" "$(ARCH_DIR)$(ISO_IMAGE_DEST)/SHA256SUMS.temp" > "$(ARCH_DIR)$(ISO_IMAGE_DEST)/SHA256SUMS"
	$(RM) "$(ARCH_DIR)$(ISO_IMAGE_DEST)/SHA256SUMS.temp"
	cd "$(ARCH_DIR)$(ISO_IMAGE_DEST)" && sha256sum -c SHA256SUMS
	mv "$(ARCH_DIR)$(ISO_IMAGE_DEST)/$(ISO_NAME)" "$(ARCH_DIR)$(ISO_IMAGE)"

iso_content $(ARCH_DIR)$(STATE_DIR)/iso_extracted: $(ARCH_DIR)$(ISO_IMAGE) $(ARCH_DIR)$(STATE_DIR)
	mkdir -p "$(ARCH_DIR)$(ISO_CONTENT)"
	7z x -o"$(ARCH_DIR)$(ISO_CONTENT)" -aos "$(ARCH_DIR)$(ISO_IMAGE)"
	touch "$(ARCH_DIR)$(STATE_DIR)/iso_extracted"

iso_clean:
	$(RM) "$(ARCH_DIR)$(ISO_IMAGE)"
	$(RM) -r "$(ARCH_DIR)$(ISO_IMAGE_DEST)"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/iso_extracted"

apt_cache $(APT_CACHE_DIR): |$(WORKSPACE)
	mkdir -p "$(APT_CACHE_DIR)"

apt_cache_clean:
	$(RM) -r "$(APT_CACHE_DIR)"

#TODO: generic unsquash/squash with magic make variables ($@ etc.)
rootfs_unsquash $(ARCH_DIR)$(STATE_DIR)/rootfs_extracted: $(ARCH_DIR)$(STATE_DIR) $(ARCH_DIR)$(STATE_DIR)/iso_extracted
	$(RM) -r "$(ARCH_DIR)$(ROOTFS)"
	unsquashfs -f -d "$(ARCH_DIR)$(ROOTFS)" "$(ARCH_DIR)$(SQUASHFS_SOURCE)"
	touch "$(ARCH_DIR)$(STATE_DIR)/rootfs_extracted"

rootfs_prepare $(ARCH_DIR)$(STATE_DIR)/rootfs_prepared: $(ARCH_DIR)$(STATE_DIR)/rootfs_extracted $(ARCH_DIR)$(STATE_DIR) /etc/resolv.conf
	if [ -e "$(ARCH_DIR)$(ROOTFS)/etc/resolv.conf" ]; then cp "$(ARCH_DIR)$(ROOTFS)/etc/resolv.conf" "$(ARCH_DIR)$(ROOTFS)/etc/resolv.conf.bak"; fi
	test ! -e "$(ARCH_DIR)$(ROOTFS)/usr/sbin/init.lxc"
	test ! -e "$(ARCH_DIR)$(ROOTFS)/remaster/"
	echo "#!/bin/bash" > "$(ARCH_DIR)$(ROOTFS)/usr/sbin/init.lxc"
	echo "shift; exec \$$@" >> "$(ARCH_DIR)$(ROOTFS)/usr/sbin/init.lxc"
	chmod +x "$(ARCH_DIR)$(ROOTFS)/usr/sbin/init.lxc"
	cp /etc/resolv.conf "$(ARCH_DIR)$(ROOTFS)/etc/resolv.conf"
	mkdir -p "$(ARCH_DIR)$(ROOTFS)/remaster"
	cp -Lr "$(CURDIR)"/config/copy_to_rootfs_remaster_dir/* "$(ARCH_DIR)$(ROOTFS)/remaster"
	echo "#!/bin/bash" > "$(ARCH_DIR)$(ROOTFS)/remaster/remaster.gen.sh"
	echo "export PATH; export TERM=$(TERM); export LIPCK_HAS_APT_CACHE=1" >> "$(ARCH_DIR)$(ROOTFS)/remaster/remaster.gen.sh"
	echo "source /remaster/scripts/remaster_rootfs.sh" >> "$(ARCH_DIR)$(ROOTFS)/remaster/remaster.gen.sh"
	chmod +x "$(ARCH_DIR)$(ROOTFS)/remaster/remaster.gen.sh"
	touch "$(ARCH_DIR)$(STATE_DIR)/rootfs_prepared"

rootfs_remaster $(ARCH_DIR)$(STATE_DIR)/rootfs_remastered: $(ARCH_DIR)$(STATE_DIR)/rootfs_prepared |$(ARCH_DIR)$(STATE_DIR) $(APT_CACHE_DIR)
	mkdir -p "$(ARCH_DIR)$(LXC_DIR)"
	lxc-execute --name "lipck_remaster_$(ARCH)" -P "$(ARCH_DIR)$(LXC_DIR)" -f "$(CURDIR)/config/lxc_common.conf" \
	-s lxc.arch="$(ARCH)" -s lxc.rootfs="$(ARCH_DIR)$(ROOTFS)" \
	-s lxc.mount.entry="$(APT_CACHE_DIR) $(ARCH_DIR)$(ROOTFS)/var/cache/apt/ none defaults,bind 0 0" \
	-s lxc.mount.entry="none /tmp tmpfs defaults 0 0" \
	-s lxc.mount.entry="none /run tmpfs defaults 0 0" \
	-- /bin/bash -l /remaster/remaster.gen.sh
	touch "$(ARCH_DIR)$(STATE_DIR)/rootfs_remastered"

rootfs_finalize $(ARCH_DIR)$(STATE_DIR)/rootfs_finalized: $(ARCH_DIR)$(STATE_DIR)/rootfs_remastered
	$(RM) "$(ARCH_DIR)$(ROOTFS)/usr/sbin/init.lxc"
	$(RM) "$(ARCH_DIR)$(ROOTFS)/etc/resolv.conf"
	if [ -e "$(ARCH_DIR)$(ROOTFS)/etc/resolv.conf.bak" ]; then mv "$(ARCH_DIR)$(ROOTFS)/etc/resolv.conf.bak" "$(ARCH_DIR)$(ROOTFS)/etc/resolv.conf"; fi
	$(RM) -r "$(ARCH_DIR)$(ROOTFS)/remaster"
	touch "$(ARCH_DIR)$(STATE_DIR)/rootfs_finalized"

rootfs_clean:
	$(RM) -r "$(ARCH_DIR)$(ROOTFS)"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_extracted"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_remastered"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_finalized"
	$(RM) -rf $(ARCH_DIR)$(LXC_DIR)

rootfs_checksums $(ARCH_DIR)$(CHECKSUMS): $(ARCH_DIR)$(STATE_DIR)/rootfs_finalized
	cd "$(ARCH_DIR)$(ROOTFS)" && find . -type f -print0 | sort -z | xargs -0 md5sum > "$(ARCH_DIR)$(CHECKSUMS)"

rootfs_deduplicate $(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated: $(PRIMARY_ARCH_DIR)$(CHECKSUMS) $(SECONDARY_ARCH_DIR)$(CHECKSUMS)
	mkdir -p "$(COMMON_DIR)$(STATE_DIR)"
	mkdir -p "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)" "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)" "$(COMMON_DIR)/lip-common"
	diff --old-line-format="" --new-line-format="" --unchanged-line-format="%L" \
	"$(PRIMARY_ARCH_DIR)$(CHECKSUMS)" "$(SECONDARY_ARCH_DIR)$(CHECKSUMS)" > "$(COMMON_DIR)$(CHECKSUMS)" || true
	cut -d" " -f3- "$(COMMON_DIR)$(CHECKSUMS)" > "$(COMMON_DIR)/common_files.list"
	$(info Copying common files...)
	rsync -av --files-from="$(COMMON_DIR)/common_files.list" "$(PRIMARY_ARCH_DIR)$(ROOTFS)/" "$(COMMON_DIR)/lip-common"
	$(info Copying $(PRIMARY_ARCH) files...)
	rsync -av --exclude-from="$(COMMON_DIR)/common_files.list" "$(PRIMARY_ARCH_DIR)$(ROOTFS)/" "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)"
	$(info Copying $(SECONDARY_ARCH) files...)
	rsync -av --exclude-from="$(COMMON_DIR)/common_files.list" "$(SECONDARY_ARCH)$(ROOTFS)/" "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)"
	touch "$(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated"

rootfs_squash: $(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated
	mksquashfs "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)" "$(COMMON_DIR)/lip$(PRIMARY_ARCH).squashfs" -comp xz
	mksquashfs "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)" "$(COMMON_DIR)/lip$(SECONDARY_ARCH).squashfs" -comp xz
	mksquashfs "$(COMMON_DIR)/lip-common" "$(COMMON_DIR)/lipcommon.squashfs" -comp xz

initrd_unpack $(ARCH_DIR)$(STATE_DIR)/initrd_extracted: $(ARCH_DIR)$(STATE_DIR)/iso_extracted $(ARCH_DIR)$(STATE_DIR)
	mkdir -p "$(ARCH_DIR)$(INITRD)"
	cd "$(ARCH_DIR)$(INITRD)" && lzma -d < "$(ARCH_DIR)$(INITRD_SOURCE)" | cpio -i
	touch "$(ARCH_DIR)$(STATE_DIR)/initrd_extracted"

initrd_clean:
	$(RM) -r "$(ARCH_DIR)$(INITRD)"
	$(RM) "$(ARCH_DIR)$(INITRD_TARGET)"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/initrd_extracted"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/initrd_remastered"

initrd_remaster $(ARCH_DIR)$(STATE_DIR)/initrd_remastered: $(ARCH_DIR)$(STATE_DIR)/initrd_extracted $(ARCH_DIR)$(STATE_DIR)
	$(ARCH_DIR)$(CURDIR)/scripts/remaster_initrd.sh "$(ARCH_DIR)$(CURDIR)" "$(ARCH_DIR)$(INITRD)"
	touch "$(ARCH_DIR)$(STATE_DIR)/initrd_remastered"

initrd_pack $(ARCH_DIR)$(INITRD_TARGET): $(ARCH_DIR)$(STATE_DIR)/initrd_remastered
	cd "$(ARCH_DIR)$(INITRD)" && find | cpio -H newc -o | lzma -z > "$(ARCH_DIR)$(INITRD_TARGET)"

config $(CONFIG_FILE):
	$(info Generating configuration $(CONFIG_FILE))
	echo -n "" > $(CONFIG_FILE)
	echo "PRIMARY_ARCH=$(PRIMARY_ARCH)" >> "$(CONFIG_FILE)"
	echo "SECONDARY_ARCH=$(SECONDARY_ARCH)" >> "$(CONFIG_FILE)"
	echo "WORKSPACE=$(WORKSPACE)" >> "$(CONFIG_FILE)"

config_clean:
	$(RM) $(CONFIG_FILE)

.PHONY : config config_clean iso_clean initrd_clean rootfs_clean apt_cache_clean
