#!/usr/bin/python3
"""Джарвис: голосовой ассистент для ALT Mobile на OnePlus 6T.

Тап по реактору: запись до паузы → whisper-server → llama-server →
Piper по предложениям. Жалобы на устройства разбираются по сводке
из diag.py, действия выполняются только после подтверждения.
"""
import array
import json
import math
import os
import queue
import re
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
import wave

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

import diag

HOME = os.path.expanduser("~")
LLM_URL = "http://127.0.0.1:8080/v1/chat/completions"
LLM_MODEL = "LFM2.5-8B-A1B-Q4_K_M"
WHISPER_URL = "http://127.0.0.1:8178/inference"
PIPER = f"{HOME}/assistant/piper/piper"
VOICE = f"{HOME}/assistant/voices/ru_RU-ruslan-medium.onnx"
VOICE_SPEED = "0.9"  # length_scale Piper: меньше значит быстрее
WORK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "jarvis")

RATE = 16000
SILENCE_RMS = 900      # ниже считается тишиной
SILENCE_END = 1.2      # столько тишины после речи завершает запись
MAX_RECORD = 20        # секунд

# Всё служебное по-английски и коротко: кеш подсказки у гибридной LFM2 не
# работает, каждый запрос читается целиком (~0.12 с на токен), а кириллица
# занимает в 2-3 раза больше токенов.
SYSTEM = ("You are Jarvis, a voice assistant on a OnePlus 6T phone running ALT Linux "
          "(ALT Mobile, Plasma Mobile). Always answer in Russian, briefly (1-3 sentences), "
          "sometimes address the user as \"сэр\". Your answer is spoken aloud: no markdown, "
          "lists, code or emoji.")

# Модель всегда сначала рассуждает по-английски (сотни токенов, десятки
# секунд). Готовое начало ответа с закрытым <think> пропускает рассуждение.
PREFILL = "<think>Отвечу кратко по-русски.</think>"

DIAG_PROMPT = ("User complaint: {complaint}\nDiagnostics just collected on the phone:\n{findings}\n"
               "Explain to the user in Russian, in 2-3 sentences, what is wrong and what to do. "
               "Use only these facts.{action}")

DEVICE_WORDS = re.compile(
    r"устройств|подключ|usb|юсб|флешк|bluetooth|блютуз|блютус|наушник|гарнитур|"
    r"геймпад|джойстик|dualshock|мыш|клавиатур|заряд|колонк|часы", re.I)
TROUBLE_WORDS = re.compile(
    r"проблем|не работ|не видит|не подключ|отвал|отключ|сломал|почему|не определ|"
    r"не заряж|ошибк|разбер", re.I)
YES = re.compile(r"^(да|давай|выполн|сделай|конечно|ок|окей|угу|ага)\b", re.I)
NO = re.compile(r"^(нет|не надо|не нужно|отмен|стоп)\b", re.I)


def post_json(url, body, timeout=600):
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=timeout)


class Speaker:
    """Piper держит модель в памяти, фразы озвучиваются по очереди."""

    def __init__(self, on_idle):
        self.on_idle = on_idle
        self.q = queue.Queue()
        self.play = None
        self.piper = None
        self.active = False
        self.lock = threading.Lock()
        os.makedirs(f"{WORK}/tts", exist_ok=True)
        threading.Thread(target=self.loop, daemon=True).start()

    def start_piper(self):
        self.piper = subprocess.Popen(
            [PIPER, "-m", VOICE, "--length_scale", VOICE_SPEED, "--output_dir", f"{WORK}/tts"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, bufsize=1)

    def say(self, text):
        text = text.replace("\n", " ").strip()
        if text:
            self.q.put(text)

    def stop(self):
        with self.lock:
            while not self.q.empty():
                self.q.get_nowait()
            if self.play:
                self.play.kill()

    def idle(self):
        return not self.active and self.q.empty()

    def loop(self):
        while True:
            text = self.q.get()
            self.active = True
            if self.piper is None or self.piper.poll() is not None:
                self.start_piper()
            self.piper.stdin.write(text + "\n")
            path = self.piper.stdout.readline().strip()
            with self.lock:
                self.play = subprocess.Popen(["pw-play", path])
            self.play.wait()
            try:
                os.unlink(path)
            except OSError:
                pass
            if self.q.empty():
                self.active = False
                self.on_idle()


class Assistant(QObject):
    stateChanged = Signal()
    levelChanged = Signal()
    messagesChanged = Signal()
    pendingChanged = Signal()
    _post = Signal(object)  # вызов из рабочего потока в главный

    def __init__(self):
        super().__init__()
        self._state = "idle"     # idle, listening, thinking, speaking
        self._level = 0.0
        self._messages = []
        self._pending = None     # (код, название, команда)
        self.history = []
        self.recording = False
        self.busy = False
        self._post.connect(lambda f: f())
        self.speaker = Speaker(lambda: self._post.emit(self._speech_done))
        threading.Thread(target=self.warmup, daemon=True).start()

    # --- свойства для QML ---
    def _get_state(self):
        return self._state

    def _get_level(self):
        return self._level

    def _get_messages(self):
        return self._messages

    def _get_pending(self):
        return self._pending[1] if self._pending else ""

    state = Property(str, _get_state, notify=stateChanged)
    level = Property(float, _get_level, notify=levelChanged)
    messages = Property("QVariantList", _get_messages, notify=messagesChanged)
    pending = Property(str, _get_pending, notify=pendingChanged)

    def set_state(self, s):
        if s != self._state:
            self._state = s
            self.stateChanged.emit()

    def add(self, role, text):
        self._messages = self._messages + [{"role": role, "text": text}]
        self.messagesChanged.emit()

    def append_last(self, text):
        msgs = list(self._messages)
        msgs[-1] = {"role": msgs[-1]["role"], "text": msgs[-1]["text"] + text}
        self._messages = msgs
        self.messagesChanged.emit()

    def set_pending(self, p):
        self._pending = p
        self.pendingChanged.emit()

    def ui(self, f, *a):
        self._post.emit(lambda: f(*a))

    def _speech_done(self):
        if self._state == "speaking" and not self.busy:
            self.set_state("idle")

    # --- действия из QML ---
    @Slot()
    def tap(self):
        if self.recording:
            self.recording = False          # закончить запись досрочно
        elif self._state == "speaking":
            self.speaker.stop()
            self.set_state("idle")
        elif not self.busy:
            self.busy = True
            self.recording = True
            self.set_state("listening")
            threading.Thread(target=self.listen, daemon=True).start()

    @Slot(str)
    def send(self, text):
        text = text.strip()
        if text and not self.busy:
            self.busy = True
            self.add("user", text)
            threading.Thread(target=self.handle, args=(text,), daemon=True).start()

    @Slot(bool)
    def confirm(self, yes):
        p = self._pending
        self.set_pending(None)
        if not p:
            return
        if yes:
            self.add("system", f"Выполняю: {p[1]}")
            threading.Thread(target=self.run_action, args=(p,), daemon=True).start()
        else:
            self.add("system", "Отменено")

    # --- рабочие потоки ---
    def warmup(self):
        # Загружает модель и заранее читает системный текст
        try:
            post_json(LLM_URL, {"model": LLM_MODEL, "max_tokens": 1,
                                "messages": [{"role": "system", "content": SYSTEM},
                                             {"role": "user", "content": "Привет"}]}).read()
        except OSError as e:
            self.ui(self.add, "system", f"Модель недоступна: {e}")

    def listen(self):
        os.makedirs(WORK, exist_ok=True)
        rec = subprocess.Popen(["pw-record", "--rate", str(RATE), "--channels", "1",
                                "--format", "s16", "-"],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        pcm = bytearray()
        chunk = RATE // 10 * 2            # 0.1 с
        heard, quiet, t0 = False, 0.0, time.time()
        while self.recording and time.time() - t0 < MAX_RECORD:
            data = rec.stdout.read(chunk)
            if not data:
                break
            pcm += data
            a = array.array("h", data)
            rms = math.sqrt(sum(x * x for x in a) / max(1, len(a)))
            self.ui(self.set_level, min(1.0, rms / 6000))
            if rms > SILENCE_RMS:
                heard, quiet = True, 0.0
            elif heard:
                quiet += 0.1
                if quiet >= SILENCE_END:
                    break
        rec.kill()
        self.recording = False
        self.ui(self.set_level, 0.0)
        if not heard:
            self.ui(self.add, "system", "Ничего не услышал")
            self.finish()
            return
        self.ui(self.set_state, "thinking")
        path = f"{WORK}/rec.wav"
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(bytes(pcm))
        text = self.transcribe(path)
        if not text:
            self.ui(self.add, "system", "Не разобрал, повторите")
            self.finish()
            return
        self.ui(self.add, "user", text)
        self.handle(text)

    def set_level(self, v):
        self._level = v
        self.levelChanged.emit()

    def transcribe(self, path):
        boundary = uuid.uuid4().hex
        with open(path, "rb") as f:
            audio = f.read()
        fields = {"language": "ru", "response_format": "json", "temperature": "0"}
        body = b""
        for k, v in fields.items():
            body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n"
                     f"{v}\r\n").encode()
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
                 f"filename=\"rec.wav\"\r\nContent-Type: audio/wav\r\n\r\n").encode()
        body += audio + f"\r\n--{boundary}--\r\n".encode()
        req = urllib.request.Request(
            WHISPER_URL, data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r).get("text", "").strip()
        except OSError as e:
            self.ui(self.add, "system", f"Распознавание недоступно: {e}")
            return ""

    def handle(self, text):
        self.ui(self.set_state, "thinking")
        if self._pending:
            if YES.search(text):
                self.ui(self.confirm, True)
                self.finish()
                return
            if NO.search(text):
                self.ui(self.confirm, False)
                self.finish()
                return
            self.ui(self.set_pending, None)
        if DEVICE_WORDS.search(text) and TROUBLE_WORDS.search(text):
            self.diagnose(text)
        else:
            self.chat(text)
        self.finish()

    def finish(self):
        self.busy = False
        self.ui(self._settle)

    def _settle(self):
        if self._state in ("thinking", "listening") or (
                self._state == "speaking" and self.speaker.idle()):
            self.set_state("idle")

    def diagnose(self, complaint):
        self.speaker.say("Минуту, сэр, проверяю.")
        self.ui(self.set_state, "speaking")
        findings, action, shown = diag.analyze(complaint)
        self.ui(self.add, "system", shown)
        hint = f" Then offer this fix: {action[1]}." if action else ""
        prompt = DIAG_PROMPT.format(complaint=complaint, action=hint,
                                    findings="\n".join(f"- {f}" for f in findings))
        answer = self.stream([{"role": "system", "content": SYSTEM},
                              {"role": "user", "content": prompt}])
        if action:
            self.ui(self.set_pending, action)
            self.speaker.say("Выполнить?")
        self.history = [{"role": "user", "content": complaint},
                        {"role": "assistant", "content": answer}]

    def chat(self, text):
        self.history = (self.history + [{"role": "user", "content": text}])[-6:]
        answer = self.stream([{"role": "system", "content": SYSTEM}] + self.history)
        self.history.append({"role": "assistant", "content": answer})

    def stream(self, messages):
        """Потоковый ответ модели; готовые предложения сразу уходят в речь."""
        self.ui(self.add, "assistant", "")
        raw_text, full, buf = "", "", ""
        try:
            r = post_json(LLM_URL, {"model": LLM_MODEL, "stream": True, "max_tokens": 300,
                                    "temperature": 0.4,
                                    "messages": messages + [{"role": "assistant", "content": PREFILL}]})
            for raw in r:
                line = raw.decode().strip()
                if not line.startswith("data: ") or line == "data: [DONE]":
                    continue
                raw_text += json.loads(line[6:])["choices"][0]["delta"].get("content") or ""
                # Сервер может вернуть подсказку обратно, видимое начинается после </think>
                visible = raw_text.split("</think>")[-1] if "</think>" in raw_text else (
                    "" if raw_text.lstrip().startswith("<") else raw_text)
                visible = visible.lstrip() if not full else visible
                delta = visible[len(full):]
                if not delta:
                    continue
                full += delta
                buf += delta
                if "ДЕЙСТВИЕ" not in full:
                    self.ui(self.append_last, delta)
                # Режем на предложения, строку ДЕЙСТВИЕ не озвучиваем
                while True:
                    m = re.search(r"[.!?…](\s|$)", buf)
                    if not m or "ДЕЙСТВИЕ" in buf[:m.end()]:
                        break
                    self.speak(buf[:m.end()])
                    buf = buf[m.end():]
        except OSError as e:
            self.ui(self.append_last, f"[ошибка: {e}]")
        tail = buf.split("ДЕЙСТВИЕ")[0].strip()
        if tail:
            self.speak(tail)
        return full

    def speak(self, sentence):
        sentence = re.sub(r"[*#`_]", "", sentence).strip()
        if sentence:
            self.ui(self.set_state, "speaking")
            self.speaker.say(sentence)

    def run_action(self, p):
        code, title, cmd = p
        r = subprocess.run(["sh", "-c", cmd], capture_output=True, text=True, timeout=60)
        ok = r.returncode == 0
        self.ui(self.add, "system", f"{title}: {'готово' if ok else 'ошибка'}\n"
                + (r.stdout + r.stderr).strip()[-400:])
        self.speaker.say("Готово, сэр." if ok else "Не получилось, подробности на экране.")
        self.ui(self.set_state, "speaking")


def main():
    os.makedirs(WORK, exist_ok=True)
    app = QGuiApplication(sys.argv)
    app.setApplicationName("jarvis")
    app.setDesktopFileName("jarvis")
    assistant = Assistant()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("assistant", assistant)
    engine.load(QUrl.fromLocalFile(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                "qml", "Main.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
