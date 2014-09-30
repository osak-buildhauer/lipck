#!/bin/bash

#This file is part of lipck - the "linux install party customization kit".
#
# Copyright (C) 2014 trilader
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

DIR="$(pwd)"

if [ ! -e "$DIR/lip32" -o ! -e "$DIR/lip64" -o ! -e "$DIR/lipcommon" ]; then
	echo "Working directories (lip32, lip64, lipcommon) don't exists. Please run unsquash.sh and deduplicate.sh before this"
	exit 1
fi

SUFFIX=""

if [ -e lip32.squashfs -o -e lip64.squashfs -o -e lipcommon.squashfs ]; then
	echo ".squashfs files already existing using .squashfs.new for output (will overwrite)"
	SUFFIX=".new"
fi

mksquashfs lip32 "lip32.squashfs$SUFFIX" -comp xz
mksquashfs lip64 "lip64.squashfs$SUFFIX" -comp xz
mksquashfs lipcommon "lipcommon.squashfs$SUFFIX" -comp xz
ls -lah

exit 0

