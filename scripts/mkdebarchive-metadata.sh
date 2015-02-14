#! /bin/bash
set -e

#Note: this script is a subset of mkdebarchive.sh. It generates only the metadata and assumes
#that the package files as well as the correct dirctory structure exist.
#The original script may be found in ../legacy_scripts .

echo "mkdebarchive.sh (C) 2012-2014 Mmoebius/ALUG, trilader/ALUG; 2014 Christopher Spinrath/OSAK"
echo "License: GPLv3 GNU Public License"
echo "Usage: mkdebarchive-metadata.sh dist-codename dist-version archives-dir architecture_list..."

test $# -ge 4 || ( echo "Expecting at least 4 arguments!" && exit 1 )

DIST_CODENAME="$1"
DIST_VERSION="$2"
BUILD_DATE="$(LC_ALL=C date -u)"
echo "Running for Ubuntu $DIST_VERSION ($DIST_CODENAME)..."

ARCHIVES_DIR="$3"

#we have three arguments followed by the architecture list
shift 3

echo "Prerequisite: Alle .deb-Packete liegen in $ARCHIVES_DIR"
test -d "$ARCHIVES_DIR" || { echo "FAIL: no '$ARCHIVES_DIR'"; exit 2; }
cd "$ARCHIVES_DIR"

ARCH_STR=""

for ARCH in $@; do

echo
echo "Erzeuge './dists/$DIST_CODENAME/lip/binary-$ARCH/Release'"
mkdir -p "dists/$DIST_CODENAME/lip/binary-$ARCH/"
cat >dists/$DIST_CODENAME/lip/binary-$ARCH/Release <<EOF
Archive: $DIST_CODENAME
Version: $DIST_VERSION
Component: main
Origin: Ubuntu
Label: Ubuntu
Architecture: $ARCH
EOF

ARCH_STR="$ARCH_STR $ARCH"

done

echo
echo "Erzeuge './Release'"
cat >Release <<EOF
Origin: Ubuntu
Label: LIP Ubuntu Extra Packages
Suite: $DIST_CODENAME
Version: $DIST_VERSION
Codename: $DIST_CODENAME
Date: $BUILD_DATE
Architectures: $ARCH_STR
Components: lip
Description: Ubuntu $DIST_CODENAME $DIST_VERSION
EOF

#echo
#echo "Erzeuge einen geeigneten Eintrag für APT in 'sources.list.d/01lip-stick-extra.list'"
#echo "deb [ trusted=yes ] file:/${PWD#/} $DIST_CODENAME lip" > /etc/apt/sources.list.d/01lip-stick-extra.list 

#echo
#echo "User: Bitte gleich 'apt-get update' starten. Das sollte das Repository einbinden"
#echo "In diesem Verzeichnis liegen noch 3 Packages.* -Dateien. Die können gelöscht werden"
#echo "Ende."

#end;

