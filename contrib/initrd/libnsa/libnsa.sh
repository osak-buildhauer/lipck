#!/bin/bash
DUMPDIR="$(mktemp -d --tmpdir /cdrom/lipstats/ .stats.XXXXXXXXXXXX)"

mkdir -p "$DUMPDIR"

uname -a > "$DUMPDIR/uname" 2> "$DUMPDIR/uname.err"
dmidecode > "$DUMPDIR/dmidecode" 2> "$DUMPDIR/dmidecode.err"
lspci -k > "$DUMPDIR/lspci" 2> "$DUMPDIR/lspci.err"
lsusb > "$DUMPDIR/lsusb" 2> "$DUMPDIR/lsusb.err"
