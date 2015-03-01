#!/bin/bash

#This file is part of lipck - the "linux install party customization kit" - and
#contains parts of UCK - the Ubuntu Customization Kit.
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

set -e

SCRIPT_DIR="/remaster"
CONTRIB_DIR="$SCRIPT_DIR/contrib/"

#source common functions (e.g. patch_all)
if [ -e "$SCRIPT_DIR/scripts/common_functions.sh" ]; then
	source "$SCRIPT_DIR/scripts/common_functions.sh"
fi

if [ -e "$SCRIPT_DIR/scripts/uck_functions.sh" ]; then
        source "$SCRIPT_DIR/scripts/uck_functions.sh"
else
	echo "Error: $SCRIPT_DIR/scripts/uck_functions.sh is missing."
	exit 1
fi

if [ ! -d "$SCRIPT_DIR" ]; then
	echo "Error: Missing remaster directory/files. Abort."
	exit 2
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
	APT_OPTIONS=$2
	PKGS=$(get_packages_from_file "$1")

	apt-get -y $APT_OPTIONS install $PKGS
}

function install_packages()
{
	apt-get dist-upgrade --assume-yes --force-yes
	apt-get -y autoremove
	#apt-get install aptitude -y

	#apt-get dist-upgrade -y # make sure we have the newest versions
	
	#Some daily images do not have a kernel;
	#ensure that a valid kernel is installed

	#make sure we have a initrd (otherwise the kernel update may fail
	if [ ! -e "$(readlink -f /initrd.img)" ]; then
		echo "LIPCK: No initrd in place; generating new one."
		update-initramfs -v -c -k all
	fi

	#Note: this does only work if we have a recent install iso since older kernels are removed from
	# the repositories
	KERNEL_PKG=$(dpkg -S "$(readlink -f /vmlinuz)" | cut -d ":" -f1)
	if [ -z "$KERNEL_PKG" ]; then
		echo "LIPCK: remaster_rootfs: unable to determine installed kernel version; giving up..."
	fi
	#[ "$(uname -m)" == "x86_64" ] || KERNEL_PKG=linux-image-generic-lts-trusty
	if [ ! -e "$(readlink -f /initrd.img)" ]; then
                echo "LIPCK: No kernel in place; try to reinstall kernel image package:"
		echo "       $KERNEL_PKG"
		apt-get --reinstall -y install $KERNEL_PKG
		#apt-cache depends $KERNEL_PKG | tail -n+2 | awk '{print $NF}' | xargs apt-get --reinstall -y install
	fi

	install_packages_from_file "$CONTRIB_DIR/pre_installed_packages" ""
	install_packages_from_file "$CONTRIB_DIR/pre_installed_packages.without-recommends" "--no-install-recommends"
	
	install_lang_packages

	install_debs "$CONTRIB_DIR/debs/"
}

function finalize()
{
	echo -n "Europe/Berlin" > /etc/timezone
	
	rm -rf /var/crash/*

	if [ -z "$LIPCK_HAS_APT_CACHE" ]
	then
	  rm -rf /var/cache/apt/*
	fi
}

function install_kde_defaults()
{
	mkdir -p /etc/skel/.kde/share/config/
	cp "$CONTRIB_DIR/kde_config/"* /etc/skel/.kde/share/config/
}

function copy_modprobe_d()
{
	cp -r "$SCRIPT_DIR/contrib/modprobe.d/" "/etc/modprobe.d/"
	update-initramfs -u
}

function hold_packages()
{
	for PKG in $@; do
		echo "$(echo "$PKG" | tr -d "[:blank:]") hold" | dpkg --set-selections
	done
}

function unhold_packages()
{
	for PKG in $@; do
		echo "$(echo "$PKG" | tr -d "[:blank:]") install" | dpkg --set-selections
	done
}

divert_initctl

PKGS_TO_HOLD=$(get_packages_from_file "$CONTRIB_DIR/hold_packages")

hold_packages $PKGS_TO_HOLD

prepare_install
copy_modprobe_d
install_packages

install_kde_defaults

#i.e. required for applying default-wallpaper patch
#echo "compiling glib2 schemas..."
#glib-compile-schemas /usr/share/glib-2.0/schemas

unhold_packages $PKGS_TO_HOLD

revert_initctl
finalize
