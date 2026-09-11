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

### Android

On this machine: Android Studio + `android-commandlinetools` (Homebrew casks) provide the SDK, rooted at `/opt/homebrew/share/android-commandlinetools`; NDK r27c (`ndk;27.3.13750724`) matches what the `~/Qt/6.10.1/android_arm64_v8a` kit was built against (check `qt.toolchain.cmake`'s `__qt_initially_configured_toolchain_file` if that ever changes); JDK 17 (`temurin@17`) is required for Gradle 8.14.3/AGP 8.10.1 — the system default JDK can stay newer, just override `JAVA_HOME` for the build.

```sh
export ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools
export ANDROID_NDK_ROOT=$ANDROID_SDK_ROOT/ndk/27.3.13750724
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

cmake -S . -B build/android-arm64 -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$HOME/Qt/6.10.1/android_arm64_v8a/lib/cmake/Qt6/qt.toolchain.cmake" \
  -DQT_HOST_PATH="$HOME/Qt/6.10.1/macos" \
  -DANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
  -DANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" \
  -DCMAKE_PREFIX_PATH="$HOME/Qt/6.10.1/android_arm64_v8a" \
  -DQT_ANDROID_ABIS=arm64-v8a \
  -DCMAKE_BUILD_TYPE=Debug
cmake --build build/android-arm64 --target apk
```

The AVD (`qthass`, Pixel 6 profile, `system-images;android-34;google_apis;arm64-v8a`) was created with `avdmanager create avd`; `avdmanager list avd`'s `devices.xml` lookup errors on this SDK layout but the AVD still gets created fine. Launch with `emulator -avd qthass`, then:

```sh
adb install -r build/android-arm64/android-build/build/outputs/apk/debug/android-build-debug.apk
adb shell am start -n org.qtproject.example.qthomeassistant/org.qtproject.qt.android.bindings.QtActivity
adb logcat -s libqthomeassistant_arm64-v8a.so qthass.api:D qthass.controller:D
```

There's no `.envrc` equivalent on Android, so before starting the activity, push a `HASS_URL=...`/`HASS_TOKEN=...` file into the app's private storage (`adb push` can't reach it directly since that uid isn't `shell`):

```sh
adb push config /data/local/tmp/config
adb shell run-as org.qtproject.example.qthomeassistant sh -c \
  'mkdir -p files/qt-hass && cp /data/local/tmp/config files/qt-hass/config'
```

See `Controler` below for why `/data/user/0/.../files` and not `/sdcard`.

## Architecture

### Two-tier QML loading

- `qml/**` is compiled into the `QtHomeAssistant` QML module and embedded under `qrc:/res/QtHomeAssistant/qml/...`. Every new QML/JS file must be added to `QML_FILES` in `CMakeLists.txt`, and changes need a rebuild.
- `default_dashboard/Dashboard.qml` is **not** in the module. `qml/Main.qml` loads it from the filesystem via `Controler.pathFor("default_dashboard/Dashboard.qml")`, which searches `SOURCE_DIRECTORY` (baked in at compile time), `/usr/share/qt-hass`, then `/sdcard/qt-hass`. Edits to it only need an app restart. This is also why it imports cards by absolute path (`import 'qrc:/res/QtHomeAssistant/qml/Cards'`). The `/sdcard/qt-hass` fallback is unverified on API 30+: scoped storage blocked the same convention for `Controler`'s config file (see below) regardless of granted `READ_EXTERNAL_STORAGE`, and this Loader path is only reachable once `HassAPI.connected` is true, so it's never actually been exercised on a modern Android version.
- The dashboard `Loader` is `active: HassAPI.connected`, so no entity components exist until auth succeeds. It is torn down again on disconnect.

### C++ singletons exposed to QML (`QML_SINGLETON`, registered via `qt_add_qml_module` SOURCES)

- **`HassAPI`** (`hassapi.{h,cpp}`) owns the `QWebSocket`. Flow: `connect()` → `auth_required` → send token → `auth_ok` sets `connected`. Incoming messages are dispatched by `type` through `message_handlers_`.
  - `registerStateChanges(entity_id, jsFunction)` stores the callback and sends a per-entity `subscribe_entities`. It deliberately avoids `get_states`: that payload is several MB and trips QWebSocket's incomplete-frame timeout (close code 1001). Registrations made before connect are subscribed on `auth_ok`. Late registrations for an already-subscribed entity get the cached state replayed.
  - Events use HA's compressed format (`a` added / `c` `+`/`-` diff / `r` removed), rebuilt into full per-entity state in `entity_states_`.
  - **Callback contract:** callbacks receive a JSON *string* of `{entity_id, state, attributes}`, so QML must `JSON.parse` it. There is no `type: "event"` wrapper, so the `j['type'] === 'event'` branch in `Light.qml` never runs.
  - Service calls are hand-written slots. `light(entity_id, on)` is currently the only one; new domains should follow its `call_service` pattern.
- **`Controler`** (`controller.{h,cpp}`; note the single-`l` spelling, which QML uses too) provides `pathFor()`, a 60 s idle timer emitting `idle(bool)` (reset by an event filter that `main.cpp` installs on the root window), and an `error(QString)` signal. On construction it searches `kPossibleConfigPaths` (cwd/`config`, `SOURCE_DIRECTORY`/`config`, `QStandardPaths::AppDataLocation`/`qt-hass/config`) for a `KEY=VALUE` file and loads `HASS_URL`/`HASS_TOKEN` from it via `hassUrl()`/`hassToken()` — `hassapi.cpp`'s `defaultUrl()`/`defaultAccessToken()` fall back to these when the environment variables are unset, which is always on Android since there's no shell to source `.envrc`. `AppDataLocation` resolves to `/data/user/0/<applicationId>/files` there, Android's app-private internal storage — deliberately not `/sdcard`, which on API 30+ a normal app can't read at all (scoped storage) regardless of the `READ_EXTERNAL_STORAGE`/`WRITE_EXTERNAL_STORAGE` permissions `androiddeployqt` happens to declare. Since it's a debug build, push a config file with `adb push config /data/local/tmp/config && adb shell run-as <applicationId> sh -c 'mkdir -p files/qt-hass && cp /data/local/tmp/config files/qt-hass/config'` (plain `adb push` straight into `/data/user/0/...` fails: that uid isn't `shell`).
- **`Mdi`** (`src/mdi.{h,cpp}`) resolves Material Design Icon names as HA sends them (`"mdi:lightbulb-on"`, aliases included) to glyphs in the bundled webfont. It loads the font itself and exposes the registered `fontFamily` (never hardcode it). Unknown names render `help-circle-outline` and warn once. Use it via `qml/MdiIcon.qml` (`icon`, `iconSize`).

### Entity cards

Cards extend `qml/EntityBase.qml`: set `required property string entity_id` and assign the `update` function property, which EntityBase registers with `HassAPI` in `Component.onCompleted`. See `qml/Light.qml` and `qml/Cards/Weather.qml`.

`qml/Tile.qml` (a Lovelace-style tile card) takes a `features` list of `qml/TileFeature.qml`-derived items (`qml/Features/ToggleFeature.qml`, `qml/Features/LightBrightnessFeature.qml`). That property is declared `list<Item>`, not `list<TileFeature>` -- confirmed on-device that `list<TileFeature>` makes the whole `Tile` type unavailable at runtime on Android (`Type Tile unavailable`, even for a bare `Tile{}` with no `features` set) while working fine on desktop. `list<Item>` keeps the same `features: [A{}, B{}]` declaration syntax and runtime behavior (JS property assignment on each element still goes through its real `TileFeature`-derived type), so don't "fix" it back to `list<TileFeature>`.

### Multi-page dashboards (TabBar + StackView)

`default_dashboard/Dashboard.qml` is a `TabBar`-over-`StackView` shell; each tab is a sibling `.qml` file in `default_dashboard/` (`PageOverview.qml`, `PageTiles.qml`, `PageLights.qml`), loaded via `Qt.createComponent(Qt.resolvedUrl("PageX.qml"))` + `stackView.replace(null, component)` rather than `StackView.initialItem`/a bare url. `initialItem` set to a dynamically-resolved url silently pushed nothing in testing (no error, no content, page just stayed blank) -- `Qt.createComponent` with explicit `component.status`/`errorString()` checking is what actually surfaces load failures (which is how the `list<Item>` bug above and a `qrc:/.../Features` stale-build issue got caught at all). Add a page by dropping a new file next to `Dashboard.qml` and listing it in `pages`.

The `TabBar` is docked at the **top**, not the bottom: confirmed on a real device (Fire tablet, Android 9) that Android's immersive-sticky navigation bar lives at the bottom edge and reappears on a touch there even in a fullscreen app, swallowing the first tap into the OS home/back/recents bar instead of the app underneath. A bottom-docked TabBar was unreliable to tap at all; top placement doesn't have this problem.

### MDI table generation

`tools/generate_mdi_table.py` runs at **configure time** (`execute_process`) and writes `build/*/generated/mdi_icons_data.h`, a sorted name→codepoint table. It is generated, never committed. It cross-checks every codepoint against the font's cmap and fails configure on mismatch. Its inputs `fonts/materialdesignicons-webfont.ttf` and `fonts/materialdesignicons-meta.json` are vendored. To upgrade MDI (the only networked step): `python3 tools/generate_mdi_table.py --fetch <version>`. Currently 7.4.47.

### CMake gotchas (already handled, don't undo)

- `qtquickcontrols2.conf` is added with a separate `qt_add_resources(... PREFIX "/")`. Qt only reads it from `:/qtquickcontrols2.conf`, and inside the QML module's resources the Material style silently doesn't apply.
- `src/` is on the include path because the generated QML type registration includes headers by basename.
- Android builds set `QT_ANDROID_EXTRA_LIBS` to `android/openssl/arm64-v8a/{libcrypto_3,libssl_3}.so`, vendored (Apache-2.0) from [KDAB/android_openssl](https://github.com/KDAB/android_openssl) `no-asm` build (commit `b71f1470`). Android doesn't expose OpenSSL to NDK apps, so without this `QtWebSockets` has no TLS backend and `wss://` connections fail at the handshake with "No functional TLS backend was found". Only arm64-v8a is vendored; another ABI or a Release Android build needs its own lib pair added under `android/openssl/<abi>` (see the upstream repo's `ssl_3/<abi>` for the non-`no-asm` variant).

## Not part of the build / leftovers

- `HassAPI/CMakeLists.txt`: never `add_subdirectory`'d, references a nonexistent `HassAPI.js`.
- `qml/Icon.js`: old MDI name table, superseded by the `Mdi` singleton (still compiled in).
- `qml/IconImage.qml`: references a missing `qt_logo_green_rgb.png`, yet is instantiated in `Main.qml`.
- `images/lightbulb*.svg`: listed in RESOURCES but referenced nowhere.
- `dashboard.html`: standalone HTML page, not used by the app.
- `3rdParty/` (untracked, local only): leftover `CustomBrandsIcons` module from the removed submodules, not referenced by CMake.

## Conventions

No formatter config. C++: 2-space indent, trailing-underscore members (`socket_`), module-qualified Qt includes (`<QtCore/QObject>`), `qC*` logging categories, C++23. QML: 4-space indent.
