CONFIG_FILE_DEFAULTS=$(CURDIR)/config/Makefile.conf.defaults
CONFIG_FILE=$(CURDIR)/config/Makefile.conf

include $(CONFIG_FILE_DEFAULTS)
include $(CONFIG_FILE)

#read all offically config options from CONFIG_FILE_DEFAULTS
CONFIGURABLE=$(shell cat "$(CONFIG_FILE_DEFAULTS)" | grep -v "^\#" | cut -s -d"=" -f1)

ifndef ARCH
  ARCH=$(PRIMARY_ARCH)
endif

#some tools and targets need alternative architecture names,
#so lets infer them
define altarch =
$(if $(subst x86_64,,$1),$(if $(subst i686,,$1),$1,i386),amd64)
endef

RSYNC=rsync -a

define archdir =
$(WORKSPACE)/$1
endef

ARCH_DIR=$(call archdir,$(ARCH))
PRIMARY_ARCH_DIR=$(call archdir,$(PRIMARY_ARCH))
SECONDARY_ARCH_DIR=$(call archdir,$(SECONDARY_ARCH))
COMMON_DIR=$(WORKSPACE)/common
IMAGE_DIR=$(WORKSPACE)/image

define gentargets =
$(PRIMARY_ARCH_DIR)$1 $(SECONDARY_ARCH_DIR)$1 : $(call archdir,%)$1
endef

ISO_IMAGE_DEST=/iso
ISO_IMAGE=$(ISO_IMAGE_DEST)/image.iso
ISO_URL=$(ISO_BASE_URL)/$(ISO_RELEASE)/release
ISO_CONTENT=$(ISO_IMAGE_DEST)/content

define getisoname =
$(ISO_FLAVOR)-$(ISO_VERSION)-desktop-$(call altarch,$1).iso
endef

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


default: help
	@exit 0

workspace: | $(WORKSPACE)

$(WORKSPACE) :
	mkdir -p "$(WORKSPACE)"

$(call gentargets,) : | $(WORKSPACE)
	mkdir -p "$(WORKSPACE)/$*"

$(call gentargets,$(STATE_DIR)) : | $(WORKSPACE)/%
	mkdir -p "$(WORKSPACE)/$*$(STATE_DIR)"

iso_download : $(ARCH_DIR)$(ISO_IMAGE)
$(call gentargets,$(ISO_IMAGE)) : | $(call archdir,%)
	mkdir -p "$(call archdir,$*)$(ISO_IMAGE_DEST)"
	wget -O "$(call archdir,$*)$(ISO_IMAGE_DEST)/$(call getisoname,$*)" -c "$(ISO_URL)/$(call getisoname,$*)"
	wget -O "$(call archdir,$*)$(ISO_IMAGE_DEST)/SHA256SUMS.temp" -c "$(ISO_URL)/SHA256SUMS"
	grep "$(call getisoname,$*)" "$(call archdir,$*)$(ISO_IMAGE_DEST)/SHA256SUMS.temp" > "$(call archdir,$*)$(ISO_IMAGE_DEST)/SHA256SUMS"
	$(RM) "$(call archdir,$*)$(ISO_IMAGE_DEST)/SHA256SUMS.temp"
	cd "$(call archdir,$*)$(ISO_IMAGE_DEST)" && sha256sum -c SHA256SUMS
	mv "$(call archdir,$*)$(ISO_IMAGE_DEST)/$(call getisoname,$*)" "$(call archdir,$*)$(ISO_IMAGE)"

iso_content : $(ARCH_DIR)$(STATE_DIR)/iso_extracted
$(call gentargets,$(STATE_DIR)/iso_extracted) : $(call archdir,%)$(ISO_IMAGE) | $(call archdir,%)$(STATE_DIR)
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
	test -e /etc/resolv.conf
	test ! -e "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	test ! -e "$(call archdir,$*)$(ROOTFS)/remaster/"
	if [ -e "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf" ]; \
	then \
		cp -a --remove-destination "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf" "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf.bak"; \
	fi
	echo "#!/bin/bash" > "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	echo "shift; exec \$$@" >> "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	chmod +x "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	cp -a --remove-destination /etc/resolv.conf "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf"
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
	$(RM) "$(ARCH_DIR)/filesystem.size"
	$(RM) -r $(ARCH_DIR)$(LXC_DIR)

rootfs_checksums : $(ARCH_DIR)$(CHECKSUMS)
$(call gentargets,$(CHECKSUMS)) : $(call archdir,%)$(STATE_DIR)/rootfs_finalized
	cd "$(call archdir,$*)$(ROOTFS)" && find . -type f -print0 | sort -z | xargs -0 md5sum > "$(call archdir,$*)$(CHECKSUMS)"

rootfs_fssize: $(ARCH_DIR)/filesystem.size
$(call gentargets,/filesystem.size) : $(call archdir,%)$(STATE_DIR)/rootfs_remastered
	IN_BYTES=$$(du -s "$(call archdir,$*)$(ROOTFS)"|cut -f1) && \
	IN_SECTORS=$$(($$IN_BYTES * 512)) && \
	echo $$IN_SECTORS > $(call archdir,$*)/filesystem.size

rootfs_deduplicate $(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated: $(PRIMARY_ARCH_DIR)$(CHECKSUMS) $(SECONDARY_ARCH_DIR)$(CHECKSUMS)
	mkdir -p "$(COMMON_DIR)$(STATE_DIR)"
	mkdir -p "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)" "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)" "$(COMMON_DIR)/lip-common"
	diff --old-line-format="" --new-line-format="" --unchanged-line-format="%L" \
	"$(PRIMARY_ARCH_DIR)$(CHECKSUMS)" "$(SECONDARY_ARCH_DIR)$(CHECKSUMS)" > "$(COMMON_DIR)$(CHECKSUMS)" || true
	cut -d" " -f3- "$(COMMON_DIR)$(CHECKSUMS)" > "$(COMMON_DIR)/common_files.list"
	@echo "Copying common files..."
	$(RSYNC) --files-from="$(COMMON_DIR)/common_files.list" "$(PRIMARY_ARCH_DIR)$(ROOTFS)/" "$(COMMON_DIR)/lip-common"
	@echo "Copying $(PRIMARY_ARCH) files..."
	$(RSYNC) "$(PRIMARY_ARCH_DIR)$(ROOTFS)/" "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)"
	cd "$(COMMON_DIR)/lip-$(PRIMARY_ARCH)" && tr \\n \\0 < "$(COMMON_DIR)/common_files.list" | xargs -0 rm 
	@echo "Copying $(SECONDARY_ARCH) files..."
	$(RSYNC) "$(SECONDARY_ARCH_DIR)$(ROOTFS)/" "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)"
	cd "$(COMMON_DIR)/lip-$(SECONDARY_ARCH)" && tr \\n \\0 < "$(COMMON_DIR)/common_files.list" | xargs -0 rm 
	touch "$(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated"

$(COMMON_DIR)/lip-%.squashfs : $(COMMON_DIR)$(STATE_DIR)/rootfs_deduplicated
	mksquashfs "$(COMMON_DIR)/lip-$*" "$(COMMON_DIR)/lip-$*.squashfs" -comp xz -noappend

rootfs_squash: $(COMMON_DIR)/lip-$(PRIMARY_ARCH).squashfs $(COMMON_DIR)/lip-$(SECONDARY_ARCH).squashfs $(COMMON_DIR)/lip-common.squashfs

rootfs_common_clean:
	$(RM) -r "$(COMMON_DIR)"

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
$(call gentargets,$(STATE_DIR)/initrd_remastered) : $(call archdir,%)$(STATE_DIR)/initrd_extracted $(call archdir,%)$(STATE_DIR)/rootfs_finalized
	$(CURDIR)/scripts/remaster_initrd.sh "$(CURDIR)" "$(call archdir,$*)$(INITRD)" "$(call archdir,$*)$(ROOTFS)"
	touch "$(call archdir,$*)$(STATE_DIR)/initrd_remastered"

initrd_pack : $(ARCH_DIR)$(INITRD_TARGET)
$(call gentargets,$(INITRD_TARGET)) : $(call archdir,%)$(STATE_DIR)/initrd_remastered
	cd "$(call archdir,$*)$(INITRD)" && find | cpio -H newc -o | lzma -z > "$(call archdir,$*)$(INITRD_TARGET)"

image_git $(IMAGE_DIR)/.git: |$(WORKSPACE)
	test ! -e "$(IMAGE_DIR)/.git"
	mkdir -p "$(IMAGE_DIR)"
	cd "$(IMAGE_DIR)" && git init
	cd "$(IMAGE_DIR)" && git remote add origin "$(IMAGE_GIT_URL)"
	cd "$(IMAGE_DIR)" && git fetch
	cd "$(IMAGE_DIR)" && git checkout -t "origin/$(IMAGE_GIT_BRANCH)"

image_git_pull: |$(IMAGE_DIR)/.git
	cd "$(IMAGE_DIR)" && $(SHELL) ./scripts/update_stick.sh "$(IMAGE_GIT_BRANCH)"

IMAGE_BINARIES= $(COMMON_DIR)/lip-$(PRIMARY_ARCH).squashfs $(COMMON_DIR)/lip-$(SECONDARY_ARCH).squashfs $(COMMON_DIR)/lip-common.squashfs \
$(PRIMARY_ARCH_DIR)$(INITRD_TARGET) $(SECONDARY_ARCH_DIR)$(INITRD_TARGET) \
$(PRIMARY_ARCH_DIR)$(STATE_DIR)/iso_extracted $(SECONDARY_ARCH_DIR)$(STATE_DIR)/iso_extracted \
$(PRIMARY_ARCH_DIR)/filesystem.size
image_binary_files $(IMAGE_DIR)/.lipbinaries: image_git_pull $(IMAGE_BINARIES)
	$(RSYNC) "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/dists" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/isolinux" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/pool" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/preseed" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/.disk" \
		 "$(IMAGE_DIR)/"
	$(RSYNC) "$(SECONDARY_ARCH_DIR)$(ISO_CONTENT)/.disk/casper-uuid-generic" "$(IMAGE_DIR)/.disk/casper-uuid-generic-$(SECONDARY_ARCH)"
	$(RSYNC) "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/EFI/BOOT/BOOTx64.EFI" "$(IMAGE_DIR)/efi/boot/"
	mkdir -p "$(IMAGE_DIR)/casper"
	$(RSYNC) --progress "$(COMMON_DIR)/lip-common.squashfs" \
		 "$(COMMON_DIR)/lip-$(PRIMARY_ARCH).squashfs" \
		 "$(COMMON_DIR)/lip-$(SECONDARY_ARCH).squashfs" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/casper/filesystem.manifest" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/casper/filesystem.manifest-remove" \
		 "$(PRIMARY_ARCH_DIR)/filesystem.size" \
		 "$(IMAGE_DIR)/casper/"
	$(RSYNC) "$(PRIMARY_ARCH_DIR)$(INITRD_TARGET)" "$(IMAGE_DIR)/casper/initrd-$(PRIMARY_ARCH).lz"
	$(RSYNC) "$(SECONDARY_ARCH_DIR)$(INITRD_TARGET)" "$(IMAGE_DIR)/casper/initrd-$(SECONDARY_ARCH).lz"
	cd "$(PRIMARY_ARCH_DIR)$(ROOTFS)" && $(RSYNC) -L vmlinuz "$(IMAGE_DIR)/casper/vmlinuz-$(PRIMARY_ARCH)"
	cd "$(SECONDARY_ARCH_DIR)$(ROOTFS)" && $(RSYNC) -L vmlinuz "$(IMAGE_DIR)/casper/vmlinuz-$(SECONDARY_ARCH)"
	touch "$(IMAGE_DIR)/.lipbinaries"

image_remaster $(IMAGE_DIR)/.remastered: $(IMAGE_DIR)/.lipbinaries
	$(CURDIR)/scripts/remaster_iso.sh "$(CURDIR)" "$(IMAGE_DIR)"
	touch "$(IMAGE_DIR)/.remastered"

image_content: image_git_pull $(IMAGE_DIR)/.remastered
	@echo
	@echo "Image content is ready: $(IMAGE_DIR)"

image_skel_file: | $(WORKSPACE)
	xz -d --keep --stdout "$(CURDIR)/contrib/image/multiboot.skel.img.xz" > "$(if $(IMAGE_FILE),$(IMAGE_FILE),$(WORKSPACE)/image.img)"
	@echo
	@echo "Image skeleton is ready: $(if $(IMAGE_FILE),$(IMAGE_FILE),$(WORKSPACE)/image.img)"
	@echo "You may want to mount appropriately (e.g. with kpartx) and execute \"make IMAGE_DIR=/your/mountpoint image\""

image : image_content

config $(CONFIG_FILE):
	@echo "Generating configuration $(CONFIG_FILE)"
	echo "#see $(CONFIG_FILE_DEFAULTS) for default values." > "$(CONFIG_FILE)"
	echo -e -n "$(foreach option,$(CONFIGURABLE),$(option)=$($(option))\n)" | tr -d "[:blank:]" >> "$(CONFIG_FILE)"

config_clean:
	$(RM) $(CONFIG_FILE)

help:
	@echo "Defaul Architecture: $(ARCH) ($(call altarch,$(ARCH)))"
	@echo "Workspace: $(WORKSPACE)"
	@echo "You may specify the Architecture by setting ARCH="
	@echo
	@echo "=== How to run lipck ==="
	@echo "0. Run make config as user e.g. \"\$$ make WORKSPACE=/media/drivewithspace config\"."
	@echo "1. Optional: Run \"make image_skel_file\" to obtain an empty image file."
	@echo "   You may specify the target file with IMAGE_FILE="
	@echo "2. Run make image as root \"# make image\"."
	@echo "   If you have mounted an image/partition (e.g. an empty image created in 1.) set IMAGE_DIR to the mount point,"
	@echo "   (e.g. \"# make IMAGE_DIR=/your/mountpoint image\") to update it."
	@echo
	@echo "There is a list of all available phony targets is available under \"make listall\""

listall:
	@echo "Available targets: "
	@echo -e "$(foreach t,$(COMMON_PHONY) $(ISO_PHONY) $(ROOTFS_PHONY) $(INITRD_PHONY) $(APT_CACHE_PHONY) $(IMAGE_PHONY),\n-$t)"

ISO_PHONY=iso_download iso_content iso_clean
ROOTFS_PHONY=rootfs_unsquash rootfs_prepare rootfs_remaster rootfs_finalize rootfs_checksums rootfs_deduplicate rootfs_squash rootfs_clean rootfs_common_clean
INITRD_PHONY=initrd_unpack initrd_remaster initrd_pack initrd_clean
APT_CACHE_PHONY=apt_cache apt_cache_clean
IMAGE_PHONY=image image_content image_skel_file image_remaster image_git image_git_pull image_binary_files
COMMON_PHONY=help workspace config config_clean

.PHONY : default $(COMMON_PHONY) $(ISO_PHONY) $(ROOTFS_PHONY) $(INITRD_PHONY) $(APT_CACHE_PHONY) $(IMAGE_PHONY)
