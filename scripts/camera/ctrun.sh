#!/bin/sh
# Запуск camtest.py в окружении сеанса Plasma
P=$(pgrep -x plasmashell)
eval "$(tr "\0" "\n" < /proc/$P/environ | grep -E "^(WAYLAND_DISPLAY|XDG_[A-Z_]*|DBUS_SESSION_BUS_ADDRESS|QT_[A-Z_]*|KDE[A-Z_]*|PLASMA_PLATFORM|TMPDIR|TMP|LANG)=" | sed "s/^/export /; s/=\(.*\)$/=\"\1\"/")"
exec python3 /home/altlinux/camtest.py "$@"
