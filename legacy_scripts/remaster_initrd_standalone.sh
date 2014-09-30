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
WORKDIR="$(pwd)"

function unpack_initrd
{
    FILE="$1"
    FOLDER="$2"
    mkdir -p "$FOLDER/remaster-initrd"
    pushd "$FOLDER/remaster-initrd" > /dev/null
    lzma -d < "$FILE" | cpio -i
    popd > /dev/null
}

function pack_initrd
{
    OUTDIR="$1"
    INDIR="$2"
    if [ ! -d "$INDIR/remaster-initrd" ]; then
        echo "Temp directory does not exist. Bug?"
        exit 1
    fi
    pushd "$INDIR/remaster-initrd" > /dev/null
    find | cpio -H newc -o | lzma -z > "$OUTDIR/initrd.lz"
    popd > /dev/null
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 INITRD_FILE PATH_TO_CUSTOMIZE_LIP"
    exit 1
fi

INITRD_FILE="$1"
PATH_TO_CUSTOMIZE_LIP="$2"

if [ ! -f "$INITRD_FILE" ]; then
    echo "Initrd file '$INITRD_FILE' not found"
    exit 1
fi

if [ ! -d "$PATH_TO_CUSTOMIZE_LIP" ]; then
    echo "You must specify the path to the customize-lip folder"
    exit 1
fi

TMPDIR="$(mktemp -d)"

unpack_initrd "$INITRD_FILE" "$TMPDIR"
pushd "$PATH_TO_CUSTOMIZE_LIP" > /dev/null
. $PATH_TO_CUSTOMIZE_LIP/customize_initrd "$TMPDIR"
popd > /dev/null
pack_initrd "$WORKDIR" "$TMPDIR"
echo "Ok, all done"
exit 0
