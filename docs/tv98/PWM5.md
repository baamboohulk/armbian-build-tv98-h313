# TV98 H313: PWM5 Early Boot and Ethernet V2 boot arguments

## Hardware / known-good baseline

- PCB: `CS_H313_H1_EMCP_V1.2A` (Allwinner H313/H616 family, 1 GiB LPDDR3).
- Known-good Linux: `6.12.64-current-sunxi64`, booted from microSD.
- U-Boot: custom v2026.07 / TOC0, also on microSD.
- Android eMMC: unchanged, **never** targeted by this workflow.

## Problem

The Linux `sunxi-gmac` driver initially reported `No PHY found!`. The PHY at
MDIO address 0 (`00441400`) subsequently appeared only with the complete
Ethernet V2 boot configuration. The driver then negotiated 100 Mbps Full
Duplex and DHCP, ping and SSH were tested on hardware.

## Root cause and limitation

The exact contribution of each part of Ethernet V2 has **not** been isolated.
The working combination comprises a PWM controller Device Tree node, these
U-Boot PWM5 initialization commands, and `clk_ignore_unused` in Linux boot
arguments. It would be inaccurate to claim PWM5 alone fixes the PHY, or to
claim that the physical PHY is conclusively AC200 versus AC300.

## Working pre-kernel PWM5 script

In the TV98 U-Boot `boot.cmd`, immediately **before** the sole
`booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}`:

```bash
# TV98_ETHERNET_V2_PWM5_START
mw.l 0x030017ac 0x00010001
mw.l 0x0300a028 0x00000050
mw.l 0x0300a040 0x00200020
mw.l 0x0300a080 0x00000020
# TV98_ETHERNET_V2_PWM5_END
```

The working `/boot/armbianEnv.txt` contains both:

```text
extraargs=clk_ignore_unused
fdtfile=sun50i-h313-tv98-ethernet-v2.dtb
```

Other boot script / environment lines are deliberately not published as a
per-device dump. A board-agnostic input template is required before making a
complete reproducible build. No private MAC, SSH keys or credentials belong
in this repository.

## Verification: observed on the running TV98

Captured from the working microSD on 2026-11-20:

| File | SHA256 of working file |
| --- | --- |
| `/boot/boot.cmd` | `e064fc1b6463f0091deef74b7843adfde5c8cf2619480c4594ffe2fb197652d4` |
| `/boot/boot.scr` | `7ca5ff19334ad347dc6e203d6967487b6a1887bfd3902b40d51153133363f93a` |
| `/boot/armbianEnv.txt` | `291c3918365fa3237e4f924392ad565be5cc6820b705ca75515ac298b8b31e88` |

The running system reported `6.12.64-current-sunxi64`, root
`/dev/mmcblk0p1` (microSD), `end0 UP,LOWER_UP`, and repeated 100 Mbps
Full Duplex link messages. A temporary 10 Mbps Full Duplex event also
appeared in the log; that event was not the latest link state.

## Prepare output offline (do not alter the running SD)

From this repository, with `uboot-tools` (`mkimage`, `dumpimage`) installed:

```bash
python3 scripts/apply-tv98-pwm5-boot.py \
    --boot-cmd /path/to/reference/boot.cmd \
    --armbian-env /path/to/reference/armbianEnv.txt \
    --output-dir output/tv98-pwm5-boot
```

This is an **offline template patcher**, not yet integrated into the full
Armbian framework. It inserts the PWM5 block before the unique `booti` line,
selects the V2 DTB, adds `clk_ignore_unused` without dropping other arguments,
and generates `boot.scr` with `mkimage`. It is idempotent, checks for known
anchors and refuses conflicting existing settings.

When run against the already-working source files, the resulting `boot.cmd`
and `armbianEnv.txt` must be byte-for-byte identical. Use `dumpimage` to
confirm both the original and newly generated `boot.scr` contain the same
script payload. `boot.scr` SHA256 is not inherently reproducible because the
U-Boot legacy image header includes a creation timestamp.

## Safety, rollback, and next steps

- The repository stores the patcher and these instructions, **not** per-device
  copies of working `/boot/` files or sensitive credentials.
- Nothing here flashes a device, writes eMMC, changes kernel modules or
  modifies the operational SD.
- If the offline generated files fail validation, delete the generated files
  from the evidence directory (outside Git); the TV98 remains unaffected.
- Complete source integration and a **new microSD hardware cold-boot test**
  are outstanding. Kernel source provenance, the full Armbian build framework,
  and public clean image remain work for later commits.
- Preserve the known-good microSD; use another microSD and a rollback path
  before testing any reconstructed image on hardware.
