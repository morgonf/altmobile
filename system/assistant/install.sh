#!/bin/sh
# Ставит Джарвиса в домашний каталог пользователя (без root).
# Нужны: ~/llm (llama.cpp, whisper.cpp, модели), ~/assistant/piper и голос,
# пакет python3-module-pyside6.
set -e
D=$(dirname "$(readlink -f "$0")")
A=$HOME/assistant/app
mkdir -p "$A/qml" ~/.config/systemd/user ~/.local/bin \
    ~/.local/share/applications ~/.local/share/icons/hicolor/scalable/apps
cp "$D/jarvis.py" "$D/diag.py" "$A/"
cp "$D/qml/Main.qml" "$A/qml/"
cp "$D/llm-server.service" "$D/whisper-server.service" ~/.config/systemd/user/
sed "s|@BIN@|$HOME/.local/bin|" "$D/jarvis.desktop" > ~/.local/share/applications/jarvis.desktop
cp "$D/jarvis.svg" ~/.local/share/icons/hicolor/scalable/apps/
cat > ~/.local/bin/jarvis <<EOT
#!/bin/sh
systemctl --user start llm-server whisper-server
exec python3 $A/jarvis.py "\$@"
EOT
chmod +x ~/.local/bin/jarvis "$A/jarvis.py"
systemctl --user daemon-reload
echo "Готово. Ящик приложений увидит ярлык после systemctl --user restart plasma-plasmashell.service"
