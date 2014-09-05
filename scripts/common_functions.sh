#!/bin/bash

function patch_all()
{
	PATCH_DIR="$1"
	TARGET_DIR="$2"

	if [ ! -d "$PATCH_DIR" ]; then
		echo "Nothing to patch here!"
		return 0
	fi
	
	if [ -z "$TARGET_DIR" ]; then
		echo "No target directory given, assuming /"
		TARGET_DIR="/"
	fi

        echo "Patching $TARGET_DIR ..."
        for p in "$PATCH_DIR/"*
        do
                cat "$p" | patch -d "$TARGET_DIR" -p1
        done
        echo "done."
}

function install_debs()
{
        DEB_DIR="$1"

        if [ ! -d "$DEB_DIR" ]; then
                echo "Nothing to install here!"
                return 0
        fi

        for p in "$DEB_DIR/"*
        do
		echo "installing $p..."
                dpkg -i "$p"
		echo "done."
        done
}
