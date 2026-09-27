#!/bin/sh
# Моторы фокуса SA3103 вместо LC898217XC: правка dtb OnePlus 6T и установка
# модуля (собрать заранее: make в этом каталоге на телефоне). От root, затем
# перезагрузка. Откат: вернуть $F.before-sa3103 и удалить updates/sa3103.ko.
set -e
K=$(uname -r)
F=/boot/devicetree/$K/qcom/sdm845-oneplus-fajita.dtb
[ -f $F.before-sa3103 ] || cp -a $F $F.before-sa3103
N0=/soc@0/cci@ac4a000/i2c-bus@0/actuator@72
N1=/soc@0/cci@ac4a000/i2c-bus@1/actuator@74
fdtput -t s $F $N0 compatible altmobile,sa3103
fdtput -t x $F $N0 reg 0c
fdtput -t s $F $N1 compatible altmobile,sa3103
fdtput -t x $F $N1 reg 0d
echo "bus0: $(fdtget $F $N0 compatible) reg $(fdtget -t x $F $N0 reg)"
echo "bus1: $(fdtget $F $N1 compatible) reg $(fdtget -t x $F $N1 reg)"
mkdir -p /lib/modules/$K/updates
install -m 644 "$(dirname "$0")"/sa3103.ko /lib/modules/$K/updates/sa3103.ko
/sbin/depmod -a
grep -c sa3103 /lib/modules/$K/modules.alias
