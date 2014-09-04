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

$(info Architecture: $(ARCH) ($(ALTARCH)))
$(info Workspace: $(WORKSPACE))

workspace : $(WORKSPACE)

$(WORKSPACE) :
	mkdir -p $(WORKSPACE)

iso_download $(ISO_IMAGE) : $(WORKSPACE)
	mkdir -p "$(ISO_IMAGE_DEST)"
	wget -O "$(ISO_IMAGE_DEST)/$(ISO_NAME)" -c "$(ISO_URL)/$(ISO_NAME)"
	wget -O "$(ISO_IMAGE_DEST)/SHA256SUMS.temp" -c "$(ISO_URL)/SHA256SUMS"
	grep "$(ISO_NAME)" "$(ISO_IMAGE_DEST)/SHA256SUMS.temp" > "$(ISO_IMAGE_DEST)/SHA256SUMS"
	$(RM) "$(ISO_IMAGE_DEST)/SHA256SUMS.temp"
	cd "$(ISO_IMAGE_DEST)" && sha256sum -c SHA256SUMS
	mv "$(ISO_IMAGE_DEST)/$(ISO_NAME)" "$(ISO_IMAGE)"

iso_files : $(ISO_IMAGE)
	mkdir -p "$(ISO_IMAGE_DEST)/content"
	7z -x -o"$(ISO_IMAGE_DEST)/content" "$(ISO_IMAGE)"

iso_clean :
	$(RM) "$(ISO_IMAGE)"
	$(RM) -r "$(ISO_IMAGE_DEST)"

config $(CONFIG_FILE) :
	$(info Generating configuration $(CONFIG_FILE))
	echo -n "" > $(CONFIG_FILE)
	echo "PRIMARY_ARCH=\"$(PRIMARY_ARCH)\"" >> "$(CONFIG_FILE)"
	echo "SECONDARY_ARCH=\"$(SECONDARY_ARCH)\"" >> "$(CONFIG_FILE)"
	echo "WORKSPACE=\"$(WORKSPACE)\"" >> "$(CONFIG_FILE)"

config_clean :
	$(RM) $(CONFIG_FILE)

.PHONY : config config_clean iso_clean
