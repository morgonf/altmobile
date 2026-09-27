# Кнопка «Местоположение» в шторке

Быстрая настройка Plasma Mobile `ru.altlinux.quicksetting.location`
(28.09.2026). Выключение:
- создаёт флаг `/var/lib/alt-mobile/location-off`;
- запрещает службу geoclue (`systemctl mask --now`), через неё программы
  получают координаты;
- гасит GPS модема.

Программы, которые берут координаты у модема напрямую (Satellite), geoclue
не нужна, поэтому при флаге:
- `49-alt-mobile-location-off.rules` запрещает действие polkit
  `org.freedesktop.ModemManager1.Location` (чтение координат); ввод PIN
  идёт через `Device.Control` и не затрагивается;
- `alt-sim-hotplug.sh` раз в 10 секунд гасит приёмник GPS, если его
  кто-то включил.

Переключают состояние службы `alt-location-off` и `alt-location-on` (от
root), запускать только их из шторки разрешает
`51-alt-mobile-location.rules`. Состояние кнопки берётся из systemd:
`UnitFileState` у `geoclue.service` (`masked` значит выключено).
Установка: `install.sh` от root, в список шторки кнопку добавляет
`../quicksettings.sh`.
