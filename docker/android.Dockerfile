# Android arm64-v8a toolchain for qt-hass, parameterized by Qt version so the
# same file produces both kits CLAUDE.md's Android section describes: qt67
# (Qt 6.7.3, targets API 27+ devices) and qt610 (Qt 6.10.1, API 28+ only --
# its libQt6Core calls getentropy(), missing on Bionic before API 28). Build
# via `just android-image qt67` / `qt610` rather than invoking docker build
# directly, so QT_VERSION and NDK_VERSION stay paired correctly (see the
# justfile) -- an ANDROID_NDK_ROOT/Qt-android-kit mismatch fails at CMake
# configure time, not obviously.
#
# This image holds only the toolchain (Qt, the Android SDK/NDK, JDK, CMake).
# The app source is bind-mounted in at `docker run` time (see the justfile's
# android-build recipe) -- rebuilding this image is only needed when the
# toolchain itself changes, not on every app source edit.
# linux/amd64 even on an Apple Silicon host (run under Docker Desktop's
# emulation): the NDK and aqt's Linux Qt kits (including the gcc_64 host kit's
# moc/rcc/qmlcachegen) only ship x86_64 binaries, and JAVA_HOME below is the
# amd64 JDK path. Left to default, Docker picks linux/arm64 there and
# sdkmanager fails straight away on the nonexistent JAVA_HOME.
FROM --platform=linux/amd64 ubuntu:24.04

ARG QT_VERSION=6.10.1
ARG NDK_VERSION=27.3.13750724
# qtcharts/qtmultimedia/qtwebsockets are required components (see
# CMakeLists.txt's find_package(Qt6 ... COMPONENTS ... Charts)); qtshadertools
# is optional (AnimatedBackground's dithered gradient, see CLAUDE.md) but
# cheap to include so the docker build has feature parity with a host build.
ARG QT_MODULES="qtcharts qtmultimedia qtwebsockets qtshadertools qtimageformats"
# Bump by re-checking https://developer.android.com/studio#command-tools for
# the current "command line tools only" package and its build id.
ARG CMDLINE_TOOLS_VERSION=11076708

ENV DEBIAN_FRONTEND=noninteractive

# build-essential/git/curl/unzip: toolchain plumbing (qtmqtt's source build
# below needs a compiler even though its target is Android, since qt-cmake's
# qt_build_repo also runs host-side code generators).
# libxkbcommon0/libgl1/libglx-mesa0/libegl1/fontconfig/libx11-6 et al: Qt's
# own host-side build tools (qmlcachegen, rcc) link against QtGui and probe
# for a platform plugin even when only generating code; QT_QPA_PLATFORM below
# forces the offscreen one, but the plugin still needs these libs present to
# load at all.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git curl unzip ca-certificates \
      cmake ninja-build python3 python3-pip python3-venv \
      openjdk-17-jdk \
      libxkbcommon0 libgl1 libglx-mesa0 libegl1 \
      fontconfig libfontconfig1 libfreetype6 \
      libx11-6 libxext6 libxrender1 libxi6 libsm6 libice6 \
  && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV QT_QPA_PLATFORM=offscreen

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}"

# Google only ships the bootstrap cmdline-tools as a zip, not a package repo
# entry -- sdkmanager (inside that zip) is what installs everything else.
RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
  && curl -fsSL -o /tmp/cmdline-tools.zip \
       "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip" \
  && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
  && mv /tmp/cmdline-tools/cmdline-tools "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
  && rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip

# platforms;android-34 only (not 36): matches the isolated SDK root the host
# build uses for its qt67 kit (see CLAUDE.md) to dodge AGP 7.4.1's aapt2
# failing to parse the android-36 platform jar. Since this image never
# installs android-36 at all, both qt67 and qt610 get that safety for free
# without needing the host's separate sdk-compat-api34 symlink farm.
RUN yes | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses >/dev/null \
  && sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" \
       "platform-tools" \
       "platforms;android-34" \
       "build-tools;34.0.0" \
       "ndk;${NDK_VERSION}"

ENV ANDROID_NDK_ROOT="${ANDROID_SDK_ROOT}/ndk/${NDK_VERSION}"

RUN pip3 install --no-cache-dir --break-system-packages aqtinstall

ARG QT_INSTALL_DIR=/opt/qt

# Two kits: a Linux desktop one purely to act as QT_HOST_PATH for
# cross-compiling (its own Gui/Quick/etc. are never linked into the Android
# app), and the android_arm64_v8a target kit that actually builds the app.
RUN aqt install-qt linux desktop "${QT_VERSION}" gcc_64 \
      -O "${QT_INSTALL_DIR}" -m ${QT_MODULES} \
  && aqt install-qt linux android "${QT_VERSION}" android_arm64_v8a \
      -O "${QT_INSTALL_DIR}" -m ${QT_MODULES}

ENV QT_HOST_DIR="${QT_INSTALL_DIR}/${QT_VERSION}/gcc_64"
ENV QT_ANDROID_DIR="${QT_INSTALL_DIR}/${QT_VERSION}/android_arm64_v8a"

# Qt MQTT (MqttPublisher, see CLAUDE.md) has no prebuilt package for any Qt
# version/platform this project uses, built from source once, straight into
# the android kit's own prefix, exactly like the host recipe in CLAUDE.md --
# minus the two macOS-only workarounds it needs (no Xcode check to skip, and
# the Ninja Multi-Config AUTOMOC bug is CMake/Qt-version-specific rather than
# OS-specific, so -G Ninja is applied here too for the same reason).
RUN git clone --branch "v${QT_VERSION}" --depth 1 https://github.com/qt/qtmqtt.git /tmp/qtmqtt \
  && "${QT_ANDROID_DIR}/bin/qt-cmake" -G Ninja -S /tmp/qtmqtt -B /tmp/qtmqtt-build \
       -DQT_HOST_PATH="${QT_HOST_DIR}" -DCMAKE_BUILD_TYPE=Release \
  && cmake --build /tmp/qtmqtt-build \
  && cmake --install /tmp/qtmqtt-build \
  && rm -rf /tmp/qtmqtt /tmp/qtmqtt-build

WORKDIR /workspace
