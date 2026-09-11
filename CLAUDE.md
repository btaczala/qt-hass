# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Qt 6 / QML Home Assistant dashboard (`qthomeassistant`) that talks to HA over its WebSocket API. Targets desktop (macOS) and Android (fullscreen when `platform == "android"`, plus `/sdcard` search paths).

## Build, run, lint

Requires Qt ≥ 6.7 (Gui, Quick, QuickControls2, Multimedia, WebSockets), Python 3 (used at configure time), CMake, Ninja. The floor is 6.7, not something newer, specifically so Android builds can target Qt 6.7.x — see Android below for why.

```sh
cmake --preset desktop
cmake --build --preset desktop
cmake --build --preset desktop --target all_qmllint   # qmllint over the QML module
```

`CMakePresets.json` (committed) only defines hidden base presets (generator, `build/${presetName}` layout, common cache variables) -- it has no Qt paths, since those are machine-specific. `CMakeUserPresets.json` (gitignored) supplies the three concrete, buildable presets: `desktop`, `qt67`, and `qt610` (`cmake --list-presets` to see them; see Android below for the latter two). `desktop` overrides its `binaryDir` to `build/debug` specifically, since that's what `compile_commands.json` symlinks to. If `CMakeUserPresets.json` is ever missing, recreate `desktop` with `CMAKE_PREFIX_PATH` pointed at a Qt ≥ 6.7 macOS kit (`$HOME/Qt/6.10.1/macos` on this machine); if the Qt version matters, check `Qt6_DIR` in `CMakeCache.txt`.

Run (macOS bundle). The app reads `HASS_URL` (e.g. `wss://host/api/websocket`; `ws://` for plain HTTP) and `HASS_TOKEN` (long-lived access token) from the environment. They live in `.envrc`, which contains the real token and is only kept out of git by a global ignore (the repo has no `.gitignore`). A non-interactive shell won't load it, so use:

```sh
direnv exec . build/debug/qthomeassistant.app/Contents/MacOS/qthomeassistant
```

Verbose logs: `QT_LOGGING_RULES="qthass.*.debug=true"` (categories `qthass.api`, `qthass.controller`).

There are no tests.

### Android

The build targets Qt **6.7.3**, not the newer 6.10.1 used for desktop: Qt 6.8+ raised Android's floor to API 28 and `libQt6Core` started calling `getentropy()` (added to Bionic libc only in API 28), so anything built with Qt ≥ 6.8 hard-crashes with `UnsatisfiedLinkError: dlopen failed: cannot locate symbol "getentropy"` on any API 27-or-older device — confirmed on a real device (Android 8.1 / API 27) in 2026-09. Qt 6.7.3's `libQt6Core` doesn't reference that symbol, and its default `qtMinSdkVersion` is 23 (Android 6.0), so the same source now installs and runs down to API 27+ without any minSdk override — lowering `QT_ANDROID_MIN_SDK_VERSION` on a Qt ≥ 6.8 build does *not* work (the manifest check passes but it still crashes at library load), it has to be a different Qt version. If a device this old ever stops mattering, upgrading back to 6.10.1 (already installed at `~/Qt/6.10.1`) is a drop-in swap of the paths below.

On this machine: Android Studio + `android-commandlinetools` (Homebrew casks) provide the SDK, rooted at `/opt/homebrew/share/android-commandlinetools`; NDK r26b (`ndk;26.1.10909125`) matches what the `~/Qt/6.7.3/android_arm64_v8a` kit was built against (check `qt.toolchain.cmake`'s `__qt_initially_configured_toolchain_file` if that ever changes — the 6.10.1 kit instead wants NDK r27c, `ndk;27.3.13750724`); JDK 17 (`temurin@17`) is required for Gradle — the system default JDK can stay newer, just override `JAVA_HOME` for the build.

Qt 6.7.3's Gradle templates pull AGP 7.4.1, whose bundled `aapt2` can't parse the `android-36` platform jar (androiddeployqt's default compileSdk is always "the highest installed platform," and this machine's SDK has `android-36` installed for the 6.10.1 kit) — it fails resource linking with `aapt2 E ... RES_TABLE_TYPE_TYPE entry offsets overlap actual entry data`. Qt 6.7.3 has no CMake-level `QT_ANDROID_COMPILE_SDK_VERSION` property to override this (that property only exists from Qt 6.8+), so the fix is a second, isolated `ANDROID_SDK_ROOT` at `~/Android/sdk-compat-api34` — symlinks to the real SDK's `platform-tools`, `cmdline-tools`, `licenses`, `emulator`, `build-tools/35.0.0`, and `ndk/26.1.10909125`, but only `platforms/android-34` (not `android-36`), so androiddeployqt's "highest installed" scan lands on 34, which AGP 7.4.1 can parse and which still covers Qt 6.7.3's `qtTargetSdkVersion` (also 34). `CMakeLists.txt` pins `QT_ANDROID_COMPILE_SDK_VERSION` to `android-34` whenever `Qt6_VERSION VERSION_LESS 6.8`, for the same reason. Recreate the symlink farm if `~/Android/sdk-compat-api34` is ever missing:

```sh
ISO=$HOME/Android/sdk-compat-api34
mkdir -p "$ISO/platforms" "$ISO/build-tools" "$ISO/ndk"
ln -sfn /opt/homebrew/share/android-commandlinetools/{platform-tools,cmdline-tools,licenses,emulator} "$ISO/"
ln -sfn /opt/homebrew/share/android-commandlinetools/build-tools/35.0.0 "$ISO/build-tools/35.0.0"
ln -sfn /opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125 "$ISO/ndk/26.1.10909125"
ln -sfn /opt/homebrew/share/android-commandlinetools/platforms/android-34 "$ISO/platforms/android-34"
```

Build with the `qt67` preset (`qt610` for the API 28+ kit -- same commands, just swap the preset name; it doesn't need the isolated SDK root, so it points `ANDROID_SDK_ROOT` straight at `/opt/homebrew/share/android-commandlinetools`):

```sh
cmake --preset qt67
cmake --build --preset qt67 --target apk
cmake --build --preset qt67 --target run   # install + launch on whatever device adb targets
```

The `qt67`/`qt610` presets in `CMakeUserPresets.json` set `toolchainFile`, `QT_HOST_PATH`, `CMAKE_PREFIX_PATH`, `ANDROID_SDK_ROOT`, `ANDROID_NDK_ROOT` (as both `environment` and `cacheVariables`, since `CMakeLists.txt`'s `run` target reads it from the environment while CMake's own Android tooling reads the cache variable) and `JAVA_HOME` (environment only) for their respective kit; `binaryDir` is pinned to `build/android-arm64-qt67` / `build/android-arm64` rather than the presets' default `build/${presetName}`, to match the paths used below and elsewhere in this doc.

`run` (added to `CMakeLists.txt`, `ANDROID`-only) depends on `qthomeassistant_make_apk`, so it builds first if needed; it shells out to `adb`, located via `ANDROID_SDK_ROOT/platform-tools` or `PATH`. The APK it installs is the stable `android-build/qthomeassistant.apk` androiddeployqt copies its final output to (`${apk_final_dir}/${target}.apk`, not the deeper `android-build/build/outputs/apk/debug/android-build-debug.apk` gradle path, which is more of an implementation detail). After installing, it runs `tools/push_android_config.py` (needs the app already installed, since it goes through `run-as`) to regenerate `<binaryDir>/config` from `.envrc`'s `HASS_URL`/`HASS_TOKEN` and push it to the device, then pushes `default_dashboard/` to `/sdcard/qt-hass/` (see Two-tier QML loading below), before launching -- dev conveniences so the device always gets the same target and dashboard the desktop build uses, with nothing to keep in sync by hand. It hardcodes the package name once, in the `ANDROID_PACKAGE_NAME` CMake variable (`org.qtproject.example.qthomeassistant`, androiddeployqt's default since nothing sets `QT_ANDROID_PACKAGE_NAME`) — update it there if that's ever set explicitly.

The AVD (`qthass`, Pixel 6 profile, `system-images;android-34;google_apis;arm64-v8a`) was created with `avdmanager create avd`; `avdmanager list avd`'s `devices.xml` lookup errors on this SDK layout but the AVD still gets created fine. Launch with `emulator -avd qthass`, then `cmake --build --preset qt67 --target run` (it's API 34, so `qt610` works too), or by hand:

```sh
adb install -r build/android-arm64-qt67/android-build/qthomeassistant.apk
adb shell am start -n org.qtproject.example.qthomeassistant/org.qtproject.qt.android.bindings.QtActivity
adb logcat -s libqthomeassistant_arm64-v8a.so qthass.api:D qthass.controller:D
```

There's no `.envrc` equivalent on Android, so before starting the activity, push a `HASS_URL=...`/`HASS_TOKEN=...` file into the app's private storage (`adb push` can't reach it directly since that uid isn't `shell`). `cmake --build --preset qt67|qt610 --target run` now does this automatically (see below) via `tools/push_android_config.py`, which re-derives the config from `.envrc` on every run; by hand:

```sh
adb push config /data/local/tmp/config
adb shell "run-as org.qtproject.example.qthomeassistant sh -c 'mkdir -p files/qt-hass && cp /data/local/tmp/config files/qt-hass/config'"
```

That has to be one quoted string, not `sh -c` and its argument as separate words: `adb shell` joins everything after `shell` with spaces before it reaches the device, so passing them separately loses the quoting that ties the command to `-c` -- the device's shell re-splits it, and `run-as`'s `sh -c` only ever sees the bare word `mkdir` (`mkdir: Needs 1 argument`), with the `cp` running outside `run-as` entirely.

See `Controler` below for why `/data/user/0/.../files` and not `/sdcard`.

## Architecture

### Two-tier QML loading

- `qml/**` is compiled into the `QtHomeAssistant` QML module and embedded under `qrc:/res/QtHomeAssistant/qml/...`. Every new QML/JS file must be added to `QML_FILES` in `CMakeLists.txt`, and changes need a rebuild.
- `default_dashboard/Dashboard.qml` is **not** in the module. `qml/Main.qml` loads it from the filesystem via `Controler.pathFor("default_dashboard/Dashboard.qml")`, which searches `SOURCE_DIRECTORY` (baked in at compile time), `/usr/share/qt-hass`, then `/sdcard/qt-hass`. Edits to it only need an app restart. This is also why it imports cards by absolute path (`import 'qrc:/res/QtHomeAssistant/qml/Cards'`). The `/sdcard/qt-hass` fallback works and has been exercised end-to-end on a real API 27 device -- `run` (see Android below) pushes `default_dashboard/` there via plain `adb push` (no `run-as` needed, unlike the app-private config; it's regular external storage). It's still unverified on API 30+: scoped storage blocked the same convention for `Controler`'s config file (see below) regardless of granted `READ_EXTERNAL_STORAGE`, and whether that also blocks this Loader path on a modern Android version hasn't been tested.
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
