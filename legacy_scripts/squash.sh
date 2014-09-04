#!/bin/bash

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

