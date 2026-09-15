cmake_minimum_required(VERSION 3.10)

project(
  QtHomeAssistant
  VERSION 0.2
  LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 23)

# Capped below 6.12: Qt Charts (energy detail overlays) is deprecated since
# 6.10 and may be gone in 6.12, so a newer kit must fail here rather than at
# the Charts component.
find_package(
  Qt6 6.7...<6.12
  COMPONENTS Gui Quick Multimedia WebSockets QuickControls2 Network Widgets Charts
  REQUIRED
  OPTIONAL_COMPONENTS Mqtt ShaderTools)

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

set(CONFIG_GENERATOR ${CMAKE_CURRENT_SOURCE_DIR}/tools/generate_config.py)
set(ENVRC ${CMAKE_CURRENT_SOURCE_DIR}/.envrc)
set(CONFIG_FILE ${CMAKE_CURRENT_SOURCE_DIR}/config)
set(HASS_CONFIG ${CMAKE_CURRENT_BINARY_DIR}/generated/config)

set_property(
  DIRECTORY
  APPEND
  PROPERTY CMAKE_CONFIGURE_DEPENDS ${CONFIG_GENERATOR})
foreach(input ${ENVRC} ${CONFIG_FILE})
  if(EXISTS ${input})
    set_property(
      DIRECTORY
      APPEND
      PROPERTY CMAKE_CONFIGURE_DEPENDS ${input})
  endif()
endforeach()

execute_process(
  COMMAND ${Python3_EXECUTABLE} ${CONFIG_GENERATOR} --envrc ${ENVRC} --config
          ${CONFIG_FILE} --out ${HASS_CONFIG}
  RESULT_VARIABLE CONFIG_RESULT
  ERROR_VARIABLE CONFIG_ERROR)

if(NOT CONFIG_RESULT EQUAL 0)
  message(FATAL_ERROR "Generating ${HASS_CONFIG} failed:\n${CONFIG_ERROR}")
elseif(CONFIG_ERROR)
  message(WARNING "${CONFIG_ERROR}")
endif()

qt_add_executable(qthomeassistant src/main.cpp src/remoteadmin.h src/remoteadmin.cpp)

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
  src/dashboardsync.h
  src/dashboardsync.cpp
  QML_FILES
  qml/Main.qml
  qml/AnimatedBackground.qml
  qml/EntityBase.qml
  qml/HassEntity.qml
  qml/Light.qml
  qml/Tile.qml
  qml/TileFeature.qml
  qml/MdiIcon.qml
  qml/IconImage.qml
  qml/Screensaver.qml
  qml/Alarm/AlarmCard.qml
  qml/Alarm/AlarmEntity.qml
  qml/Alarm/AlarmPopup.qml
  qml/Clock.qml
  qml/SystemTray/SystemTray.qml
  qml/SystemTray/SystemTrayIndicators.qml
  qml/SystemTray/BatteryIndicator.qml
  qml/SystemTray/CountIndicator.qml
  qml/SystemTray/HassAlerts.qml
  qml/SystemTray/SystemTrayPanel.qml
  qml/Cards/Weather.qml
  qml/Cards/ButtonCard.qml
  qml/Features/ToggleFeature.qml
  qml/Features/LightBrightnessFeature.qml
  qml/Features/ButtonsFeature.qml
  qml/Dashboard/Dashboard.qml
  qml/Dashboard/DashboardPage.qml
  qml/Dashboard/DashboardOverlay.qml
  qml/Dashboard/DashboardMessage.qml
  qml/Dashboard/DashboardHost.qml
  qml/Cameras/CameraCard.qml
  qml/Cameras/CameraDetails.qml
  qml/Cameras/CameraSensors.qml
  qml/Cameras/CameraStreamPopup.qml
  qml/Cameras/CameraUrls.js
  qml/Energy/EnergyFlowCard.qml
  qml/Energy/EnergyFlowLine.qml
  qml/Energy/EnergyFlows.js
  qml/Energy/EnergyNode.qml
  qml/Energy/EnergySummary.qml
  qml/Energy/HassEnergySource.qml
  qml/Energy/EnergyFlowPage.qml
  qml/Energy/Details/EnergyDetailPopup.qml
  qml/Energy/Details/EnergyChartView.qml
  qml/Energy/Details/EnergyValueAxis.qml
  qml/Energy/Details/EnergyStat.qml
  qml/Energy/Details/EnergyFormat.js
  qml/Energy/Details/SolarDetail.qml
  qml/Energy/Details/SolarDay.qml
  qml/Energy/Details/SolarWeek.qml
  qml/Energy/Details/GridDetail.qml
  qml/Energy/Details/BatteryDetail.qml
  qml/Energy/Details/HomeDetail.qml
  qml/Navigation/NavBar.qml
  qml/Settings/SettingsPage.qml
  qml/Weather/WeatherCard.qml
  qml/Weather/WeatherForecast.qml
  qml/Weather/WeatherIcon.qml
  qml/Weather/WeatherSummary.qml
  qml/Weather/WeatherFormat.js
  qml/Weather/WindIndicator.qml
  qml/Setup/ErrorLabel.qml
  qml/Setup/HassAuth.qml
  qml/Setup/LoginStep.qml
  qml/Setup/OptionsStep.qml
  qml/Setup/ServerStep.qml
  qml/Setup/SetupWizard.qml
  qml/Settings/UiSettings.qml
  RESOURCES
  fonts/materialdesignicons-webfont.ttf
  images/lightbulb.svg
  images/lightbulb-off.svg
  images/screensaver.gif
  images/noise.png)

qt_add_resources(qthomeassistant "controls_conf" PREFIX "/" FILES
                 qtquickcontrols2.conf)

qt_add_resources(qthomeassistant "hass_config" PREFIX "/qt-hass" BASE
                 ${CMAKE_CURRENT_BINARY_DIR}/generated FILES ${HASS_CONFIG})

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
                          Qt6::QuickControls2 Qt6::Network Qt6::Widgets Qt6::Charts)

target_sources(qthomeassistant PRIVATE )

if(COMMAND qt_add_shaders)
  qt_add_shaders(qthomeassistant "background_shaders" PREFIX "/res/QtHomeAssistant"
                 FILES shaders/background.frag)
  target_compile_definitions(qthomeassistant PRIVATE QTHASS_HAS_SHADERS)
  message(STATUS "Qt Shader Tools found: dithered background shader enabled")
else()
  message(STATUS "Qt Shader Tools not found: using the plain background gradient")
endif()

if(TARGET Qt6::Mqtt)
  target_sources(qthomeassistant PRIVATE mqttpublisher.h mqttpublisher.cpp)
  target_link_libraries(qthomeassistant PRIVATE Qt6::Mqtt)
  target_compile_definitions(qthomeassistant PRIVATE QTHASS_HAS_MQTT)
  message(STATUS "Qt MQTT found: MQTT publishing enabled")
else()
  message(STATUS "Qt MQTT not found: building without MQTT publishing")
endif()

target_include_directories(qthomeassistant PRIVATE src
                                                   ${CMAKE_CURRENT_BINARY_DIR}/generated)

target_compile_definitions(qthomeassistant
                           PRIVATE APP_VERSION="${PROJECT_VERSION}")

if(ANDROID)
  include(cmake/android.cmake)
endif()

install(
  TARGETS qthomeassistant
  BUNDLE DESTINATION .
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
