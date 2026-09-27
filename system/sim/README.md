# SIM-карта на OnePlus 6T

## Карта, вставленная при работающем телефоне

Модем (QMI) видит карту и приложение USIM, читает ICCID, но не открывает
основную сессию подготовки: `qmicli --uim-get-card-status` показывает
`Primary GW: session doesn't exist`, `PIN1 state: 'not-initialized'`, а
ModemManager остаётся в `failed`, `sim-missing`. Перезапуск ModemManager и
перевключение питания слота не помогают. Помогает открыть сессию вручную:

    qmicli -p -d qrtr://0 --uim-change-provisioning-session="session-type=primary-gw-provisioning,activate=yes,slot=1,aid=<AID USIM>"
    systemctl restart ModemManager

После этого ModemManager видит `lock: sim-pin`. Служба `alt-sim-hotplug`
делает это сама, раз в 10 секунд проверяя `sim-missing`.

## Запрос PIN-кода

На запертой карте раньше выходили два окна plasma-nm на старых виджетах Qt,
вне темы и без экранной клавиатуры. Первое («Вход в mts») выводил агент
секретов: NetworkManager поднимал `mts` сам, уходил в `need-auth` и просил
PIN. Второе («Требуется разблокирование PIN-код SIM-карты») выводил
следильщик модема в kded plasma-nm, в том числе на `sim-pin2`, которое
модем сообщает уже после разблокировки. Модуль «Сотовая сеть»
(`kcm_cellular_network`) запертый модем не видит вовсе.

Как устроено теперь (проверено 27.09.2026):

- `alt-sim-unlock` открывает окно `sim-unlock/main.qml` в стиле настроек
  (FormCard, цифровая клавиатура). Код уходит прямо в ModemManager
  (`Sim.SendPin`, после трёх ошибок `Sim.SendPuk` с новым PIN), окно
  показывает остаток попыток.
- `alt-sim-pin-notify` (служба пользователя) открывает окно, как только
  находит запертую карту. Если окно закрыли кнопкой «Позже», висит
  уведомление с кнопкой «Разблокировать».
- `50-alt-mobile-sim.rules` разрешает вводить PIN без пароля пользователя
  (по умолчанию у ModemManager `auth_self_keep`).
- У `mts` выключено автоподключение. Подключение поднимает
  `alt-sim-hotplug`, когда модем зарегистрировался в сети.
- В `~/.config/plasma-nm` стоит `UnlockModemOnDetection=false`, это
  выключает окно следильщика модема.

Модуль QML DBus из Plasma (`org.kde.plasma.workspace.dbus`) ждёт сигнатуру
в скобках, `(s)`. С голой `s` аргументы теряются и модем отвечает
`type of message, "()", does not match expected type "(s)"`.

Установка: `install.sh` от root.
