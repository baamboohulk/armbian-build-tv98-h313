# TV98 H313 - U-Boot TOC0 Signing

## Problem

The original SD bootloader configuration did not
successfully boot Linux on the tested TV98 hardware.

The original Android eMMC bootloader used a TOC0.GLH
header, while the earlier Armbian SD image used eGON.BT0.

A compatible custom TOC0 U-Boot was subsequently built
and verified to boot Linux from microSD.

The difference in image headers alone does not prove
which hardware security mechanisms are enabled.

## Tested hardware

- Board: CS_H313_H1_EMCP_V1.2A
- SoC: Allwinner H313 / H616 family
- RAM: 1 GB LPDDR3
- Boot device: microSD
- Original Android eMMC: preserved

## Source revisions

- Armbian build framework:
  eadca54dc8d891d3ddc159d70c90ca903fdb9c1e

- U-Boot v2026.07:
  ece349ade2973e220f524ce59e59711cc919263f

These revisions were recorded from the original
development environment and build logs.

## TOC0 configuration

The U-Boot board patch contains:

    CONFIG_SPL_IMAGE_TYPE_SUNXI_TOC0=y

The companion build extension is:

    userpatches/extensions/tv98-toc0-key.sh

The extension uses Armbian's
pre_config_uboot_target hook.

It prepares the RSA signing key as root_key.pem
in the U-Boot build working directory.

If the local userpatches signing key is absent,
the preserved extension can generate one.

## Security

The private signing key is NOT stored in Git.

Expected local-only key:

    userpatches/tv98-root-key.pem

Do not commit or publish:

- RSA private keys
- U-Boot signing secrets
- SSH private keys
- Original Android firmware dumps
- Private build configuration or credentials

Generating a different RSA key may change the
resulting signed binary. Acceptance of that key
by another device is not guaranteed.

## Previously successful build command

Run from the original Armbian build framework:

    ./compile.sh uboot BOARD=x96q BRANCH=current \
      PREFER_DOCKER=yes \
      ARTIFACT_IGNORE_CACHE=yes \
      ENABLE_EXTENSIONS=tv98-toc0-key \
      SET_OWNER_TO_UID="$(id -u)"

This is the historical successful build procedure.

It is NOT yet a complete standalone build procedure
for this new repository.

## Validation

The historical build produced:

    u-boot-sunxi-with-spl.bin

The binary was verified to contain TOC0.GLH,
and the configured SPL used the sunxi TOC0 format.

The bootloader was written to microSD at offset
8192 bytes and verified by reading it back.

Physical TV98 boot testing subsequently passed:

- U-Boot start from microSD
- Armbian Linux boot
- Linux root filesystem from microSD
- UART console

Ethernet V2 is a separate Device Tree and
early-boot initialization change.

## Rebuild status

The signing extension is preserved from the
working source tree.

A clean rebuild from this standalone repository
is still pending integration of the full Armbian
build framework and board configuration.

## Recovery

Do not write to the Android eMMC or eFuses.

Keep the known-working microSD bootloader
until a replacement has passed cold-boot tests.

## References

- https://linux-sunxi.org/TOC0
- https://docs.armbian.com/build-framework/extensions/
- https://github.com/u-boot/u-boot
- https://github.com/armbian/build
