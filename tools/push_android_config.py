#!/usr/bin/env python3
"""Push the desktop `config` file to the device's app-private storage via adb.

Dev convenience for the CMake `run` target only -- re-pushes the same config
file every run, so there's nothing to keep in sync by hand. Not meant as the
long-term way to provision a device; see CLAUDE.md's Android section for the
underlying adb push / run-as recipe this automates.

`config` is already in the plain `KEY=value` form controller.cpp's
Controler::loadConfig() expects (no `export`, no surrounding quotes -- it
splits on the first '=' and only trims whitespace), so this just validates
the required keys are present and pushes it through as-is.

    python3 tools/push_android_config.py --config config \
        --package org.qtproject.example.qthomeassistant --out build/.../config
"""

import argparse
import subprocess
import sys
from pathlib import Path


def parse_config(text):
    values = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--out", required=True, type=Path,
                         help="local path to copy the config file to before pushing it")
    parser.add_argument("--adb", default="adb")
    args = parser.parse_args()

    if not args.config.is_file():
        sys.exit(f"{args.config} not found -- can't derive HASS_URL/HASS_TOKEN for the device")

    text = args.config.read_text()
    values = parse_config(text)
    missing = [key for key in ("HASS_URL", "HASS_TOKEN") if key not in values]
    if missing:
        sys.exit(f"{args.config} is missing {', '.join(missing)}")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text)

    subprocess.run([args.adb, "push", str(args.out), "/data/local/tmp/config"], check=True)

    # `adb shell` joins all args after "shell" with spaces before it ever reaches
    # the device, so passing sh/-c/"cmd" as separate argv elements loses the
    # quoting that ties "cmd" to -c -- the device's outer shell then splits it
    # back up on its own, and run-as's `sh -c` only sees the first word. Passing
    # one pre-quoted string sidesteps that: nothing left to rejoin.
    remote_cmd = (
        f"run-as {args.package} sh -c "
        "'mkdir -p files/qt-hass && cp /data/local/tmp/config files/qt-hass/config'"
    )
    subprocess.run([args.adb, "shell", remote_cmd], check=True)


if __name__ == "__main__":
    main()
