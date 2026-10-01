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
#
# Зависание. После неудачного подключения к карте («Could not connect»)
# контроллер перестаёт отвечать, neard держит объект карты, StartPollLoop
# отвечает Busy, а включение адаптера кончается таймаутом. Если опрос не
# удаётся запустить 15 секунд, служба сначала выключает и включает
# адаптер, а если и это не помогло, запускает alt-nfc-reset.service
# (перепривязка чипа от root, разрешена правилом polkit). Не чаще раза в
# минуту.
import time

from gi.repository import Gio, GLib

NEARD = "org.neard"
ADAPTER = "/org/neard/nfc0"
bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
pending = {"id": 0}
backoff = {"delay": 1, "started": 0.0}
stuck = {"since": 0.0, "reset": 0.0}


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
            stuck["since"] = 0.0
        except GLib.Error as e:
            # Busy: метка ещё у телефона или контроллер завис
            if "busy" not in e.message.lower():
                print("StartPollLoop:", e.message, flush=True)
            now = time.monotonic()
            if not stuck["since"]:
                stuck["since"] = now
            elif now - stuck["since"] > 15 and now - stuck["reset"] > 60:
                stuck["reset"] = now
                stuck["since"] = 0.0
                recover()
            schedule(3)
    elif prop("Powered") is False:
        # Адаптер выключился сам (после зависания), включаем
        if not set_powered(True) and time.monotonic() - stuck["reset"] > 60:
            stuck["reset"] = time.monotonic()
            reset_chip()
        schedule(5)
    return False


def set_powered(value):
    try:
        bus.call_sync(NEARD, ADAPTER, "org.freedesktop.DBus.Properties", "Set",
                      GLib.Variant("(ssv)", ("org.neard.Adapter", "Powered", GLib.Variant("b", value))),
                      None, 0, -1, None)
        return True
    except GLib.Error as e:
        print("Powered", value, e.message, flush=True)
        return False


def reset_chip():
    print("контроллер NFC не отвечает, сброс", flush=True)
    try:
        bus.call_sync("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
                      "org.freedesktop.systemd1.Manager", "StartUnit",
                      GLib.Variant("(ss)", ("alt-nfc-reset.service", "replace")),
                      None, 0, -1, None)
    except GLib.Error as e:
        print("alt-nfc-reset:", e.message, flush=True)


def recover():
    set_powered(False)
    time.sleep(2)
    if not set_powered(True):
        reset_chip()


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
