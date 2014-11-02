#!/bin/bash
PKG_LIST="gufw pwgen inkscape gimp subversion git graphviz gnome \
xubuntu-desktop fityk openssh-server linux-firmware-nonfree zsh zsh-doc lftp gddrescue liblapack-dev liblapack-doc \
python-numpy python-simpy python-scipy python-matplotlib ipython gnuplot wxmaxima root-system bpython \
postgresql dia haskell-platform default-jdk swi-prolog libntl0 \
"

DESTINATION="/cdrom"
PKG_DESTINATION=$DESTINATION/archives

#begin
echo "creating structure..."
mkdir -p $PKG_DESTINATION/
echo "done."
echo "downloading archives. this may take some time..."
wget -nc -P $PKG_DESTINATION $(apt-get install --reinstall --print-uris -qq $PKG_LIST | cut -d"'" -f2)
#wget -nc -P $PKG_DESTINATION $(apt-get -o APT::Architecture=$ARCHITECTURE install --reinstall --allow-unauthenticated --print-uris -qq $PKG_LIST | cut -d"'" -f2)
echo "updating package lists..."
apt-get update
echo "done."
#end.
