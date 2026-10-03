#!/bin/sh
# От root: запрет обновления подменённых пакетов (RPM::Hold) и проверка.
set -e
install -m 644 "$(dirname "$0")/90-altmobile-hold.conf" /etc/apt/apt.conf.d/90-altmobile-hold.conf
apt-config dump | grep -c 'RPM::Hold::' | sed 's/^/правил в RPM::Hold: /'
