# neard 0.20-alt1.1

Пакет neard ALT (Sisyphus, 0.20-alt1) с двумя исправлениями из основной
ветки neard после выпуска 0.20:

- `0001` (upstream f6f07a5cca) «tag: Fix invalid D-Bus message for
  non-existing uids». У метки без UID neard объявлял свойство `Uid` и слал
  неправильное сообщение, dbus-daemon отключал его («D-Bus disconnect»),
  neard завершался. Запускает его только udev при появлении nfc0, так что
  NFC пропадал до перезагрузки (01.10.2026 23:37, «Адаптер не найден»);
- `0002` (upstream d347cbb226) «Fix invalid D-Bus message on multi-language
  Text or SmartPoster tags».

Сборка на телефоне: `rpm -i neard-0.20-alt1.src.rpm`, патчи в
`~/RPM/SOURCES`, `neard.spec` отсюда, `rpmbuild -ba`. Сборочные зависимости
`libnl-devel autoconf-archive systemd-devel`. Ошибка про `near/version.h`
в конце сборки относится к проверке заголовков `neard-devel` и не мешает.
Установка `rpm -Uvh neard-0.20-alt1.1.aarch64.rpm` от root.

Страховка на случай других падений: `system/nfc/neard-restart.conf`
(Restart=always).
