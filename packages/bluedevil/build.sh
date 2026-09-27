#!/bin/sh
# Сборка отдельных целей bluedevil-6.7.5 из исходников ALT (rpmbuild -bp --nodeps).
# Для конфигурации нужен kf6-bluez-qt-devel.
# Четыре потока, температуру стережёт
# scripts/build-thermal-guard.sh. Цели передаются аргументами.
exec > /home/altlinux/bluedevil-6.7.5.log 2>&1
cd /home/altlinux/RPM/BUILD/bluedevil-6.7.5
mkdir -p BUILD && cd BUILD
export LC_ALL=C.UTF-8 PATH=/usr/lib/kf6/bin:$PATH CFLAGS="-O2 -g" CXXFLAGS="-O2 -g"
INC=$(rpm --eval %_K6inc)
echo "== configure"
[ -f Makefile ] || cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
	-DKDE_INSTALL_LIBDIR=lib64 -DKDE_INSTALL_INCLUDEDIR=$INC \
	-DLIBEXEC_INSTALL_DIR:PATH=/usr/libexec/kf6 \
	> /home/altlinux/bluedevil-6.7.5-cmake.log 2>&1
echo "cmake rc=$?"; grep -E "CMake Error" -A3 /home/altlinux/bluedevil-6.7.5-cmake.log | head -10
echo "== build $*"
make -j4 "$@" > /home/altlinux/bluedevil-6.7.5-make.log 2>&1; echo "make rc=$?"
grep -E "error:" /home/altlinux/bluedevil-6.7.5-make.log | head -5
echo done
