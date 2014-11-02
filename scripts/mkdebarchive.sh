#! /bin/bash
set -e

echo "mkdebarchive.sh (C) 2012-2014 Mmoebius/ALUG, trilader/ALUG; 2014 Christopher Spinrath/OSAK"
echo "License: GPLv3 GNU Public License"
echo "Usage: mkdebarchive.sh [dist-codename [dist-version [archives-dir]]]"

DIST_CODENAME="${1:-"trusty"}"
DIST_VERSION="${2:-"14.04"}"
BUILD_DATE="$(LC_ALL=C date -u)"
echo "Running for Ubuntu $DIST_VERSION ($DIST_CODENAME)..."

ARCHIVES_DIR="${3:-"./archives"}"

echo "Prerequisite: Alle .deb-Packete liegen in $ARCHIVES_DIR"
test -d "$ARCHIVES_DIR" || { echo "FAIL: no '$ARCHIVES_DIR'"; exit 2; }
cd "$ARCHIVES_DIR"

echo
echo "Scanne nach Packages"
dpkg-scanpackages -a noarch . > Packages.noarch
dpkg-scanpackages -a amd64  . > Packages.amd64
dpkg-scanpackages -a i386   . > Packages.i386

echo
echo "Erzeuge dist-Verzeichnisse"
mkdir -p "dists/$DIST_CODENAME/lip/binary-amd64"
mkdir -p "dists/$DIST_CODENAME/lip/binary-i386"

echo
echo "Erzeuge Packages.bz2"
cat Packages.noarch Packages.amd64 | bzip2 -c9 > "dists/$DIST_CODENAME/lip/binary-amd64/Packages.bz2"
cat Packages.noarch Packages.i386  | bzip2 -c9 > "dists/$DIST_CODENAME/lip/binary-i386/Packages.bz2"

echo
echo "Erzeuge './dists/$DIST_CODENAME/lip/binary-amd/Release'"
cat >dists/$DIST_CODENAME/lip/binary-amd64/Release <<EOF
Archive: $DIST_CODENAME
Version: $DIST_VERSION
Component: main
Origin: Ubuntu
Label: Ubuntu
Architecture: amd64
EOF

echo
echo "Erzeuge './dists/$DIST_CODENAME/lip/binary-i386/Release'"
cat >dists/$DIST_CODENAME/lip/binary-i386/Release <<EOF
Archive: $DIST_CODENAME
Version: $DIST_VERSION
Component: main
Origin: Ubuntu
Label: Ubuntu
Architecture: i386
EOF

echo
echo "Erzeuge './Release'"
cat >Release <<EOF
Origin: Ubuntu
Label: LIP Ubuntu Extra Packages
Suite: $DIST_CODENAME
Version: $DIST_VERSION
Codename: $DIST_CODENAME
Date: $BUILD_DATE
Architectures: amd64 i386
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

