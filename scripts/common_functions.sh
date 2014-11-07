#!/bin/bash

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

function patch_all()
{
	PATCH_DIR="$1"
	TARGET_DIR="$2"

	if [ ! -d "$PATCH_DIR" ]; then
		echo "Nothing to patch here!"
		return 0
	fi
	
	if [ -z "$TARGET_DIR" ]; then
		echo "No target directory given, assuming /"
		TARGET_DIR="/"
	fi

        echo "Patching $TARGET_DIR ..."
        for p in "$PATCH_DIR/"*
        do
                cat "$p" | patch -d "$TARGET_DIR" -p1
        done
        echo "done."
}

function install_debs()
{
        DEB_DIR="$1"

        if [ ! -d "$DEB_DIR" ]; then
                echo "Nothing to install here!"
                return 0
        fi

        for p in "$DEB_DIR/"*
        do
		echo "installing $p..."
                dpkg -i "$p"
		echo "done."
        done
}
