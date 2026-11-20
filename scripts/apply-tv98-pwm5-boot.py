#!/usr/bin/env python3
"""Prepare TV98 PWM5 boot configuration in a separate output directory.

This program never writes to the input files, block devices, or the TV98.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

FDT = b"sun50i-h313-tv98-ethernet-v2.dtb"
ARG = b"clk_ignore_unused"
ANCHOR = b"booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}"
BLOCK = b"\n".join((
    b"# TV98_ETHERNET_V2_PWM5_START",
    b"mw.l 0x030017ac 0x00010001",
    b"mw.l 0x0300a028 0x00000050",
    b"mw.l 0x0300a040 0x00200020",
    b"mw.l 0x0300a080 0x00000020",
    b"# TV98_ETHERNET_V2_PWM5_END",
)) + b"\n"


def patch_boot(content: bytes) -> bytes:
    if b"\r" in content or b"\x00" in content:
        raise ValueError("boot.cmd must be a plain LF-terminated text file")
    if content.count(ANCHOR) != 1:
        raise ValueError("expected exactly one booti anchor; refuse to guess")
    if content.count(BLOCK) == 1:
        if content.find(BLOCK) > content.find(ANCHOR):
            raise ValueError("existing PWM5 block is after booti")
        if content.count(b"TV98_ETHERNET_V2_PWM5_START") != 1:
            raise ValueError("duplicate PWM5 marker")
        return content
    if b"TV98_ETHERNET_V2_PWM5_START" in content or b"TV98_ETHERNET_V2_PWM5_END" in content:
        raise ValueError("unexpected or partial PWM5 block; refusing replacement")
    # The original boot.cmd is preserved; the new source is written only to output/.
    return content.replace(ANCHOR, BLOCK + b"\n" + ANCHOR, 1)


def patch_env(content: bytes) -> bytes:
    if b"\r" in content or b"\x00" in content:
        raise ValueError("armbianEnv.txt must be plain LF-terminated text")
    lines = content.splitlines(keepends=True)
    if any(line and not line.endswith(b"\n") for line in lines):
        raise ValueError("armbianEnv.txt must end with a newline")
    fdt_lines = [i for i, line in enumerate(lines) if line.startswith(b"fdtfile=")]
    extra_lines = [i for i, line in enumerate(lines) if line.startswith(b"extraargs=")]
    if len(fdt_lines) > 1 or len(extra_lines) > 1:
        raise ValueError("duplicate fdtfile or extraargs keys")
    if fdt_lines:
        if lines[fdt_lines[0]] != b"fdtfile=" + FDT + b"\n":
            raise ValueError("existing fdtfile is not the verified TV98 Ethernet V2 DTB")
    else:
        lines.append(b"fdtfile=" + FDT + b"\n")
    if extra_lines:
        idx = extra_lines[0]
        value = lines[idx][len(b"extraargs="):].rstrip(b"\n")
        parts = value.split()
        if ARG not in parts:
            lines[idx] = b"extraargs=" + (value + b" " if value else b"") + ARG + b"\n"
    else:
        lines.append(b"extraargs=" + ARG + b"\n")
    return b"".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--boot-cmd", type=Path, required=True)
    parser.add_argument("--armbian-env", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    src_boot = args.boot_cmd.resolve(strict=True)
    src_env = args.armbian_env.resolve(strict=True)
    out = args.output_dir.resolve()
    output_boot = out / "boot.cmd"
    output_env = out / "armbianEnv.txt"
    if src_boot == output_boot or src_env == output_env:
        raise SystemExit("output must not overwrite an input file")
    out.mkdir(parents=True, exist_ok=True)
    output_boot.write_bytes(patch_boot(src_boot.read_bytes()))
    output_env.write_bytes(patch_env(src_env.read_bytes()))
    output_scr = out / "boot.scr"
    subprocess.run([
        "mkimage", "-C", "none", "-A", "arm", "-T", "script",
        "-d", str(output_boot), str(output_scr),
    ], check=True, stdout=subprocess.DEVNULL)
    print("TV98_PWM5_BOOT_CONFIG=GENERATED_OFFLINE")
    print("OUTPUT_DIR=" + str(out))
    print("NO_DEVICE_WRITE=YES")


if __name__ == "__main__":
    main()
