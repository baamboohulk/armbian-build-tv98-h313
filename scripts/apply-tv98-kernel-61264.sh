#!/usr/bin/env bash
set -euo pipefail

FW="${1:?Usage: apply-tv98-kernel-61264.sh CLEAN_ARMBIAN_WORKTREE}"
FW="$(realpath "$FW")"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

EXPECTED="eadca54dc8d891d3ddc159d70c90ca903fdb9c1e"
PATCH="$ROOT/patch/armbian/0001-tv98-kernel-61264-framework.patch"
DRIVER="patch/kernel/archive/sunxi-6.12/patches.armbian/driver-allwinner-h618-emac.patch"
WIFI="patch/kernel/archive/sunxi-6.12/patches.armbian/driver-broadcom-brcmfmac-bcm43342.patch"
CONFIG="config/kernel/linux-sunxi64-legacy.config"

test "$(git -C "$FW" rev-parse HEAD)" = "$EXPECTED"
test -z "$(git -C "$FW" status --porcelain)"
test ! -e "$FW/$DRIVER"
test ! -e "$FW/$WIFI"

git -C "$FW" apply --check "$PATCH"

printf '%s  %s\n' \
  907bdf9f2b64ac957e5786e073c8c7052b0e3ac5f8c8b16aed0e0b353e46bccf \
  "$ROOT/$DRIVER" | sha256sum -c -

git -C "$FW" apply "$PATCH"
install -m 644 "$ROOT/$DRIVER" "$FW/$DRIVER"
install -m 644 "$ROOT/$WIFI" "$FW/$WIFI"
cmp -s "$ROOT/$WIFI" "$FW/$WIFI"
install -m 644 "$ROOT/$CONFIG" "$FW/$CONFIG"

git -C "$FW" diff --check
echo "TV98_KERNEL_SOURCE_PREPARED=PASS"
echo "KERNEL_BUILD=NOT_RUN"
