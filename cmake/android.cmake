# Android-only build settings, included from the root CMakeLists.txt inside
# if(ANDROID) after the qthomeassistant target is defined.

# Android doesn't expose OpenSSL to NDK apps, so QtWebSockets has no TLS backend
# for wss:// unless we bundle it ourselves. Prebuilt from
# https://github.com/KDAB/android_openssl (Apache-2.0), commit b71f1470, the
# "no-asm" build it recommends for Debug. Only arm64-v8a is vendored, matching
# the only Android ABI kit this project builds against so far; a Release
# Android build or another ABI needs its own lib pair added under
# android/openssl/<abi>.
if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
  set_target_properties(
    qthomeassistant PROPERTIES
    QT_ANDROID_EXTRA_LIBS
    "${CMAKE_CURRENT_SOURCE_DIR}/android/openssl/arm64-v8a/libcrypto_3.so;${CMAKE_CURRENT_SOURCE_DIR}/android/openssl/arm64-v8a/libssl_3.so"
  )
endif()

if(Qt6_VERSION VERSION_LESS 6.8)
  # Qt < 6.8's Gradle templates pull AGP 7.4.1, whose bundled aapt2 can't
  # parse the android-36 platform jar (androiddeployqt's default compileSdk,
  # a platform much newer than AGP 7.4.1 was built for) -- aapt2 fails with
  # "RES_TABLE_TYPE_TYPE entry offsets overlap actual entry data". Pin
  # compileSdk down to something that AGP actually understands; 34 still
  # covers this Qt version's targetSdk (also 34).
  set_target_properties(qthomeassistant PROPERTIES QT_ANDROID_COMPILE_SDK_VERSION "android-34")
endif()

set(ANDROID_PACKAGE_NAME "org.qtproject.qthass.qthomeassistant")

find_program(
  ADB_EXECUTABLE adb
  HINTS "${ANDROID_SDK_ROOT}/platform-tools" "$ENV{ANDROID_SDK_ROOT}/platform-tools"
)
if(ADB_EXECUTABLE)
  add_custom_target(
    run
    COMMAND ${ADB_EXECUTABLE} install -r
            "${CMAKE_CURRENT_BINARY_DIR}/android-build/qthomeassistant.apk"
    COMMAND ${ADB_EXECUTABLE} shell am start -n
            ${ANDROID_PACKAGE_NAME}/org.qtproject.qt.android.bindings.QtActivity
    DEPENDS qthomeassistant_make_apk
    USES_TERMINAL
    COMMENT "Installing and launching qthomeassistant on the connected Android device")
else()
  message(
    WARNING
      "adb not found (checked ANDROID_SDK_ROOT/platform-tools and PATH) -- the 'run' target won't be available."
  )
endif()
