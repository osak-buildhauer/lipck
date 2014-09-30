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

if [ -e lip32 -o -e lip64 ]; then
	echo "Workspace exisiting. Please clean up!"
	exit 1
fi

unsquashfs -f -d lip32 lip32.squashfs
unsquashfs -f -d lip32 lipcommon.squashfs

unsquashfs -f -d lip64 lip64.squashfs
unsquashfs -f -d lip64 lipcommon.squashfs

echo "Ok. Now run chroot.sh (lip32|lip64) and do stuff"

exit 0
