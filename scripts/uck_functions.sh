#!/bin/bash

###################################################################################
# UCK - Ubuntu Customization Kit                                                  #
# Copyright (C) 2006-2010 UCK Team                                                #
# Copyright (C) 2014 trilader, Anwarias, Christopher Spinrath
#                                                                                 #
# UCK is free software: you can redistribute it and/or modify                     #
# it under the terms of the GNU General Public License as published by            #
# the Free Software Foundation, either version 3 of the License, or               #
# (at your option) any later version.                                             #
#                                                                                 #
# UCK is distributed in the hope that it will be useful,                          #
# but WITHOUT ANY WARRANTY; without even the implied warranty of                  #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                   #
# GNU General Public License for more details.                                    #
#                                                                                 #
# You should have received a copy of the GNU General Public License               #
# along with UCK.  If not, see <http://www.gnu.org/licenses/>.                    #
###################################################################################

function install_lang_packages()
{
        #the content of this function is extracted from UCK
        MISSING_LANG_PKG="$(check-language-support -l de_DE)"
        MISSING_LANG_PKG="$(check-language-support -l en_US) $MISSING_LANG_PKG" # check for missing packages for de_DE and en_US

        if [ -n "$MISSING_LANG_PKG" ]; then
                apt-get -y install $MISSING_LANG_PKG
        fi

        EXTRA_LANG_PKG="$(dpkg-query --show | cut -f1 | grep -E '^(language-pack|language-support|firefox-locale|thunderbird-locale|libreoffice-help|libreoffice-l10n)' | grep -Ev "[-](de|en)\>" || true)" # remove extra language packages

        if [ -n "$EXTRA_LANG_PKG" ]; then
                apt-get -y purge $EXTRA_LANG_PKG
        fi
}
