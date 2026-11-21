# Armbian Linux for TV98 H313

Independent community project for the TV98 Android TV Box.

## Hardware

- Board: CS_H313_H1_EMCP_V1.2A
- SoC: Allwinner H313 / H616 family
- RAM: 1 GB LPDDR3
- Linux boot media: microSD
- Android storage: eMMC (preserved)

## Verified Linux baseline

- Armbian-unofficial 26.02
- Debian Bookworm
- Linux kernel 6.12.64-current-sunxi64
- Custom U-Boot v2026.07 TOC0

## Ethernet V2

Verified on the TV98:

- PHY ID: 00441400
- MDIO address: 0
- Ethernet: 100 Mbps Full Duplex
- DHCP: PASS
- Ping: PASS
- SSH: PASS

The working configuration includes a modified Device Tree
and PWM5 initialization before Linux boots.

## Project roadmap

1. Preserve the working TV98 configuration.
2. Import the required build source with license attribution.
3. Add custom U-Boot TOC0 support.
4. Add Ethernet V2 and PWM5 initialization.
5. Build a reproducible Linux microSD image.
6. Publish installation and recovery documentation.

## Status

This repository starts with an independent Git history.

The existing TV98 device boots successfully.
A complete image rebuilt from this repository has not
yet been verified.

## Safety

Do not flash Android eMMC.
Do not publish private signing keys, credentials,
SSH keys or personal backup data.

## U-Boot support

See [TV98 U-Boot LPDDR3 / TOC0 documentation](docs/tv98/UBOOT.md)
for the source patch, hardware information and verification notes.

## TOC0 secure boot image

See [TOC0 signing and build documentation](docs/tv98/TOC0.md)
for the bootloader configuration, signing extension,
security considerations and verified boot procedure.

## Ethernet V2 Device Tree

See [Ethernet V2 source and test evidence](docs/tv98/ETHERNET.md).
The DTS and patch are now reproducible; kernel-source integration
and testing of the newly compiled DTB are still pending.

## PWM5 Early Boot

See [PWM5 boot commands and arguments](docs/tv98/PWM5.md). The known-good microSD configuration has been captured as an offline boot script patcher; full image build and retesting remain pending.

## Linux kernel 6.12.64 candidate

See [TV98 kernel source and build evidence](docs/tv98/KERNEL.md).
The candidate kernel has compiled successfully but has
not yet been hardware-tested on TV98.

## TV98 Debian Bookworm image

See [image assembly and hardware QA](docs/tv98/IMAGE.md).
The new image is not hardware-approved until
it passes testing on a spare microSD.
