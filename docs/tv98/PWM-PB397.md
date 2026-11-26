# TV98 H313/H616 - Pb397 hardware validation

Validation date: 2026-11-26

## Target hardware

- PCB: CS_H313_H1_EMCP_V1.2A
- SoC: Allwinner H313/H616
- RAM: 1 GiB LPDDR3
- Internal storage: 8 GB nominal eMMC
- Distribution: Armbian Debian Bookworm minimal
- Kernel: 6.12.64-legacy-sunxi64
- Build identifier: Pb397

## Kernel and Device Tree changes

- Register TV98 kernel patches in the Armbian patch series.
- Preserve the BT-26 RTC auto-calibration patch.
- Correct the vendor PWM driver's probe/remove lifetime.
- Register the six PWM child nodes.
- Assign PA12 pinctrl to the PWM controller.
- Preserve PWM5 clock initialization for Ethernet.
- Preserve BCM43342 Wi-Fi and Bluetooth configuration.

PWM5 is reserved for the Ethernet clock.
Do not export or reconfigure its period or duty cycle.

## Build and image assembly

Use the matching Armbian framework and the verified
Pb397 kernel and DTB packages.

Compile the board Device Tree:

    dtc -I dts -O dtb \
        -o tv98-pa12.dtb \
        device-tree/tv98/sun50i-h313-tv98-ethernet-v2.dts

The validated assembler invocation is:

    bash scripts/assemble-tv98-bookworm-image.sh \
        SOURCE_IMG UBOOT_BIN BOOT_EVIDENCE_DIR \
        tv98-pa12.dtb OUTPUT_IMG KERNEL_DEB DTB_DEB

The uppercase arguments are local artifact paths.

The legacy five-argument invocation does not install
the Pb397 kernel and is not the validated Pb397 workflow.

The current assembler is pinned to the tested input
hashes and filesystem profile. It is not a general-purpose
assembler for arbitrary Armbian images or kernel versions.

## Validated artifact hashes

Custom DTB:
7b1029baec3dfdaaa6e001c8ba9a3e37e1aacfe81a1c2478a66d0401632e8fef

Kernel package:
a870ffbafc7aca732aec431f728469d3b71d6c5da422b051ced7eec6c2ed4000

DTB package:
1d83bf74ee04afefacddf8073a2eb720d202b1ed5695c5f2e2d2d8e33540c4a5

Private QA image:
560ec8a5976abb1c0c130025d83c21809143f3ed011b66179f0cfd73c3832e55

Image hashes are not expected to be identical across
independent builds containing generated timestamps.

## Hardware validation

| Test | Result |
| --- | --- |
| microSD image readback SHA256 | PASS |
| U-Boot and cold boot | PASS |
| PWM driver binding | PASS |
| PA12 pinmux | PASS |
| AC200 Ethernet PHY | PASS |
| Ethernet 100 Mbps full duplex | PASS |
| Ethernet DHCP and Internet | PASS |
| BCM43342 Wi-Fi scan | PASS |
| Wi-Fi association and DHCP | PASS |
| Wi-Fi Internet connectivity | PASS |
| Bluetooth BCM43342A1 firmware build 0987 | PASS |
| Bluetooth device discovery | PASS |
| Bluetooth pairing on Pb397 | Not retested |
| RTC and NTP synchronization | PASS |
| CPU OPP table 480 MHz to 1.2 GHz | PASS |
| SSH password authentication | PASS |
| First-login password setup | PASS |
| Login after cold boot | PASS |

Bluetooth pairing was previously validated on BT-26.
It was not repeated on the final Pb397 image.

Pb397 has been validated on removable media.
Deployment to internal eMMC remains pending.

## Kernel update precautions

The assembler extracts the validated kernel packages
into the image. Package-manager metadata must not
be treated as proof of the active kernel build.

Until a maintained TV98 package upgrade channel exists,
protect the installed kernel and DTB packages:

    sudo apt-mark hold linux-image-legacy-sunxi64 \
        linux-dtb-legacy-sunxi64

    apt-mark showhold

Do not blindly run a kernel upgrade or armbian-upgrade.
Continue reviewing Debian security updates independently.

Kernel holds are a temporary compatibility safeguard,
not a replacement for security maintenance.

## Firmware and distribution

BCM43342 firmware is supplied by armbian-firmware.
The assembler verifies the original firmware and creates
the board-specific firmware alias when required.

No proprietary firmware binary is added to this source
repository.

The redistribution rights of the exact firmware payload
must be verified before publishing a complete image.

Do not publish private TOC0 signing keys, raw Android
dumps, device backups, credentials or private boot evidence.

## Image privacy and release status

The private QA image is not approved for public download.

Before distributing a binary image, review embedded root
password hashes, SSH host keys, machine identity, filesystem
UUID handling, credentials, login records, build artifacts,
and applicable licenses.

A different SSH host key was observed after the tested
first-boot procedure. This does not replace a complete
public-image security audit.

Source validation and binary redistribution approval
are separate release gates.
