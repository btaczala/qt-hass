cmake_minimum_required(VERSION 3.16)

project(
  qt-hass
  VERSION 0.1
  LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

find_package(Qt6 6.6 REQUIRED COMPONENTS Quick QuickControls2 Charts)

FetchContent_Declare(
  yaml-cpp
  GIT_REPOSITORY https://github.com/jbeder/yaml-cpp
  GIT_TAG 0.8.0)
FetchContent_MakeAvailable(yaml-cpp)

qt_standard_project_setup()

qt_add_executable(appqt-hass main.cpp controller.cpp hass.cpp)

qt_add_qml_module(
  appqt-hass
  URI
  qt-hass
  VERSION
  1.0
  QML_FILES
  qml/Main.qml
  qml/Clock.qml
  qml/Dashboard.qml
  qml/DetailsPopup.qml
  qml/EntityBase.qml
  qml/VisualItemBase.qml
  qml/Settings.qml
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
  qml/Test1.qml
  qml/Test2.qml
  RESOURCES
  homekit-bg-blue-red.jpg
  qml/Hass.js
  images/lightbulb.svg
  images/drawer.svg
  images/menu.svg
  images/lightbulb-off.svg)

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
target_link_libraries(appqt-hass PRIVATE Qt6::Quick Qt6::QuickControls2
                                         yaml-cpp)

include(GNUInstallDirs)
install(
  TARGETS appqt-hass
  BUNDLE DESTINATION .
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
