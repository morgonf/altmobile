# ALT Mobile: помощник KAuth, включает и выключает sshd
add_executable(sshhelper sshhelper.cpp)
target_link_libraries(sshhelper Qt::Core KF6::AuthCore)
install(TARGETS sshhelper DESTINATION ${KAUTH_HELPER_INSTALL_DIR})
kauth_install_helper_files(sshhelper org.altmobile.ssh root)
kauth_install_actions(org.altmobile.ssh org.altmobile.ssh.actions)
