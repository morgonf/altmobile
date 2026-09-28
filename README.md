# ALT Mobile на OnePlus 6T

Доводка [ALT Mobile](https://altmobile.org) (Sisyphus, aarch64) на OnePlus 6T
(fajita, Snapdragon 845) до повседневного телефона, чтобы работали звонки, Plasma Mobile,
датчики, GPS и SIM-карта. Здесь патчи, пересобранные пакеты, системные
настройки, скрипты и разбор найденных проблем, которые стоит передать
в ALT и в upstream.

## Что работает и что сделано

| Область | Состояние | Где |
|---|---|---|
| Звонки, эхоподавление | работает; свойство `qcom,cvd-v2.3` в DT, правки q6voice | `docs/voice-calls.md`, `kernel/` |
| Plasma Mobile вместо Phosh | работает | `system/plasma/` |
| Модули настроек под экран телефона | переделаны на мобильные карточки | `packages/`, `packages/README.md` |
| Тема ALT по брендбуку Базальт СПО | цвета, значки, обои, шрифт PT Root UI | `system/plasma/alt-theme/` |
| Оболочка Plasma Mobile | цвета панелей, размеры, строка состояния под вырез | `packages/plasma-mobile/` |
| Браузеры | Firefox мобильный вид и масштаб; Chromium в бэклоге | `system/plasma/browsers.sh` |
| SIM-карта | подхват без перезагрузки, уведомление о PIN | `system/sim/` |
| GPS | работает автономно; AGPS нет | `system/gps/` |
| Датчики | акселерометр (автоповорот), свет, приближение; компаса нет | `system/sensors/` |
| Wi-Fi | ath10k ломается на роуминге 802.11r | `docs/plasma-plan.md` |
| Загрузчик | отметка удачной загрузки (qbootctl) | `scripts/boot-mark-successful.sh` |

Порядок запуска всех служб и назначение каждой описаны в `docs/boot-order.md`.
Состояние на телефоне по слоям показывает `alt-mobile-status`.

## Устройство репозитория

- `docs/` содержит разборы и планы. Текущее состояние и бэклог в
  `plasma-plan.md`, порядок загрузки в `boot-order.md`, звонки в
  `voice-calls.md` и остальных файлах про q6voice и ACDB. План отказа от
  Phosh и настройки системы под 6T в `phosh-exit-and-tuning.md`.
- `kernel/` содержит патчи драйверов голосового тракта q6voice.
- `packages/<пакет>/` содержит патчи к пакетам ALT, скрипты сборки на телефоне и
  установки; сводка в `packages/README.md`.
- `system/` содержит настройки и службы по областям (`plasma`, `sim`, `gps`,
  `sensors`, `boot`), у каждой свой `install.sh` и README.
- `scripts/` и `tools/` содержат вспомогательные скрипты, разборщик
  формата ACDB (`tools/acdb.py`) и сборщик калибровки (`tools/mkcal.py`).

Проприетарные данные (калибровка ACDB, прошивки DSP, файлы разделов
`vendor`) в репозиторий не входят. На телефоне их раскладывает
droid-juicer, калибровку читает `tools/acdb.py`.

## Для разработчиков ALT

Кандидаты в Bugzilla, у каждого есть разбор и проверенное решение:

- `iio-sensor-proxy` собран без SSC (ALT #59720). Помогает пересборка с
  `--enable ssc_support` и udev-правило с `ssc-accel ssc-proximity`
  (`packages/iio-sensor-proxy`, `system/sensors`).
- `hexagonrpcd-sdsp` выключен по умолчанию, а файлы для него droid-juicer
  уже кладёт.
- `plasma-mobile` не тянет `plasma6-integration`, `powerdevil`, Breeze,
  plasma-nm, plasma-pa, kscreen, bluedevil (`system/plasma/README.md`).
- В `plasma-mobile` `StartupFeedbackPanelFill` оставляет панели в цветах
  окна на главном экране (`packages/plasma-mobile`).
- Мастер первого запуска Plasma Mobile читает флаг из `[InitialStart]`.
- Модем (QMI) не открывает сессию USIM для SIM, вставленной на ходу
  (`system/sim/README.md`).
- Стандартные NMEA в модеме выключены, geoclue без агента не отвечает
  программам (`system/gps/README.md`).
- Kirigami не подгружает свой перевод `libkirigami6_qt.qm`.
- `/usr/bin/chromium` дописывает `--ozone-platform=wayland` после
  пользовательских флагов.
- Нет кнопки «Разблокировать SIM» при запертой карте в `kcm_cellular_network`
  (модем не виден модулю).

## Лицензия

Как и ALT Mobile, репозиторий распространяется под лицензией MIT (файл
`LICENSE`, автор morgonf): скрипты, настройки, правила, документация и
новые файлы.

Правки чужих проектов остаются под лицензиями этих проектов, их нельзя
перевести на MIT:

| Что | Лицензия |
|---|---|
| `kernel/src`, `kernel/oot`, `kernel/wcd`, `kernel/*.upstream`, патчи q6voice | GPL-2.0, как ядро Linux |
| `kernel/imx37x` (правки драйверов imx371 и imx376 из sdm845-mainline) | GPL-2.0 |
| `kernel/sa3103` (свой драйвер мотора фокуса) | GPL-2.0 или MIT на выбор (`Dual MIT/GPL`, как требует ядро) |
| `packages/libcamera` | LGPL-2.1-or-later, файлы настройки матриц CC0-1.0 и BSD-2-Clause (матрицы цвета Raspberry Pi) |
| `packages/plasma-camera` | лицензия plasma-camera (в пакете ALT GPL-3.0-only, в исходниках GPL-2.0-or-later и BSD-3-Clause); новые файлы `nightmerge` и `flash` под MIT |
| `packages/iio-sensor-proxy`, `packages/gnome-compass` | GPL-3.0, как эти проекты |
| `packages/plasma-mobile`, `packages/plasma-keyboard`, прочие патчи KDE | лицензии соответствующих проектов KDE (GPL/LGPL) |
| `system/plasma/alt-theme/*.colors` | LGPL-2.0-or-later (основа Breeze) |
| `system/plasma/AppletConfiguration.qml` | GPL-2.0-or-later (из Plasma) |

Калибровочные данные производителя (ACDB) и файлы Android в репозиторий
не входят.

Автор коммитов и правок morgonf.
