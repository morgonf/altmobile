"""Инструменты локального агента: команда, файл, поиск, страница.

Вывод любого инструмента обрезается: модель на телефоне читает около
8 токенов в секунду, 2000 символов это уже полминуты-минута.
"""
import html
import re
import subprocess
import urllib.parse
import urllib.request

LIMIT = 1500
UA = "Mozilla/5.0 (X11; Linux aarch64; rv:140.0) Gecko/20100101 Firefox/140.0"

SPECS = [
    {"type": "function", "function": {
        "name": "shell",
        "description": "Run a shell command on the phone (ALT Linux) and return its output.",
        "parameters": {"type": "object", "properties": {
            "command": {"type": "string", "description": "Command line for sh -c"}},
            "required": ["command"]}}},
    {"type": "function", "function": {
        "name": "read_file",
        "description": "Read a text file on the phone.",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"}}, "required": ["path"]}}},
    {"type": "function", "function": {
        "name": "web_search",
        "description": "Search the internet, returns titles, links and snippets.",
        "parameters": {"type": "object", "properties": {
            "query": {"type": "string"}}, "required": ["query"]}}},
    {"type": "function", "function": {
        "name": "fetch_url",
        "description": "Download a web page and return its text.",
        "parameters": {"type": "object", "properties": {
            "url": {"type": "string"}}, "required": ["url"]}}},
]


def clip(text, limit=LIMIT):
    text = text.strip()
    if len(text) <= limit:
        return text
    head = limit * 2 // 3
    return text[:head] + f"\n…[обрезано {len(text) - limit} симв.]…\n" + text[-(limit - head):]


def shell(command):
    try:
        r = subprocess.run(["sh", "-c", command], capture_output=True, text=True, timeout=60)
        out = r.stdout + (("\n[stderr] " + r.stderr) if r.stderr.strip() else "")
        return clip(out or f"(пусто, код {r.returncode})")
    except subprocess.TimeoutExpired:
        return "(команда не завершилась за 60 с)"


def read_file(path):
    try:
        with open(path, errors="replace") as f:
            return clip(f.read(20000))
    except OSError as e:
        return f"(ошибка: {e})"


def _get(url, data=None):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read(400000).decode(r.headers.get_content_charset() or "utf-8", "replace")


def _text(page):
    page = re.sub(r"(?is)<(script|style|noscript|svg|head)\b.*?</\1>", " ", page)
    page = re.sub(r"(?s)<[^>]+>", " ", page)
    return re.sub(r"\s+", " ", html.unescape(page)).strip()


def web_search(query, n=5):
    try:
        page = _get("https://lite.duckduckgo.com/lite/",
                    urllib.parse.urlencode({"q": query}).encode())
    except OSError as e:
        return f"(поиск недоступен: {e})"
    links = re.findall(r"<a[^>]+href=\"([^\"]+)\"[^>]+class='result-link'>(.*?)</a>", page, re.S)
    snippets = re.findall(r"class='result-snippet'>(.*?)</td>", page, re.S)
    out = []
    for i, (href, title) in enumerate(links[:n]):
        if "uddg=" in href:
            href = urllib.parse.unquote(href.split("uddg=")[1].split("&")[0])
        snip = _text(snippets[i]) if i < len(snippets) else ""
        out.append(f"{i + 1}. {_text(title)}\n   {href}\n   {snip[:200]}")
    return "\n".join(out) or "(ничего не найдено)"


def fetch_url(url):
    try:
        return clip(_text(_get(url)))
    except OSError as e:
        return f"(ошибка: {e})"


FUNCS = {"shell": shell, "read_file": read_file, "web_search": web_search, "fetch_url": fetch_url}
