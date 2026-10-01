#!/bin/sh
# Сборка kcm_altappearance на телефоне, лог в /home/altlinux/altappearance.log
exec > /home/altlinux/altappearance.log 2>&1
cd /home/altlinux/alt-settings/kcm_altappearance
mkdir -p build && cd build
[ -f Makefile ] || cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DKDE_INSTALL_LIBDIR=lib64
echo "cmake rc=$?"
make -j4; echo "make rc=$?"
