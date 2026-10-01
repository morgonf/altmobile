#!/usr/bin/python3
# Держит опрос NFC включённым (OnePlus 6T, neard). neard с ConstantPoll
# возобновляет опрос после метки, но не после ошибки чтения («Error while
# reading NFC bytes» на метке без NDEF), и следующие карты уже не видны.
# Служба следит за Polling и Powered адаптера и снова вызывает
# StartPollLoop, когда адаптер включён, а опрос встал.
#
# Карта, которая лежит у телефона (в чехле), находится снова через
# несколько секунд после каждого перезапуска, и цикл не кончается. Если
# опрос встал быстрее чем за 10 секунд после запуска, пауза перед
# следующим удваивается до 30 секунд, после минуты тишины снова 1 секунда.
import time

from gi.repository import Gio, GLib

NEARD = "org.neard"
ADAPTER = "/org/neard/nfc0"
bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
pending = {"id": 0}
backoff = {"delay": 1, "started": 0.0}


def prop(name):
    try:
        r = bus.call_sync(NEARD, ADAPTER, "org.freedesktop.DBus.Properties", "Get",
                          GLib.Variant("(ss)", ("org.neard.Adapter", name)),
                          None, 0, -1, None)
        return r.unpack()[0]
    except GLib.Error:
        return None


def restart():
    pending["id"] = 0
    if prop("Powered") and prop("Polling") is False and prop("Mode") == "Idle":
        try:
            bus.call_sync(NEARD, ADAPTER, "org.neard.Adapter", "StartPollLoop",
                          GLib.Variant("(s)", ("Initiator",)), None, 0, -1, None)
            backoff["started"] = time.monotonic()
        except GLib.Error as e:
            # Busy: метка ещё у телефона, проверим позже
            if "Busy" not in e.message and "busy" not in e.message:
                print("StartPollLoop:", e.message, flush=True)
            schedule(3)
    return False


def schedule(seconds=1):
    if not pending["id"]:
        pending["id"] = GLib.timeout_add_seconds(seconds, restart)


def on_changed(conn, sender, path, iface, signal, params):
    if prop("Polling") is False and backoff["started"]:
        since = time.monotonic() - backoff["started"]
        if since < 10:
            backoff["delay"] = min(backoff["delay"] * 2, 30)
        elif since > 60:
            backoff["delay"] = 1
    schedule(backoff["delay"])


bus.signal_subscribe(NEARD, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                     ADAPTER, None, 0, on_changed)
# neard появился заново (перезапуск службы)
bus.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                     "/org/freedesktop/DBus", NEARD, 0, on_changed)
# Страховка: раз в 30 секунд
GLib.timeout_add_seconds(30, lambda: (schedule(), True)[1])
schedule()
GLib.MainLoop().run()
