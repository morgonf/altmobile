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

Прежде PIN спрашивал агент секретов plasma-nm окном «Вход в mts» на старых
виджетах Qt: вне темы, экранная клавиатура в нём не выходила. У подключения
`mts` PIN помечен как не требуемый (`nmcli con modify mts gsm.pin-flags
not-required`), а пользовательская служба `alt-sim-pin-notify` показывает
уведомление «SIM-карта заблокирована» с кнопкой «Разблокировать», которая
открывает «Сотовую сеть» (`kcm_cellular_network`, экран разблокировки SIM
в стиле Kirigami). После ввода PIN мобильный интернет поднимается сам.

Установка: `install.sh` от root.
