#!/usr/bin/python3
"""Проверка: справится ли маленькая модель с разбором журнала.

15 кусков журнала (реальные строки с телефона и несколько дописанных)
с разметкой «есть проблема» и подсистема. Ответ модели ограничен схемой
JSON, чтобы маленькая модель не сбивалась с формата.
Запуск: logtest.py ПОРТ [метка]
"""
import json
import sys
import time
import urllib.request

SUBSYSTEMS = ["bluetooth", "wifi", "modem", "audio", "gpu", "usb", "nfc", "storage",
              "memory", "time", "kernel", "none"]

# (строки журнала, есть ли проблема, подсистема)
CASES = [
    ("Error while reading NFC bytes\nError while reading NFC bytes\nError while reading NFC bytes", True, "nfc"),
    ("Detected locale \"C\" with character encoding \"ANSI_X3.4-1968\", which is not UTF-8.\n"
     "Qt depends on a UTF-8 locale, and has switched to \"C.UTF-8\" instead.", False, "none"),
    ("wcd934x-codec wcd934x-codec.1.auto: Port Closed TX port 7, value 4", False, "none"),
    ("<wrn> [device qcom-soc] error initializing: Modem in failed state: sim-missing\n"
     "Couldn't get sim: No SIM object available", True, "modem"),
    ("ath10k_snoc 18800000.wifi: failed to install key for vdev 0 peer 52:ff:20:8f:dc:dd: -110\n"
     "wlan0: failed to remove key (0, 52:ff:20:8f:dc:dd) from hardware (-110)", True, "wifi"),
    ("W: Failed to load Vulkan ICD #10 from /usr/share/vulkan/icd.d/nvidia_icd.aarch64.json: "
     "openat(...): No such file or directory", False, "none"),
    ("chronyd: Can't synchronise: no selectable sources (4 unreachable sources)", True, "time"),
    ("msm_dpu ae01000.display-controller: Direct firmware load for qcom/a630_sqe.fw failed with error -2\n"
     "msm_dpu ae01000.display-controller: [drm:adreno_request_fw] *ERROR* failed to load a630_sqe.fw", True, "gpu"),
    ("------------[ cut here ]------------\nWARNING: CPU: 2 PID: 61 at drivers/clk/clk.c:1513\n"
     "Call trace:\n clk_core_reparent_orphans_nolock+0x90/0xe0\n---[ end trace 0000000000000000 ]---", True, "kernel"),
    ("<wrn> [modem1] unhandled QMI radio interface '9'", False, "none"),
    ("Bluetooth: hci0: command 0xfc00 tx timeout\nBluetooth: hci0: Reading QCA version information failed (-110)\n"
     "bluetoothd: Failed to set mode: Failed (0x03)", True, "bluetooth"),
    ("Out of memory: Killed process 4321 (plasmashell) total-vm:5508552kB, anon-rss:1982000kB", True, "memory"),
    ("systemd[1]: Started session-5.scope - Session 5 of User altlinux.\n"
     "systemd-logind: New session 5 of user altlinux.", False, "none"),
    ("ufshcd-qcom 1d84000.ufshc: ufshcd_abort: Device abort task at tag 7\n"
     "ufshcd-qcom 1d84000.ufshc: ufshcd_err_handler started; HBA state eh_fatal", True, "storage"),
    ("NetworkManager: <info> device (wlan0): state change: activated -> deactivating\n"
     "NetworkManager: <info> device (wlan0): state change: deactivating -> disconnected\n"
     "wlan0: deauthenticated from 52:ff:20:8f:dc:dd (Reason: 7=CLASS3_FRAME_FROM_NONASSOC_STA)", True, "wifi"),
]

SCHEMA = {"type": "object", "properties": {
    "problem": {"type": "boolean"},
    "subsystem": {"type": "string", "enum": SUBSYSTEMS},
    "summary": {"type": "string", "maxLength": 120}},
    "required": ["problem", "subsystem", "summary"]}

SYSTEM = ("You check Linux phone logs. Decide if the lines show a real problem the user may "
          "notice (a failure, crash, lost connection, missing firmware), or harmless noise "
          "(info messages, cosmetic warnings, missing optional files). Answer with JSON.")


def ask(port, lines):
    body = {"messages": [{"role": "system", "content": SYSTEM},
                         {"role": "user", "content": "Log lines:\n" + lines}],
            "max_tokens": 120, "temperature": 0,
            "response_format": {"type": "json_schema", "json_schema": {"name": "verdict", "schema": SCHEMA}}}
    req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/chat/completions",
                                 json.dumps(body).encode(), {"Content-Type": "application/json"})
    t0 = time.time()
    r = json.load(urllib.request.urlopen(req, timeout=600))
    return json.loads(r["choices"][0]["message"]["content"]), time.time() - t0


def main():
    port, label = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
    ok_p = ok_s = 0
    total = 0.0
    for lines, problem, subsystem in CASES:
        try:
            v, dt = ask(port, lines)
        except Exception as e:  # noqa: BLE001 - модель могла выдать мусор
            print(f"  ОШИБКА {e}: {lines[:60]!r}")
            continue
        total += dt
        hit_p = v["problem"] == problem
        hit_s = v["subsystem"] == subsystem
        ok_p += hit_p
        ok_s += hit_s
        print(f"  {'✓' if hit_p else '✗'}{'✓' if hit_s else '✗'} {dt:4.1f} с  "
              f"ждём {problem!s:5} {subsystem:9} получили {v['problem']!s:5} {v['subsystem']:9} | {v['summary']}")
        sys.stdout.flush()
    print(f"{label}: проблема верно {ok_p}/{len(CASES)}, подсистема {ok_s}/{len(CASES)}, "
          f"в среднем {total / len(CASES):.1f} с")


if __name__ == "__main__":
    main()
