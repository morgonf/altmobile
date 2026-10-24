#!/usr/bin/python3
"""Проверка: умеет ли модель вызывать инструменты.

Каждая задача: запрос с инструментами, выполнение вызовов (задачи только
читают), ответ модели по результату. Пишет выбор инструмента, время,
число токенов и финальный ответ.
"""
import json
import os
import sys
import time
import urllib.request

import tools

URL = "http://127.0.0.1:8080/v1/chat/completions"
SYSTEM = ("You are an assistant on a OnePlus 6T phone with ALT Linux. Use tools to get real "
          "facts about the phone, never guess. Answer in Russian, 1-2 sentences.\n"
          "Phone facts: storage free: df -h /; battery: /sys/class/power_supply/bq27411-0/"
          "{capacity,status}; RAM: free -h; network: nmcli; Bluetooth: bluetoothctl; "
          "packages: rpm -q; logs: journalctl.")

TASKS = [
    ("Привет! Как дела?", None),
    ("Сколько свободного места на телефоне?", "shell"),
    ("Какая версия ядра Linux стоит на телефоне?", "shell"),
    ("Сколько сейчас процентов заряда батареи?", "shell|read_file"),
    ("Что написано в файле /etc/os-release?", "read_file|shell"),
    ("Найди в интернете, что такое модель LFM2.5 от Liquid AI.", "web_search"),
]


# Подсказки начала ответа для LFM2.5 (иначе она рассуждает сотни токенов).
# После результата инструмента нужна другая, иначе модель повторяет вызов.
AFTER_TOOL = "<think>I have the tool result. Now I answer the user in Russian.</think>"


def call(model, messages, prefill):
    body = {"model": model, "messages": messages, "tools": tools.SPECS,
            "max_tokens": int(os.environ.get("MAX_TOKENS", 400)), "temperature": 0.2}
    if prefill:
        p = AFTER_TOOL if messages[-1]["role"] == "tool" else prefill
        body["messages"] = messages + [{"role": "assistant", "content": p}]
    req = urllib.request.Request(URL, json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    t0 = time.time()
    r = json.load(urllib.request.urlopen(req, timeout=900))
    return r, time.time() - t0


def run(model, prefill, max_steps=3):
    print(f"\n######## {model}  prefill={bool(prefill)}")
    for task, expect in TASKS:
        msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": task}]
        print(f"\n=== {task}  (ждём: {expect})")
        for step in range(max_steps):
            r, dt = call(model, msgs, prefill)
            m = r["choices"][0]["message"]
            t = r.get("timings", {})
            calls = m.get("tool_calls") or []
            print(f"  шаг {step + 1}: {dt:.0f} с, чтение {t.get('prompt_n')} ток, "
                  f"ответ {t.get('predicted_n')} ток, вызовов {len(calls)}")
            if m.get("reasoning_content"):
                print("    думал:", m["reasoning_content"][:150].replace("\n", " "))
            if not calls:
                print("    ОТВЕТ:", (m.get("content") or "").split("</think>")[-1].strip()[:400].replace("\n", " "))
                break
            msgs.append({"role": "assistant", "content": m.get("content") or "",
                         "tool_calls": calls})
            for c in calls:
                name = c["function"]["name"]
                try:
                    args = json.loads(c["function"]["arguments"] or "{}")
                except json.JSONDecodeError:
                    args = {}
                res = tools.FUNCS[name](**args) if name in tools.FUNCS else "(нет такого инструмента)"
                print(f"    → {name}({json.dumps(args, ensure_ascii=False)}) = "
                      f"{res[:120]!r}")
                msgs.append({"role": "tool", "tool_call_id": c.get("id", ""),
                             "content": res[:800]})
        sys.stdout.flush()


if __name__ == "__main__":
    model = sys.argv[1]
    prefill = sys.argv[2] if len(sys.argv) > 2 else ""
    if len(sys.argv) > 3:
        AFTER_TOOL = sys.argv[3]
    run(model, prefill)
