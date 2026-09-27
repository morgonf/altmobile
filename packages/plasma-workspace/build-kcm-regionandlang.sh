#!/bin/sh
exec > /home/altlinux/rlbuild.log 2>&1
cd /home/altlinux/RPM/BUILD/plasma-workspace-6.7.5
# Дерево сборки переиспользуется, конфигурация только при первом запуске.
# Четыре потока, температуру стережёт scripts/build-thermal-guard.sh.
mkdir -p BUILD && cd BUILD
export LC_ALL=C.UTF-8 PATH=/usr/lib/kf6/bin:$PATH CFLAGS="-O2 -g" CXXFLAGS="-O2 -g"
INC=$(rpm --eval %_K6inc)
echo "== configure"
[ -f Makefile ] || cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
	-DKDE_INSTALL_LIBDIR=lib64 -DLIB_INSTALL_DIR=/usr/lib64 -DPLUGIN_INSTALL_DIR=/usr/lib64/qt6/plugins -DQT_PLUGIN_INSTALL_DIR=/usr/lib64/qt6/plugins -DQML_INSTALL_DIR=/usr/lib64/qt6/qml -DDATA_INSTALL_DIR=/usr/share -DCONFIG_INSTALL_DIR=/etc/xdg -DLIBEXEC_INSTALL_DIR=/usr/libexec -DKCFG_INSTALL_DIR=/usr/share/config.kcfg -DXDG_APPS_INSTALL_DIR=/usr/share/applications -DAUTOSTART_INSTALL_DIR=/etc/xdg/autostart \
	-DINCLUDE_INSTALL_DIR=$INC -DKDE_INSTALL_INCLUDEDIR=$INC \
	-DUBUNTU_PACKAGEKIT=OFF -DGLIBC_LOCALE_GENERATED=ON -DGLIBC_LOCALE_GEN=OFF \
	-DAppStreamQt_DIR:PATH=$PWD/../cmake/AppStreamQt -DPACKAGEKIT_OFFLINE_UPDATES=ON \
	> /home/altlinux/rlcmake.log 2>&1
echo "cmake rc=$?"; grep -E "CMake Error|Could NOT find.*REQUIRED" /home/altlinux/rlcmake.log | head -5
echo "== build"
make -j4 kcm_regionandlang > /home/altlinux/rlmake.log 2>&1; echo "make rc=$?"
grep -E "error:" /home/altlinux/rlmake.log | head -5
find . -name "kcm_regionandlang.so" -exec ls -l {} \;
echo done
