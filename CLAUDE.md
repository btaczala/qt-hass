# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Qt 6 / QML Home Assistant dashboard (`qthomeassistant`) that talks to HA over its WebSocket API. Targets desktop (macOS) and Android (fullscreen when `platform == "android"`).

## Build, run, lint

Requires Qt ≥ 6.7 (Gui, Quick, QuickControls2, Multimedia, WebSockets), Python 3 (used at configure time), CMake, Ninja. The floor is 6.7, not something newer, specifically so Android builds can target Qt 6.7.x — see Android below for why.

```sh
cmake --preset desktop
cmake --build --preset desktop
cmake --build --preset desktop --target all_qmllint   # qmllint over the QML module
```

`CMakePresets.json` (committed) only defines hidden base presets (generator, `build/${presetName}` layout, common cache variables) -- it has no Qt paths, since those are machine-specific. `CMakeUserPresets.json` (gitignored) supplies the three concrete, buildable presets: `desktop`, `qt67`, and `qt610` (`cmake --list-presets` to see them; see Android below for the latter two). `desktop` overrides its `binaryDir` to `build/debug` specifically, since that's what `compile_commands.json` symlinks to. If `CMakeUserPresets.json` is ever missing, recreate `desktop` with `CMAKE_PREFIX_PATH` pointed at a Qt ≥ 6.7 macOS kit (`$HOME/Qt/6.10.1/macos` on this machine); if the Qt version matters, check `Qt6_DIR` in `CMakeCache.txt`.

Run (macOS bundle). The app needs `HASS_URL` (e.g. `wss://host/api/websocket`; `ws://` for plain HTTP) and `HASS_TOKEN` (long-lived access token). They live in `.envrc`, which contains the real token and is only kept out of git by a global ignore (the repo has no `.gitignore`). Configure bakes them into the binary (see `Controler` below), so a plain launch works; the environment variables, when set, override the bundled values, and values saved from the in-app settings page override both:

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

`run` (added to `CMakeLists.txt`, `ANDROID`-only) depends on `qthomeassistant_make_apk`, so it builds first if needed; it shells out to `adb`, located via `ANDROID_SDK_ROOT/platform-tools` or `PATH`, to install and launch. The APK it installs is the stable `android-build/qthomeassistant.apk` androiddeployqt copies its final output to (`${apk_final_dir}/${target}.apk`, not the deeper `android-build/build/outputs/apk/debug/android-build-debug.apk` gradle path, which is more of an implementation detail). Nothing else is pushed to the device: the dashboard QML and the HASS config are both inside the APK. It hardcodes the package name once, in the `ANDROID_PACKAGE_NAME` CMake variable (`org.qtproject.example.qthomeassistant`, androiddeployqt's default since nothing sets `QT_ANDROID_PACKAGE_NAME`) — update it there if that's ever set explicitly.

The AVD (`qthass`, Pixel 6 profile, `system-images;android-34;google_apis;arm64-v8a`) was created with `avdmanager create avd`; `avdmanager list avd`'s `devices.xml` lookup errors on this SDK layout but the AVD still gets created fine. Launch with `emulator -avd qthass`, then `cmake --build --preset qt67 --target run` (it's API 34, so `qt610` works too), or by hand:

```sh
adb install -r build/android-arm64-qt67/android-build/qthomeassistant.apk
adb shell am start -n org.qtproject.example.qthomeassistant/org.qtproject.qt.android.bindings.QtActivity
adb logcat -s libqthomeassistant_arm64-v8a.so qthass.api:D qthass.controller:D
```

Since the config is bundled, the token ends up inside the APK — fine for a personal debug build, don't distribute it.

## Architecture

### QML loading

- All QML, the dashboard included, is compiled into the `QtHomeAssistant` QML module and embedded under `qrc:/res/QtHomeAssistant/qml/...`. Every new QML/JS file must be added to `QML_FILES` in `CMakeLists.txt`, and changes need a rebuild. Subdirectory files (`qml/Cards/`, `qml/Features/`, `qml/Dashboard/`) are still registered by basename, so `import QtHomeAssistant` is enough to use them.
- This is deliberately simple: the dashboard used to be loaded off the filesystem (source dir, `/usr/share/qt-hass`, `/sdcard/qt-hass`) so it could be edited without a rebuild, but how others will customize a build isn't figured out yet, so it was folded into the module for now. Don't reintroduce a filesystem search path without settling that first.
- `qml/Main.qml`'s dashboard `Loader` is `active: HassAPI.connected` with `sourceComponent: Dashboard {}`, so no entity components exist until auth succeeds. It is torn down again on disconnect.

### C++ singletons exposed to QML (`QML_SINGLETON`, registered via `qt_add_qml_module` SOURCES)

- **`HassAPI`** (`hassapi.{h,cpp}`) owns the `QWebSocket`. Flow: `connect()` → `auth_required` → send token → `auth_ok` sets `connected`. Incoming messages are dispatched by `type` through `message_handlers_`.
  - `registerStateChanges(entity_id, jsFunction)` stores the callback and sends a per-entity `subscribe_entities`. It deliberately avoids `get_states`: that payload is several MB and trips QWebSocket's incomplete-frame timeout (close code 1001). Registrations made before connect are subscribed on `auth_ok`. Late registrations for an already-subscribed entity get the cached state replayed.
  - Events use HA's compressed format (`a` added / `c` `+`/`-` diff / `r` removed), rebuilt into full per-entity state in `entity_states_`.
  - **Callback contract:** callbacks receive a JSON *string* of `{entity_id, state, attributes}`, so QML must `JSON.parse` it. There is no `type: "event"` wrapper, so the `j['type'] === 'event'` branch in `Light.qml` never runs.
  - Service calls are hand-written slots. `light(entity_id, on)` is currently the only one; new domains should follow its `call_service` pattern.
- **`Controler`** (`controller.{h,cpp}`; note the single-`l` spelling, which QML uses too) provides an idle timer emitting `idle(bool)` (reset by an event filter that `main.cpp` installs on the root window; nothing consumes `idle` yet) and an `error(QString)` signal. It owns the app-level settings C++ needs, as writable, persisted (`QSettings`) properties: `hassUrl`, `hassToken`, and `idleTimeout` (seconds, default 60). URL/token resolve in increasing priority from the bundled `:/qt-hass/config` resource (`KEY=VALUE`), the `HASS_URL`/`HASS_TOKEN` environment variables, then values saved from the settings page; `HassAPI` reads them from `Controler` only, and `clearSavedConnection()` drops the saved ones again (the settings page's "Use built-in" button). `HassAPI.reconnect()` aborts the socket and reconnects with the current values. The resource is generated at configure time by `tools/generate_config.py` from `.envrc` into `build/*/generated/config` — the build dir only, never the source tree, since it holds the real token. `.envrc` is a configure dependency, so editing it and rebuilding picks up the change. A missing `.envrc` only warns and bundles an empty config. Once a URL/token has been saved from the app, `.envrc` edits no longer take effect on that machine until "Use built-in" clears the saved values (`connection/url`, `connection/token` in the `qt-hass`/`qthomeassistant` QSettings store, named in `main.cpp`).
- **`Mdi`** (`src/mdi.{h,cpp}`) resolves Material Design Icon names as HA sends them (`"mdi:lightbulb-on"`, aliases included) to glyphs in the bundled webfont. It loads the font itself and exposes the registered `fontFamily` (never hardcode it). Unknown names render `help-circle-outline` and warn once. Use it via `qml/MdiIcon.qml` (`icon`, `iconSize`).

### Entity cards

Cards extend `qml/EntityBase.qml`: set `required property string entity_id` and assign the `update` function property, which EntityBase registers with `HassAPI` in `Component.onCompleted`. See `qml/Light.qml` and `qml/Cards/Weather.qml`.

`qml/Tile.qml` (a Lovelace-style tile card) takes a `features` list of `qml/TileFeature.qml`-derived items (`qml/Features/ToggleFeature.qml`, `qml/Features/LightBrightnessFeature.qml`). That property is declared `list<Item>`, not `list<TileFeature>` -- confirmed on-device that `list<TileFeature>` makes the whole `Tile` type unavailable at runtime on Android (`Type Tile unavailable`, even for a bare `Tile{}` with no `features` set) while working fine on desktop. `list<Item>` keeps the same `features: [A{}, B{}]` declaration syntax and runtime behavior (JS property assignment on each element still goes through its real `TileFeature`-derived type), so don't "fix" it back to `list<TileFeature>`.

### Drawer and settings

`qml/Main.qml` has a `Drawer` holding `qml/Settings/SettingsPage.qml` (connection URL/token with "Save and reconnect" / "Use built-in", theme, animated background on/off, idle timeout). The drawer and its menu button live in `Main.qml`, outside the dashboard `Loader`, so settings are reachable before the first successful connection (e.g. to fix a wrong URL). It opens from a menu `ToolButton`, not just the edge swipe, for the same Android system-bar reason the `TabBar` is top-docked (see below). That button is declared in `Main.qml` after the dashboard `Loader`, pinned top-left so it stacks over the left end of the dashboard's `TabBar`; `Dashboard.qml` takes a `leadingInset` (bound to the button's width) and applies it as the TabBar's `leftPadding`, so the tabs shift right while the TabBar background still runs behind the button. It isn't inside `Dashboard.qml` because the dashboard doesn't exist while disconnected. Settings only QML reads (theme, animated background) live in `qml/Settings/UiSettings.qml`, a `QtCore` `Settings` subtype (category `ui`) that `Main.qml` instantiates once and passes to `SettingsPage`. It's a named type rather than a bare `Settings {}` so qmllint can see its custom properties, and there's a single instance because separate `Settings` instances don't sync live. `Material.theme` is set on the `ApplicationWindow` from it, so don't set a theme on `Dashboard.qml` or individual pages again.

### Multi-page dashboards (TabBar + StackLayout)

`qml/Dashboard/Dashboard.qml` is a `TabBar` over a `StackLayout` whose `currentIndex` is bound to the tab bar; each tab is a sibling `.qml` file in `qml/Dashboard/` (`PageOverview.qml`, `PageEnergy.qml`), declared directly as a `StackLayout` child. Every page is instantiated up front and lives for as long as the dashboard does, so its entities register with `HassAPI` exactly once. An earlier `StackView` version that created a fresh page on each tab switch crashed the QML engine's GC on a real device after a handful of switches, so don't go back to destroying pages on switch. Add a page by dropping a new file next to `Dashboard.qml`, adding it to `QML_FILES`, and adding a `TabButton` plus the page to `Dashboard.qml` in matching order.

The `TabBar` is docked at the **top**, not the bottom: confirmed on a real device (Fire tablet, Android 9) that Android's immersive-sticky navigation bar lives at the bottom edge and reappears on a touch there even in a fullscreen app, swallowing the first tap into the OS home/back/recents bar instead of the app underneath. A bottom-docked TabBar was unreliable to tap at all; top placement doesn't have this problem.

### Energy overview

`qml/Dashboard/PageEnergy.qml` shows `qml/Energy/EnergyFlowCard.qml`, a power-flow diagram modeled on [power-flow-card-plus](https://github.com/flixlix/power-flow-card-plus): solar on top, grid left, battery right, home at the bottom, with a dot moving along every active route. Two individual consumers (car, heat pump) sit in a row below home, hidden by default; tapping home (`EnergyNode.clickable`/`clicked`) toggles `consumersVisible`, which fades them in or out. The card sizes itself to the diagram: its height animates between `collapsedHeight` and `expandedHeight` (design units) in step with the fade, the diagram is clipped to the current height, and `PageEnergy.qml` hands it a `diagramScale` at which the *expanded* card fits, so the pane grows downward without rescaling the circles. The faded-out group is `visible: false` so its dot animations stop. Colors are HA's energy dashboard defaults. The card takes only HA-style readings (`solarPower`, `gridPower` +import/−export, `batteryPower` +discharge/−charge, `batterySoc`, per-device power) and derives the per-route flows itself: export and battery charging are served from solar first. Its diagram is laid out in fixed design units (`designSize`) and scaled to fit. `EnergyFlowLine` advances its dot with a `FrameAnimation` (speed ∝ flow / largest flow, so a speed change doesn't wait for a loop restart), stopped while the page is hidden. The dot follows a separate plain `Path` duplicating the curve, not the `ShapePath` that draws it: `PathInterpolator` on a `ShapePath` never moves (Qt skips the point cache for shape paths, so the position sits at the end point). The page is fed by `qml/Energy/FakeEnergySource.qml`, a simulated day compressed into ~4 minutes, until it's bound to real HA entities.

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
