# ALT Mobile: страница «Местоположение» для plasma-settings
cmake_minimum_required(VERSION 3.20)
project(kcm_altlocation)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
set(QT_MAJOR_VERSION 6)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

find_package(Qt6 REQUIRED COMPONENTS Core Quick DBus Xml)
find_package(KF6 REQUIRED COMPONENTS KCMUtils CoreAddons)

kcmutils_add_qml_kcm(kcm_altlocation SOURCES kcm.cpp)
target_link_libraries(kcm_altlocation PRIVATE
    Qt::DBus
    Qt::Xml
    KF6::KCMUtilsQuick
    KF6::CoreAddons
)
