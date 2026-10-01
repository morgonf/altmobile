#!/usr/bin/python3
# SPDX-FileCopyrightText: 2026 morgonf
# SPDX-License-Identifier: MIT
#
# NFC для ALT Mobile (OnePlus 6T, NXP PN553, neard). Служба пользователя:
#
# 1. Выбор «NFC включён» хранится в ~/.config/alt-mobile/nfc.conf и
#    доступен по D-Bus сеанса (ru.altlinux.Nfc, /ru/altlinux/Nfc): свойство
#    Enabled, метод SetEnabled. Им пользуются плитка шторки и «Настройки».
#    Выключенный NFC это остановленный опрос, а не обесточенный адаптер:
#    PN553 после Powered=false не включается снова (ошибка -110), его
#    оживляет только перепривязка к драйверу.
# 2. Опрос меток держится включённым. neard не возобновляет его после
#    ошибки чтения и сам не запускает первый. Карта, лежащая у телефона,
#    находится снова через секунды, поэтому при быстрых остановках пауза
#    растёт до 30 секунд.
# 3. Пока экран заблокирован (org.freedesktop.ScreenSaver), опрос стоит,
#    как в Android: метки не читаются с чужих рук и заряд не тратится.
# 4. Сбой. После неудачного подключения к карте neard держит объект карты и
#    отвечает «занято», это лечит перезапуск neard (alt-nfc-reset.service от
#    root, разрешён правилом polkit), не чаще раза в минуту. Если контроллер
#    завис по-настоящему (адаптер выключился, -110), помогает только
#    перезагрузка: служба один раз показывает уведомление. Перепривязку
#    драйвера не делаем, она попадала во взаимную блокировку в ядре.
# 5. Метки с данными NDEF дают уведомление с действием: ссылка открывается,
#    сеть Wi-Fi (WSC) подключается, текст копируется, контакт (vCard)
#    сохраняется и открывается. Записи neard публикует объектами
#    org.neard.Record, они ловятся по InterfacesAdded.
# 7. Запись (для приложения «Метки»): WriteTag(json) взводит запись, и
#    следующая поднесённая метка получает ссылку, текст, сеть Wi-Fi или
#    контакт через org.neard.Tag.Write. Итог в свойстве LastWrite (json).
#    Act(json) выполняет действие с записью, как кнопка уведомления.
# 6. История последних меток (UID, тип, записи) в
#    ~/.local/state/alt-mobile/nfc-history.json и по D-Bus (GetHistory,
#    сигнал TagSeen) для приложения «Метки».
import json
import os
import struct
import subprocess
import time

from gi.repository import Gio, GLib

NEARD = "org.neard"
ADAPTER = "/org/neard/nfc0"
CONFIG = os.path.expanduser("~/.config/alt-mobile/nfc.conf")
HISTORY = os.path.expanduser("~/.local/state/alt-mobile/nfc-history.json")
HISTORY_MAX = 50

IFACE_XML = """
<node>
  <interface name="ru.altlinux.Nfc">
    <property name="Enabled" type="b" access="read"/>
    <property name="Available" type="b" access="read"/>
    <property name="Locked" type="b" access="read"/>
    <method name="SetEnabled"><arg type="b" direction="in"/></method>
    <method name="GetHistory"><arg type="s" direction="out"/></method>
    <method name="ClearHistory"/>
    <property name="WritePending" type="b" access="read"/>
    <property name="LastWrite" type="s" access="read"/>
    <method name="WriteTag"><arg type="s" direction="in"/></method>
    <method name="CancelWrite"/>
    <method name="Act"><arg type="s" direction="in"/></method>
    <signal name="TagSeen"><arg type="s"/></signal>
  </interface>
</node>
"""

system = Gio.bus_get_sync(Gio.BusType.SYSTEM)
session = Gio.bus_get_sync(Gio.BusType.SESSION)

state = {
    "enabled": True,
    "locked": False,
    "pending": 0,
    "delay": 1,
    "started": 0.0,
    "stuck_since": 0.0,
    "reset_at": 0.0,
    "last_uid": None,
    "last_uid_time": 0.0,
    "notif_actions": {},
    "write": None,  # a{sv} для Tag.Write или None
    "last_write": "",
}
tags = {}  # путь метки -> {"uid", "type", "protocol", "records": []}


def log(*args):
    print(*args, flush=True)


# --- настройки и история ----------------------------------------------------

def load_config():
    kf = GLib.KeyFile()
    try:
        kf.load_from_file(CONFIG, GLib.KeyFileFlags.NONE)
        state["enabled"] = kf.get_boolean("NFC", "Enabled")
    except GLib.Error:
        state["enabled"] = True


def save_config():
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    kf = GLib.KeyFile()
    kf.set_boolean("NFC", "Enabled", state["enabled"])
    kf.save_to_file(CONFIG)


def load_history():
    try:
        with open(HISTORY) as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def add_history(entry):
    history = load_history()
    history.insert(0, entry)
    del history[HISTORY_MAX:]
    os.makedirs(os.path.dirname(HISTORY), exist_ok=True)
    tmp = HISTORY + ".tmp"
    with open(tmp, "w") as f:
        json.dump(history, f, ensure_ascii=False, indent=1)
    os.replace(tmp, HISTORY)


# --- neard -------------------------------------------------------------------

def neard_prop(name, path=ADAPTER, iface="org.neard.Adapter"):
    try:
        r = system.call_sync(NEARD, path, "org.freedesktop.DBus.Properties", "Get",
                             GLib.Variant("(ss)", (iface, name)), None, 0, 2000, None)
        return r.unpack()[0]
    except GLib.Error:
        return None


def neard_call(method, args=None, sig=None):
    system.call_sync(NEARD, ADAPTER, "org.neard.Adapter", method,
                     GLib.Variant(sig, args) if sig else None, None, 0, 5000, None)


def stop_poll():
    try:
        neard_call("StopPollLoop")
    except GLib.Error:
        pass


def reset_chip():
    log("NFC не отвечает, перезапуск neard")
    try:
        system.call_sync("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
                         "org.freedesktop.systemd1.Manager", "StartUnit",
                         GLib.Variant("(ss)", ("alt-nfc-reset.service", "replace")),
                         None, 0, -1, None)
    except GLib.Error as e:
        log("alt-nfc-reset:", e.message)


def want_polling():
    return state["enabled"] and not state["locked"]


def tick():
    """Привести адаптер к нужному состоянию."""
    state["pending"] = 0
    if neard_prop("Mode") is None:
        return False  # neard ещё нет, дождёмся NameOwnerChanged
    if not neard_prop("Powered"):
        # Выключен не нами. Сначала перезапуск neard (с DefaultPowered он
        # включит адаптер), если и после него выключен, контроллер завис
        if time.monotonic() - state["reset_at"] > 60:
            state["reset_at"] = time.monotonic()
            state["resets"] = state.get("resets", 0) + 1
            if state["resets"] <= 2:
                reset_chip()
            elif not state.get("dead_notified"):
                state["dead_notified"] = True
                notify("NFC не отвечает", "Контроллер NFC завис. Он заработает после перезагрузки телефона.", [])
        schedule(10)
        return False
    state["resets"] = 0
    state["dead_notified"] = False
    if not want_polling():
        if neard_prop("Polling"):
            stop_poll()
        return False
    if neard_prop("Polling") is False and neard_prop("Mode") == "Idle":
        try:
            neard_call("StartPollLoop", ("Initiator",), "(s)")
            state["started"] = time.monotonic()
            state["stuck_since"] = 0.0
        except GLib.Error as e:
            # Busy: метка ещё у телефона или контроллер завис
            if "busy" not in e.message.lower():
                log("StartPollLoop:", e.message)
            now = time.monotonic()
            if not state["stuck_since"]:
                state["stuck_since"] = now
            elif now - state["stuck_since"] > 15 and now - state["reset_at"] > 60:
                state["reset_at"] = now
                state["stuck_since"] = 0.0
                reset_chip()
            schedule(3)
    return False


def schedule(seconds=1):
    if not state["pending"]:
        state["pending"] = GLib.timeout_add_seconds(seconds, tick)


def on_adapter_changed(conn, sender, path, iface, signal, params):
    if path != ADAPTER:
        return
    if neard_prop("Polling") is False and state["started"]:
        since = time.monotonic() - state["started"]
        if since < 10:
            state["delay"] = min(state["delay"] * 2, 30)
        elif since > 60:
            state["delay"] = 1
    emit_props(["Available"])
    schedule(state["delay"])


def on_neard_owner(conn, sender, path, iface, signal, params):
    emit_props(["Available"])
    schedule(2)


# --- метки и уведомления ----------------------------------------------------

def unpack_value(v):
    return v.unpack() if isinstance(v, GLib.Variant) else v


def on_interfaces_added(conn, sender, path, iface, signal, params):
    obj, ifaces = params.unpack()
    if "org.neard.Tag" in ifaces:
        props = {k: unpack_value(v) for k, v in ifaces["org.neard.Tag"].items()}
        uid = ":".join("%02X" % b for b in props.get("Uid", []))
        tags[obj] = {"uid": uid, "type": props.get("Type", ""), "protocol": props.get("Protocol", ""), "records": []}
        if state["write"] is not None:
            write_tag(obj)
        # Записи приходят следом отдельными объектами, собираем их
        GLib.timeout_add(400, finish_tag, obj)
    elif "org.neard.Record" in ifaces:
        props = {k: unpack_value(v) for k, v in ifaces["org.neard.Record"].items()}
        parent = obj.rsplit("/", 1)[0]
        if parent in tags:
            tags[parent]["records"].append(props)


def on_interfaces_removed(conn, sender, path, iface, signal, params):
    # Объект метки не удаляем сразу: карту ISO-DEP без данных neard
    # прочитывает и убирает быстрее, чем через 400 мс сработает finish_tag,
    # и она пропадала из истории. Запись удаляет сам finish_tag.
    pass


def write_tag(obj):
    attrs = state["write"]
    state["write"] = None
    tags[obj]["written"] = True

    def done(conn, res):
        try:
            conn.call_finish(res)
            result = {"ok": True, "message": "Метка записана"}
        except GLib.Error as e:
            result = {"ok": False, "message": e.message.split(": ", 1)[-1]}
        result["time"] = int(time.time())
        state["last_write"] = json.dumps(result, ensure_ascii=False)
        emit_props(["WritePending", "LastWrite"])
        notify("Метка записана" if result["ok"] else "Не удалось записать метку",
               "" if result["ok"] else result["message"], [])

    system.call(NEARD, obj, "org.neard.Tag", "Write", GLib.Variant("(a{sv})", (attrs,)),
                None, 0, 10000, None, done)


def build_write(d):
    """Словарь для Tag.Write из запроса приложения."""
    kind = d.get("kind")
    if kind == "URI":
        return {"Type": GLib.Variant("s", "URI"), "URI": GLib.Variant("s", d["uri"])}
    if kind == "Text":
        return {"Type": GLib.Variant("s", "Text"), "Encoding": GLib.Variant("s", "UTF-8"),
                "Language": GLib.Variant("s", d.get("lang") or "ru"),
                "Representation": GLib.Variant("s", d["text"])}
    if kind == "WiFi":
        a = {"Type": GLib.Variant("s", "MIME"), "MIME": GLib.Variant("s", "application/vnd.wfa.wsc"),
             "SSID": GLib.Variant("s", d["ssid"])}
        if d.get("key"):
            a["Passphrase"] = GLib.Variant("s", d["key"])
        return a
    if kind == "Contact":
        lines = ["BEGIN:VCARD", "VERSION:3.0", "FN:" + d.get("name", "")]
        if d.get("phone"):
            lines.append("TEL:" + d["phone"])
        if d.get("email"):
            lines.append("EMAIL:" + d["email"])
        lines.append("END:VCARD")
        return {"Type": GLib.Variant("s", "MIME"), "MIME": GLib.Variant("s", "text/x-vcard"),
                "Payload": GLib.Variant("ay", "\r\n".join(lines).encode() + b"\r\n")}
    raise ValueError("неизвестный тип записи")


def act(rec):
    kind = rec.get("kind")
    if kind in ("URI", "SmartPoster") and rec.get("uri"):
        run("xdg-open", rec["uri"])
    elif kind == "Text":
        run("wl-copy", rec.get("text", ""))
    elif kind == "WiFi" and rec.get("ssid"):
        connect_wifi(rec["ssid"], rec.get("key", ""))
    elif kind == "Contact":
        save_contact(rec.get("vcard", ""))


def finish_tag(obj):
    tag = tags.pop(obj, None)
    if not tag:
        return False
    now = time.time()
    # Та же карта, лежащая у телефона, не даёт повторных уведомлений
    repeat = tag["uid"] and tag["uid"] == state["last_uid"] and now - state["last_uid_time"] < 60
    state["last_uid"], state["last_uid_time"] = tag["uid"], now
    if repeat:
        return False
    records = [describe_record(r) for r in tag["records"]]
    entry = {"time": int(now), "uid": tag["uid"], "type": tag["type"], "protocol": tag["protocol"], "records": records}
    add_history(entry)
    session.emit_signal(None, "/ru/altlinux/Nfc", "ru.altlinux.Nfc", "TagSeen",
                        GLib.Variant("(s)", (json.dumps(entry, ensure_ascii=False),)))
    if not tag.get("written"):
        for rec in records:
            notify_record(rec)
    return False


def parse_wsc(payload):
    """Сеть Wi-Fi из записи application/vnd.wfa.wsc (TLV Wi-Fi Simple Config)."""
    def tlvs(data):
        i = 0
        while i + 4 <= len(data):
            t, n = struct.unpack(">HH", data[i:i + 4])
            yield t, data[i + 4:i + 4 + n]
            i += 4 + n
    result = {}
    for t, v in tlvs(bytes(payload)):
        if t == 0x100E:  # Credential
            for t2, v2 in tlvs(v):
                if t2 == 0x1045:
                    result["ssid"] = v2.decode("utf-8", "replace")
                elif t2 == 0x1027:
                    result["key"] = v2.decode("utf-8", "replace")
                elif t2 == 0x1003:
                    result["auth"] = struct.unpack(">H", v2)[0] if len(v2) == 2 else 0
    return result


def describe_record(r):
    kind = r.get("Type", "")
    d = {"kind": kind}
    if kind in ("URI", "SmartPoster"):
        d["uri"] = r.get("URI", "")
        if r.get("Representation"):
            d["title"] = r["Representation"]
    elif kind == "Text":
        d["text"] = r.get("Representation", "")
        d["lang"] = r.get("Language", "")
    elif kind == "MIME":
        mime = r.get("MIMEType", "")
        d["mime"] = mime
        payload = bytes(r.get("MIMEPayload", []))
        if mime == "application/vnd.wfa.wsc":
            d.update({"kind": "WiFi"}, **parse_wsc(payload))
        elif mime in ("text/vcard", "text/x-vcard"):
            d["kind"] = "Contact"
            d["vcard"] = payload.decode("utf-8", "replace")
        else:
            d["size"] = len(payload)
    elif kind == "AAR":
        d["package"] = r.get("AndroidPackage", "")
    return d


def notify(summary, body, actions):
    key = "%d" % int(time.time() * 1000)
    acts = []
    for name, label, handler in actions:
        acts += [name, label]
        state["notif_actions"][(key, name)] = handler
    try:
        r = session.call_sync("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                              "org.freedesktop.Notifications", "Notify",
                              GLib.Variant("(susssasa{sv}i)", ("NFC", 0, "nfc", summary, body, acts,
                                                               {"desktop-entry": GLib.Variant("s", "org.kde.plasma.settings")}, -1)),
                              None, 0, -1, None)
        nid = r.unpack()[0]
        for (k, name), handler in list(state["notif_actions"].items()):
            if k == key:
                state["notif_actions"][(nid, name)] = state["notif_actions"].pop((k, name))
    except GLib.Error as e:
        log("Notify:", e.message)


def run(*cmd):
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def connect_wifi(ssid, key):
    args = ["nmcli", "device", "wifi", "connect", ssid]
    if key:
        args += ["password", key]
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode == 0:
        notify("Wi-Fi подключён", ssid, [])
    else:
        notify("Не удалось подключиться к Wi-Fi", "%s (%s)" % (ssid, (p.stderr or p.stdout).strip()), [])


def save_contact(vcard):
    d = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DOWNLOAD) or os.path.expanduser("~")
    path = os.path.join(d, "контакт-nfc-%d.vcf" % int(time.time()))
    with open(path, "w") as f:
        f.write(vcard)
    run("xdg-open", path)


def notify_record(rec):
    kind = rec["kind"]
    if kind in ("URI", "SmartPoster") and rec.get("uri"):
        uri = rec["uri"]
        notify(rec.get("title") or "Ссылка с метки", uri, [("default", "Открыть", lambda: run("xdg-open", uri)),
                                                           ("open", "Открыть", lambda: run("xdg-open", uri))])
    elif kind == "Text" and rec.get("text"):
        text = rec["text"]
        notify("Текст с метки", text, [("copy", "Копировать", lambda: run("wl-copy", text))])
    elif kind == "WiFi" and rec.get("ssid"):
        ssid, key = rec["ssid"], rec.get("key", "")
        notify("Сеть Wi-Fi с метки", ssid, [("connect", "Подключиться", lambda: connect_wifi(ssid, key))])
    elif kind == "Contact":
        vcard = rec["vcard"]
        name = next((l[3:] for l in vcard.splitlines() if l.upper().startswith("FN:")), "Контакт")
        notify("Контакт с метки", name, [("save", "Сохранить", lambda: save_contact(vcard))])


def on_action(conn, sender, path, iface, signal, params):
    nid, name = params.unpack()
    handler = state["notif_actions"].get((nid, name))
    if handler:
        handler()


def on_closed(conn, sender, path, iface, signal, params):
    nid = params.unpack()[0]
    for k in [k for k in state["notif_actions"] if k[0] == nid]:
        del state["notif_actions"][k]


# --- блокировка экрана -------------------------------------------------------

def on_screensaver(conn, sender, path, iface, signal, params):
    state["locked"] = bool(params.unpack()[0])
    emit_props(["Locked"])
    tick()


def read_locked():
    try:
        r = session.call_sync("org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver",
                              "GetActive", None, None, 0, 2000, None)
        state["locked"] = bool(r.unpack()[0])
    except GLib.Error:
        state["locked"] = False


# --- D-Bus сеанса ------------------------------------------------------------

def get_prop(conn, sender, path, iface, name):
    if name == "Enabled":
        return GLib.Variant("b", state["enabled"])
    if name == "Available":
        return GLib.Variant("b", neard_prop("Mode") is not None)
    if name == "Locked":
        return GLib.Variant("b", state["locked"])
    if name == "WritePending":
        return GLib.Variant("b", state["write"] is not None)
    if name == "LastWrite":
        return GLib.Variant("s", state["last_write"])
    return None


def emit_props(names):
    changed = {n: get_prop(None, None, None, None, n) for n in names}
    session.emit_signal(None, "/ru/altlinux/Nfc", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                        GLib.Variant("(sa{sv}as)", ("ru.altlinux.Nfc", changed, [])))


def method_call(conn, sender, path, iface, method, params, invocation):
    if method == "SetEnabled":
        state["enabled"] = bool(params.unpack()[0])
        save_config()
        emit_props(["Enabled"])
        if not state["enabled"]:
            stop_poll()
        tick()
        invocation.return_value(None)
    elif method == "GetHistory":
        invocation.return_value(GLib.Variant("(s)", (json.dumps(load_history(), ensure_ascii=False),)))
    elif method == "WriteTag":
        try:
            state["write"] = build_write(json.loads(params.unpack()[0]))
        except (ValueError, KeyError) as e:
            invocation.return_dbus_error("ru.altlinux.Nfc.Error.InvalidArguments", str(e))
            return
        state["last_write"] = ""
        emit_props(["WritePending", "LastWrite"])
        invocation.return_value(None)
    elif method == "CancelWrite":
        state["write"] = None
        emit_props(["WritePending"])
        invocation.return_value(None)
    elif method == "Act":
        try:
            act(json.loads(params.unpack()[0]))
        except ValueError:
            pass
        invocation.return_value(None)
    elif method == "ClearHistory":
        try:
            os.remove(HISTORY)
        except OSError:
            pass
        invocation.return_value(None)


def main():
    load_config()
    read_locked()
    info = Gio.DBusNodeInfo.new_for_xml(IFACE_XML).interfaces[0]
    session.register_object("/ru/altlinux/Nfc", info, method_call, get_prop, None)
    Gio.bus_own_name_on_connection(session, "ru.altlinux.Nfc", Gio.BusNameOwnerFlags.NONE, None, None)

    system.signal_subscribe(NEARD, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                            ADAPTER, None, 0, on_adapter_changed)
    system.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                            "/org/freedesktop/DBus", NEARD, 0, on_neard_owner)
    system.signal_subscribe(NEARD, "org.freedesktop.DBus.ObjectManager", "InterfacesAdded",
                            "/", None, 0, on_interfaces_added)
    system.signal_subscribe(NEARD, "org.freedesktop.DBus.ObjectManager", "InterfacesRemoved",
                            "/", None, 0, on_interfaces_removed)
    session.signal_subscribe(None, "org.freedesktop.ScreenSaver", "ActiveChanged",
                             "/ScreenSaver", None, 0, on_screensaver)
    session.signal_subscribe(None, "org.freedesktop.Notifications", "ActionInvoked",
                             "/org/freedesktop/Notifications", None, 0, on_action)
    session.signal_subscribe(None, "org.freedesktop.Notifications", "NotificationClosed",
                             "/org/freedesktop/Notifications", None, 0, on_closed)
    # Страховка: раз в 30 секунд
    GLib.timeout_add_seconds(30, lambda: (schedule(), True)[1])
    schedule()
    GLib.MainLoop().run()


main()
