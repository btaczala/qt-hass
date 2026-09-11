cmake_minimum_required(VERSION 3.10)

project(
  QtHomeAssistant
  VERSION 0.1
  LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 23)

find_package(
  Qt6 6.7
  COMPONENTS Gui Quick Multimedia WebSockets QuickControls2
  REQUIRED)

if(QT_KNOWN_POLICY_QTP0002)
  qt_policy(SET QTP0002 NEW)
endif()
if(QT_KNOWN_POLICY_QTP0004)
  qt_policy(SET QTP0004 NEW)
endif()

# The MDI name -> codepoint table is generated at configure time from the font and
# metadata vendored under fonts/, rather than committed. Both are offline inputs;
# refreshing them to a newer MDI release is a manual, explicitly networked step:
#   python3 tools/generate_mdi_table.py --fetch <version>
find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(MDI_GENERATOR ${CMAKE_CURRENT_SOURCE_DIR}/tools/generate_mdi_table.py)
set(MDI_FONT ${CMAKE_CURRENT_SOURCE_DIR}/fonts/materialdesignicons-webfont.ttf)
set(MDI_META ${CMAKE_CURRENT_SOURCE_DIR}/fonts/materialdesignicons-meta.json)
set(MDI_TABLE ${CMAKE_CURRENT_BINARY_DIR}/generated/mdi_icons_data.h)

# Editing any input re-runs configure, which is what regenerates the table.
set_property(
  DIRECTORY
  APPEND
  PROPERTY CMAKE_CONFIGURE_DEPENDS ${MDI_GENERATOR} ${MDI_FONT} ${MDI_META})

execute_process(
  COMMAND ${Python3_EXECUTABLE} ${MDI_GENERATOR} --font ${MDI_FONT} --meta
          ${MDI_META} --output ${MDI_TABLE}
  RESULT_VARIABLE MDI_RESULT
  OUTPUT_VARIABLE MDI_OUTPUT
  ERROR_VARIABLE MDI_ERROR)

if(NOT MDI_RESULT EQUAL 0)
  message(FATAL_ERROR "Generating ${MDI_TABLE} failed:\n${MDI_OUTPUT}${MDI_ERROR}")
endif()

message(STATUS "MDI icons: ${MDI_OUTPUT}")

qt_add_executable(qthomeassistant src/main.cpp)

qt_add_qml_module(
  qthomeassistant
  URI
  QtHomeAssistant
  VERSION
  1.0
  RESOURCE_PREFIX
  /res
  SOURCES
  hassapi.h
  hassapi.cpp
  controller.h
  controller.cpp
  src/mdi.h
  src/mdi.cpp
  QML_FILES
  qml/Main.qml
  qml/AnimatedBackground.qml
  qml/EntityBase.qml
  qml/Light.qml
  qml/Tile.qml
  qml/TileFeature.qml
  qml/MdiIcon.qml
  qml/IconImage.qml
  qml/Cards/Weather.qml
  qml/Features/ToggleFeature.qml
  qml/Features/LightBrightnessFeature.qml
  RESOURCES
  fonts/materialdesignicons-webfont.ttf
  images/lightbulb.svg
  images/lightbulb-off.svg)

# Qt only looks for the Controls configuration at :/qtquickcontrols2.conf, and
# qt_add_qml_module pins its RESOURCES under RESOURCE_PREFIX/URI -- so this file
# has to be added separately or the Material style silently never activates.
qt_add_resources(qthomeassistant "controls_conf" PREFIX "/" FILES
                 qtquickcontrols2.conf)

set_target_properties(
  qthomeassistant
  PROPERTIES MACOSX_BUNDLE_GUI_IDENTIFIER bartek.homeassistant
             MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
             MACOSX_BUNDLE_SHORT_VERSION_STRING
             ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
             MACOSX_BUNDLE TRUE
             WIN32_EXECUTABLE TRUE)

target_link_libraries(
  qthomeassistant PRIVATE Qt6::Gui Qt6::Quick Qt6::Multimedia Qt6::WebSockets
                          Qt6::QuickControls2)

# qt_add_qml_module's generated type registration includes headers by basename,
# so src/ has to be reachable the same way the root-level headers are.
target_include_directories(qthomeassistant PRIVATE src
                                                   ${CMAKE_CURRENT_BINARY_DIR}/generated)

target_compile_definitions(qthomeassistant
                           PRIVATE SOURCE_DIRECTORY="${CMAKE_SOURCE_DIR}")

# Android doesn't expose OpenSSL to NDK apps, so QtWebSockets has no TLS backend
# for wss:// unless we bundle it ourselves. Prebuilt from
# https://github.com/KDAB/android_openssl (Apache-2.0), commit b71f1470, the
# "no-asm" build it recommends for Debug. Only arm64-v8a is vendored, matching
# the only Android ABI kit this project builds against so far; a Release
# Android build or another ABI needs its own lib pair added under
# android/openssl/<abi>.
if(ANDROID AND CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
  set_target_properties(
    qthomeassistant PROPERTIES
    QT_ANDROID_EXTRA_LIBS
    "${CMAKE_CURRENT_SOURCE_DIR}/android/openssl/arm64-v8a/libcrypto_3.so;${CMAKE_CURRENT_SOURCE_DIR}/android/openssl/arm64-v8a/libssl_3.so"
  )
endif()

if(ANDROID AND Qt6_VERSION VERSION_LESS 6.8)
  # Qt < 6.8's Gradle templates pull AGP 7.4.1, whose bundled aapt2 can't
  # parse the android-36 platform jar (androiddeployqt's default compileSdk,
  # a platform much newer than AGP 7.4.1 was built for) -- aapt2 fails with
  # "RES_TABLE_TYPE_TYPE entry offsets overlap actual entry data". Pin
  # compileSdk down to something that AGP actually understands; 34 still
  # covers this Qt version's targetSdk (also 34).
  set_target_properties(qthomeassistant PROPERTIES QT_ANDROID_COMPILE_SDK_VERSION "android-34")
endif()

if(ANDROID)
  # `cmake --build <dir> --target run`: install the just-built APK on
  # whatever device `adb` currently targets, push a device-local config
  # derived from .envrc, and launch it. The package name is the
  # org.qtproject.example.<target> androiddeployqt falls back to since
  # nothing here sets QT_ANDROID_PACKAGE_NAME -- update it here if that ever
  # changes. QtActivity itself is Qt's own fixed Android bindings class, not
  # project-specific.
  set(ANDROID_PACKAGE_NAME "org.qtproject.example.qthomeassistant")

  find_program(
    ADB_EXECUTABLE adb
    HINTS "${ANDROID_SDK_ROOT}/platform-tools" "$ENV{ANDROID_SDK_ROOT}/platform-tools"
  )
  if(ADB_EXECUTABLE)
    add_custom_target(
      run
      COMMAND ${ADB_EXECUTABLE} install -r
              "${CMAKE_CURRENT_BINARY_DIR}/android-build/qthomeassistant.apk"
      # `run-as` needs the app already installed (its data dir must exist),
      # so this has to come after install and before the app starts. Dev
      # convenience only -- re-derives HASS_URL/HASS_TOKEN from .envrc every
      # time rather than provisioning the device once, see the script.
      COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/tools/push_android_config.py"
              --envrc "${CMAKE_CURRENT_SOURCE_DIR}/.envrc"
              --package ${ANDROID_PACKAGE_NAME}
              --out "${CMAKE_CURRENT_BINARY_DIR}/config"
              --adb ${ADB_EXECUTABLE}
      # Controler::pathFor()'s /sdcard/qt-hass fallback (see qml/Main.qml) is
      # the only one of its three search paths that exists on-device --
      # SOURCE_DIRECTORY is baked in at compile time as this machine's path,
      # and /usr/share/qt-hass is a desktop-only convention. Unlike the config
      # above, /sdcard is plain external storage: no run-as needed, and it
      # doesn't require the app to already be installed.
      COMMAND ${ADB_EXECUTABLE} shell mkdir -p /sdcard/qt-hass
      COMMAND ${ADB_EXECUTABLE} push "${CMAKE_CURRENT_SOURCE_DIR}/default_dashboard"
              /sdcard/qt-hass/
      COMMAND ${ADB_EXECUTABLE} shell am start -n
              ${ANDROID_PACKAGE_NAME}/org.qtproject.qt.android.bindings.QtActivity
      DEPENDS qthomeassistant_make_apk
      USES_TERMINAL
      COMMENT "Installing qthomeassistant, pushing its config and dashboard, and launching it on the connected Android device")
  else()
    message(
      WARNING
        "adb not found (checked ANDROID_SDK_ROOT/platform-tools and PATH) -- the 'run' target won't be available."
    )
  endif()
endif()

install(
  TARGETS qthomeassistant
  BUNDLE DESTINATION .
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
