# Android builds via Docker, so the Android SDK/NDK/Qt toolchain doesn't have
# to be installed on the host -- see docker/android.Dockerfile and CLAUDE.md's
# Android section for why two separate kits (qt67, qt610) exist at all.
#
# Usage:
#   just android-image qt67     # build (or rebuild) the toolchain image
#   just android-build qt67     # configure + build the APK in that image
#   just android-run qt67       # adb install + launch on the connected device
#   just android-deploy qt67    # build then run, in one step
# ("qt610" works the same everywhere "qt67" does above.)
#
#   just dashboard-sync               # copy every examples/* dashboard to Home Assistant
#   just dashboard-sync office-panel  # or just these ones

image_tag := "qthass-android"
gradle_cache_volume := "qthass-gradle-cache"

# Where dashboards go: an ssh host (~/.ssh/config) and Home Assistant's
# /config/www/qthass/, served at http://<hass>:8123/local/qthass/. Each
# dashboard gets its own folder there; examples/index.json lists them for the
# app's settings when the dashboard source is "Home Assistant www folder".
hass_ssh := "hass"
hass_dashboard_dir := "/config/www/qthass"

# Copy dashboards from examples/ (all by default) and its index.json into Home Assistant's www.
dashboard-sync *examples:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ justfile_directory() }}/examples"
    names=({{ examples }})
    if [ ${#names[@]} -eq 0 ]; then
      for dir in */; do
        [ -f "$dir/main.qml" ] && names+=("${dir%/}")
      done
    fi
    for name in "${names[@]}"; do
      if [ ! -f "$name/main.qml" ]; then
        echo "no dashboard at examples/$name (expected a main.qml)" >&2
        exit 1
      fi
    done
    # Home Assistant serves www files but not folder listings (403 for
    # /local/qthass/), so the app's settings list the dashboards from
    # examples/index.json, a JSON array of folder names kept by hand.
    python3 - <<'EOF'
    import json, os, sys
    names = json.load(open("index.json"))
    if not isinstance(names, list) or not all(isinstance(n, str) for n in names):
        sys.exit("examples/index.json must be a JSON array of folder names")
    missing = [n for n in names if not os.path.isfile(os.path.join(n, "main.qml"))]
    if missing:
        sys.exit("examples/index.json lists folders without a main.qml: " + ", ".join(missing))
    EOF
    # Homebrew's rsync, not macOS's own (openrsync), which lacks --mkpath.
    rsync="$(brew --prefix)/bin/rsync"
    if [ ! -x "$rsync" ]; then
      echo "no Homebrew rsync at $rsync -- brew install rsync" >&2
      exit 1
    fi
    # -rt rather than -a, so files on the server don't take this machine's
    # user and group ids.
    for name in "${names[@]}"; do
      "$rsync" -rtv --mkpath --chmod=D755,F644 --exclude .DS_Store \
        "$name/" "{{ hass_ssh }}:{{ hass_dashboard_dir }}/$name/"
    done
    "$rsync" -tv --mkpath --chmod=F644 index.json "{{ hass_ssh }}:{{ hass_dashboard_dir }}/"

# Build (or rebuild) the Android toolchain image for `variant`.
android-image variant:
    #!/usr/bin/env bash
    set -euo pipefail
    # Only needs re-running when docker/android.Dockerfile changes or a
    # Qt/NDK version is bumped -- not on every app source edit, since the app
    # itself is bind-mounted in at build time, not baked into the image.
    case "{{ variant }}" in
      qt67)  qt=6.7.3;  ndk=26.1.10909125; platform=android-34; build_tools=34.0.0 ;;
      qt610) qt=6.10.1; ndk=27.3.13750724; platform=android-36; build_tools=35.0.0 ;;
      *) echo "variant must be qt67 or qt610, got '{{ variant }}'" >&2; exit 1 ;;
    esac
    docker build --platform linux/amd64 -f docker/android.Dockerfile \
      --build-arg QT_VERSION="$qt" \
      --build-arg NDK_VERSION="$ndk" \
      --build-arg ANDROID_PLATFORM="$platform" \
      --build-arg BUILD_TOOLS_VERSION="$build_tools" \
      -t {{ image_tag }}:{{ variant }} \
      docker

# Configure + build the APK for `variant` inside its toolchain image.
android-build variant: (android-image variant)
    #!/usr/bin/env bash
    set -euo pipefail
    # build/docker-<variant>, kept separate from a host-native
    # build/android-arm64* dir -- both cache absolute toolchain paths in
    # CMakeCache.txt, and the container's paths aren't valid outside it.
    dir="build/docker-{{ variant }}"
    # The Gradle cache is a named volume, not bind-mounted, so
    # androiddeployqt's underlying Gradle build only downloads its
    # distribution/AGP/dependencies once across runs, not on every
    # `docker run`.
    # --platform matches the image (see docker/android.Dockerfile's FROM).
    # The host's ~/.android is mounted so the debug signing key
    # (debug.keystore, created there on first build if missing) outlives the
    # container: with a fresh key per `docker run --rm`, every build would be
    # signed differently and `adb install -r` would refuse to update the app
    # (INSTALL_FAILED_UPDATE_INCOMPATIBLE) without uninstalling it -- and its
    # data -- first. Same key as a host-native build uses, too.
    mkdir -p "$HOME/.android"
    docker run --rm --platform linux/amd64 \
      -v "{{ justfile_directory() }}":/workspace \
      -v {{ gradle_cache_volume }}:/root/.gradle \
      -v "$HOME/.android":/root/.android \
      -w /workspace \
      {{ image_tag }}:{{ variant }} bash -lc "
        set -euo pipefail
        cmake -S . -B '$dir' -G Ninja \
          -DCMAKE_BUILD_TYPE=Debug \
          -DQT_ANDROID_ABIS=arm64-v8a \
          -DCMAKE_TOOLCHAIN_FILE=\"\$QT_ANDROID_DIR/lib/cmake/Qt6/qt.toolchain.cmake\" \
          -DQT_HOST_PATH=\"\$QT_HOST_DIR\" \
          -DCMAKE_PREFIX_PATH=\"\$QT_ANDROID_DIR\" \
          -DANDROID_SDK_ROOT=\"\$ANDROID_SDK_ROOT\" \
          -DANDROID_NDK_ROOT=\"\$ANDROID_NDK_ROOT\"
        cmake --build '$dir' --target apk
      "

# Install + launch the APK last built by `android-build variant`.
android-run variant:
    #!/usr/bin/env bash
    set -euo pipefail
    # Run on the HOST, not in the container: Docker Desktop on macOS doesn't
    # reliably pass USB devices through. Mirrors CMakeLists.txt's own
    # ANDROID-only `run` target (adb install -r, then `am start` on
    # QtActivity), just using the host's adb instead of one inside a container.
    apk="{{ justfile_directory() }}/build/docker-{{ variant }}/android-build/qthomeassistant.apk"
    if [ ! -f "$apk" ]; then
      echo "no APK at $apk -- run 'just android-build {{ variant }}' first" >&2
      exit 1
    fi
    adb install -r "$apk"
    adb shell am start -n org.qtproject.example.qthomeassistant/org.qtproject.qt.android.bindings.QtActivity

# Build then install+launch in one step.
android-deploy variant: (android-build variant) (android-run variant)
