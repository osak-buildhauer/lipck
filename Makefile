#This file is part of lipck - the "linux install party customization kit".
#
# Copyright (C) 2014 trilader, Anwarias, Christopher Spinrath
#
# lipck is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# lipck is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with lipck.  If not, see <http://www.gnu.org/licenses/>.

$(info lipck Copyright (C) 2014 trilader, Anwarias, Christopher Spinrath)
$(info This program comes with ABSOLUTELY NO WARRANTY;)
$(info This is free software, and you are welcome to redistribute it)
$(info under certain conditions; cf. the COPYING file for details.)
$(info )

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

#inverse function of altarch; required by targets containing
#the altarch string to depend on architecture specific stuff
#Since all unknown names are mapped to itself this function
#may be used to convert any name to the normal architecture name.
define to_arch =
$(if $(subst amd64,,$1),$(if $(subst i386,,$1),$1,i686),x86_64)
endef

RSYNC=rsync -a
LZMA_FLAGS=-T 0

define archdir =
$(WORKSPACE)/$(call to_arch,$1)
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
ISO_URL=$(ISO_BASE_URL)/$(ISO_RELEASE)/$(ISO_CHANNEL)
ISO_CONTENT=$(ISO_IMAGE_DEST)/content

IMAGE_PART_FILE=$(WORKSPACE)/image.img.part
GRUB_ASSEMBLE_DIR=$(WORKSPACE)/grub
#GRUB_INSTALL_DIR is passed to grub mbr, so it has to be relative!
#Moreover, it has to be kept in sync with /contrib/image/grub_early.cfg
#and should not conflict with the secure boot grub shipped with the iso
#(usually /boot/grub)
GRUB_INSTALL_DIR=/grub

ifneq (,$(findstring release-prefix,$(ISO_PATTERN_FLAGS)))
  ISO_PREFIX=$(ISO_RELEASE)-
else
  ISO_PREFIX=$(ISO_FLAVOR)-$(ISO_VERSION)-
endif

define getisoname =
$(ISO_PREFIX)desktop-$(call altarch,$1).iso
endef

GPARTED_BASE_URL=http://sourceforge.net/projects/gparted/files/gparted-live-stable/$(GPARTED_VERSION)/

#applies all patches in $1 to target directory $2
define patch_all =
$(foreach p,$(wildcard $1/*),@echo "Applying \"$1\" to \"$2\":" && \
	cat "$p" | patch -d"$2" -p1 && echo "done." && ) true
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

REPO_ARCHIVE_DIR=$(IMAGE_DIR)/archives
REPO_DIST_DIR=$(REPO_ARCHIVE_DIR)/dists/$(ISO_RELEASE)/lip

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

iso_clean_both:
	$(MAKE) ARCH=$(PRIMARY_ARCH) iso_clean
	$(MAKE) ARCH=$(SECONDARY_ARCH) iso_clean

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
	echo "#!/bin/bash" > "$(call archdir,$*)$(ROOTFS)/remaster/remaster.proxy.sh"
	echo "export PATH; export TERM=$(TERM); export LIPCK_HAS_APT_CACHE=1" >> "$(call archdir,$*)$(ROOTFS)/remaster/remaster.proxy.sh"
	echo "test -n \"\$$1\" || exit 41" >> "$(call archdir,$*)$(ROOTFS)/remaster/remaster.proxy.sh"
	echo "exec \$$@" >> "$(call archdir,$*)$(ROOTFS)/remaster/remaster.proxy.sh"
	chmod +x "$(call archdir,$*)$(ROOTFS)/remaster/remaster.proxy.sh"
	touch "$(call archdir,$*)$(STATE_DIR)/rootfs_prepared"

rootfs_remaster : $(ARCH_DIR)$(STATE_DIR)/rootfs_remastered
$(call gentargets,$(STATE_DIR)/rootfs_remastered) : $(call archdir,%)$(STATE_DIR)/rootfs_extracted | $(APT_CACHE_DIR)
	$(MAKE) ARCH=$* rootfs_prepare
ifneq ($(strip $(APT_SOURCE_URL_OVERRIDE)),)
	#override apt sources list
	echo "deb $(APT_SOURCE_URL_OVERRIDE) $(ISO_RELEASE) main restricted universe multiverse" \
		> "$(call archdir,$*)$(ROOTFS)/etc/apt/sources.list"
	echo "deb $(APT_SOURCE_URL_OVERRIDE) $(ISO_RELEASE)-security main restricted universe multiverse" \
		>> "$(call archdir,$*)$(ROOTFS)/etc/apt/sources.list"
	echo "deb $(APT_SOURCE_URL_OVERRIDE) $(ISO_RELEASE)-updates main restricted universe multiverse" \
		>> "$(call archdir,$*)$(ROOTFS)/etc/apt/sources.list"
endif
	mkdir -p "$(call archdir,$*)$(LXC_DIR)"
	lxc-execute --name "lipck_remaster_$*" -P "$(call archdir,$*)$(LXC_DIR)" -f "$(CURDIR)/config/lxc_common.conf" \
	-s lxc.arch="$*" -s lxc.rootfs="$(call archdir,$*)$(ROOTFS)" \
	-s lxc.mount.entry="$(APT_CACHE_DIR) $(call archdir,$*)$(ROOTFS)/var/cache/apt/ none defaults,bind 0 0" \
	-s lxc.mount.entry="none $(call archdir,$*)$(ROOTFS)/tmp tmpfs defaults 0 0" \
	-s lxc.mount.entry="none $(call archdir,$*)$(ROOTFS)/run tmpfs defaults 0 0" \
	-- /bin/bash -l /remaster/remaster.proxy.sh /remaster/scripts/rootfs_remaster.sh
	$(MAKE) ARCH=$* rootfs_finalize

	#apply patches
	$(call patch_all,$(CURDIR)/patches/rootfs,$(call archdir,$*)$(ROOTFS))
	touch "$(call archdir,$*)$(STATE_DIR)/rootfs_remastered"

rootfs_console : $(call archdir,$(ARCH))$(STATE_DIR)/rootfs_extracted | $(APT_CACHE_DIR)
	$(MAKE) ARCH=$(ARCH) rootfs_prepare
	mkdir -p "$(call archdir,$(ARCH))$(LXC_DIR)"
	@echo
	@echo "==> LIPCK: Entering container... (exit with CTRL+D but _NOT_ with  CTRL+C!)"
	lxc-execute --name "lipck_remaster_$(ARCH)" -P "$(call archdir,$(ARCH))$(LXC_DIR)" -f "$(CURDIR)/config/lxc_common.conf" \
        -s lxc.arch="$(ARCH)" -s lxc.rootfs="$(call archdir,$(ARCH))$(ROOTFS)" \
        -s lxc.mount.entry="$(APT_CACHE_DIR) $(call archdir,$(ARCH))$(ROOTFS)/var/cache/apt/ none defaults,bind 0 0" \
        -s lxc.mount.entry="none $(call archdir,$(ARCH))$(ROOTFS)/tmp tmpfs defaults 0 0" \
        -s lxc.mount.entry="none $(call archdir,$(ARCH))$(ROOTFS)/run tmpfs defaults 0 0" \
        -- /bin/bash -l /remaster/remaster.proxy.sh /bin/bash -l || exit 0
	@echo
	@echo "==> LIPCK: Leaving container and cleaning up..."
	@echo
	$(MAKE) ARCH=$(ARCH) rootfs_finalize

rootfs_finalize : $(ARCH_DIR)$(STATE_DIR)/rootfs_finalized
$(call gentargets,$(STATE_DIR)/rootfs_finalized) : $(call archdir,%)$(STATE_DIR)/rootfs_prepared
	$(RM) "$(call archdir,$*)$(ROOTFS)/usr/sbin/init.lxc"
	$(RM) "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf"
	if [ -e "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf.bak" ]; then mv "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf.bak" "$(call archdir,$*)$(ROOTFS)/etc/resolv.conf"; fi
	$(RM) -r "$(call archdir,$*)$(ROOTFS)/remaster"
	$(RM) "$(call archdir,$*)$(STATE_DIR)/rootfs_prepared"
	touch "$(call archdir,$*)$(STATE_DIR)/rootfs_finalized"

rootfs_clean:
	$(RM) -r "$(ARCH_DIR)$(ROOTFS)"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_extracted"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_prepared"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_remastered"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/rootfs_finalized"
	$(RM) "$(ARCH_DIR)/filesystem.size"
	$(RM) "$(ARCH_DIR)/$(CHECKSUMS)"
	$(RM) -r $(ARCH_DIR)$(LXC_DIR)

rootfs_clean_both:
	$(MAKE) ARCH=$(PRIMARY_ARCH) rootfs_clean
	$(MAKE) ARCH=$(SECONDARY_ARCH) rootfs_clean

rootfs_checksums : $(ARCH_DIR)$(CHECKSUMS)
$(call gentargets,$(CHECKSUMS)) : $(call archdir,%)$(STATE_DIR)/rootfs_remastered
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
	cd "$(call archdir,$*)$(INITRD)" && lzma $(LZMA_FLAGS) -d < "$(call archdir,$*)$(INITRD_SOURCE)" | cpio -i
	touch "$(call archdir,$*)$(STATE_DIR)/initrd_extracted"

initrd_clean:
	$(RM) -r "$(ARCH_DIR)$(INITRD)"
	$(RM) "$(ARCH_DIR)$(INITRD_TARGET)"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/initrd_extracted"
	$(RM) "$(ARCH_DIR)$(STATE_DIR)/initrd_remastered"

initrd_clean_both:
	$(MAKE) ARCH=$(PRIMARY_ARCH) initrd_clean
	$(MAKE) ARCH=$(SECONDARY_ARCH) initrd_clean

initrd_remaster : $(ARCH_DIR)$(STATE_DIR)/initrd_remastered
$(call gentargets,$(STATE_DIR)/initrd_remastered) : $(call archdir,%)$(STATE_DIR)/initrd_extracted $(call archdir,%)$(STATE_DIR)/rootfs_remastered
	mkdir -p "$(call archdir,$*)$(INITRD)/lip"

	#nmtelekinese
	mkdir -p "$(call archdir,$*)$(INITRD)/lip/nm"
	cp "$(CURDIR)/contrib/initrd/nmtelekinese/nmtelekinese.desktop" "$(call archdir,$*)$(INITRD)/lip/nm"
	cp "$(CURDIR)/contrib/initrd/nmtelekinese/nmtelekinese.py" "$(call archdir,$*)$(INITRD)/lip/nm"
	cp "$(CURDIR)/contrib/initrd/nmtelekinese/26mopsmops" "$(call archdir,$*)$(INITRD)/scripts/casper-bottom/"
	chmod +x "$(call archdir,$*)$(INITRD)/scripts/casper-bottom/26mopsmops"

	#liphook
	cp "$(CURDIR)/contrib/initrd/initrd_hook/24liphook" "$(call archdir,$*)$(INITRD)/scripts/casper-bottom/"
	chmod +x "$(call archdir,$*)$(INITRD)/scripts/casper-bottom/24liphook"

	$(RM) "$(call archdir,$*)$(INITRD)/scripts/casper-bottom/ORDER"
	find "$(call archdir,$*)$(INITRD)/scripts/casper-bottom/" -type f \
		| xargs basename -a | grep -E "^[0-9]{2}" | sort | xargs -I{} \
		echo -e "/scripts/casper-bottom/{}\n[ -e /conf/param.conf ] && . /conf/param.conf" \
		>> "$(call archdir,$*)$(INITRD)/scripts/casper-bottom/ORDER"

	#install new kernel modules
	$(RM) -R "$(call archdir,$*)$(INITRD)/lib/modules/"*
	cp -a "$(call archdir,$*)$(ROOTFS)/lib/modules/$(shell basename $$(readlink -f "$(call archdir,$*)$(ROOTFS)/vmlinuz") | cut -d'-' -f2-)" \
		 "$(call archdir,$*)$(INITRD)/lib/modules"

	$(call patch_all,$(CURDIR)/patches/initrd,$(call archdir,$*)$(INITRD))
	touch "$(call archdir,$*)$(STATE_DIR)/initrd_remastered"

initrd_pack : $(ARCH_DIR)$(INITRD_TARGET)
$(call gentargets,$(INITRD_TARGET)) : $(call archdir,%)$(STATE_DIR)/initrd_remastered
	cd "$(call archdir,$*)$(INITRD)" && find | cpio -H newc -o | lzma $(LZMA_FLAGS) -z > "$(call archdir,$*)$(INITRD_TARGET)"

clean_really_all: iso_clean_both rootfs_clean_both rootfs_common_clean initrd_clean_both image_clean

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
$(PRIMARY_ARCH_DIR)/filesystem.size \
$(PRIMARY_ARCH_DIR)/gparted-live.iso $(SECONDARY_ARCH_DIR)/gparted-live.iso
image_binary_files $(IMAGE_DIR)/.lipbinaries: image_git_pull $(IMAGE_BINARIES)
	$(RSYNC) "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/dists" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/isolinux" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/pool" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/preseed" \
		 "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/.disk" \
		 "$(IMAGE_DIR)/"
	$(RSYNC) "$(SECONDARY_ARCH_DIR)$(ISO_CONTENT)/.disk/casper-uuid-generic" "$(IMAGE_DIR)/.disk/casper-uuid-generic-$(SECONDARY_ARCH)"
	$(RSYNC) "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/EFI/BOOT/BOOTx64.EFI" "$(IMAGE_DIR)/efi/boot/"
	$(RSYNC) "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/EFI/BOOT/grubx64.efi" "$(IMAGE_DIR)/efi/boot/"
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
	$(RSYNC) --progress "$(PRIMARY_ARCH_DIR)/gparted-live.iso" "$(IMAGE_DIR)/gparted-live-$(PRIMARY_ARCH).iso"
	$(RSYNC) --progress "$(SECONDARY_ARCH_DIR)/gparted-live.iso" "$(IMAGE_DIR)/gparted-live-$(SECONDARY_ARCH).iso"
	cd "$(PRIMARY_ARCH_DIR)$(ROOTFS)" && $(RSYNC) -L vmlinuz "$(IMAGE_DIR)/casper/vmlinuz-$(PRIMARY_ARCH)"
	cd "$(SECONDARY_ARCH_DIR)$(ROOTFS)" && $(RSYNC) -L vmlinuz "$(IMAGE_DIR)/casper/vmlinuz-$(SECONDARY_ARCH)"
	mkdir -p "$(IMAGE_DIR)/boot/grub/" #note: this must not be $$(GRUB_INSTALL_DIR)!
	$(RSYNC) "$(PRIMARY_ARCH_DIR)$(ISO_CONTENT)/boot/grub/x86_64-efi" \
		 "$(IMAGE_DIR)/boot/grub/"
	touch "$(IMAGE_DIR)/.lipbinaries"

image_remaster $(IMAGE_DIR)/.remastered: $(IMAGE_DIR)/.lipbinaries
	$(call patch_all,$(CURDIR)/patches/iso/,$(IMAGE_DIR))
	touch "$(IMAGE_DIR)/.remastered"

image_content: image_git_pull $(IMAGE_DIR)/.remastered $(IMAGE_DIR)$(GRUB_INSTALL_DIR)/lipinfo.cfg
	@echo
	@echo "Image content is ready: $(IMAGE_DIR)"

image_skel_file: $(IMAGE_PART_FILE)
$(IMAGE_PART_FILE):
	truncate -s "$(IMAGE_PART_SIZE)" "$@"
	mkfs.vfat -n "$(IMAGE_PART_LABEL)" "$@"

	@echo
	@echo "Image partition skeleton is ready: $@"

image_grub_mkimage_efi: $(GRUB_ASSEMBLE_DIR)/grub.x86_64-efi
$(GRUB_ASSEMBLE_DIR)/grub.x86_64-efi $(GRUB_ASSEMBLE_DIR)/grub.i386-efi : $(GRUB_ASSEMBLE_DIR)/grub.%-efi : | $(WORKSPACE)
	mkdir -p "$(GRUB_ASSEMBLE_DIR)"
	grub-mkimage --config "$(CURDIR)/contrib/image/grub_early.cfg" \
		--output "$@" --format "$*-efi" \
		$(IMAGE_GRUB_EFI_MODULES)

image_grub_mkimage_mbr: $(GRUB_ASSEMBLE_DIR)/grub.i386-pc
$(GRUB_ASSEMBLE_DIR)/grub.i386-pc : | $(WORKSPACE)
	mkdir -p "$(GRUB_ASSEMBLE_DIR)"
	grub-mkimage --prefix "(hd0,msdos1)$(GRUB_INSTALL_DIR)" \
                --output "$@" --format "i386-pc" \
                $(IMAGE_GRUB_MBR_MODULES)

image_grub_mbr_template: $(GRUB_ASSEMBLE_DIR)/mbr.img
$(GRUB_ASSEMBLE_DIR)/mbr.img : $(GRUB_ASSEMBLE_DIR)/grub.i386-pc
	dd if=/usr/lib/grub/i386-pc/boot.img of="$@" bs=446 count=1
	dd if="$(GRUB_ASSEMBLE_DIR)/grub.i386-pc" of="$@" bs=512 seek=1

#TODO: which file to track here?
image_grub_install: $(GRUB_ASSEMBLE_DIR)/grub.x86_64-efi $(GRUB_ASSEMBLE_DIR)/grub.i386-efi
	mkdir -p "$(IMAGE_DIR)$(GRUB_INSTALL_DIR)"
	$(RSYNC) "/usr/lib/grub/x86_64-efi" "$(IMAGE_DIR)$(GRUB_INSTALL_DIR)/"
	$(RSYNC) "/usr/lib/grub/i386-efi" "$(IMAGE_DIR)$(GRUB_INSTALL_DIR)/"
	$(RSYNC) "/usr/lib/grub/i386-pc" "$(IMAGE_DIR)$(GRUB_INSTALL_DIR)/"
	$(RSYNC) "/usr/share/grub/themes" "$(IMAGE_DIR)$(GRUB_INSTALL_DIR)/"
	mkdir -p "$(IMAGE_DIR)$(GRUB_INSTALL_DIR)/fonts"
	$(RSYNC) "/usr/share/grub/unicode.pf2" "$(IMAGE_DIR)$(GRUB_INSTALL_DIR)/fonts/"
	#copy efi core files; note that the x64 binary is named grubx64-unsigned.efi because grubx64.efi
	#is occupied by the ubuntu secure boot grub.
	mkdir -p "$(IMAGE_DIR)/efi/boot"
	$(RSYNC) --no-p --no-g --no-o "$(GRUB_ASSEMBLE_DIR)/grub.x86_64-efi" "$(IMAGE_DIR)/efi/boot/grubx64-unsigned.efi"
	#our i386 efi bootloader shall be the default:
	$(RSYNC) --no-p --no-g --no-o "$(GRUB_ASSEMBLE_DIR)/grub.i386-efi" "$(IMAGE_DIR)/efi/boot/bootia32.efi"

image_assemble: $(IMAGE_FILE)
$(IMAGE_FILE): $(IMAGE_PART_FILE) $(GRUB_ASSEMBLE_DIR)/mbr.img
	cp "$(GRUB_ASSEMBLE_DIR)/mbr.img" "$@"
	ddrescue --output-position=2048s --sparse "$(IMAGE_PART_FILE)" "$@"
	#sfdisk: start, as large as possible, FAT, bootable
	echo -e "label: dos\nunit: sectors\n2048,+,b,*"\
		| sfdisk "$@"

	@echo
	@echo "Image is ready: $@"

image_clean:
	$(RM) "$(IMAGE_PART_FILE)"
	$(RM) -r "$(GRUB_ASSEMBLE_DIR)"

image_grub_lipinfo : $(IMAGE_DIR)$(GRUB_INSTALL_DIR)/lipinfo.cfg
$(IMAGE_DIR)$(GRUB_INSTALL_DIR)/lipinfo.cfg : | $(WORKSPACE)
	mkdir -p "$(IMAGE_DIR)$(GRUB_INSTALL_DIR)"
	echo "#This file was generated by lipck." > "$@"
	echo "#Feel free to edit it." >> "$@"
	echo "set lip_flavor=\"$$(echo "$(ISO_FLAVOR)" | sed "s/\(.\)\(.*\)/\u\1\2/")\"" >> "$@"
	echo "set lip_version=\"$(ISO_VERSION)\"" >> "$@"
	echo "set lip_release=\"$(ISO_RELEASE)\"" >> "$@"
	echo "set lip_extra_info=\"$(IMAGE_EXTRA_INFO)\"" >> "$@"

image_mount_if : $(IMAGE_PART_FILE)
	mkdir -p "$(IMAGE_DIR)"
	[ "$$(findmnt --target "$(IMAGE_DIR)" -f -n --output=target)" = "$(IMAGE_DIR)" ] \
		|| mount "$(IMAGE_PART_FILE)" "$(IMAGE_DIR)"

image_umount :
	umount -d "$(IMAGE_DIR)"

image : image_content $(GRUB_ASSEMBLE_DIR)/mbr.img

#The following target is not used by lipck itself. It may be used to create
#an empty (only the bootloader will be installed) manually. In particular,
#it can be used to test the image creation process of lipck (it is not
#necessary to remaster an image to test this crucial base part).
multiboot :
	$(MAKE) "IMAGE_PART_FILE=$(WORKSPACE)/multiboot.part" image_skel_file
	mkdir -p "$(WORKSPACE)/multiboot.work"
	mount "$(WORKSPACE)/multiboot.part" "$(WORKSPACE)/multiboot.work"
	$(MAKE) "IMAGE_DIR=$(WORKSPACE)/multiboot.work" image_grub_install \
		|| (umount "$(WORKSPACE)/multiboot.work" && exit 1)
	#since this is most likely a standalone image make the lipck grubx64 the
	#default bootloader for 64bit efi systems
	mv "$(WORKSPACE)/multiboot.work/efi/boot/"{grubx64-unsigned.efi,bootx64.efi} \
		|| (umount "$(WORKSPACE)/multiboot.work" && exit 1)
	umount "$(WORKSPACE)/multiboot.work"
	$(MAKE) "IMAGE_PART_FILE=$(WORKSPACE)/multiboot.part" IMAGE_FILE=MultiBoot.img \
		image_assemble

gparted : $(call archdir,$(PRIMARY_ARCH))/gparted-live.iso $(call archdir,$(SECONDARY_ARCH))/gparted-live.iso
$(call gentargets,/gparted-live.iso) :
	wget -O "$@" "$(GPARTED_BASE_URL)/gparted-live-$(GPARTED_VERSION)-$(subst $(SECONDARY_ARCH),i686-pae,$(subst $(PRIMARY_ARCH),amd64,$*)).iso"

repo_packages : $(REPO_ARCHIVE_DIR)/Packages.$(call altarch,$(ARCH))
$(REPO_ARCHIVE_DIR)/Packages.$(call altarch,$(PRIMARY_ARCH)) $(REPO_ARCHIVE_DIR)/Packages.$(call altarch,$(SECONDARY_ARCH)) : $(REPO_ARCHIVE_DIR)/Packages.% : $(call archdir,$*)$(STATE_DIR)/rootfs_remastered | $(IMAGE_DIR)
	$(MAKE) ARCH=$(call to_arch,$*) rootfs_prepare
	mkdir -p "$(call archdir,$*)$(ROOTFS)/cdrom"
	mkdir -p "$(call archdir,$*)$(LXC_DIR)"
	lxc-execute --name "lipck_remaster_$*" -P "$(call archdir,$*)$(LXC_DIR)" -f "$(CURDIR)/config/lxc_common.conf" \
        -s lxc.arch="$(call to_arch,$*)" -s lxc.rootfs="$(call archdir,$*)$(ROOTFS)" \
        -s lxc.mount.entry="none $(call archdir,$*)$(ROOTFS)/var/cache/apt/ tmpfs defaults 0 0" \
        -s lxc.mount.entry="none $(call archdir,$(ARCH))$(ROOTFS)/tmp tmpfs defaults 0 0" \
        -s lxc.mount.entry="none $(call archdir,$(ARCH))$(ROOTFS)/run tmpfs defaults 0 0" \
	-s lxc.mount.entry="$(IMAGE_DIR) $(call archdir,$*)$(ROOTFS)/cdrom none defaults,bind 0 0" \
        -- /bin/bash -l /remaster/remaster.proxy.sh \
	/remaster/scripts/repo_packages.sh "$*" "/cdrom"
	rmdir "$(call archdir,$*)$(ROOTFS)/cdrom"
	$(MAKE) ARCH=$(call to_arch,$*) rootfs_finalize

repo_package_info : $(REPO_DIST_DIR)/binary-$(call altarch,$(ARCH))/Packages.bz2
$(REPO_DIST_DIR)/binary-$(call altarch,$(PRIMARY_ARCH))/Packages.bz2 $(REPO_DIST_DIR)/binary-$(call altarch,$(SECONDARY_ARCH))/Packages.bz2 : $(REPO_DIST_DIR)/binary-%/Packages.bz2 : $(REPO_ARCHIVE_DIR)/Packages.%
	mkdir -p "$(REPO_ARCHIVE_DIR)"
	mkdir -p "$(REPO_DIST_DIR)/binary-$*/"
	#info/release file
	echo "Archive: $(ISO_RELEASE)" > "$(REPO_DIST_DIR)/binary-$*/Release"
	echo "Version: $(shell echo $(ISO_VERSION) | cut -f-2 -d'.')" \
		>> "$(REPO_DIST_DIR)/binary-$*/Release"
	echo "Component: main" \
		>> "$(REPO_DIST_DIR)/binary-$*/Release"
	echo "Origin: Ubuntu" \
		>> "$(REPO_DIST_DIR)/binary-$*/Release"
	echo "Label: Ubuntu" \
		>> "$(REPO_DIST_DIR)/binary-$*/Release"
	echo "Architecture: $*" \
		>> "$(REPO_DIST_DIR)/binary-$*/Release"

	cd "$(REPO_ARCHIVE_DIR)" \
	&& cat Packages.noarch "Packages.$*" | bzip2 -c9 > "$(REPO_DIST_DIR)/binary-$*/Packages.bz2"

#The following rules requires none of its dependencies. However, it writes a timestamp to the metadata
#that should always be "newer" than the dependencies.
repo_metadata : $(REPO_ARCHIVE_DIR)/Release
$(REPO_ARCHIVE_DIR)/Release : $(REPO_DIST_DIR)/binary-$(call altarch,$(PRIMARY_ARCH))/Packages.bz2 $(REPO_DIST_DIR)/binary-$(call altarch,$(SECONDARY_ARCH))/Packages.bz2
	mkdir -p "$(REPO_ARCHIVE_DIR)"

	echo "Origin: Ubuntu" > "$(REPO_ARCHIVE_DIR)"/Release
	echo "Label: LIP Ubuntu Extra Packages" \
		>> "$(REPO_ARCHIVE_DIR)"/Release
	echo "Suite: $(ISO_RELEASE)" \
		>> "$(REPO_ARCHIVE_DIR)"/Release
	echo "Version: $(shell echo $(ISO_VERSION) | cut -f-2 -d'.')" \
		>> "$(REPO_ARCHIVE_DIR)"/Release
	echo "Codename: $(ISO_RELEASE)" \
		>> "$(REPO_ARCHIVE_DIR)"/Release
	echo "Date: $$(LC_ALL=C date -u)" \
		>> "$(REPO_ARCHIVE_DIR)"/Release
	echo "Architectures: $(call altarch,$(PRIMARY_ARCH)) $(call altarch,$(SECONDARY_ARCH))" \
		>> "$(REPO_ARCHIVE_DIR)"/Release
	echo "Components: lip" \
		>> "$(REPO_ARCHIVE_DIR)"/Release
	echo "Description: Ubuntu $(ISO_RELEASE) $(shell echo $(ISO_VERSION) | cut -f-2 -d'.')" \
		>> "$(REPO_ARCHIVE_DIR)"/Release

repo_clean:
	$(RM) -r "$(REPO_DIST_DIR)"
	$(RM) -r "$(REPO_ARCHIVE_DIR)"

repo: repo_packages repo_package_info repo_metadata

config $(CONFIG_FILE):
	@echo "Generating configuration $(CONFIG_FILE)"
	echo "#see $(CONFIG_FILE_DEFAULTS) for default values." > "$(CONFIG_FILE)"
	echo -e -n "$(foreach option,$(CONFIGURABLE),$(option)=$($(option))\n)" | tr -d "[:blank:]" >> "$(CONFIG_FILE)"

config_clean:
	$(RM) $(CONFIG_FILE)

%.vmdk : %.img
	vboxmanage convertfromraw --format vmdk "$<" "$@"

help:
	@echo "Defaul Architecture: $(ARCH) ($(call altarch,$(ARCH)))"
	@echo "Workspace: $(WORKSPACE)"
	@echo "You may specify the Architecture by setting ARCH="
	@echo
	@echo "=== Example run of lipck ==="
	@echo "\$$ make WORKSPACE=/media/drivewithspace config #configure lipck"
	@echo "# make image_mount_if #create and mount a partition"
	@echo "# make image_grub_install #install grub files"
	@echo "# make image #main remaster process (requires several cups of coffee)"
	@echo "# make image_umount #umount the image partition"
	@echo "\$$ #copy mbr+partition to final destination"
	@echo "\$$ make IMAGE_FILE=/somewhere/myfinalimage.img image_assemble"
	@echo "\$$ make /somewhere/myfinalimage.vmdk #(optionally) create a vmdk version"
	@echo
	@echo "There is a list of all phony targets available under \"make listall\""
	@echo "A list of all config options may be found in:"
	@echo "    $(CONFIG_FILE_DEFAULTS)"

listall:
	@echo "Available targets: "
	@echo -e "$(foreach t,$(COMMON_PHONY) $(ISO_PHONY) $(ROOTFS_PHONY) $(INITRD_PHONY) $(APT_CACHE_PHONY) $(IMAGE_PHONY),\n-$t)"

ISO_PHONY=iso_download iso_content iso_clean iso_clean_both
ROOTFS_PHONY=rootfs_unsquash rootfs_prepare rootfs_remaster rootfs_finalize rootfs_checksums rootfs_deduplicate rootfs_squash rootfs_console rootfs_clean rootfs_common_clean rootfs_clean_both
INITRD_PHONY=initrd_unpack initrd_remaster initrd_pack initrd_clean initrd_clean_both
APT_CACHE_PHONY=apt_cache apt_cache_clean
REPO_PHONY=repo repo_packages repo_package_info repo_metadata repo_clean
IMAGE_PHONY=image image_content image_skel_file image_assemble image_remaster image_git image_git_pull image_binary_files image_grub_lipinfo image_grub_mkimage_efi image_grub_mkimage_mbr image_grub_mbr_template image_grub_install image_umount image_mount_if image_clean
COMMON_PHONY=help workspace config multiboot config_clean clean_really_all

.PHONY : default $(COMMON_PHONY) $(ISO_PHONY) $(ROOTFS_PHONY) $(INITRD_PHONY) $(APT_CACHE_PHONY) $(IMAGE_PHONY) $(REPO_PHONY)
