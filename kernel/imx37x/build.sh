#!/bin/sh
# Сборка исправленных imx371 и imx376 на телефоне. Исходники берутся из
# sdm845-mainline (ветка sdm845/7.1-dev, из неё же ядро ALT), коммит
# закреплён, поверх накладывается imx37x-alt-mobile.patch.
set -e
cd "$(dirname "$0")"
C=85f1df2a4ec71d7a91dd95a7a49f889d1595ffa8
for f in imx371 imx376; do
	curl -sfL -o $f.c https://gitlab.com/sdm845-mainline/linux/-/raw/$C/drivers/media/i2c/$f.c
done
patch -p1 < imx37x-alt-mobile.patch
make -j4
