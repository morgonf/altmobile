#!/bin/sh
# Запретить оболочке усыплять телефон при простое, чтобы не рвалась связь.
# Запускается от обычного пользователя, root не нужен.
#
# Вернуть как было:
#   gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
#   gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend'

export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
P=org.gnome.settings-daemon.plugins.power

echo "== было"
for k in sleep-inactive-battery-type sleep-inactive-battery-timeout \
	 sleep-inactive-ac-type sleep-inactive-ac-timeout idle-dim; do
	printf "  %-32s %s\n" "$k" "$(gsettings get $P $k 2>&1)"
done
printf "  %-32s %s\n" "idle-delay" "$(gsettings get org.gnome.desktop.session idle-delay 2>&1)"

echo
echo "== запрещаю сон при простое"
gsettings set $P sleep-inactive-battery-type 'nothing' && echo "  от батареи: ничего не делать"
gsettings set $P sleep-inactive-ac-type 'nothing' && echo "  от зарядки: ничего не делать"

echo
echo "== стало"
for k in sleep-inactive-battery-type sleep-inactive-ac-type; do
	printf "  %-32s %s\n" "$k" "$(gsettings get $P $k 2>&1)"
done
