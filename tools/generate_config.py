#!/usr/bin/env python3
"""Generate the bundled app config from .envrc and/or a `config` file.

Runs at CMake configure time; the output is compiled into the binary as the
:/qt-hass/config resource that Controler reads. Always writes into the build
directory, never the source tree -- the file holds the real access token and
passwords.

    python3 tools/generate_config.py --envrc .envrc --config config \
        --out build/.../generated/config

Both inputs are optional: .envrc holds `export KEY="value"` lines, `config`
plain `KEY=value` lines, and a key set in both takes its `config` value. Missing
HASS_URL/HASS_TOKEN only warns, so a fresh checkout still configures; the
environment variables then have to be set at runtime instead.
"""

import argparse
import re
import sys
from pathlib import Path

# Keys Controler understands. Anything else in the inputs is left out, so an
# .envrc full of unrelated exports doesn't end up embedded in the binary.
KEYS = (
    "HASS_URL",
    "HASS_TOKEN",
    "DASHBOARD_URL",
    "IDLE_TIMEOUT_SECONDS",
    "REMOTE_ADMIN_PASSWORD",
    "REMOTE_ADMIN_PORT",
    "MQTT_BROKER_HOST",
    "MQTT_BROKER_PORT",
    "MQTT_USERNAME",
    "MQTT_PASSWORD",
)
REQUIRED = ("HASS_URL", "HASS_TOKEN")

# The config file controller.cpp reads is plain `KEY=value` -- no `export`, no
# surrounding quotes (it splits on the first '=' and only trims whitespace, so a
# literal quote in the value would end up as part of the URL/token).
ENVRC_LINE = re.compile(r'^export\s+(\w+)\s*=\s*(.*)$')


def unquote(value):
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def parse_envrc(text):
    values = {}
    for line in text.splitlines():
        match = ENVRC_LINE.match(line.strip())
        if match:
            values[match.group(1)] = unquote(match.group(2).strip())
    return values


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
    parser.add_argument("--envrc", type=Path)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    values = {}
    if args.envrc and args.envrc.is_file():
        values.update(parse_envrc(args.envrc.read_text()))
    if args.config and args.config.is_file():
        values.update(parse_config(args.config.read_text()))

    missing = [key for key in REQUIRED if key not in values]
    if missing:
        print(f"missing {', '.join(missing)} in .envrc/config -- the bundled "
              "config won't provide them", file=sys.stderr)

    content = "".join(f"{key}={values[key]}\n" for key in KEYS if key in values)

    # Only touch the file when it changes, so reconfiguring doesn't force rcc
    # to re-embed it and relink.
    if args.out.is_file() and args.out.read_text() == content:
        return
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(content)


if __name__ == "__main__":
    main()
