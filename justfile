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

image_tag := "qthass-android"
gradle_cache_volume := "qthass-gradle-cache"

# Build (or rebuild) the Android toolchain image for `variant`.
android-image variant:
    #!/usr/bin/env bash
    set -euo pipefail
    # Only needs re-running when docker/android.Dockerfile changes or a
    # Qt/NDK version is bumped -- not on every app source edit, since the app
    # itself is bind-mounted in at build time, not baked into the image.
    case "{{ variant }}" in
      qt67)  qt=6.7.3;  ndk=26.1.10909125 ;;
      qt610) qt=6.10.1; ndk=27.3.13750724 ;;
      *) echo "variant must be qt67 or qt610, got '{{ variant }}'" >&2; exit 1 ;;
    esac
    docker build -f docker/android.Dockerfile \
      --build-arg QT_VERSION="$qt" \
      --build-arg NDK_VERSION="$ndk" \
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
    docker run --rm \
      -v "{{ justfile_directory() }}":/workspace \
      -v {{ gradle_cache_volume }}:/root/.gradle \
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
