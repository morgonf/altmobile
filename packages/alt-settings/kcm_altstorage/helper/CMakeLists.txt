# ALT Mobile: помощник KAuth, удаляет скачанные пакеты apt
add_executable(storagehelper storagehelper.cpp)
target_link_libraries(storagehelper Qt::Core KF6::AuthCore)
install(TARGETS storagehelper DESTINATION ${KAUTH_HELPER_INSTALL_DIR})
kauth_install_helper_files(storagehelper org.altmobile.storage root)
kauth_install_actions(org.altmobile.storage org.altmobile.storage.actions)
