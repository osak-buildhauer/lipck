#!/usr/bin/env python3

"""
Simple helper scripts that parses a package list in json format
(as required by linuxparty.py) and prints the relevant information
(as required by lipck) in a simple table format.
Afterwards, this table can be used by lipck and its bash helper
scripts that do not have a build in json parser like python.
"""

PACKAGES_KEY = "packages"
PACKAGE_NAME_KEY = "pkgname"
PACKAGE_URLS_KEY = "urls"

import codecs
import json
import sys
import os

def packageJsonToSimpleList(filename):
  file_handle = codecs.open(filename, 'r', 'utf-8-sig')
  pkginfo = json.load(file_handle)

  for category_name,category in pkginfo.items():
    for pkg in category[PACKAGES_KEY]:
      print(pkg[PACKAGE_NAME_KEY],end="")

      if PACKAGE_URLS_KEY in pkg:
        for url in pkg[PACKAGE_URLS_KEY]:
          print(" {0}".format(url), end="")

      print()

if __name__ == "__main__":
  if len(sys.argv) < 2:
    sys.exit("Usage: {0} /path/to/packagelist.json".format(sys.argv[0]))

  filename = sys.argv[1]
  if not os.path.exists(filename):
    sys.exit("{0}: error: {1} does not exist!".format(sys.argv[0],filename))

  packageJsonToSimpleList(filename)
