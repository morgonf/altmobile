#!/bin/sh
# Настройка под OnePlus 6T (пп. 2.2 и 2.4 docs/phosh-exit-and-tuning.md), от root.
set -e
export PATH=/sbin:/usr/sbin:$PATH
cd "$(dirname "$0")"
# zram
rpm -q zram-generator >/dev/null || apt-get install -y zram-generator
install -m 644 zram-generator.conf /etc/systemd/zram-generator.conf
install -m 644 90-altmobile-zram.conf /etc/sysctl.d/90-altmobile-zram.conf
sysctl -q -p /etc/sysctl.d/90-altmobile-zram.conf
systemctl daemon-reload
systemctl start systemd-zram-setup@zram0.service dev-zram0.swap
# журнал
install -d /etc/systemd/journald.conf.d
install -m 644 journald-altmobile.conf /etc/systemd/journald.conf.d/altmobile.conf
systemctl restart systemd-journald
journalctl --vacuum-size=100M >/dev/null 2>&1
# Waydroid не настроен (п. 23 бэклога): контейнер только по запуску
systemctl disable --now waydroid-container.service
swapon --show; journalctl --disk-usage; systemctl is-enabled waydroid-container.service || true
# Крупный шрифт консоли при загрузке (п. 8 бэклога): Terminus 16x32 с
# кириллицей вместо UniCyr 8x16. Ядро умеет только 8x8 и 8x16, поэтому
# первые строки ядра остаются мелкими, крупно с запуска systemd в корне.
if grep -q '^FONT=' /etc/vconsole.conf 2>/dev/null; then
	sed -i 's/^FONT=.*/FONT=ter-v32n/' /etc/vconsole.conf
else
	echo FONT=ter-v32n >> /etc/vconsole.conf
fi
grep FONT /etc/vconsole.conf
