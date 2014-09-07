#!/bin/bash

SCRIPT_DIR="/remaster"
CONTRIB_DIR="$SCRIPT_DIR/contrib/"

#TODO: Disable initctl

#source common functions (e.g. patch_all)
if [ -e "$SCRIPT_DIR/scripts/common_functions.sh" ]; then
	source "$SCRIPT_DIR/scripts/common_functions.sh"
fi

function prepare_install()
{
	if [ -e "$CONTRIB_DIR/lip_sources.list" ]; then
		cp -v "$CONTRIB_DIR/lip_sources.list" "/etc/apt/sources.list"
	fi
	
	#uncomment if newest texlive is not part of your distribution
	#add-apt-repository -y ppa:texlive-backports/ppa

	apt-get update
}

function install_packages_from_file()
{
	FILENAME="$1"
	APT_OPTIONS=$2
	
	if [ ! -e "$FILENAME" ]; then
		echo "Error: package file $FILENAME does not exist!"
		exit 3
	fi

	PKGS=$(grep -v "^#" "$FILENAME" | tr '\n' ' ')

	aptitude install -y $APT_OPTIONS $PKGS
}

function install_packages()
{
	apt-get upgrade --assume-yes --force-yes
	apt-get install aptitude -y

	#aptitude full-upgrade -y # make sure we have the newest versions
	# Some daily images do not have a kernel ?!?
	
	#uncomment this if you remaster a daily build (fix kernel version!)
	#aptitude reinstall linux-image-generic-lts-raring -y
	#apt-cache depends linux-image-generic-lts-raring | tail -n+2 | awk '{print $NF}' | xargs aptitude reinstall -y 

	install_packages_from_file "$CONTRIB_DIR/pre_installed_packages" ""
	install_packages_from_file "$CONTRIB_DIR/pre_installed_packages.without-recommends" "--without-recommends"
	
	MISSING_LANG_PKG="$(check-language-support -l de_DE)"
	MISSING_LANG_PKG="$(check-language-support -l en_US) $MISSING_LANG_PKG" # check for missing packages for de_DE and en_US
	
	if [ -n "$MISSING_LANG_PKG" ]; then
		aptitude install $MISSING_LANG_PKG -y
	fi
	
	EXTRA_LANG_PKG="$(dpkg-query --show | cut -f1 | grep -E '^(language-pack|language-support|firefox-locale|thunderbird-locale|libreoffice-help|libreoffice-l10n)' | grep -Ev "[-](de|en)\>")" # remove extra language packages

	if [ -n "$EXTRA_LANG_PKG" ]; then
		aptitude purge $EXTRA_LANG_PKG -y
	fi
	
	install_debs "$CONTRIB_DIR/debs/"
}

function finalize()
{
	echo -n "Europe/Berlin" > /etc/timezone
	
	rm -rf /var/crash/*
	#TODO: verify
	rm -rf /var/cache/apt/*
}

function install_kde_defaults()
{
	mkdir -p /etc/skel/.kde/share/config/
	cp "$CONTRIB_DIR/kde_config/"* /etc/skel/.kde/share/config/
}

prepare_install
install_packages

install_kde_defaults

#patch rootfs
patch_all "$SCRIPT_DIR/patches/" "/"

#i.e. required for applying default-wallpaper patch
#echo "compiling glib2 schemas..."
#glib-compile-schemas /usr/share/glib-2.0/schemas

finalize
