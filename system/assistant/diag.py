"""Диагностика подключённых устройств для ассистента.

Всё читается без root. Выводы делают правила ниже, а не модель: модель
на телефоне читает около 8 токенов в секунду, кеш подсказки у гибридной
LFM2 не работает, а без размышлений она путается в длинных сводках.
Модели достаётся короткий список готовых выводов на английском (кириллица
обходится в 2-3 раза больше токенов), отвечает она по-русски.
"""
import glob
import os
import re
import subprocess

KERNEL_KEEP = re.compile(
    r"usb|hid|input|bluetooth|hci|btqca|dwc3|typec|udc|charger|pmi8998|"
    r"error|fail|disconnect|timeout|reset|over-?current|unable", re.I)
KERNEL_DROP = re.compile(r"audit|apparmor|wlan0: |ath10k_snoc", re.I)

TOPICS = {
    "bt": re.compile(r"bluetooth|блютуз|блютус|наушник|гарнитур|геймпад|джойстик|"
                     r"плойк|playstation|dualshock|колонк|часы|беспровод", re.I),
    "usb": re.compile(r"usb|юсб|флешк|провод|кабел|otg|мыш|клавиатур|переходник|"
                      r"диск|вставил|воткнул", re.I),
    "power": re.compile(r"заряд|батаре|аккумулятор|питани", re.I),
}


def run(cmd, timeout=5):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def kernel_events(minutes=15, limit=6):
    out = run(["journalctl", "-k", "--since", f"-{minutes}min", "-o", "cat",
               "--no-pager", "-q", "-p", "warning"])
    lines = [l for l in out.splitlines() if KERNEL_KEEP.search(l) and not KERNEL_DROP.search(l)]
    return lines[-limit:]


def bluetooth():
    show = run(["bluetoothctl", "show"])
    st = {"responding": bool(show),
          "powered": bool(re.search(r"Powered: yes", show)),
          "soft_blocked": False, "hard_blocked": False, "devices": []}
    for rf in glob.glob("/sys/class/rfkill/rfkill*"):
        if read(f"{rf}/type") == "bluetooth":
            st["soft_blocked"] |= read(f"{rf}/soft") == "1"
            st["hard_blocked"] |= read(f"{rf}/hard") == "1"
    for line in run(["bluetoothctl", "devices"]).splitlines():
        m = re.match(r"Device (\S+) (.*)", line)
        if m:
            info = run(["bluetoothctl", "info", m.group(1)])
            st["devices"].append({
                "mac": m.group(1), "name": m.group(2),
                **{k.lower(): bool(re.search(rf"{k}: yes", info))
                   for k in ("Paired", "Bonded", "Trusted", "Connected", "Blocked")}})
    return st


def usb():
    devs = [d for d in glob.glob("/sys/bus/usb/devices/*") if "-" in os.path.basename(d)]
    return {"devices": [read(f"{d}/product") or os.path.basename(d) for d in devs],
            "gadget_state": next((read(f"{u}/state") for u in glob.glob("/sys/class/udc/*")), None)}


def power():
    ch, bat = "/sys/class/power_supply/pmi8998-charger", "/sys/class/power_supply/bq27411-0"
    t = read(f"{bat}/temp")
    return {"online": read(f"{ch}/online") == "1",
            "type": read(f"{ch}/usb_type") or read(f"{ch}/type"),
            "capacity": read(f"{bat}/capacity"), "status": read(f"{bat}/status"),
            "temp": int(t) // 10 if t.lstrip("-").isdigit() else None}


def bt_action(code, mac=None):
    if code == "bt_power_on":
        return ("Включить Bluetooth", "bluetoothctl power on")
    if code == "bt_unblock":
        return ("Снять программную блокировку Bluetooth", "rfkill unblock bluetooth && bluetoothctl power on")
    if code == "bt_restart":
        return ("Перезапустить Bluetooth", "bluetoothctl power off; sleep 2; bluetoothctl power on")
    if code == "bt_reconnect":
        return ("Переподключить устройство",
                f"bluetoothctl disconnect {mac}; sleep 2; bluetoothctl connect {mac}")


def analyze(complaint):
    """Возвращает (выводы на английском, действие или None, сырые сведения для экрана)."""
    topics = {t for t, rx in TOPICS.items() if rx.search(complaint)} or set(TOPICS)
    findings, action, shown = [], None, []

    if "usb" in topics:
        u = usb()
        shown.append(f"USB: устройств {len(u['devices'])}, порт: {u['gadget_state']}")
        if not u["devices"] and u["gadget_state"] is not None:
            findings.append(
                "The USB port of this phone works only in device (gadget) mode: USB host / OTG "
                "is not supported by the kernel of this ALT Mobile build. Flash drives, mice, "
                "keyboards and gamepads connected by cable are not detected at all. No setting "
                "fixes it. Workaround: copy files over Wi-Fi or Bluetooth, use Bluetooth devices.")

    if "bt" in topics:
        b = bluetooth()
        shown.append("Bluetooth: " + ("нет ответа" if not b["responding"] else
                     "включён" if b["powered"] else "выключен")
                     + "".join(f"; {d['name']}: " + ("подключён" if d["connected"] else
                               "сопряжён" if d["paired"] or d["bonded"] or d["trusted"] else "не сопряжён")
                               for d in b["devices"]))
        if b["hard_blocked"]:
            findings.append("Bluetooth is hard-blocked by a hardware switch or airplane mode.")
        elif b["soft_blocked"]:
            findings.append("Bluetooth is soft-blocked (rfkill), probably airplane mode.")
            action = ("bt_unblock", *bt_action("bt_unblock"))
        elif not b["responding"]:
            findings.append("The Bluetooth service does not respond.")
        elif not b["powered"]:
            findings.append("The Bluetooth adapter is powered off.")
            action = ("bt_power_on", *bt_action("bt_power_on"))
        else:
            known = [d for d in b["devices"] if d["paired"] or d["bonded"] or d["trusted"]]
            want = [d for d in known if re.search(r"playstation|dualshock|геймпад|джойстик|плойк", d["name"] + " " + complaint, re.I)] or known
            if not b["devices"]:
                findings.append("Bluetooth is on, but no devices were ever paired.")
            for d in want[:2]:
                if d["connected"]:
                    findings.append(f"{d['name']} is paired and connected right now.")
                else:
                    findings.append(f"{d['name']} is paired but not connected now. It may be off, "
                                    "out of range, or need a reconnect.")
                    if "PLAYSTATION" in d["name"]:
                        findings.append("A DualShock 3 connects when you press its PS button; "
                                        "if it keeps blinking, its battery may be low.")
                    if action is None:
                        title, cmd = bt_action("bt_reconnect", d["mac"])
                        action = ("bt_reconnect", f"Переподключить {d['name']}", cmd)

    if "power" in topics:
        p = power()
        shown.append(f"Зарядка: {'есть' if p['online'] else 'нет'} {p['type']}, батарея {p['capacity']} %"
                     f" {p['status']}, {p['temp']} °C")
        if not p["online"]:
            findings.append("The phone does not see any charger right now. Check the cable, "
                            "the adapter and the port.")
        elif p["status"] in ("Not charging", "Discharging"):
            findings.append(f"A charger ({p['type']}) is connected, but the battery is not charging"
                            + (f"; battery temperature is {p['temp']} C, too hot" if p["temp"] and p["temp"] > 45 else "")
                            + ".")
        if p["temp"] and p["temp"] > 45:
            findings.append("The battery is hot; charging slows down or stops until it cools.")

    events = kernel_events()
    if events:
        shown += ["Ядро:"] + events
        findings.append("Recent kernel warnings: " + " | ".join(e[:120] for e in events[-3:]))
    if not findings:
        findings.append("No problems were found in the collected data.")
    return findings, action, "\n".join(shown)


if __name__ == "__main__":
    import sys
    f, a, s = analyze(" ".join(sys.argv[1:]))
    print(s, "\n")
    print("\n".join("- " + x for x in f))
    print("action:", a)
