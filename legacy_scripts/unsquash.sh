#!/bin/bash

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
