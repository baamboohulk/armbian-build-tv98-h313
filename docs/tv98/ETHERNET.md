# TV98 H313 Ethernet V2 - Device Tree source

## Hardware and tested baseline

- PCB: CS_H313_H1_EMCP_V1.2A
- Kernel: 6.12.64-current-sunxi64
- Bootloader: custom U-Boot v2026.07 TOC0, on microSD

## Problem and verified result

Original Linux initially reported `sunxi-gmac: No PHY found!`.
With the complete working V2 boot setup, the PHY is eventually
recognized as `00441400` at MDIO address 0, link is 100 Mbps Full
Duplex, and DHCP/ping/SSH pass.

## Actual configuration changes

The working configuration includes all three:

1. An added `/soc/pwm@300a000` Device Tree node.
2. PWM5 initialization in the U-Boot `boot.scr` script.
3. `clk_ignore_unused` in boot arguments.

These changes were tested together. The separate necessity of
any single change has **not** been isolated.

## Source provenance and checksums

These DTS files were reconstructed from the verified Device Tree
binaries on the working microSD, then canonicalized with `dtc`.

- Original DTB SHA256: `e094dbf173906c0c1507789bdd036eeda05889fbe6067b8e6b7ea0baf39ffbc7`
- Working V2 DTB SHA256: `226c19e3904658444da11d7eddc61ba9fc3267ab2da1c3c26fe60d0e9ad7d6e5`

The original binary includes a device-specific Wi-Fi MAC address.
`local-mac-address` was removed from both public DTS files.
Therefore the rebuilt DTB is **not byte-for-byte identical** to the
original working binary and has **not yet been tested on hardware**.

The patch in `device-tree/tv98/patches/` adds the PWM node to this
**decompiled baseline DTS**. It is not yet a Linux kernel source patch.

## Build and test

On Arch Linux:

```sh
sudo pacman -S --needed dtc patch
bash scripts/build-tv98-ethernet-v2-dtb.sh
```

The output is `output/sun50i-h313-tv98-ethernet-v2.dtb` (Git-ignored).
The build script checks that the generated Device Tree round-trips
through `dtc` without semantic or formatting drift.

**Do not replace** the working DTB with this rebuilt file yet.
A kernel-source integration and a fresh microSD boot test are pending.

## Safety and licensing

Never write to Android eMMC. No private device MAC, keys, or personal
backups belong in the public repository. When integrating with the
Linux kernel, retain the original DTS copyrights and licenses.
