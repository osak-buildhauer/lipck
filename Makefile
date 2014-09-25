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

define archdir =
$(WORKSPACE)/$1
endef

ARCH_DIR=$(call archdir,$(ARCH))
PRIMARY_ARCH_DIR=$(call archdir,$(PRIMARY_ARCH))
SECONDARY_ARCH_DIR=$(call archdir,$(SECONDARY_ARCH))
COMMON_DIR=$(WORKSPACE)/common

define gentargets =
$(PRIMARY_ARCH_DIR)$1 $(SECONDARY_ARCH_DIR)$1 : $(call archdir,%)$1
endef

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

$(WORKSPACE) :
	mkdir -p "$(WORKSPACE)"

$(call gentargets,) : $(WORKSPACE)
	mkdir -p "$(WORKSPACE)/$*"

$(call gentargets,$(STATE_DIR)) : $(WORKSPACE)/%
	mkdir -p "$(WORKSPACE)/$*$(STATE_DIR)"

iso_download : $(ARCH_DIR)$(ISO_IMAGE)
$(call gentargets,$(ISO_IMAGE)) : | $(call archdir,%)
	mkdir -p "$(call archdir,$*)$(ISO_IMAGE_DEST)"
	wget -O "$(call archdir,$*)$(ISO_IMAGE_DEST)/$(ISO_NAME)" -c "$(ISO_URL)/$(ISO_NAME)"
	wget -O "$(call archdir,$*)$(ISO_IMAGE_DEST)/SHA256SUMS.temp" -c "$(ISO_URL)/SHA256SUMS"
	grep "$(call archdir,$*)$(ISO_NAME)" "$(call archdir,$*)$(ISO_IMAGE_DEST)/SHA256SUMS.temp" > "$(call archdir,$*)$(ISO_IMAGE_DEST)/SHA256SUMS"
	$(RM) "$(call archdir,$*)$(ISO_IMAGE_DEST)/SHA256SUMS.temp"
	cd "$(call archdir,$*)$(ISO_IMAGE_DEST)" && sha256sum -c SHA256SUMS
	mv "$(call archdir,$*)$(ISO_IMAGE_DEST)/$(ISO_NAME)" "$(call archdir,$*)$(ISO_IMAGE)"

iso_content : $(ARCH_DIR)$(STATE_DIR)/iso_extracted
$(call gentargets,$(STATE_DIR)/iso_extracted) : $(call archdir,%)$(ISO_IMAGE) $(call archdir,%)$(STATE_DIR)
	mkdir -p "$(call archdir,$*)$(ISO_CONTENT)"
	7z x -o"$(call archdir,$*)$(ISO_CONTENT)" -aos "$(call archdir,$*)$(ISO_IMAGE)"
	touch "$(call archdir,$*)$(STATE_DIR)/iso_extracted"

iso_clean:
	$(RM) "$(ARCH_DIR)$(ISO_IMAGE)"
	$(RM) -r "$(ARCH_DIR)$(ISO_IMAGE_DEST)"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/iso_extracted"

apt_cache $(APT_CACHE_DIR): |$(WORKSPACE)
	mkdir -p "$(APT_CACHE_DIR)"

apt_cache_clean:
	$(RM) -r "$(APT_CACHE_DIR)"

rootfs_unsquash : $(ARCH_DIR)$(STATE_DIR)/rootfs_extracted
$(call gentargets,$(STATE_DIR)/rootfs_extracted) : $(call archdir,%)$(STATE_DIR)/iso_extracted
	$(RM) -r "$(call archdir,$*)$(ROOTFS)"
	unsquashfs -f -d "$(call archdir,$*)$(ROOTFS)" "$(call archdir,$*)$(SQUASHFS_SOURCE)"
	touch "$(call archdir,$*)$(STATE_DIR)/rootfs_extracted"

rootfs_prepare : $(ARCH_DIR)$(STATE_DIR)/rootfs_prepared
$(call gentargets,$(STATE_DIR)/rootfs_prepared) : $(call archdir,%)$(STATE_DIR)/rootfs_extracted
	test ! -e /etc/resolv.conf
	test ! -e "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	test ! -e "$(call archdir,$*)$(ROOTFS)/remaster/"
	if [ -e "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf" ]; \
	then \
		cp "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf" "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf.bak"; \
	fi
	echo "#!/bin/bash" > "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	echo "shift; exec \$$@" >> "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	chmod +x "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	cp /etc/resolv.conf "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf"
	mkdir -p "$(call archdir,$*)$(ROOTFS)/remaster"
	cp -Lr "$(CURDIR)"/config/copy_to_rootfs_remaster_dir/* "$(call archdir,$*)$(ROOTFS)/remaster"
	echo "#!/bin/bash" > "$(call archdir,$*)$(ROOTFS)/remaster/remaster.gen.sh"
	echo "export PATH; export TERM=$(TERM); export LIPCK_HAS_APT_CACHE=1" >> "$(call archdir,$*)$(ROOTFS)/remaster/remaster.gen.sh"
	echo "source /remaster/scripts/remaster_rootfs.sh" >> "$(call archdir,$*)$(ROOTFS)/remaster/remaster.gen.sh"
	chmod +x "$(call archdir,$*)$(ROOTFS)/remaster/remaster.gen.sh"
	touch "$(call archdir,$*)$(STATE_DIR)/rootfs_prepared"

rootfs_remaster : $(ARCH_DIR)$(STATE_DIR)/rootfs_remastered
$(call gentargets,$(STATE_DIR)/rootfs_remastered) : $(call archdir,%)$(STATE_DIR)/rootfs_prepared | $(APT_CACHE_DIR)
	mkdir -p "$(call archdir,$*)$(LXC_DIR)"
	lxc-execute --name "lipck_remaster_$*" -P "$(call archdir,$*)$(LXC_DIR)" -f "$(CURDIR)/config/lxc_common.conf" \
	-s lxc.arch="$*" -s lxc.rootfs="$(call archdir,$*)$(ROOTFS)" \
	-s lxc.mount.entry="$(APT_CACHE_DIR) $(call archdir,$*)$(ROOTFS)/var/cache/apt/ none defaults,bind 0 0" \
	-s lxc.mount.entry="none /tmp tmpfs defaults 0 0" \
	-s lxc.mount.entry="none /run tmpfs defaults 0 0" \
	-- /bin/bash -l /remaster/remaster.gen.sh
	touch "$(call archdir,$*)$(STATE_DIR)/rootfs_remastered"

rootfs_finalize : $(ARCH_DIR)$(STATE_DIR)/rootfs_finalized
$(call gentargets,$(STATE_DIR)/rootfs_finalized) : $(call archdir,%)$(STATE_DIR)/rootfs_remastered
	$(RM) "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	$(RM) "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf"
	if [ -e "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf.bak" ]; then mv "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf.bak" "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf"; fi
	$(RM) -r "$(call archdir,$*)$(ROOTFS)/remaster"
	touch "$(call archdir,$*)$(STATE_DIR)/rootfs_finalized"

rootfs_clean:
	$(RM) -r "$(ARCH_DIR)$(ROOTFS)"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_extracted"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_prepared"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_remastered"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_finalized"
	$(RM) -rf $(ARCH_DIR)$(LXC_DIR)

rootfs_checksums : $(ARCH_DIR)$(CHECKSUMS)
$(call gentargets,$(CHECKSUMS)) : $(call archdir,%)$(STATE_DIR)/rootfs_finalized
	cd "$(call archdir,$*)$(ROOTFS)" && find . -type f -print0 | sort -z | xargs -0 md5sum > "$(call archdir,$*)$(CHECKSUMS)"

rootfs_deduplicate $(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated: $(PRIMARY_ARCH_DIR)$(CHECKSUMS) $(SECONDARY_ARCH_DIR)$(CHECKSUMS)
	mkdir -p "$(COMMON_DIR)$(STATE_DIR)"
	mkdir -p "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)" "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)" "$(COMMON_DIR)/lip-common"
	diff --old-line-format="" --new-line-format="" --unchanged-line-format="%L" \
	"$(PRIMARY_ARCH_DIR)$(CHECKSUMS)" "$(SECONDARY_ARCH_DIR)$(CHECKSUMS)" > "$(COMMON_DIR)$(CHECKSUMS)" || true
	cut -d" " -f3- "$(COMMON_DIR)$(CHECKSUMS)" > "$(COMMON_DIR)/common_files.list"
	$(info Copying common files...)
	rsync -av --files-from="$(COMMON_DIR)/common_files.list" "$(PRIMARY_ARCH_DIR)$(ROOTFS)/" "$(COMMON_DIR)/lip-common"
	$(info Copying $(PRIMARY_ARCH) files...)
	rsync -av "$(PRIMARY_ARCH_DIR)$(ROOTFS)/" "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)"
	cd "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)" && tr \\n \\0 < "$(COMMON_DIR)/common_files.list" | xargs -0 rm 
	$(info Copying $(SECONDARY_ARCH) files...)
	rsync -av "$(SECONDARY_ARCH_DIR)$(ROOTFS)/" "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)"
	cd "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)" && tr \\n \\0 < "$(COMMON_DIR)/common_files.list" | xargs -0 rm 
	touch "$(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated"

$(COMMON_DIR)/lip%.squashfs : $(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated | $(COMMON_DIR)/lip-%
	mksquashfs "$(COMMON_DIR)/lip-$*" "$(COMMON_DIR)/lip$*.squashfs" -comp xz

rootfs_squash: $(COMMON_DIR)/lip$(PRIMARY_ARCH).squashfs $(COMMON_DIR)/lip$(SECONDARY_ARCH).squashfs $(COMMON_DIR)/lipcommon.squashfs

initrd_unpack : $(ARCH_DIR)$(STATE_DIR)/initrd_extracted
$(call gentargets,$(STATE_DIR)/initrd_extracted) : $(call archdir,%)$(STATE_DIR)/iso_extracted
	mkdir -p "$(call archdir,$*)$(INITRD)"
	cd "$(call archdir,$*)$(INITRD)" && lzma -d < "$(call archdir,$*)$(INITRD_SOURCE)" | cpio -i
	touch "$(call archdir,$*)$(STATE_DIR)/initrd_extracted"

initrd_clean:
	$(RM) -r "$(ARCH_DIR)$(INITRD)"
	$(RM) "$(ARCH_DIR)$(INITRD_TARGET)"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/initrd_extracted"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/initrd_remastered"

initrd_remaster : $(ARCH_DIR)$(STATE_DIR)/initrd_remastered
$(call gentargets,$(STATE_DIR)/initrd_remastered) : $(call archdir,%)$(STATE_DIR)/initrd_extracted
	$(CURDIR)/scripts/remaster_initrd.sh "$(CURDIR)" "$(call archdir,$*)$(INITRD)"
	touch "$(call archdir,$*)$(STATE_DIR)/initrd_remastered"

initrd_pack : $(ARCH_DIR)$(INITRD_TARGET)
$(call gentargets,$(INITRD_TARGET)) : $(call archdir,%)$(STATE_DIR)/initrd_remastered
	cd "$(call archdir,$*)$(INITRD)" && find | cpio -H newc -o | lzma -z > "$(call archdir,$*)$(INITRD_TARGET)"

config $(CONFIG_FILE):
	$(info Generating configuration $(CONFIG_FILE))
	echo -n "" > $(CONFIG_FILE)
	echo "PRIMARY_ARCH=$(PRIMARY_ARCH)" >> "$(CONFIG_FILE)"
	echo "SECONDARY_ARCH=$(SECONDARY_ARCH)" >> "$(CONFIG_FILE)"
	echo "WORKSPACE=$(WORKSPACE)" >> "$(CONFIG_FILE)"

config_clean:
	$(RM) $(CONFIG_FILE)

ISO_PHONY=iso_download iso_content iso_clean
ROOTFS_PHONY=rootfs_unsquash rootfs_prepare rootfs_remaster rootfs_finalize rootfs_checksums rootfs_deduplicate rootfs_squash rootfs_clean
INITRD_PHONY=initrd_unpack initrd_remaster initrd_pack initrd_clean
APT_CACHE_PHONY=apt_cache apt_cache_clean

.PHONY : workspace config config_clean $(ISO_PHONY) $(ROOTFS_PHONY) $(INITRD_PHONY) $(APT_CACHE_PHONY)
