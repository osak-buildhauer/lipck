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

set -e

SCRIPT_DIR="$1"
ISO_REMASTER_DIR="$2"

if [ ! -d "$SCRIPT_DIR" ]; then
        echo "Expected lipck base path as first argument!"
        exit 1
fi

if [ ! -d "$ISO_REMASTER_DIR" ]; then
        echo "Expected target iso or target image root directory as second argument!"
        exit 2
fi

if [ -e "$SCRIPT_DIR/scripts/common_functions.sh" ]; then
        source "$SCRIPT_DIR/scripts/common_functions.sh"
fi

patch_all "$SCRIPT_DIR/patches/iso/" "$ISO_REMASTER_DIR"
