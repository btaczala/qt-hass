#!/usr/bin/env python3
"""Generate the bundled HASS config from .envrc.

Runs at CMake configure time; the output is compiled into the binary as the
:/qt-hass/config resource that Controler reads. Always writes into the build
directory, never the source tree -- the file holds the real access token.

    python3 tools/generate_config.py --envrc .envrc --out build/.../generated/config

A missing .envrc (or missing keys) still produces an empty config so a fresh
checkout configures; HASS_URL/HASS_TOKEN from the environment then have to be
set at runtime instead.
"""

import argparse
import re
import sys
from pathlib import Path

# .envrc holds `export KEY="value"` (or unquoted); the config file controller.cpp
# reads is plain `KEY=value` -- no `export`, no surrounding quotes (it splits on
# the first '=' and only trims whitespace, so a literal quote in the value would
# end up as part of the URL/token).
ENVRC_LINE = re.compile(r'^export\s+(\w+)\s*=\s*(.*)$')
KEYS = ("HASS_URL", "HASS_TOKEN")


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
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    values = parse_envrc(args.envrc.read_text()) if args.envrc.is_file() else {}
    missing = [key for key in KEYS if key not in values]
    if missing:
        print(f"{args.envrc}: missing {', '.join(missing)} -- the bundled config "
              "won't provide them", file=sys.stderr)

    content = "".join(f"{key}={values[key]}\n" for key in KEYS if key in values)

    # Only touch the file when it changes, so reconfiguring doesn't force rcc
    # to re-embed it and relink.
    if args.out.is_file() and args.out.read_text() == content:
        return
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(content)


if __name__ == "__main__":
    main()
