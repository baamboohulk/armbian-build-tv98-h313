# TV98 H313 - BCM43342 Wi-Fi

Board: CS_H313_H1_EMCP_V1.2A
Kernel tested: 6.12.64-legacy-sunxi64

## Source fixes

- Add BCM43342 support to brcmfmac
- Set Wi-Fi pwrseq clock name to `ext_clock`
- Assign the PG10 32 kHz clock pinctrl
- Preserve the original 150 MHz SDIO configuration
- Remove the incompatible AW859A extension

## Verified on physical TV98

- BCM43342 firmware initialization: PASS
- wlan0 interface: PASS
- Wi-Fi scan: PASS (47 APs)
- WPA association: PASS
- DHCP: PASS
- Wi-Fi Internet ping: PASS
- Short stability test: 5/5 PASS
- Ethernet and SSH: PASS

Known-good device DTB SHA256:
a6916f0160867aafd601e6f42a26444fa79c439ba6e50d9d0de5822e3a5f4e45

## Pending acceptance

- Wi-Fi automatic reconnect after reboot
- Extended stability
- Rebuilt image verification
- Bluetooth initialization and hardware tests

This is a tested source checkpoint, not a finished image release.
Do not commit passwords, private keys, device-specific
credentials, or proprietary firmware binaries.
