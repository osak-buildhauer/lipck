#!/bin/bash

SCRIPT_DIR="$1"
ISO_REMASTER_DIR="$2"

if [ ! -d "$SCRIPT_DIR" ]; then
        echo "Expected lipck base path as first argument!"
        exit 1
fi

if [ ! -d "$ISO_REMASTER_DIR" ]; then
        echo "Expected target iso or target image root directory as second argument!"
        exit 2
fi

if [ -e "$SCRIPT_DIR/scripts/common_functions.sh" ]; then
        source "$SCRIPT_DIR/scripts/common_functions.sh"
fi

patch_all "$SCRIPT_DIR/patches/iso/" "$ISO_REMASTER_DIR"
