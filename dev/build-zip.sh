#!/bin/bash
# Build a test zip of the plugin from a git ref, laid out like upstream's release zip
# (.github/workflows/main.yml), with <version> written into install.xml.
# usage: build-zip.sh <git-ref> <version>     e.g. build-zip.sh main 3.4.0.4
# writes dist/Deezer-<version>-test.zip and prints its SHA-1
set -euo pipefail
D=$(cd "$(dirname "$0")" && pwd)
REF=${1:?git ref}; VERSION=${2:?version}
OUT=$D/dist/Deezer-$VERSION-test.zip
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

git -C "$D/.." archive "$REF" | tar -x -C "$TMP"
sed -i '' -E "s|<version>[^<]*</version>|<version>$VERSION</version>|" "$TMP/install.xml"
grep -q "<version>$VERSION</version>" "$TMP/install.xml" || { echo "version not set in install.xml"; exit 1; }

mkdir -p "$D/dist"; rm -f "$OUT"
(cd "$TMP" && zip -q -X -r "$OUT" API ./*.pm HTML lib install.xml strings.txt README.md)
echo "$OUT"
echo "built from $(git -C "$D/.." rev-parse --short "$REF") ($REF)"
shasum -a 1 "$OUT" | awk '{print "SHA-1 " $1}'
