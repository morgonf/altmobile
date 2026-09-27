#!/usr/bin/python3
# Уведомление «SIM-карта заблокирована» с кнопкой, открывающей экран
# разблокировки в «Сотовой сети» (kcm_cellular_network). Вместо старого
# окна plasma-nm на виджетах, в котором не выходила экранная клавиатура;
# само окно отключено у подключения mts: gsm.pin-flags not-required.
import subprocess
from gi.repository import Gio, GLib

MM = "org.freedesktop.ModemManager1"
LOCK_SIM_PIN, LOCK_SIM_PUK = 2, 4
session = Gio.bus_get_sync(Gio.BusType.SESSION)
system = Gio.bus_get_sync(Gio.BusType.SYSTEM)
state = {"notif": 0}


def locked():
    try:
        om = Gio.DBusProxy.new_sync(system, 0, None, MM, "/org/freedesktop/ModemManager1",
                                    "org.freedesktop.DBus.ObjectManager", None)
        objs = om.call_sync("GetManagedObjects", None, 0, -1, None).unpack()[0]
    except GLib.Error:
        return 0
    for ifaces in objs.values():
        m = ifaces.get("org.freedesktop.ModemManager1.Modem")
        if m and m.get("UnlockRequired") in (LOCK_SIM_PIN, LOCK_SIM_PUK):
            return m["UnlockRequired"]
    return 0


def notify(kind):
    body = ("Введите PIN-код, чтобы пользоваться мобильной связью."
            if kind == LOCK_SIM_PIN else "Нужен PUK-код от оператора.")
    r = session.call_sync("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                          "org.freedesktop.Notifications", "Notify",
                          GLib.Variant("(susssasa{sv}i)", ("SIM-карта", 0, "smartphone",
                                       "SIM-карта заблокирована", body,
                                       ["default", "Разблокировать", "unlock", "Разблокировать"],
                                       {"urgency": GLib.Variant("y", 2),
                                        "resident": GLib.Variant("b", True)}, 0)),
                          None, 0, -1, None)
    state["notif"] = r.unpack()[0]


def close():
    if state["notif"]:
        session.call_sync("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                          "org.freedesktop.Notifications", "CloseNotification",
                          GLib.Variant("(u)", (state["notif"],)), None, 0, -1, None)
        state["notif"] = 0


def on_action(conn, sender, path, iface, signal, params):
    nid, key = params.unpack()
    if nid == state["notif"]:
        subprocess.Popen(["plasma-settings", "-m", "kcm_cellular_network"])


def tick():
    kind = locked()
    if kind and not state["notif"]:
        notify(kind)
    elif not kind and state["notif"]:
        close()
    return True


session.signal_subscribe(None, "org.freedesktop.Notifications", "ActionInvoked",
                         "/org/freedesktop/Notifications", None, 0, on_action)
tick()
GLib.timeout_add_seconds(10, tick)
GLib.MainLoop().run()
