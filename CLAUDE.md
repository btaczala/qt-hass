# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Qt 6 / QML Home Assistant dashboard (`qthomeassistant`) that talks to HA over its WebSocket API. Targets desktop (macOS) and Android (fullscreen when `platform == "android"`, plus `/sdcard` search paths).

## Build, run, lint

Requires Qt ≥ 6.10 (Gui, Quick, QuickControls2, Multimedia, WebSockets), Python 3 (used at configure time), CMake, Ninja.

```sh
cmake -S . -B build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=$HOME/Qt/6.10.1/macos
cmake --build build/debug
cmake --build build/debug --target all_qmllint   # qmllint over the QML module
```

On this machine a gitignored `CMakeUserPresets.json` provides `cmake --preset user-qt-debug` (same `build/debug` dir, which `.qmlls.ini` and the `compile_commands.json` symlink point at). Its `user-qt-release` preset names `~/Qt/6.7.0/gcc_64`, which doesn't exist here, so it silently configures against Homebrew Qt (`/opt/homebrew`) instead. If the Qt version matters, check `Qt6_DIR` in `CMakeCache.txt`.

Run (macOS bundle). The app reads `HASS_URL` (e.g. `wss://host/api/websocket`; `ws://` for plain HTTP) and `HASS_TOKEN` (long-lived access token) from the environment. They live in `.envrc`, which contains the real token and is only kept out of git by a global ignore (the repo has no `.gitignore`). A non-interactive shell won't load it, so use:

```sh
direnv exec . build/debug/qthomeassistant.app/Contents/MacOS/qthomeassistant
```

Verbose logs: `QT_LOGGING_RULES="qthass.*.debug=true"` (categories `qthass.api`, `qthass.controller`).

There are no tests.

## Architecture

### Two-tier QML loading

- `qml/**` is compiled into the `QtHomeAssistant` QML module and embedded under `qrc:/res/QtHomeAssistant/qml/...`. Every new QML/JS file must be added to `QML_FILES` in `CMakeLists.txt`, and changes need a rebuild.
- `default_dashboard/Dashboard.qml` is **not** in the module. `qml/Main.qml` loads it from the filesystem via `Controler.pathFor("default_dashboard/Dashboard.qml")`, which searches `SOURCE_DIRECTORY` (baked in at compile time), `/usr/share/qt-hass`, then `/sdcard/qt-hass`. Edits to it only need an app restart. This is also why it imports cards by absolute path (`import 'qrc:/res/QtHomeAssistant/qml/Cards'`).
- The dashboard `Loader` is `active: HassAPI.connected`, so no entity components exist until auth succeeds. It is torn down again on disconnect.

### C++ singletons exposed to QML (`QML_SINGLETON`, registered via `qt_add_qml_module` SOURCES)

- **`HassAPI`** (`hassapi.{h,cpp}`) owns the `QWebSocket`. Flow: `connect()` → `auth_required` → send token → `auth_ok` sets `connected`. Incoming messages are dispatched by `type` through `message_handlers_`.
  - `registerStateChanges(entity_id, jsFunction)` stores the callback and sends a per-entity `subscribe_entities`. It deliberately avoids `get_states`: that payload is several MB and trips QWebSocket's incomplete-frame timeout (close code 1001). Registrations made before connect are subscribed on `auth_ok`. Late registrations for an already-subscribed entity get the cached state replayed.
  - Events use HA's compressed format (`a` added / `c` `+`/`-` diff / `r` removed), rebuilt into full per-entity state in `entity_states_`.
  - **Callback contract:** callbacks receive a JSON *string* of `{entity_id, state, attributes}`, so QML must `JSON.parse` it. There is no `type: "event"` wrapper, so the `j['type'] === 'event'` branch in `Light.qml` never runs.
  - Service calls are hand-written slots. `light(entity_id, on)` is currently the only one; new domains should follow its `call_service` pattern.
- **`Controler`** (`controller.{h,cpp}`; note the single-`l` spelling, which QML uses too) provides `pathFor()`, a 60 s idle timer emitting `idle(bool)` (reset by an event filter that `main.cpp` installs on the root window), and an `error(QString)` signal. `configurationPath` / `loadConfig` are unimplemented stubs.
- **`Mdi`** (`src/mdi.{h,cpp}`) resolves Material Design Icon names as HA sends them (`"mdi:lightbulb-on"`, aliases included) to glyphs in the bundled webfont. It loads the font itself and exposes the registered `fontFamily` (never hardcode it). Unknown names render `help-circle-outline` and warn once. Use it via `qml/MdiIcon.qml` (`icon`, `iconSize`).

### Entity cards

Cards extend `qml/EntityBase.qml`: set `required property string entity_id` and assign the `update` function property, which EntityBase registers with `HassAPI` in `Component.onCompleted`. See `qml/Light.qml` and `qml/Cards/Weather.qml`.

### MDI table generation

`tools/generate_mdi_table.py` runs at **configure time** (`execute_process`) and writes `build/*/generated/mdi_icons_data.h`, a sorted name→codepoint table. It is generated, never committed. It cross-checks every codepoint against the font's cmap and fails configure on mismatch. Its inputs `fonts/materialdesignicons-webfont.ttf` and `fonts/materialdesignicons-meta.json` are vendored. To upgrade MDI (the only networked step): `python3 tools/generate_mdi_table.py --fetch <version>`. Currently 7.4.47.

### CMake gotchas (already handled, don't undo)

- `qtquickcontrols2.conf` is added with a separate `qt_add_resources(... PREFIX "/")`. Qt only reads it from `:/qtquickcontrols2.conf`, and inside the QML module's resources the Material style silently doesn't apply.
- `src/` is on the include path because the generated QML type registration includes headers by basename.

## Not part of the build / leftovers

- `HassAPI/CMakeLists.txt`: never `add_subdirectory`'d, references a nonexistent `HassAPI.js`.
- `qml/Icon.js`: old MDI name table, superseded by the `Mdi` singleton (still compiled in).
- `qml/IconImage.qml`: references a missing `qt_logo_green_rgb.png`, yet is instantiated in `Main.qml`.
- `images/lightbulb*.svg`: listed in RESOURCES but referenced nowhere.
- `dashboard.html`: standalone HTML page, not used by the app.
- `3rdParty/` (untracked, local only): leftover `CustomBrandsIcons` module from the removed submodules, not referenced by CMake.

## Conventions

No formatter config. C++: 2-space indent, trailing-underscore members (`socket_`), module-qualified Qt includes (`<QtCore/QObject>`), `qC*` logging categories, C++23. QML: 4-space indent.
