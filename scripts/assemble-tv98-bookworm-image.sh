#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 SOURCE_IMG UBOOT_BIN BOOT_EVIDENCE_DIR V2_DTB OUTPUT_IMG" >&2
    exit 2
fi

SOURCE="$1"
UBOOT="$2"
BOOT="$3"
DTB="$4"
TARGET="$5"

case "$TARGET" in
    /dev/*)
        echo "REFUSING_BLOCK_DEVICE_PATH" >&2
        exit 1
        ;;
esac

for F in "$SOURCE" "$UBOOT" "$DTB" \
    "$BOOT/boot.cmd" "$BOOT/boot.scr" \
    "$BOOT/armbianEnv.txt"
do
    test -f "$F"
    test ! -L "$F"
done

test ! -e "$TARGET"
test ! -L "$TARGET"

UBOOT_SHA="c0fb48f774184ce9d40b6ac03b3bae767597924f71ad65bd324352dfa174438b"
DTB_SHA="226c19e3904658444da11d7eddc61ba9fc3267ab2da1c3c26fe60d0e9ad7d6e5"

printf '%s  %s\n' "$UBOOT_SHA" "$UBOOT" | sha256sum -c -
printf '%s  %s\n' "$DTB_SHA" "$DTB" | sha256sum -c -

printf '%s  %s\n' \
 e064fc1b6463f0091deef74b7843adfde5c8cf2619480c4594ffe2fb197652d4 \
 "$BOOT/boot.cmd" | sha256sum -c -

printf '%s  %s\n' \
 7ca5ff19334ad347dc6e203d6967487b6a1887bfd3902b40d51153133363f93a \
 "$BOOT/boot.scr" | sha256sum -c -

printf '%s  %s\n' \
 291c3918365fa3237e4f924392ad565be5cc6820b705ca75515ac298b8b31e88 \
 "$BOOT/armbianEnv.txt" | sha256sum -c -

echo "INPUT_CHECKSUMS=PASS"

python3 - "$SOURCE" "$UBOOT" <<'PY'
import json
import os
import subprocess
import sys

image, uboot = sys.argv[1:]

table = json.loads(
    subprocess.check_output(
        ["sfdisk", "--json", image],
        text=True
    )
)["partitiontable"]

parts = table.get("partitions", [])
sector = int(table.get("sectorsize", 512))

if table.get("label") != "dos" or len(parts) != 1:
    sys.exit("PARTITION_LAYOUT_UNSUPPORTED")

start = int(parts[0]["start"]) * sector
end = 8192 + os.path.getsize(uboot)

if start <= end:
    sys.exit("UBOOT_PARTITION_OVERLAP")

size = (
    int(parts[0]["start"]) +
    int(parts[0]["size"])
) * sector

if os.path.getsize(image) < size:
    sys.exit("IMAGE_TRUNCATED")

print("PARTITION_LAYOUT=PASS")
PY

SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"

cp --reflink=auto --sparse=always -- "$SOURCE" "$TARGET"
chmod 600 "$TARGET"

test "$(stat -c '%s' "$SOURCE")" = \
     "$(stat -c '%s' "$TARGET")"

dd if="$UBOOT" of="$TARGET" \
    bs=1024 seek=8 conv=notrunc,fsync status=none

SIZE="$(stat -c '%s' "$UBOOT")"

ACTUAL="$(
    dd if="$TARGET" bs=1M \
      iflag=skip_bytes,count_bytes \
      skip=8192 count="$SIZE" status=none |
    sha256sum | awk '{print $1}'
)"

test "$ACTUAL" = "$UBOOT_SHA"

echo "TOC0_OFFSET_8K=PASS"

LOOP=""
MNT=""

cleanup() {
    local rc=$?
    trap - EXIT

    if [ -n "$MNT" ] && mountpoint -q "$MNT"; then
        sudo -n umount "$MNT" || rc=1
    fi

    if [ -n "$LOOP" ] && {
        [ -z "$MNT" ] || ! mountpoint -q "$MNT";
    }; then
        sudo -n losetup -d "$LOOP" || rc=1
    fi

    if [ -n "$MNT" ] && ! mountpoint -q "$MNT"; then
        rmdir "$MNT" || true
    fi

    if [ "$rc" -ne 0 ]; then
        echo "ASSEMBLY=INCOMPLETE_REVIEW_REQUIRED"
        echo "SOURCE_IMAGE=UNMODIFIED"
    fi

    exit "$rc"
}

trap cleanup EXIT

MNT="$(mktemp -d)"
LOOP="$(sudo -n losetup --find --show --partscan "$TARGET")"

sudo -n udevadm settle

PART="${LOOP}p1"

test -b "$PART"
test "$(sudo -n blkid -p -o value -s TYPE "$PART")" = ext4

UUID="$(sudo -n blkid -p -o value -s UUID "$PART")"
test -n "$UUID"

sudo -n mount -t ext4 -o rw "$PART" "$MNT"

echo "ROOTFS_MOUNT=PASS"

test -f "$MNT/etc/os-release"
grep -q '^VERSION_CODENAME=bookworm' "$MNT/etc/os-release"

REL="6.12.64-legacy-sunxi64"

test -s "$MNT/boot/Image"
test -s "$MNT/boot/uInitrd"
test -d "$MNT/lib/modules/$REL"

grep -Eq \
  "^UUID=$UUID[[:space:]]+/[[:space:]]+ext4" \
  "$MNT/etc/fstab"

for MOD in sunxi_gmac sunxi-ephy; do
    FILE="$(
        find "$MNT/lib/modules/$REL" \
            -type f -name "${MOD}.ko*" -print -quit
    )"

    test -n "$FILE"

    VERMAGIC="$(modinfo -F vermagic "$FILE")"

    case "$VERMAGIC" in
        "$REL "*) ;;
        *)
            echo "MODULE_VERMAGIC_MISMATCH=$MOD"
            exit 1
            ;;
    esac
done

echo "KERNEL_AND_MODULES=PASS"

ENV="$MNT/boot/armbianEnv.txt"
CMD="$MNT/boot/boot.cmd"
NETWORK="$MNT/etc/systemd/network/20-tv98-ethernet.network"

test ! -L "$ENV"
test ! -L "$CMD"
test ! -L "$MNT/etc/systemd/network"
test ! -e "$NETWORK"
test ! -L "$NETWORK"

awk '
    /^setenv rootdev / {root=NR}
    /env import -t/ {imp=NR}
    /^setenv bootargs / {args=NR}
    END {
        exit !(root && imp && args &&
               root < imp && imp < args)
    }
' "$BOOT/boot.cmd"

sudo -n install -m 644 "$BOOT/boot.cmd" \
    "$MNT/boot/boot.cmd"

sudo -n install -m 644 "$BOOT/boot.scr" \
    "$MNT/boot/boot.scr"

sudo -n install -m 644 "$BOOT/armbianEnv.txt" \
    "$MNT/boot/armbianEnv.txt"

sudo -n install -d -m 755 "$MNT/boot/dtb/allwinner"

sudo -n install -m 644 "$DTB" \
    "$MNT/boot/dtb/allwinner/sun50i-h313-tv98-ethernet-v2.dtb"

test "$(grep -c '^rootdev=' "$ENV")" -eq 1

sudo -n sed -i \
    "s|^rootdev=.*$|rootdev=UUID=$UUID|" \
    "$ENV"

grep -Fxq "rootdev=UUID=$UUID" "$ENV"
grep -Fxq 'extraargs=clk_ignore_unused' "$ENV"
grep -Fxq 'fdtfile=sun50i-h313-tv98-ethernet-v2.dtb' "$ENV"

echo "ROOT_UUID_AND_DTB=PASS"

test -L \
  "$MNT/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"

test -L \
  "$MNT/etc/systemd/system/multi-user.target.wants/ssh.service"

sudo -n install -d -m 755 \
    "$MNT/etc/systemd/network"

sudo -n tee "$NETWORK" >/dev/null <<'NETWORKFILE'
[Match]
Name=end0 eth0 en*
Type=ether

[Network]
DHCP=ipv4
NETWORKFILE

sudo -n chmod 644 "$NETWORK"

grep -Fxq 'Name=end0 eth0 en*' "$NETWORK"
grep -Fxq 'DHCP=ipv4' "$NETWORK"

echo "ETHERNET_DHCP=PASS"

cmp "$BOOT/boot.cmd" "$CMD"
cmp "$BOOT/boot.scr" "$MNT/boot/boot.scr"

printf '%s  %s\n' "$DTB_SHA" \
 "$MNT/boot/dtb/allwinner/sun50i-h313-tv98-ethernet-v2.dtb" |
 sudo -n sha256sum -c -

echo "BOOT_ASSETS=PASS"

sync
sudo -n umount "$MNT"
sudo -n losetup -d "$LOOP"
LOOP=""

echo "=== READ-ONLY REOPEN ==="

LOOP="$(sudo -n losetup --find --show --read-only --partscan "$TARGET")"
sudo -n udevadm settle

test -b "${LOOP}p1"

sudo -n mount -t ext4 -o ro,noload "${LOOP}p1" "$MNT"

grep -Fxq "rootdev=UUID=$UUID" \
    "$MNT/boot/armbianEnv.txt"

grep -Fxq 'DHCP=ipv4' \
    "$MNT/etc/systemd/network/20-tv98-ethernet.network"

test -d "$MNT/lib/modules/$REL"

echo "INDEPENDENT_READONLY_QA=PASS"

sudo -n umount "$MNT"
sudo -n losetup -d "$LOOP"
LOOP=""

rmdir "$MNT"
MNT=""

test "$(sha256sum "$SOURCE" | awk '{print $1}')" = \
     "$SOURCE_SHA"

echo "SOURCE_IMAGE_UNCHANGED=PASS"

sha256sum "$TARGET"

echo "TV98_IMAGE_ASSEMBLY=PASS"
echo "IMAGE_READY_TO_FLASH=NO"
echo "HARDWARE_TEST=NOT_DONE"
echo "PRIVATE_IMAGE=$TARGET"
