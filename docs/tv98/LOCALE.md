# TV98 English locale

## Issue

A TV98 Bookworm first-boot configuration used
LANG=vi_VN, LANGUAGE=vi_VN and LC_MESSAGES=vi_VN.

This translated login messages, dates and some logs
into Vietnamese.

## Fix

Run scripts/configure-tv98-locale-en-us.sh
as root on the TV98 after first boot.

The script:
- Confirms the expected TV98 kernel and SD rootfs
- Saves original locale settings under
  /root/TV98_BACKUPS/locale
- Generates en_US.UTF-8 if not already available
- Runs update-locale --reset LANG=en_US.UTF-8
- Verifies the resulting system locale

Start a new SSH/login session after the change.

## Scope

This is a post-boot configuration patch.
It does not alter the previously released image
or the U-Boot, kernel, DTB or Ethernet driver.

Future image assembly should apply the same
default through a separately tested build hook.

## Rollback

The original settings are retained locally
on the TV98 in /root/TV98_BACKUPS/locale.

Do not commit device backups to GitHub.
