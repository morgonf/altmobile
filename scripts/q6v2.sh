#!/bin/sh
# Разговор на топологии TX_SM_ECNS_V2 (0x10f89) с заводской калибровкой пары
# устройств 4/7 (вариант 7, передача 8 кГц): включён только модуль 0x10f1f.
# Требует запущенного hexagonrpcd (hexstart.sh), иначе модуль не загрузится
# и TOPOLOGY_COMMIT откажет. Запуск от root. Вернуть первую версию:
#   amixer -c0 cset name='VoiceMMode1 TX Topology' 69489

set -e
install -m 644 /home/altlinux/cal-v2-factory.bin /lib/firmware/cal-v2-factory.bin
printf %s cal-v2-factory.bin > /sys/module/q6voice/parameters/cal_firmware
echo N > /sys/module/q6voice/parameters/probe_topologies
echo Y > /sys/module/q6voice/parameters/cal_after_start
echo Y > /sys/module/q6voice/parameters/cal_readback
echo Y > /sys/module/q6cvp/parameters/ec_ref_info
echo Y > /sys/module/q6cvp/parameters/ds_mapping
# внешняя опора эхоподавителя с порта приёма, режим EC_EXT_MIXING
echo Y > /sys/module/q6cvp/parameters/ec_ref_rx
echo 0x10F7D > /sys/module/q6cvp/parameters/vocproc_mode
amixer -c0 cset name='VoiceMMode1 TX Topology' 69513 >/dev/null
# управление на ходу без su: live_set и live_get открыты на запись всем
chmod 0222 /sys/module/q6voice/parameters/live_set /sys/module/q6voice/parameters/live_get
echo "cal_firmware = '$(cat /sys/module/q6voice/parameters/cal_firmware)'"
echo "probe_topologies = $(cat /sys/module/q6voice/parameters/probe_topologies)"
echo "cal_after_start = $(cat /sys/module/q6voice/parameters/cal_after_start)"
echo "cal_readback = $(cat /sys/module/q6voice/parameters/cal_readback)"
echo "ec_ref_info = $(cat /sys/module/q6cvp/parameters/ec_ref_info)"
echo "ds_mapping = $(cat /sys/module/q6cvp/parameters/ds_mapping)"
echo "ec_ref_rx = $(cat /sys/module/q6cvp/parameters/ec_ref_rx)"
echo "vocproc_mode = $(printf %#x $(cat /sys/module/q6cvp/parameters/vocproc_mode))"
amixer -c0 cget name='VoiceMMode1 TX Topology' | tail -1
systemctl is-active hexrpc-adsp
