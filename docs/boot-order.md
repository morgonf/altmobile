# Порядок загрузки ALT Mobile на OnePlus 6T

Всё, что мы добавили поверх ALT Mobile, собрано в цель `alt-mobile.target`
(`system/boot/`). Порядок внутри слоёв задают drop-in-файлы служб (`After=`),
цель только собирает службы вместе, чтобы их было видно одной командой.
Состояние по слоям показывает `alt-mobile-status` (`scripts/alt-mobile-status`).

## Слои

| Слой | Службы | Зачем | Где |
|---|---|---|---|
| 0. Qualcomm | `rmtfs`, `pd-mapper`, `tqftpserv` | разделы модема, домены DSP, TFTP для прошивок | пакеты ALT |
| 0. Загрузчик | `qbootctl-mark-successful` | отметка удачной загрузки, иначе после 7 перезагрузок fastboot | `scripts/boot-mark-successful.sh` |
| 1. Модем | `ModemManager` | после слоя 0 (`qcom-base.conf`) | `system/boot/dropins/` |
| 1. Модем | `alt-sim-hotplug` | SIM, вставленная на ходу: открыть сессию USIM | `system/sim/` |
| 1. Модем | `alt-gps-nmea` | стандартные NMEA в модеме, иначе нет координат | `system/gps/` |
| 2. DSP | `hexagonrpcd-sdsp` | файлы реестра для процессора датчиков SLPI | пакет ALT, `system/sensors/` |
| 2. DSP | `hexagonrpcd-adsp-audio`, `configure-q6voiced`, `q6voiced`, `q6echo-activate` | звонки и эхоподавление | `system/`, `kernel/` |
| 3. Датчики | `iio-sensor-proxy` (с `ExecStartPre=alt-sensors-wait.sh`) | запуск, только когда акселерометр реально отвечает (~30 с после старта) | `system/sensors/` |
| 4. Сеанс | `plasma-mobile.service` | после `iio-sensor-proxy`, иначе KWin читает ориентацию `undefined` и автоповорот не работает | `system/plasma/`, `system/sensors/` |
| 5. Пользователь | `alt-sim-pin-notify` (user), агент geoclue (autostart) | уведомление о запертой SIM, доступ программ к GPS | `system/sim/`, `system/gps/` |

## Правила, найденные на практике

- Процессор датчиков SLPI **нельзя перезапускать** через
  `/sys/class/remoteproc/remoteproc3/state`: обратно он не стартует
  (`Boot failed: -110`), датчики возвращает только перезагрузка телефона.
- `hexagonrpcd-sdsp` стартует на ~12-й секунде, данные датчиков идут с
  ~30-й: всё, что читает датчики, должно ждать `alt-sensors-wait.sh`.
- Слой 4 ждёт слой 3: экран Plasma появляется на 10-20 секунд позже, зато
  автоповорот работает с первого включения.

## Остатки Phosh в автозапуске

`/etc/xdg/autostart`: `mobi.phosh.PhoshTour-first-login` (показывает «Phone
Tour»), `org.kop316.antispam-daemon`, `sm.puri.Chatty-daemon`,
`org.gnome.Calls-daemon`. Звонилка GNOME Calls и Chatty (SMS) пока нужны,
замены из Plasma Mobile ещё не собраны; Phone Tour не нужен.
