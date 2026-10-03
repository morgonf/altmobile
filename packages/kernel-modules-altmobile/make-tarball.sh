#!/bin/sh
# Тарбол altmobile-kmodules-1.0.tar для спецификации: sa3103 из репозитория,
# imx371/imx376 из sdm845-mainline (закреплённый коммит), NFC из Linux v7.0.
# make-tarball.sh КАТАЛОГ_ВЫВОДА
set -e
H=$(dirname "$(readlink -f "$0")")/../../kernel
O=$(readlink -f "${1:-.}")
W=$(mktemp -d)/altmobile-kmodules-1.0
mkdir -p $W/sa3103 $W/imx37x $W/nfc/nci $W/nfc/nxp-nci
cp $H/sa3103/sa3103.c $H/sa3103/Makefile $W/sa3103/
cp $H/imx37x/Makefile $W/imx37x/
C=85f1df2a4ec71d7a91dd95a7a49f889d1595ffa8
for f in imx371 imx376; do
	curl -sfL -o $W/imx37x/$f.c https://gitlab.com/sdm845-mainline/linux/-/raw/$C/drivers/media/i2c/$f.c
done
R="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain"
T=v7.0
curl -sfL -o $W/nfc/nfc.h "$R/net/nfc/nfc.h?h=$T"
for f in core.c data.c lib.c ntf.c rsp.c hci.c; do curl -sfL -o $W/nfc/nci/$f "$R/net/nfc/nci/$f?h=$T"; done
for f in core.c firmware.c i2c.c nxp-nci.h; do curl -sfL -o $W/nfc/nxp-nci/$f "$R/drivers/nfc/nxp-nci/$f?h=$T"; done
cp $H/nfc/Makefile.nci $W/nfc/nci/Makefile
cp $H/nfc/Makefile.nxp-nci $W/nfc/nxp-nci/Makefile
tar -C $(dirname $W) -cf $O/altmobile-kmodules-1.0.tar altmobile-kmodules-1.0
rm -rf $(dirname $W)
echo "$O/altmobile-kmodules-1.0.tar"
