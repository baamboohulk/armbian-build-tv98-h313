# TV98 Bluetooth BT-26

## Verified hardware profile

Board: TV98 / X96Q H313-H616 family, BCM43342A.

Tested kernel: Linux 6.12.64-legacy-sunxi64-bt26.

Hardware verification included:

- Boot from removable microSD
- Boot from internal eMMC
- Ethernet and Wi-Fi Internet access
- Broadcom Bluetooth firmware loading, build 0987
- BLE discovery
- Pairing and reconnecting Redmi Buds 6 Active
- Persistence of Bluetooth bonding information

These results apply to the tested TV98 hardware revision.
They do not imply compatibility with every X96Q board.

## Kernel patch integration

RTC patch:
patch/kernel/archive/sunxi-6.12/patches.armbian/tv98-h616-rtc-autocal.patch

The repository preparation script copies this patch into the
matching Armbian framework patch directory.

The patch enables internal RTC clock auto-calibration for the
compatible H616 RTC driver on the tested Linux 6.12.64 source.

Recheck patch applicability and functionality for other
kernel versions.

## Board-specific GPIOs

Device Tree:
device-tree/tv98/sun50i-h313-tv98-ethernet-v2.dts

Bluetooth reset/shutdown: PG19
Bluetooth device wake: PG17

The baseline device tree remains unchanged.

These GPIO assignments must not be applied to other boards
without hardware verification.

## Bluetooth firmware

The tested controller uses BCM43342A1 firmware build 0987.

On the tested system, the driver requests the board-specific
firmware filename:

brcm/BCM.hechuang,x96-q.hcd

The tested firmware source is BCM43342.hcd.

The firmware binary is not included in this repository.
A release image must supply legally redistributable firmware
and arrange the correct board-specific firmware filename.

## Portable image configuration

The distributed image must not embed machine-specific:

- Timezone or locale
- User credentials or SSH host keys
- Hostname or fixed IP addresses
- Wi-Fi credentials
- Root filesystem UUID
- Bluetooth MAC address or pairing database

Network, locale, timezone, hostname and accounts must be
configured through installation or normal OS configuration.

Hardware-specific settings belong in board profiles.

## Release status

This source commit does not by itself constitute a tested
release image.

Before release, build the actual kernel and image from the
updated source, validate modules and boot assets, and test
the resulting image on removable media with UART recovery.
