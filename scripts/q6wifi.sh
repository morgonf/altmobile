#!/bin/sh
# Выключить энергосбережение Wi-Fi, из-за которого связь пропадает,
# и посмотреть, уходит ли телефон в сон.
#
# Вернуть как было: nmcli connection modify <SSID> wifi.powersave 0

PATH=/sbin:/usr/sbin:$PATH
export PATH

echo "== было"
iw dev wlan0 get power_save 2>&1
nmcli -f 802-11-wireless.powersave connection show <SSID> 2>&1

echo
echo "== выключаю сейчас"
iw dev wlan0 set power_save off 2>&1 && echo "  в драйвере выключено"
iw dev wlan0 get power_save 2>&1 | sed 's/^/  /'

echo
echo "== закрепляю в профиле соединения"
# 2 означает выключено насовсем, 3 включено, 0 по умолчанию
nmcli connection modify <SSID> wifi.powersave 2 && echo "  записано"
nmcli -f 802-11-wireless.powersave connection show <SSID> 2>&1 | sed 's/^/  /'

echo
echo "== уходил ли телефон в сон"
journalctl -b --no-pager 2>/dev/null | grep -icE "PM: suspend|Suspending system|entering sleep" | sed 's/^/  событий сна: /'
journalctl -b --no-pager 2>/dev/null | grep -iE "PM: suspend entry|Suspending system" | tail -3 | sed 's/^/  /'

echo
echo "== настройки простоя"
loginctl show-session 2>/dev/null | grep -iE "idle" | sed 's/^/  /'
grep -iE "^#?IdleAction" /etc/systemd/logind.conf 2>/dev/null | sed 's/^/  /'
