#!/usr/bin/python3
# Подхват SIM-карты по событиям модема (OnePlus 6T, QMI), от root.
#
# Модем сообщает о вставке и извлечении карты сразу (индикация UIM «Slot
# Status») и читает ICCID даже в неактивном гнезде. Но сам он:
# - работает только с одним физическим гнездом из двух, и карту во втором
#   гнезде не видит, пока гнездо не переключить (--uim-switch-slot);
# - для карты, вставленной на ходу, не открывает сессию приложения USIM
#   (Primary GW). ModemManager на такую карту минуту переспрашивает
#   «карты нет» раз в 2 секунды и остаётся в failed/sim-missing.
# Поэтому на каждое событие: если в активном гнезде нет читаемой карты, а в
# другом есть, переключаемся на него; затем открываем сессию USIM. ModemManager
# сам пересоздаёт модем по событию гнезда и находит карту на ближайшем
# переспросе, без перезапуска. Перезапуск только запасной путь, если
# ModemManager уже сдался (failed/sim-missing при открытой сессии).
# Проверено 11.10.2026; раньше это делал опрос раз в 3-10 секунд и окно PIN
# появлялось через 35-45 секунд.
#
# «Present» с ICCID «unknown» бывает у гнезда, где карты нет или она не
# читается (через 4 секунды после того, как задвинули лоток), такое гнездо
# не выбираем.
import re
import subprocess
import sys
import threading
import time

DEV = "qrtr://0"
QMI = ["qmicli", "-p", "-d", DEV]


def log(msg):
    print(msg, flush=True)


def qmi(*args, timeout=10):
    try:
        r = subprocess.run(QMI + list(args), capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        log(f"qmicli {' '.join(args)}: нет ответа")
        return None
    if r.returncode != 0:
        log(f"qmicli {' '.join(args)}: {r.stderr.strip()}")
        return None
    return r.stdout


def slot_status():
    """Физические гнёзда: {номер: {"card", "active", "logical", "iccid"}}"""
    out = qmi("--uim-get-slot-status")
    if out is None:
        return None
    slots, cur = {}, None
    for line in out.splitlines():
        m = re.match(r"\s*Physical slot (\d+):", line)
        if m:
            cur = slots.setdefault(int(m.group(1)), {"iccid": "unknown", "logical": None})
            continue
        if cur is None or ":" not in line:
            continue
        key, val = (x.strip() for x in line.split(":", 1))
        if key == "Card status":
            cur["card"] = val
        elif key == "Slot status":
            cur["active"] = val == "active"
        elif key == "Logical slot":
            cur["logical"] = int(val)
        elif key == "ICCID":
            cur["iccid"] = val
    return slots


def usable(s):
    return s.get("card") == "present" and s["iccid"] not in ("", "unknown")


def card_status(logical):
    """(сессия Primary GW есть, AID приложения USIM в логическом гнезде)"""
    out = qmi("--uim-get-card-status")
    if out is None:
        return None, None
    session = "Primary GW:   session doesn't exist" not in out
    aid, in_slot, usim, take = None, False, False, False
    for line in out.splitlines():
        m = re.match(r"Slot \[(\d+)\]:", line)
        if m:
            in_slot = int(m.group(1)) == logical
            continue
        if not in_slot:
            continue
        if "Application type:" in line:
            usim = "usim" in line
        elif "Application ID:" in line:
            take = usim
        elif take:
            aid = line.strip()
            break
    return session, aid


def mm_sim_missing():
    r = subprocess.run(["mmcli", "-m", "any", "-K"], capture_output=True, text=True)
    return re.search(r"state-failed-reason\s*:\s*sim-missing", r.stdout) is not None


def handle():
    slots = slot_status()
    if not slots:
        return
    active = next((n for n, s in slots.items() if s.get("active")), None)
    if active is None or not usable(slots[active]):
        other = next((n for n, s in sorted(slots.items()) if usable(s) and n != active), None)
        if other is None:
            return
        log(f"карта в гнезде {other}, активное {active} пустое: переключаю гнездо")
        if qmi(f"--uim-switch-slot={other}") is None:
            return
        # Переключение само вызывает событие гнезда, но сессию открываем сразу
        time.sleep(0.5)
        slots = slot_status() or {}
        active = other
    logical = slots.get(active, {}).get("logical") or 1
    # Приложение USIM появляется в состоянии карты не сразу после вставки
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        session, aid = card_status(logical)
        if session:
            return
        if aid:
            log(f"открываю сессию USIM {aid} в логическом гнезде {logical} (физическое {active})")
            qmi("--uim-change-provisioning-session="
                f"session-type=primary-gw-provisioning,activate=yes,slot={logical},aid={aid}")
            break
        time.sleep(0.3)
    else:
        log("приложение USIM не появилось за 15 секунд")
        return
    # ModemManager находит карту на ближайшем переспросе (раз в 2 секунды,
    # минуту после события гнезда). Если он уже сдался, перезапускаем.
    time.sleep(4)
    if mm_sim_missing():
        log("ModemManager остался в sim-missing: перезапускаю")
        subprocess.run(["systemctl", "restart", "ModemManager"])


pending = threading.Event()


def worker():
    while True:
        pending.wait()
        pending.clear()
        try:
            handle()
        except Exception as e:  # служба не должна падать из-за одного события
            log(f"ошибка: {e!r}")


def main():
    threading.Thread(target=worker, daemon=True).start()
    # Карта, вставленная до запуска (загрузка, перезапуск службы)
    pending.set()
    while True:
        p = subprocess.Popen(QMI + ["--uim-monitor-slot-status"],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in p.stdout:
            if "Received slot status indication" in line:
                pending.set()
        p.wait()
        log(f"наблюдение за гнёздами прервалось (код {p.returncode}), перезапуск")
        time.sleep(2)
        pending.set()


if __name__ == "__main__":
    sys.exit(main())
