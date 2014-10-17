#!/bin/bash

function install_lang_packages()
{
        #the content of this function is extracted from UCK
        MISSING_LANG_PKG="$(check-language-support -l de_DE)"
        MISSING_LANG_PKG="$(check-language-support -l en_US) $MISSING_LANG_PKG" # check for missing packages for de_DE and en_US

        if [ -n "$MISSING_LANG_PKG" ]; then
                aptitude install $MISSING_LANG_PKG -y
        fi

        EXTRA_LANG_PKG="$(dpkg-query --show | cut -f1 | grep -E '^(language-pack|language-support|firefox-locale|thunderbird-locale|libreoffice-help|libreoffice-l10n)' | grep -Ev "[-](de|en)\>")" # remove extra language packages

        if [ -n "$EXTRA_LANG_PKG" ]; then
                aptitude purge $EXTRA_LANG_PKG -y
        fi
}
