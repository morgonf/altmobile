#!/bin/sh
# Сборка модулей NFC вне дерева ядра на телефоне (от пользователя).
# Исходники v7.0 с kernel.org: net/nfc/nci (в ядре ALT
# kernel-image-qualcomm-sdm845-7.1.0-alt0.rc1 не изменён) и
# drivers/nfc/nxp-nci (патч ALT меняет в нём только firmware.c, правка
# повторена ниже). Результат в ~/nci-build/nci и ~/nxpnci-build/nxp-nci.
set -e
R="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain"
T=v7.0
H=$(dirname "$(readlink -f "$0")")
K=/lib/modules/$(uname -r)/build
rm -rf ~/nci-build ~/nxpnci-build
mkdir -p ~/nci-build/nci ~/nxpnci-build/nxp-nci
cd ~/nci-build
curl -sfL -o nfc.h "$R/net/nfc/nfc.h?h=$T"
for f in core.c data.c lib.c ntf.c rsp.c hci.c; do curl -sfL -o nci/$f "$R/net/nfc/nci/$f?h=$T"; done
(cd nci && git apply -p4 "$H/nci-skip-classic-t2t.patch")
cp "$H/Makefile.nci" nci/Makefile
make -C $K M=$PWD/nci modules
cd ~/nxpnci-build/nxp-nci
for f in core.c firmware.c i2c.c nxp-nci.h; do curl -sfL -o $f "$R/drivers/nfc/nxp-nci/$f?h=$T"; done
sed -i 's/\tstrcpy(fw_info->name, firmware_name);/\tstrscpy(fw_info->name, firmware_name);/' firmware.c
git apply -p4 "$H/nxp-nci-remove-deadlock.patch"
cp "$H/Makefile.nxp-nci" Makefile
make -C $K M=$PWD modules
