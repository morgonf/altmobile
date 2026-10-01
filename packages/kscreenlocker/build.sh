#!/bin/sh
# Сборка целей kscreenlocker (по умолчанию kscreenlocker_greet) из исходников ALT (rpmbuild -bp --nodeps
# --define "__ubt_branch_id M110") с патчами kscreenlocker-greet-rearm.patch и
# kscreenlocker-kcm-mobile.patch (цель kcm_screenlocker).
# Четыре потока, около десяти минут. Лог в /home/altlinux/kslbuild.log.
exec > /home/altlinux/kslbuild.log 2>&1
cd /home/altlinux/RPM/BUILD/kscreenlocker-6.7.5
mkdir -p BUILD && cd BUILD
export PATH=/home/altlinux/RPM/BUILD/kscreenlocker-6.7.5/bin_fake:$PATH
export LC_ALL=C.UTF-8 PATH=/usr/lib/kf6/bin:$PATH CFLAGS="-O2 -g" CXXFLAGS="-O2 -g"
INC=$(rpm --eval %_K6inc)
echo "== configure"
[ -f Makefile ] || cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
	-DKDE_INSTALL_LIBDIR=lib64 -DKDE_INSTALL_INCLUDEDIR=$INC \
	-DKDE_INSTALL_LIBEXECDIR=/usr/libexec \
	> /home/altlinux/kslcmake.log 2>&1
echo "cmake rc=$?"; grep -E "CMake Error" -A3 /home/altlinux/kslcmake.log | head -10
T=${*:-kscreenlocker_greet}
echo "== build $T"
make -j4 $T > /home/altlinux/kslmake.log 2>&1; echo "make rc=$?"
grep -E "error:" /home/altlinux/kslmake.log | head -5
echo done
