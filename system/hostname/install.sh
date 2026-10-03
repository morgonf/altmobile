#!/bin/sh
# От root: правило polkit для смены имени телефона и русские строки модуля
# «Сведения о системе» (kcm_mobile_info, патч plasma-mobile/info-device-name.patch).
set -e
cd "$(dirname "$0")"
install -m 644 50-altmobile-hostname.rules /etc/polkit-1/rules.d/50-altmobile-hostname.rules
M=/usr/share/locale/ru/LC_MESSAGES/kcm_mobile_info.mo
[ -f $M.orig ] || cp -a $M $M.orig
python3 "${MO_MERGE:-../../packages/plasma-camera/mo-merge.py}" $M.orig kcm_mobile_info.ru-add.po /tmp/kcm_mobile_info.mo
install -m 644 /tmp/kcm_mobile_info.mo $M
