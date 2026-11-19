# TV98 H313 — U-Boot LPDDR3 / TOC0

## Hardware

- PCB: CS_H313_H1_EMCP_V1.2A
- SoC: Allwinner H313/H616 family
- RAM: 1 GB LPDDR3
- Boot media: microSD
- Android eMMC: preserved

## Original problem

The previous SD bootloader configuration did not
successfully boot Armbian Linux on this TV98 board.

The working configuration uses custom U-Boot v2026.07
with board-specific LPDDR3 and TOC0 boot support.

## Source provenance

- Original build environment: armbian-toc0
- Armbian framework HEAD: eadca54dc8d891d3ddc159d70c90ca903fdb9c1e
- U-Boot worktree HEAD: unavailable
- Patch: patch/u-boot/v2026.07-sunxi64/board_x96q/0001-add-x96q-lpddr3-dt-and-defconfig.patch
- Patch SHA256: b0b42fc1ad5dfcf8d9c086eed75705bec0e5759ab367c07ef9ae873d13709231

Upstream references:

- https://github.com/armbian/build
- https://github.com/sicXnull/armbian-build
- https://github.com/u-boot/u-boot

## Changes

This commit preserves the U-Boot source patch from
the working TV98 development environment.

The patch is preserved without modification.

TOC0 image assembly/signing and Ethernet V2 boot
initialization are separate integration steps.

## Verification

Previously verified on physical TV98 hardware:

- Custom U-Boot starts from microSD
- Armbian Linux 6.12.64 boots
- Serial console works
- Root filesystem loads from microSD

A clean rebuild from this new standalone repository
has not yet been verified.

## Recovery

Keep a verified working microSD backup.

Never overwrite the original Android eMMC.

Never publish TOC0 private signing keys,
SSH private keys, credentials, or Android dumps.
