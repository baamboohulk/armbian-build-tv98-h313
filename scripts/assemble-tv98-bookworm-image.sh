#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

if [ "$#" -ne 5 ] && [ "$#" -ne 7 ]; then
    echo "Usage: $0 SOURCE_IMG UBOOT_BIN BOOT_EVIDENCE_DIR V2_DTB OUTPUT_IMG [KERNEL_DEB DTB_DEB]" >&2
    exit 2
fi

SOURCE="$1"
UBOOT="$2"
BOOT="$3"
DTB="$4"
TARGET="$5"
test ! -e "$TARGET" && test ! -L "$TARGET" || exit 1
TARGET="$(realpath -m -- "$TARGET")"
PB397=0
if [ "$#" -eq 7 ]; then
    PB397=1
    KERNEL_DEB="$6"
    DTB_DEB="$7"
fi

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

if [ "$PB397" = 1 ]; then
    DTB_SHA="7b1029baec3dfdaaa6e001c8ba9a3e37e1aacfe81a1c2478a66d0401632e8fef"
    for F in "$KERNEL_DEB" "$DTB_DEB"; do
        test -f "$F" && test ! -L "$F" || exit 1
    done
    printf '%s  %s\n' \
        a870ffbafc7aca732aec431f728469d3b71d6c5da422b051ced7eec6c2ed4000 "$KERNEL_DEB" \
        1d83bf74ee04afefacddf8073a2eb720d202b1ed5695c5f2e2d2d8e33540c4a5 "$DTB_DEB" |
        sha256sum -c -
fi

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
STAGE=""

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
        echo "SOURCE_IMAGE_VERIFICATION=INCOMPLETE"
    fi

    if [ -n "$STAGE" ]; then
        rm -rf -- "$STAGE" || rc=1
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

verify_pb397() {
    sudo -n chroot "$MNT" /bin/sh -ec '
        export PATH=/usr/sbin:/usr/bin:/sbin:/bin
        printf "%s  %s\n" \
          09970c63b7a0fc677915195923739ddac5e9ee8d589ef9f4b0ded7370684874f \
          /lib/firmware/brcm/BCM43342.hcd \
          09970c63b7a0fc677915195923739ddac5e9ee8d589ef9f4b0ded7370684874f \
          /lib/firmware/brcm/BCM.hechuang,x96-q.hcd |
          sha256sum -c -
    '
    echo 'BT_FIRMWARE_ALIAS_QA=PASS'

    sudo -n cmp "$STAGE/boot/vmlinuz-$REL" "$MNT/boot/Image"

    sudo -n diff -qr \
        "$STAGE/lib/modules/$REL/kernel" \
        "$MNT/lib/modules/$REL/kernel"

    sudo -n cmp \
        "$STAGE/boot/dtb-$REL/allwinner/overlay/sun50i-h616-fixup.scr" \
        "$MNT/boot/dtb/allwinner/overlay/sun50i-h616-fixup.scr"

    sudo -n python3 - "$MNT/boot/initrd.img-$REL" "$MNT/boot/uInitrd" <<'CRC'
import sys, struct, zlib, gzip
from pathlib import Path

raw, wrapped = (Path(p).read_bytes() for p in sys.argv[1:])
h, payload = wrapped[:64], wrapped[64:]
magic, hc, _, size, _, _, dc = struct.unpack('>7I', h[:28])

assert magic == 0x27051956
assert size == len(payload) and payload == raw
assert zlib.crc32(h[:4]+bytes(4)+h[8:]) == hc
assert zlib.crc32(payload) == dc
assert 0 < len(raw) < 33554432
assert gzip.decompress(raw)

print('INITRD_UIMAGE_CRC=PASS')
CRC
}

if [ "$PB397" = 1 ]; then
    test "$UUID" = e9912dd5-e671-40b4-8d19-f8804fc929ad
    test "$(findmnt -n -o SOURCE --target "$MNT")" = "$PART"
    test "$(sudo -n losetup --list --noheadings --output BACK-FILE "$LOOP")" = "$TARGET"

    test "$(realpath "$MNT/boot")" = "$MNT/boot"
    case "$(realpath "$MNT/lib/modules")" in
        "$MNT/"*) ;;
        *) exit 1;;
    esac

    test ! -L "$MNT/lib/modules/$REL"
    test ! -L "$MNT/boot/dtb-$REL"
    test -L "$MNT/boot/dtb"

    for D in dev proc; do
        test -d "$MNT/$D" && test ! -L "$MNT/$D" || exit 1
    done

    for F in vmlinuz config System.map initrd.img uInitrd; do
        test ! -L "$MNT/boot/$F-$REL"
    done

    sudo -n chroot "$MNT" /bin/sh -c \
        'test -x /usr/sbin/mkinitramfs && test -x /sbin/depmod'

    STAGE="$(mktemp -d)"

    (
        umask 022
        dpkg-deb -x "$KERNEL_DEB" "$STAGE"
        dpkg-deb -x "$DTB_DEB" "$STAGE"
    )

    test -s "$STAGE/boot/vmlinuz-$REL"
    test -d "$STAGE/lib/modules/$REL/kernel"
    test -d "$STAGE/boot/dtb-$REL/allwinner"

    for K in MMC MMC_BLOCK MMC_SUNXI EXT4_FS BLK_DEV_INITRD RD_GZIP; do
        grep -Fxq "CONFIG_$K=y" "$STAGE/boot/config-$REL"
    done

    FIXUP="allwinner/overlay/sun50i-h616-fixup.scr"

    if [ ! -s "$STAGE/boot/dtb-$REL/$FIXUP" ]; then
        install -D -m 644 \
            "$MNT/boot/dtb/$FIXUP" \
            "$STAGE/boot/dtb-$REL/$FIXUP"
    fi

    sudo -n rm -rf -- \
        "$MNT/lib/modules/$REL" \
        "$MNT/boot/dtb-$REL"

    sudo -n cp -a --no-preserve=ownership \
        "$STAGE/lib/modules/$REL" "$MNT/lib/modules/"

    sudo -n cp -a --no-preserve=ownership \
        "$STAGE/boot/dtb-$REL" "$MNT/boot/"

    for F in vmlinuz config System.map; do
        sudo -n install -m 644 \
            "$STAGE/boot/$F-$REL" "$MNT/boot/$F-$REL"
    done

    sudo -n ln -sfnT "vmlinuz-$REL" "$MNT/boot/Image"
    sudo -n ln -sfnT "dtb-$REL" "$MNT/boot/dtb"

    sudo -n chroot "$MNT" /bin/sh -c '
        export PATH=/usr/sbin:/usr/bin:/sbin:/bin
        umask 022

        /sbin/depmod -a "$1" || exit 1
        chmod a+r "/lib/modules/$1"/modules.* || exit 1

        for M in sunxi_gmac sunxi-ephy sunxi_ac200 brcmfmac hci_uart btbcm pwm-sunxi-enhance; do
            V="$(/sbin/modinfo -k "$1" -F vermagic "$M")" ||
                { echo "MODULE_LOOKUP_FAIL=$M"; exit 1; }

            case "$V" in
                "$1 "*) ;;
                *) echo "MODULE_VERMAGIC_FAIL=$M"; exit 1;;
            esac
        done

        FW=/lib/firmware/brcm/BCM43342.hcd
        ALIAS=/lib/firmware/brcm/BCM.hechuang,x96-q.hcd

        printf "%s  %s\n" \
          09970c63b7a0fc677915195923739ddac5e9ee8d589ef9f4b0ded7370684874f \
          "$FW" | sha256sum -c - || exit 1

        if [ ! -e "$ALIAS" ] && [ ! -L "$ALIAS" ]; then
            ln -s BCM43342.hcd "$ALIAS" || exit 1
        fi

        printf "%s  %s\n" \
          09970c63b7a0fc677915195923739ddac5e9ee8d589ef9f4b0ded7370684874f \
          /lib/firmware/brcm/BCM.hechuang,x96-q.hcd |
          sha256sum -c -
    ' sh "$REL"

    echo 'PB397_MODULES_AND_FIRMWARE=PASS'

    sudo -n unshare --mount --pid --fork --propagation private \
        bash -s -- "$MNT" "$REL" <<'HOST'
set -Eeuo pipefail

R="$1"
REL="$2"

mount -t tmpfs -o mode=0755,nosuid tmpfs "$R/dev"

for SPEC in 'null 3' 'zero 5' 'random 8' 'urandom 9'; do
    read -r N MINOR <<< "$SPEC"
    mknod -m 666 "$R/dev/$N" c 1 "$MINOR"
done

mount -t proc -o nosuid,nodev,noexec proc "$R/proc"

chroot "$R" /bin/bash -s -- "$REL" <<'GUEST'
set -Eeuo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umask 022

REL="$1"
CFG="$(mktemp -d)"
NEW="/boot/initrd.img-$REL.pb397-new"

trap 'rm -rf "$CFG"; rm -f "$NEW"' EXIT

cp -a /etc/initramfs-tools/. "$CFG/"
mkdir -p "$CFG/conf.d"

printf '%s\n' MODULES=list COMPRESS=gzip \
    > "$CFG/conf.d/zzzzzz-tv98-pb397"

/usr/sbin/mkinitramfs \
    -d "$CFG" -c gzip -o "$NEW" "$REL"

gzip -t "$NEW"
lsinitramfs "$NEW" > "$CFG/contents"
grep -Ex '(\./)?init' "$CFG/contents"

test "$(stat -c %s "$NEW")" -lt 33554432

mv -f "$NEW" "/boot/initrd.img-$REL"
GUEST
HOST

    sudo -n mkimage -A arm64 -O linux -T ramdisk -C gzip \
        -n 'TV98 Pb397 PWM QA' \
        -d "$MNT/boot/initrd.img-$REL" \
        "$MNT/boot/uInitrd-$REL"

    sudo -n ln -sfnT "uInitrd-$REL" "$MNT/boot/uInitrd"

    verify_pb397

    echo 'PB397_KERNEL_INITRAMFS=PASS'
fi

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

if [ "$PB397" = 1 ]; then
    verify_pb397

    printf '%s  %s\n' "$DTB_SHA" \
        "$MNT/boot/dtb/allwinner/sun50i-h313-tv98-ethernet-v2.dtb" |
        sudo -n sha256sum -c -

    echo 'PB397_READONLY_QA=PASS'
fi

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
