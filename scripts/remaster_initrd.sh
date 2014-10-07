#!/bin/bash

###################################################################################
# UCK - Ubuntu Customization Kit                                                  #
# Copyright (C) 2006-2010 UCK Team                                                #
#                                                                                 #
# UCK is free software: you can redistribute it and/or modify                     #
# it under the terms of the GNU General Public License as published by            #
# the Free Software Foundation, either version 3 of the License, or               #
# (at your option) any later version.                                             #
#                                                                                 #
# UCK is distributed in the hope that it will be useful,                          #
# but WITHOUT ANY WARRANTY; without even the implied warranty of                  #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                   #
# GNU General Public License for more details.                                    #
#                                                                                 #
# You should have received a copy of the GNU General Public License               #
# along with UCK.  If not, see <http://www.gnu.org/licenses/>.                    #
###################################################################################

SCRIPT_DIR="$1"
IRD="$2"
ROOTFS="$3"

if [ ! -d "$SCRIPT_DIR" ]; then
	echo "Expected lipck base path as first argument!"
	exit 1
fi

if [ ! -d "$IRD" ]; then
        echo "Expected initrd root directory as second argument!"
        exit 2
fi

if [ ! -d "$ROOTFS" ]; then
	echo "Expected rootfs directory as third argument!"
	exit 3
fi

CONTRIB_DIR="$SCRIPT_DIR/contrib/initrd"

if [ -e "$SCRIPT_DIR/scripts/common_functions.sh" ]; then
        source "$SCRIPT_DIR/scripts/common_functions.sh"
fi

function install_nmtelekinese()
{
	mkdir -p "$IRD/lip/nm"
	cp "$CONTRIB_DIR/nmtelekinese/nmtelekinese.desktop" "$IRD/lip/nm"
	cp "$CONTRIB_DIR/nmtelekinese/nmtelekinese.py" "$IRD/lip/nm"
	cp "$CONTRIB_DIR/nmtelekinese/26mopsmops" "$IRD/scripts/casper-bottom/"
	chmod +x "$IRD/scripts/casper-bottom/26mopsmops"
}

function add_no_bootloader_icon()
{
	mkdir -p "$IRD/lip/no-bootloader-icon"
	cp "$CONTRIB_DIR/no-bootloader-icon/ubiquity-kdeui.desktop" "$IRD/lip/no-bootloader-icon/"
#	cp "$SCRIPT_DIR/no-bootloader-icon/ubiquity-kdeui-no-bootloader.desktop" "$IRD/lip/no-bootloader-icon/"

	cp "$CONTRIB_DIR/no-bootloader-icon/25adduser" "$IRD/scripts/casper-bottom/"
	chmod +x "$IRD/scripts/casper-bottom/25adduser"
}

function install_liphook()
{
	cp "$CONTRIB_DIR/initrd_hook/24liphook" "$IRD/scripts/casper-bottom/"
	chmod +x "$IRD/scripts/casper-bottom/24liphook"
	cp "$CONTRIB_DIR/initrd_hook/ORDER" "$IRD/scripts/casper-bottom/"
}

function replace_modules()
{
	local version=$(basename $(readlink -f "$ROOTFS/vmlinuz") | cut -d'-' -f2-)
	rm -rf "$IRD/lib/modules/*"
	cp -a "$ROOTFS/lib/modules/$version" "$IRD/lib/modules"
}

mkdir -p "$IRD/lip"
install_nmtelekinese
#add_no_bootloader_icon
install_liphook
replace_modules

patch_all "$SCRIPT_DIR/patches/initrd" "$IRD"
