cmake_minimum_required(VERSION 3.16)

project(
  qt-hass
  VERSION 0.1
  LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

find_package(Qt6 6.6 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup()

qt_add_executable(appqt-hass main.cpp controller.cpp hass.cpp)
set_source_files_properties(qml/AppSettings.qml PROPERTIES QT_QML_SINGLETON_TYPE
                                                           TRUE)
if(QT_KNOWN_POLICY_QTP0004)
  qt_policy(SET QTP0004 NEW)
endif()

if(QT_KNOWN_POLICY_QTP0001)
  qt_policy(SET QTP0001 NEW)
endif()

qt_add_qml_module(
  appqt-hass
  URI
  QtHass
  VERSION
  1.0
  QML_FILES
  qml/Main.qml
  qml/Dashboard.qml
  qml/DetailsPopup.qml
  qml/EntityBase.qml
  qml/VisualItemBase.qml
  qml/SettingsMenu.qml
  qml/AppSettings.qml
  qml/Layouts/BaseLayout.qml
  qml/Layouts/VerticalStack.qml
  qml/Layouts/HorizontalStack.qml
  qml/Layouts/GridStack.qml
  qml/Cards/Rectangle.qml
  qml/Cards/Horizontal-stack.qml
  qml/Cards/Spacer.qml
  qml/Cards/Light.qml
  qml/Cards/Custom/MushroomLightCard.qml
  qml/Cards/Custom/MushroomClimateCard.qml
  qml/Cards/Entity.qml
  qml/Cards/Button.qml
  qml/Details/Light.qml
  qml/Details/Climate.qml
  qml/Components/Switch.qml
  qml/Components/BrightnessSlider.qml
  qml/Test1.qml
  qml/Test2.qml
  qml/Screensavers/Clock.qml
  qml/Screensavers/Black.qml
  RESOURCES
  homekit-bg-blue-red.jpg
  qml/Hass.js
  images/lightbulb.svg
  images/drawer.svg
  images/menu.svg
  images/lightbulb-off.svg
  images/power.svg
  images/power-off.svg
  images/brightness.svg
  RESOURCE_PREFIX
  "/")

set_target_properties(
  appqt-hass
  PROPERTIES # MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appqt-hass
             MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
             MACOSX_BUNDLE_SHORT_VERSION_STRING
             ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
             MACOSX_BUNDLE TRUE
             WIN32_EXECUTABLE TRUE)

target_compile_definitions(appqt-hass
                           PRIVATE SOURCE_DIRECTORY=\"${CMAKE_SOURCE_DIR}\")
target_link_libraries(appqt-hass PRIVATE Qt6::Quick Qt6::QuickControls2)

include(GNUInstallDirs)
install(
  TARGETS appqt-hass
  BUNDLE DESTINATION .
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
