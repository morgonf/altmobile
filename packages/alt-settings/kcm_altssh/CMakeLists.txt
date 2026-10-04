# ALT Mobile: страница «Доступ по SSH» для plasma-settings
cmake_minimum_required(VERSION 3.20)
project(kcm_altssh)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
set(QT_MAJOR_VERSION 6)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

find_package(Qt6 REQUIRED COMPONENTS Core Quick DBus Network)
find_package(KF6 REQUIRED COMPONENTS KCMUtils CoreAddons Auth)

kcmutils_add_qml_kcm(kcm_altssh SOURCES kcm.cpp)
target_link_libraries(kcm_altssh PRIVATE
    Qt::DBus
    Qt::Network
    KF6::KCMUtilsQuick
    KF6::CoreAddons
    KF6::AuthCore
)

add_subdirectory(helper)
