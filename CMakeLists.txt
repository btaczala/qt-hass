cmake_minimum_required(VERSION 3.16)

project(
  QtHomeAssistant
  VERSION 0.1
  LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 23)

find_package(
  Qt6 6.2
  COMPONENTS Gui Quick Multimedia WebSockets QuickControls2
  REQUIRED)

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
  QML_FILES
  qml/main.qml
  qml/EntityBase.qml
  qml/Light.qml
  RESOURCES
  qtquickcontrols2.conf
  images/lightbulb.svg
  images/lightbulb-off.svg)

set_target_properties(
  qthomeassistant
  PROPERTIES MACOSX_BUNDLE_GUI_IDENTIFIER bartek.homeassistant
             MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
             MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
             MACOSX_BUNDLE TRUE
             WIN32_EXECUTABLE TRUE)

add_subdirectory(3rdParty)

target_link_libraries(qthomeassistant PRIVATE Qt6::Gui Qt6::Quick Qt6::Multimedia Qt6::WebSockets
                                              Qt6::QuickControls2)

target_compile_definitions(qthomeassistant PRIVATE SOURCE_DIRECTORY="${CMAKE_SOURCE_DIR}")

install(
  TARGETS qthomeassistant
  BUNDLE DESTINATION .
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
