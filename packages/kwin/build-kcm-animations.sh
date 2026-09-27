#!/bin/sh
# Сборка одной цели kcm_animations из исходников kwin ALT (rpmbuild -bp),
# четыре потока. Температуру стережёт build-thermal-guard.sh.
exec > /home/altlinux/animbuild.log 2>&1
cd /home/altlinux/RPM/BUILD/kwin-6.7.5
patch -p1 -N < /home/altlinux/RPM/SOURCES/kwin-animations-mobile.patch
rm -rf BUILD && mkdir BUILD && cd BUILD
export LC_ALL=C.UTF-8 PATH=/usr/lib/kf6/bin:$PATH CFLAGS="-O2 -g" CXXFLAGS="-O2 -g"
INC=$(rpm --eval %_K6inc)
echo "== configure"
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
	-DKDE_INSTALL_LIBDIR=lib64 -DKDE_INSTALL_INCLUDEDIR=$INC \
	> /home/altlinux/animcmake.log 2>&1
echo "cmake rc=$?"; grep -E "CMake Error|Could NOT find" /home/altlinux/animcmake.log | head -10
echo "== build"
make -j4 kcm_animations > /home/altlinux/animmake.log 2>&1; echo "make rc=$?"
grep -E "error:" /home/altlinux/animmake.log | head -5
find . -name "kcm_animations.so" -exec ls -l {} \;
echo done
