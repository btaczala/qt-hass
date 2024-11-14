qt_add_library(UtilitiesLib STATIC)

set_target_properties(UtilitiesLib PROPERTIES AUTOMOC ON)
target_link_libraries(UtilitiesLib PRIVATE Qt6::Quick)

list(APPEND MODULE_JS_FILES HassAPI.js)

qt_add_qml_module(
  UtilitiesLib
  URI
  HassAPI
  VERSION
  1.0
  RESOURCE_PREFIX
  /qthomeassistant/imports
  QML_FILES
  ${MODULE_QML_FILES}
  ${MODULE_JS_FILES})
