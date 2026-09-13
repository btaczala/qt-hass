# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Qt 6 / QML Home Assistant dashboard (`qthomeassistant`) that talks to HA over its WebSocket API. Targets desktop (macOS) and Android (fullscreen when `platform == "android"`, plus `/sdcard` search paths).

## Build, run, lint

Requires Qt ≥ 6.7 (Gui, Quick, QuickControls2, Multimedia, WebSockets, Mqtt), Python 3 (used at configure time), CMake, Ninja. The floor is 6.7, not something newer, specifically so Android builds can target Qt 6.7.x — see Android below for why. `Mqtt` has no prebuilt aqt package for any of this project's kits and has to be built from source once per kit — see "Qt MQTT (built from source)" below before configuring for the first time on a new machine.

```sh
cmake --preset desktop
cmake --build --preset desktop
cmake --build --preset desktop --target all_qmllint   # qmllint over the QML module
```

`CMakePresets.json` (committed) only defines hidden base presets (generator, `build/${presetName}` layout, common cache variables) -- it has no Qt paths, since those are machine-specific. `CMakeUserPresets.json` (gitignored) supplies the three concrete, buildable presets: `desktop`, `qt67`, and `qt610` (`cmake --list-presets` to see them; see Android below for the latter two). `desktop` overrides its `binaryDir` to `build/debug` specifically, since that's what `compile_commands.json` symlinks to. If `CMakeUserPresets.json` is ever missing, recreate `desktop` with `CMAKE_PREFIX_PATH` pointed at a Qt ≥ 6.7 macOS kit (`$HOME/Qt/6.10.1/macos` on this machine); if the Qt version matters, check `Qt6_DIR` in `CMakeCache.txt`.

Run (macOS bundle). The app reads all of its runtime config -- `HASS_URL` (e.g. `wss://host/api/websocket`; `ws://` for plain HTTP), `HASS_TOKEN` (long-lived access token), and the optional `IDLE_TIMEOUT_SECONDS`/`REMOTE_ADMIN_PASSWORD`/`REMOTE_ADMIN_PORT`/`MQTT_BROKER_HOST`/`MQTT_BROKER_PORT`/`MQTT_USERNAME`/`MQTT_PASSWORD` keys -- from a `config` file (`KEY=VALUE` per line, no `export`, no quotes); see `Controler` below for the exact search order. There is no environment-variable fallback on any platform, so there's nothing to source before running:

```sh
build/debug/qthomeassistant.app/Contents/MacOS/qthomeassistant
```

`config` contains the real HA token and is only kept out of git by a repo-local `.git/info/exclude` entry (the repo has no `.gitignore`, and this file's generic name isn't covered by the global ignore the way `.envrc` used to be).

Verbose logs: `QT_LOGGING_RULES="qthass.*.debug=true"` (categories `qthass.api`, `qthass.controller`).

There are no tests.

### Qt MQTT (built from source)

`Mqtt` (needed by `MqttPublisher`, see Architecture below) has no prebuilt aqt package for any Qt version/platform combination this project uses, so it's built from source, once per kit, straight into that kit's own install prefix -- `qt-cmake` from a binary Qt kit already points `CMAKE_INSTALL_PREFIX` at that kit's prefix, so `cmake --install` drops `Qt6Mqtt` in next to the other Qt6 modules and `find_package(Qt6 ... COMPONENTS Mqtt)` just starts working, no `CMAKE_PREFIX_PATH` changes needed anywhere. Already done for all three kits this project builds (`~/Qt/6.10.1/macos`, `~/Qt/6.7.3/android_arm64_v8a`, `~/Qt/6.10.1/android_arm64_v8a`) -- only needed again if a kit is reinstalled from scratch.

Two things needed overriding on this machine, both required regardless of which kit is being built:

- **No full Xcode, only Command Line Tools.** Building an *application against* Qt (this project's own `qt_add_executable`) never needs Xcode.app, but building a *Qt module itself from source* goes through `qt_build_repo`, which unconditionally shells out to `xcodebuild -version` to sanity-check the Xcode/SDK version pairing -- and fails configure outright (`Can't determine Xcode version`) when only the Command Line Tools are installed. `-DQT_NO_APPLE_SDK_AND_XCODE_CHECK=ON` skips that check entirely; plain CLI compilation doesn't otherwise need Xcode.app.
- **Ninja Multi-Config's AUTOMOC "better graph" mode is broken here.** `qt-cmake`'s default generator (Ninja Multi-Config) hits a real bug in CMake's per-config AUTOMOC dependency tracking for Qt ≥ 6.8 modules (`AUTOGEN_BETTER_GRAPH_MULTI_CONFIG`, on by default for Qt 6.8+): the build graph ends up depending on a `<Module>_fake_header.h` that no rule ever generates (`ninja: error: '.../Mqtt_fake_header.h', needed by '.../Mqtt_autogen_timestamp_deps-Debug', missing and no known rule to make it`). Neither downgrading CMake below the 3.29 version that introduced the feature nor disabling the `CMAKE_AUTOGEN_BETTER_GRAPH_MULTI_CONFIG` cache variable avoids it (Qt's own `qt_internal_add_module` sets the *target* property directly once it detects Qt ≥ 6.8, overriding the cache variable's default). The fix that actually works: don't use a multi-config generator at all -- pass `-G Ninja -DCMAKE_BUILD_TYPE=Release` instead of accepting `qt-cmake`'s default, which sidesteps the whole per-config autogen graph this bug lives in.

Recipe, parameterized per kit (`<qt_version>` matches the target kit exactly -- `6.10.1` for desktop/`qt610`, `6.7.3` for `qt67`; `<kit_bin>` is that kit's own `bin/qt-cmake`; Android kits additionally need `-DQT_HOST_PATH=<host_qt>/bin/qt-cmake`'s macOS host counterpart, e.g. `~/Qt/6.7.3/macos` for `qt67`, already the same path used as `QT_HOST_PATH` in `CMakeUserPresets.json` for the app's own Android presets):

```sh
git clone --branch v<qt_version> --depth 1 https://github.com/qt/qtmqtt.git /tmp/qtmqtt-<kit>
<kit_bin>/qt-cmake -G Ninja -S /tmp/qtmqtt-<kit> -B /tmp/qtmqtt-<kit>-build \
  -DQT_NO_APPLE_SDK_AND_XCODE_CHECK=ON -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/qtmqtt-<kit>-build
cmake --install /tmp/qtmqtt-<kit>-build
rm -rf /tmp/qtmqtt-<kit> /tmp/qtmqtt-<kit>-build
```

Verify a given kit has it with `ls <kit_prefix>/lib/cmake/Qt6Mqtt`.

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

`run` (added to `CMakeLists.txt`, `ANDROID`-only) depends on `qthomeassistant_make_apk`, so it builds first if needed; it shells out to `adb`, located via `ANDROID_SDK_ROOT/platform-tools` or `PATH`. The APK it installs is the stable `android-build/qthomeassistant.apk` androiddeployqt copies its final output to (`${apk_final_dir}/${target}.apk`, not the deeper `android-build/build/outputs/apk/debug/android-build-debug.apk` gradle path, which is more of an implementation detail). After installing, it runs `tools/push_android_config.py` (needs the app already installed, since it goes through `run-as`) to push the repo-root `config` file (copied to `<binaryDir>/config` first) to the device, then pushes `default_dashboard/` to `/sdcard/qt-hass/` (see Two-tier QML loading below), before launching -- dev conveniences so the device always gets the same target and dashboard the desktop build uses, with nothing to keep in sync by hand. It hardcodes the package name once, in the `ANDROID_PACKAGE_NAME` CMake variable (`org.qtproject.example.qthomeassistant`, androiddeployqt's default since nothing sets `QT_ANDROID_PACKAGE_NAME`) — update it there if that's ever set explicitly.

The AVD (`qthass`, Pixel 6 profile, `system-images;android-34;google_apis;arm64-v8a`) was created with `avdmanager create avd`; `avdmanager list avd`'s `devices.xml` lookup errors on this SDK layout but the AVD still gets created fine. Launch with `emulator -avd qthass`, then `cmake --build --preset qt67 --target run` (it's API 34, so `qt610` works too), or by hand:

```sh
adb install -r build/android-arm64-qt67/android-build/qthomeassistant.apk
adb shell am start -n org.qtproject.example.qthomeassistant/org.qtproject.qt.android.bindings.QtActivity
adb logcat -s libqthomeassistant_arm64-v8a.so qthass.api:D qthass.controller:D
```

Android needs the same `config` file desktop uses pushed into the app's private storage before starting the activity (`adb push` can't reach it directly since that uid isn't `shell`). `cmake --build --preset qt67|qt610 --target run` does this automatically (see below) via `tools/push_android_config.py`, which re-pushes it on every run; by hand:

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
- **`Controler`** (`controller.{h,cpp}`; note the single-`l` spelling, which QML uses too) provides `pathFor()`, a `screensaverActive` bool property backed by a 60 s idle timer (single-shot; any interaction restarts it), an `idleTimeoutSeconds` int property, a `hassConnected` bool property, and an `error(QString)` signal. `hassConnected` exists purely so `RemoteAdmin` (C++) can read `HassAPI.connected` (QML) — `HassAPI::create()` isn't cached the way `Controler::create()` is (a cached-pointer version was tried and abandoned: QML was observed constructing a second, separate `HassAPI` instance that ended up being the one actually driving the real connection, leaving a C++-side cached pointer referencing an orphaned object with stale state), so `Main.qml`'s `Connections { target: HassAPI; function onConnectedChanged() { Controler.hassConnected = HassAPI.connected } }` mirrors it across instead, since QML's own property bindings on `HassAPI` are reliably consistent even though a stable C++ pointer to it isn't. `screensaverActive` and `idleTimeoutSeconds` are the single source of truth for `qml/Screensaver.qml` (bound directly to `screensaverActive`) *and* `RemoteAdmin` (see below) — both just call `Controler::setScreensaverActive()`/`setIdleTimeoutSeconds()` rather than each keeping their own state. `main.cpp` installs `Controler` as an event filter on the root window; any touch/key/mouse press calls `setScreensaverActive(false)`, which rearms the idle timer. `main.cpp` fetches the `Controler`/`RemoteAdmin` pointer via `engine.singletonInstance<Controler *>("QtHomeAssistant", "Controler")`, called *before* `engine.load()` -- calling `Controler::create()`/`instance()` directly from C++ *after* `load()` was observed to race QML's own singleton resolution and return a second, disconnected instance (each internally self-consistent, silently wrong); `singletonInstance()` goes through the engine's own registry instead, guaranteeing it's the exact instance QML will use, and calling it before `load()` makes it unambiguously the first resolution. On construction it searches `kPossibleConfigPaths` (cwd/`config`, `SOURCE_DIRECTORY`/`config`, `QStandardPaths::AppDataLocation`/`qt-hass/config`) for a `KEY=VALUE` file and loads `HASS_URL`/`HASS_TOKEN`/`IDLE_TIMEOUT_SECONDS`/`REMOTE_ADMIN_PASSWORD`/`REMOTE_ADMIN_PORT`/`MQTT_BROKER_HOST`/`MQTT_BROKER_PORT`/`MQTT_USERNAME`/`MQTT_PASSWORD` from it. This config file is the *sole* source of `HASS_URL`/`HASS_TOKEN` on every platform -- `hassapi.cpp`'s `defaultUrl()`/`defaultAccessToken()` read `hassUrl()`/`hassToken()` directly, with no environment-variable fallback (there used to be one, read from `.envrc` via `direnv`; both are gone). `AppDataLocation` resolves to `/data/user/0/<applicationId>/files` on Android, its app-private internal storage — deliberately not `/sdcard`, which on API 30+ a normal app can't read at all (scoped storage) regardless of the `READ_EXTERNAL_STORAGE`/`WRITE_EXTERNAL_STORAGE` permissions `androiddeployqt` happens to declare. Since it's a debug build, push a config file with `adb push config /data/local/tmp/config && adb shell run-as <applicationId> sh -c 'mkdir -p files/qt-hass && cp /data/local/tmp/config files/qt-hass/config'` (plain `adb push` straight into `/data/user/0/...` fails: that uid isn't `shell`). `setIdleTimeoutSeconds()` persists via a private `saveConfig()`, which rewrites `configuration_path_` (falling back to creating `AppDataLocation/qt-hass/config` if no config file was ever found at all).
- **`RemoteAdmin`** (`remoteadmin.{h,cpp}`) is a minimal Fully-Kiosk-Browser-style remote admin server: `GET http://<device>:<REMOTE_ADMIN_PORT>/?cmd=<command>&password=<REMOTE_ADMIN_PASSWORD>[&key=...&value=...]`, JSON responses (`{"status":"OK"|"Error", ...}`). Hand-rolled on `QTcpServer`/`QTcpSocket` rather than `Qt6::HttpServer` — the wire protocol is GET-only with no body, and this avoids a Qt module that isn't guaranteed installed for the pinned Qt 6.7.3 Android kit. Mirrors real Fully Kiosk's wire *conventions* (query-string `cmd`/`password`, JSON envelope, familiar command names) for the commands this app actually supports. `deviceInfo` includes `deviceID`/`deviceName`/`Mac`/`ip4`/`deviceManufacturer`/`deviceModel`/`appVersionName` purely so Home Assistant's official `fully_kiosk` integration works at all -- confirmed field-by-field via HA's own logs, since each missing one throws a bare, uncaught `KeyError` (no `.get()`/default anywhere in these code paths): `config_flow.py`'s `_create_entry` needs `deviceID`/`deviceName`/`Mac` just for "Add device" to succeed (HA's UI shows any failure there as "Unknown error occurred"), and separately `entity.py`'s `FullyKioskEntity.__init__` -- the base class almost every entity platform (switch, camera, media_player, notify, image, button) constructs -- additionally needs `ip4`, `deviceManufacturer`, `deviceModel`, `appVersionName`, or that whole platform creates zero entities. `deviceManufacturer` is hardcoded to `"qthomeassistant"` (this is not real hardware), `deviceModel` is `QSysInfo::prettyProductName()`, `appVersionName` is `APP_VERSION` (a compile definition set from `CMakeLists.txt`'s `PROJECT_VERSION`, alongside `SOURCE_DIRECTORY`). `isInScreensaver` mirrors `screensaverActive` under Fully Kiosk's own field name -- `switch.py`'s "screensaver" `FullySwitchEntityDescription` reads its on/off state via `is_on_fn=lambda data: data.get("isInScreensaver")`, so without this exact key that switch always reported "off" regardless of what `startScreensaver`/`stopScreensaver` actually did. This is still **not** a real drop-in: `sensor.py`/`binary_sensor.py` are better-behaved (`coordinator.data.get(...)` plus an `if description.key in coordinator.data` existence check, so they degrade gracefully instead of crashing) but want battery, RAM, storage, foreground app, screen orientation, etc. -- this app has no equivalent for any of that, so those entities stay absent rather than being faked. `switch.py`'s other four switches (`maintenance`/`kiosk`/`motion-detection`/`screenOn`, reading `maintenanceMode`/`kioskLocked`/`settings.motionDetection`/`screenOn`) are in the same boat *and* call commands (`enableLockedMode`, `lockKiosk`, `enableMotionDetection`, `screenOn`) this server doesn't implement at all -- they'll show "off" and fail with "Unknown command" if toggled. Point HA's generic `rest`/`rest_command`/`switch` platforms at this server instead if you want reliable behavior. Only starts listening if `REMOTE_ADMIN_PASSWORD` is set in the config file (see `Controler` above) — no unauthenticated control surface by default. Plaintext HTTP, password in the URL query string (same weak model as real Fully Kiosk) — LAN-only, never port-forward this. Default port 2323 (`REMOTE_ADMIN_PORT` to override). Commands: `deviceInfo` (returns `deviceID`/`deviceName`/`Mac`/`ip4`/`screensaverActive`/`isInScreensaver`/`idleTimeoutSeconds`/`hassConnected`), `startScreensaver`/`stopScreensaver`, `getStringSetting`/`setStringSetting&key=idleTimeoutSeconds&value=<seconds>` (`idleTimeoutSeconds` is this app's own setting key, not a verified real Fully Kiosk one), `listSettings` (HA's `fully_kiosk` coordinator polls this — via `python-fullykiosk`'s `getSettings()`, a *different* wire command from `getStringSetting`/`setStringSetting` above — on every refresh alongside `deviceInfo`; returns `{"idleTimeoutSeconds": ..., "mqttEnabled": ...}`, plus `mqttEventTopic` when `mqttEnabled` is true, with no `status` wrapper, since the coordinator merges it as-is under `deviceInfo`'s `settings` key — a missing `mqttEnabled` key would leave the screensaver/screen switches permanently "unavailable", since `entity.py`'s `mqtt_subscribe()` does `data["settings"]["mqttEnabled"]` with no default and the exception happens after the entity's already added, so it never gets a first coordinator update). `mqttEnabled` mirrors whether `MqttPublisher` (below) is configured (`!Controler::mqttBrokerHost().isEmpty()`), not a live connection check. HA's `fully_kiosk` integration otherwise only polls this server on a fixed 30 s interval (`homeassistant/components/fully_kiosk/const.py`'s `UPDATE_INTERVAL`, not configurable from our side), so without MQTT a local screensaver dismiss can take up to 30 s to show up in HA's switch state; see `MqttPublisher` below for how that lag is avoided when MQTT is configured.
- **`MqttPublisher`** (`mqttpublisher.{h,cpp}`) is a plain `QObject` (like `RemoteAdmin`, no QML surface) that publishes this device's screensaver state to an MQTT broker in exactly the shape HA's `fully_kiosk` integration expects for its push path, so `switch.py`'s screensaver switch updates immediately instead of waiting for the 30 s poll mentioned above. Confirmed by reading `entity.py`'s `mqtt_subscribe()`: it only subscribes if `data["settings"]["mqttEnabled"]` is truthy, and builds the topic from `data["settings"]["mqttEventTopic"]` by replacing `$appId`→`"fully"`, `$event`→the event name, `$deviceId`→`deviceInfo`'s `deviceID`; `switch.py`'s screensaver entry uses `mqtt_on_event="onScreensaverStart"`/`mqtt_off_event="onScreensaverStop"`, and the payload just needs to be JSON containing `{"event": "<name>"}` (extra fields are ignored). `kMqttEventTopicTemplate` (`controller.h`) is the literal template string (`"$appId/event/$event/$deviceId"`) shared between `RemoteAdmin::cmdListSettings()` (which advertises it) and `MqttPublisher` (which resolves it the same way before publishing) — a single source of truth so the two can't drift apart. `Controler::deviceId()` (hoisted out of what used to be `RemoteAdmin::deviceMac()`) is the shared MAC-based id used for both `deviceInfo`'s `deviceID` and the topic's `$deviceId`. Only connects if `MQTT_BROKER_HOST` is set in the config file (see `Controler` above) — same empty-means-disabled gating as `REMOTE_ADMIN_PASSWORD`; `MQTT_BROKER_PORT` defaults to 1883, `MQTT_USERNAME`/`MQTT_PASSWORD` are optional (anonymous if unset). Plain TCP, no TLS support yet — LAN-only broker assumed, consistent with this file's other LAN-only assumptions (`RemoteAdmin`). Reconnects on disconnect with a flat 5 s single-shot timer, no backoff.
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
