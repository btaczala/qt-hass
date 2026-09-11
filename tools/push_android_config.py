#!/usr/bin/env python3
"""Regenerate the Android on-device config from .envrc and push it via adb.

Dev convenience for the CMake `run` target only -- re-derives HASS_URL/HASS_TOKEN
from .envrc on every run, so there's nothing to keep in sync by hand. Not meant as
the long-term way to provision a device; see CLAUDE.md's Android section for the
underlying adb push / run-as recipe this automates.

    python3 tools/push_android_config.py --envrc .envrc \
        --package org.qtproject.example.qthomeassistant --out build/.../config
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

# .envrc holds `export KEY="value"` (or unquoted); the on-device config file
# controller.cpp reads is plain `KEY=value` -- no `export`, no surrounding quotes
# (it splits on the first '=' and only trims whitespace, so a literal quote in the
# value would end up as part of the URL/token).
ENVRC_LINE = re.compile(r'^export\s+(\w+)\s*=\s*(.*)$')


def parse_envrc(text):
    values = {}
    for line in text.splitlines():
        match = ENVRC_LINE.match(line.strip())
        if not match:
            continue
        key, value = match.group(1), match.group(2).strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key] = value
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--envrc", required=True, type=Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--out", required=True, type=Path,
                         help="local path to write the config file before pushing it")
    parser.add_argument("--adb", default="adb")
    args = parser.parse_args()

    if not args.envrc.is_file():
        sys.exit(f"{args.envrc} not found -- can't derive HASS_URL/HASS_TOKEN for the device")

    values = parse_envrc(args.envrc.read_text())
    missing = [key for key in ("HASS_URL", "HASS_TOKEN") if key not in values]
    if missing:
        sys.exit(f"{args.envrc} is missing {', '.join(missing)}")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(f"HASS_URL={values['HASS_URL']}\nHASS_TOKEN={values['HASS_TOKEN']}\n")

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
