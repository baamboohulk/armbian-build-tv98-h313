#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== TV98 ENGLISH LOCALE PATCH ==="

test "$(id -u)" -eq 0
test "$(uname -r)" = "6.12.64-legacy-sunxi64"
test "$(findmnt -n -o SOURCE /)" = "/dev/mmcblk0p1"
test -d /sys/class/net/end0

command -v update-locale >/dev/null
command -v locale >/dev/null
test -f /etc/default/locale

echo "TARGET_DEVICE=PASS"

echo "=== CURRENT CONFIGURATION ==="
cat /etc/default/locale

BACKUP="/root/TV98_BACKUPS/locale"
install -d -m 700 "$BACKUP"

if [ ! -e "$BACKUP/default-locale.before-en-us" ]; then
    cp -a /etc/default/locale \
        "$BACKUP/default-locale.before-en-us"
    chmod 600 "$BACKUP/default-locale.before-en-us"
fi

echo "LOCALE_BACKUP=PASS"

echo "=== ENABLE EN_US UTF-8 ==="

if ! locale -a | grep -Eqi '^en_US\.(utf8|utf-8)$'; then
    command -v locale-gen >/dev/null
    test -f /etc/locale.gen

    if [ ! -e "$BACKUP/locale.gen.before-en-us" ]; then
        cp -a /etc/locale.gen \
            "$BACKUP/locale.gen.before-en-us"
        chmod 600 "$BACKUP/locale.gen.before-en-us"
    fi

    sed -i -E \
      's/^#[[:space:]]*(en_US\.UTF-8[[:space:]]+UTF-8)[[:space:]]*$/\1/' \
      /etc/locale.gen

    grep -Eq '^en_US\.UTF-8[[:space:]]+UTF-8' \
        /etc/locale.gen

    locale-gen en_US.UTF-8
fi

locale -a | grep -Eqi '^en_US\.(utf8|utf-8)$'

echo "EN_US_UTF8_GENERATED=PASS"

echo "=== CHANGE SYSTEM DEFAULT ==="

update-locale --reset LANG=en_US.UTF-8

grep -Fxq 'LANG=en_US.UTF-8' /etc/default/locale

if grep -Eq '^(LANGUAGE|LC_MESSAGES|LC_ALL)=' \
    /etc/default/locale; then
    echo "UNEXPECTED_LOCALE_OVERRIDE"
    exit 1
fi

localectl status

localectl status | grep -Fq \
    'System Locale: LANG=en_US.UTF-8'

echo "=== TEST ENGLISH OUTPUT ==="

env -i \
    PATH=/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=en_US.UTF-8 \
    date '+%a %b %d %Y'

echo "=== FINAL ==="
echo "TV98_LOCALE=en_US.UTF-8"
echo "LOCALE_FIX=PASS"
echo "REBOOT_REQUIRED=NO"
echo "KERNEL_CHANGED=NO"
echo "NETWORK_CHANGED=NO"
echo "EMMC_MODIFIED=NO"
