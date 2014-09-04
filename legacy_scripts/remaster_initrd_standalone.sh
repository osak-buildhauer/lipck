#!/bin/bash
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
