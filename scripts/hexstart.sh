#!/bin/sh
# Запуск hexagonrpcd с реализацией apps_std_ftell на rootpd ADSP, чтобы
# процессор мог загрузить реестр модулей adsp_avs_config.acdb и динамические
# модули mmecns_module.so.1 (ECNS v2) и fluence_voiceplus_module.so.1.
# Запуск от root после перезагрузки. Останов: systemctl stop hexrpc-adsp.

systemd-run --unit=hexrpc-adsp --collect \
	stdbuf -oL -eL /home/altlinux/hexrpc/hexagonrpcd-ftell \
	-f /dev/fastrpc-adsp -d adsp -R /var/lib/droid-juicer/sensors/
sleep 10
systemctl is-active hexrpc-adsp
journalctl -b -u hexrpc-adsp --no-pager | tail -80
/home/altlinux/q6probe.sh
