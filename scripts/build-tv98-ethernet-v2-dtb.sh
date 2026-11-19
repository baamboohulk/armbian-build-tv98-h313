#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/device-tree/tv98/sun50i-h313-tv98-ethernet-v2.dts"
DEST="${1:-$ROOT/output/sun50i-h313-tv98-ethernet-v2.dtb}"
command -v dtc >/dev/null
mkdir -p "$(dirname "$DEST")"
dtc -q -s -I dts -O dtb -o "$DEST" "$SOURCE"
T="$(mktemp)"
trap 'rm -f -- "$T"' EXIT
dtc -q -s -I dtb -O dts -o "$T" "$DEST"
cmp "$SOURCE" "$T"
sha256sum "$DEST"
echo 'TV98_DTB_SOURCE_REBUILD=PASS'
