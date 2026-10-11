#!/bin/sh
# Звонки, SMS и контакты на программах KDE вместо GNOME Calls, Chatty и
# GNOME Contacts (п. 10 docs/plasma-plan.md, решение пользователя 11.10.2026:
# GNOME Calls в Plasma не будит экран и не показывает входящий поверх
# блокировки, Plasma Dialer это умеет). От пользователя, внутри сеанса.
# Перезапускает оболочку (значки на главном экране).
set -e
A=$HOME/.config/autostart
mkdir -p "$A"

# Службы KDE: убрать наши файлы-скрытия (05.10.2026, до появления SIM)
for d in org.kde.modem.daemon org.kde.telephony.daemon org.kde.spacebar.daemon; do
	f=$A/$d.desktop
	if [ -f "$f" ] && grep -q "ALT Mobile: звонки и SMS пока обслуживают" "$f"; then
		rm "$f"
	fi
done

# GNOME Calls и Chatty не запускать: иначе входящий звонок обслуживают
# два приложения, а SMS делят между собой две программы
for d in org.gnome.Calls-daemon sm.puri.Chatty-daemon; do
	printf '[Desktop Entry]\nHidden=true\n# ALT Mobile: звонки и SMS обслуживают Plasma Dialer и Spacebar\n' > "$A/$d.desktop"
done

# Остановить GNOME Calls и Chatty в текущем сеансе и запустить службы KDE
systemctl --user stop 'app-org.gnome.Calls\x2ddaemon@autostart.service' \
	'app-sm.puri.Chatty\x2ddaemon@autostart.service' 2>/dev/null || true
pkill -x gnome-calls 2>/dev/null || true
pkill -x chatty 2>/dev/null || true
for x in modem-daemon kde-telephony-daemon spacebar-daemon; do
	pgrep -x "$x" >/dev/null ||
		systemd-run --user --quiet --collect --unit="alt-$x" /usr/libexec/$x
done

# Значки на главном экране (панель избранного Folio). Оболочка держит
# настройки в памяти и при выходе записывает свои, поэтому правим, пока она
# остановлена
C=$HOME/.config/plasma-org.kde.plasma.mobileshell-appletsrc
systemctl --user stop plasma-plasmashell.service
sed -i -e 's/"org\.gnome\.Calls\.desktop"/"org.kde.plasma.dialer.desktop"/g' \
	-e 's/"sm\.puri\.Chatty\.desktop"/"org.kde.spacebar.desktop"/g' \
	-e 's/"org\.gnome\.Contacts\.desktop"/"org.kde.phonebook.desktop"/g' "$C"
systemctl --user start plasma-plasmashell.service
echo "готово: Plasma Dialer, Spacebar, Контакты KDE"
