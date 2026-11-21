# TV98 H313 - Debian Bookworm image

## Status

Commit 06 prepares a source-based Debian Bookworm
image using the verified TV98 boot components.

Offline build and checks do not constitute a
hardware boot acceptance test.

## Components

- Board: CS_H313_H1_EMCP_V1.2A
- Kernel: 6.12.64-legacy-sunxi64
- Root filesystem: Debian Bookworm minimal, ext4
- U-Boot: v2026.07 TOC0, verified SHA256
- Ethernet: sunxi_gmac, sunxi-ephy and V2 DTB
- Boot: PWM5 initialization before booti
- Network: systemd-networkd, IPv4 DHCP
- Root filesystem: booted by filesystem UUID

## Image assembly

Use scripts/assemble-tv98-bookworm-image.sh with:

1. A newly built, unmodified Bookworm .img
2. Verified TV98 TOC0 U-Boot binary
3. Local boot.cmd, boot.scr and armbianEnv.txt evidence
4. TV98 Ethernet V2 DTB from local private evidence
5. A new output image path

The script validates boot asset checksums, verifies
partition clearance for the bootloader at 8 KiB,
copies the input image, installs boot components,
sets the actual root filesystem UUID, creates
the Ethernet DHCP configuration, and reopens the
result read-only for final inspection.

The original input image is not modified.

## Privacy and release

The hardware-extracted V2 DTB may contain the
device's MAC address.

NEVER commit or publish this raw DTB, its parent
device image, private TOC0 signing keys, Android
eMMC dumps, or private boot evidence.

The public repository contains source files,
scripts, documentation and non-sensitive hashes.

The sanitized public V2 DTS is a separate source
artifact and is not automatically equivalent to
the hardware-tested private DTB.

## Hardware acceptance (pending)

Test only on a spare microSD, with UART capture:

- Cold boot and Linux login
- uname -r and root filesystem
- Ethernet PHY and link at 100 Mbps full duplex
- DHCP, ping and SSH
- Reboot and cold power cycle

Keep the original working microSD and Android
eMMC unchanged. Do not install to eMMC.

If the candidate fails, restore operation using
the previously working microSD.
