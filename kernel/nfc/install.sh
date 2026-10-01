#!/bin/sh
# Установка модулей NFC в updates, от root. Действуют после перезагрузки:
# выгружать работающий штатный nxp-nci нельзя, его remove() попадает во
# взаимную блокировку (это и чинит nxp-nci-remove-deadlock.patch).
# В updates лежат и другие наши модули (sa3103, imx371, imx376): каталог
# целиком не удалять. Откат: удалить только nci.ko, nxp-nci.ko,
# nxp-nci_i2c.ko и выполнить /sbin/depmod -a.
set -e
export PATH=/sbin:/usr/sbin:$PATH
U=/lib/modules/$(uname -r)/updates
install -d $U
install -m 644 /home/altlinux/nci-build/nci/nci.ko $U/
install -m 644 /home/altlinux/nxpnci-build/nxp-nci/nxp-nci.ko /home/altlinux/nxpnci-build/nxp-nci/nxp-nci_i2c.ko $U/
depmod -a
ls -l $U
