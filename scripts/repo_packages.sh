#!/bin/bash

#This file is part of lipck - the "linux install party customization kit" - and
#contains parts of UCK - the Ubuntu Customization Kit.
#
# Copyright (C) 2014 Christopher Spinrath
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

ARCH="$1"
DESTINATION="${2:-"/cdrom"}"
SCRIPT_DIR="/remaster"
CONTRIB_DIR="$SCRIPT_DIR/contrib/"

test -n "$ARCH"  || { echo "$(basename $0): fatal error: no architecture specified."; exit 1; }

echo
echo "==> Fetching packages for offline repository for $ARCH"

#source common functions
if [ -e "$SCRIPT_DIR/scripts/common_functions.sh" ]; then
        source "$SCRIPT_DIR/scripts/common_functions.sh"
fi

if [ ! -d "$SCRIPT_DIR" ]; then
        echo "Error: Missing remaster directory/files. Abort."
        exit 2
fi

PKG_LIST=$(get_packages_from_file "$CONTRIB_DIR/offline_repo_packages")

PKG_DESTINATION=$DESTINATION/archives

#begin
echo "creating structure..."
mkdir -p $PKG_DESTINATION/
echo "done."

#maybe not necessary, but lets do it
divert_initctl

echo "Updating package lists..."
apt-get update
echo "ok."

echo "downloading archives. this may take some time..."
wget -nc -P $PKG_DESTINATION $(apt-get install --reinstall --print-uris -qq $PKG_LIST | cut -d"'" -f2)
#wget -nc -P $PKG_DESTINATION $(apt-get -o APT::Architecture=$ARCHITECTURE install --reinstall --allow-unauthenticated --print-uris -qq $PKG_LIST | cut -d"'" -f2)

revert_initctl

echo "updating package lists..."
apt-get update
echo "done."

cd "$PKG_DESTINATION"
echo
echo "Scanning packages..."

#TODO: "noarch" is created multiple times (once per architecture) and may be changed
#by another call of this script independently of the .$ARCH file! This may cause
#side effects.
dpkg-scanpackages -a noarch . > Packages.noarch
dpkg-scanpackages -a $ARCH  . > Packages.$ARCH

#end.
