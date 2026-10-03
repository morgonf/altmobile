#!/usr/bin/python3
# Проверка plasma-camera: разбудить экран, держать его включённым, запустить
# камеру и по сценарию касаться и снимать экран.
# camtest.py "wait 12; shot a; tap 540 1000; wait 1; shot b; ..."
import os, subprocess, sys, time
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
ss = Gio.DBusProxy.new_sync(bus, 0, None, "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", None)
ss.call_sync("SimulateUserActivity", None, 0, -1, None)
subprocess.run(["kscreen-doctor", "--dpms", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
cookie = ss.call_sync("Inhibit", GLib.Variant("(ss)", ("camtest", "camera test")), 0, -1, None).unpack()[0]
D = "/tmp/.private/altlinux/ct-shots"; os.makedirs(D, exist_ok=True)
log = open("/tmp/.private/altlinux/pc-test.log", "w")
env = dict(os.environ, LIBCAMERA_LOG_LEVELS="*:2,IPASoftAutoFocus:0,IPASoftExposure:0,IPASoftAwb:0,IPASoftBL:0")
if "nolaunch" not in sys.argv[1]:
    subprocess.run(["pkill", "-x", "plasma-camera"]); time.sleep(1)
    subprocess.Popen(["plasma-camera"], stdout=log, stderr=log, env=env)
for cmd in sys.argv[1].split(";"):
    a = cmd.split()
    if not a or a[0] == "nolaunch": continue
    if a[0] == "wait": time.sleep(float(a[1]))
    elif a[0] == "shot": subprocess.run(["spectacle", "-b", "-n", "-f", "-o", f"{D}/{a[1]}.png"], stderr=subprocess.DEVNULL)
    elif a[0] == "tap": subprocess.run(["python3", "/home/altlinux/tap.py"] + a[1:])
    ss.call_sync("SimulateUserActivity", None, 0, -1, None)
ss.call_sync("UnInhibit", GLib.Variant("(u)", (cookie,)), 0, -1, None)
