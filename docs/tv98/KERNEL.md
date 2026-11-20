# TV98 H313 - Linux kernel 6.12.64 candidate

## Scope

Source-based candidate build for TV98 PCB
CS_H313_H1_EMCP_V1.2A (1 GiB LPDDR3).

This is NOT a hardware-verified replacement for the
working microSD kernel 6.12.64-current-sunxi64.

## Source provenance

- Framework: sicXnull/armbian-build
- Framework revision: eadca54dc8d891d3ddc159d70c90ca903fdb9c1e
- Kernel source: Linux stable, tag v6.12.64
- Build source HEAD: 1a4a7249e794de9e022baabe6387d9c0f831b0be
- Historical driver: Armbian commit 01176b0150940dca466b7ffdf18336541eb717ff
- Original patch author: chraac
- Historical patch SHA256: 907bdf9f2b64ac957e5786e073c8c7052b0e3ac5f8c8b16aed0e0b353e46bccf
- Reconstructed sunxi-gmac.c SHA256: 5b6d81ae775a6f5086e5a58d08046df8e27d836e46a32b75c6378043597f9994

Preserve original copyright, source attribution and
applicable upstream licenses. No Git history is imported.

## Build preparation

Use scripts/apply-tv98-kernel-61264.sh with a clean,
disposable Armbian framework worktree at the exact
framework revision above.

Do not run that script against the original armbian-toc0
tree or the working TV98 microSD.

## Build command

Run as a normal user with working Docker:

    ./compile.sh kernel BOARD=x96q BRANCH=legacy KERNELBRANCH=tag:v6.12.64 KERNEL_CONFIGURE=no PREFER_DOCKER=yes ARTIFACT_IGNORE_CACHE=yes SET_OWNER_TO_UID="$(id -u)"

## Candidate build results

- Kernel release: 6.12.64-legacy-sunxi64
- Kernel image package SHA256:
  3815860c21a806705798b8a5aa7a136289c16e18ee78f7e10d9e414c3256be97
- Kernel DTB package SHA256:
  caa377e4187c4b82b0c594dbc2cbdb9bec4730be25414373638ab2b718b61718
- sunxi_gmac.ko: compiled, vermagic PASS
- sunxi-ephy.ko: present
- AC200 and PWM modules: present
- Reconstructed Ethernet driver source: SHA256 MATCH

These results describe one successful local build.
Bit-for-bit reproducibility on another host has
not yet been demonstrated.

## Known limitations

The working hardware baseline uses
6.12.64-current-sunxi64, while this candidate uses
6.12.64-legacy-sunxi64.

The Ethernet V2 DTB, PWM5 U-Boot initialization and
clk_ignore_unused must be integrated and tested
together in a later image build.

Do not mix modules from current and legacy kernels.
Do not overwrite the working microSD or Android eMMC.

Hardware testing of the newly built kernel is pending.
