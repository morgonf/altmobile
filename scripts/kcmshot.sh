#!/bin/sh
# Снимок модуля настроек с разбуженным экраном: kcmshot.sh kcm_имя [файл]
P=$(pgrep -x plasmashell)
eval "$(tr "\0" "\n" < /proc/$P/environ | grep -E "^(WAYLAND_DISPLAY|XDG_[A-Z_]*|DBUS_SESSION_BUS_ADDRESS|QT_[A-Z_]*|KDE[A-Z_]*|PLASMA_PLATFORM|TMPDIR|LANG)=" | sed "s/^/export /; s/=\(.*\)$/=\"\1\"/")"
python3 - "$1" "${2:-$TMPDIR/shot_$1.png}" <<"PY"
import subprocess, sys, time
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
ss = Gio.DBusProxy.new_sync(bus, 0, None, "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", None)
ss.call_sync("SimulateUserActivity", None, 0, -1, None)
subprocess.run(["kscreen-doctor", "--dpms", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
cookie = ss.call_sync("Inhibit", GLib.Variant("(ss)", ("kcmshot", "screenshot")), 0, -1, None).unpack()[0]
subprocess.run(["pkill", "-x", "plasma-settings"]); time.sleep(1)
p = subprocess.Popen(["systemd-run", "--user", "--collect", "--wait", "-q", "-E", "WAYLAND_DISPLAY", "-E", "QT_QPA_PLATFORM=wayland", "timeout", "10", "plasma-settings", "-s", "-m", sys.argv[1]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
for i in range(8):
    time.sleep(1); ss.call_sync("SimulateUserActivity", None, 0, -1, None)
subprocess.run(["spectacle", "-b", "-n", "-f", "-o", sys.argv[2]], stderr=subprocess.DEVNULL)
p.terminate()
ss.call_sync("UnInhibit", GLib.Variant("(u)", (cookie,)), 0, -1, None)
PY
