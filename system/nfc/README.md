# NFC на OnePlus 6T (NXP PN553)

Проверено 01.10.2026. Чип NXP PN553 на i2c-3, адрес 0x28, драйвер ядра
`nxp-nci_i2c`, устройство `nfc0`. neard 0.20 (пакет ALT) запускает udev
(`99-neard.rules`), адаптер `/org/neard/nfc0`. Протоколы Felica, MIFARE
(Type 2), Jewel, ISO-DEP, NFC-DEP. ISO15693 (Type 5) нет. Пользователь
сеанса управляет neard без root (`at_console`).

`install.sh` от root:

- `org.neard-alt-mobile.conf` разрешает neard вызывать NDEF- и
  Handover-агентов программ пользователя. В пакете ALT правила для root
  ограничены `send_destination="org.neard"` (патч openSUSE), и агенты не
  получали бы меток;
- `/etc/neard/main.conf` с `DefaultPowered=true` и `ConstantPoll=true`.
  Без него после загрузки адаптер выключен, а опрос после первой метки
  не возобновляется. Первый `StartPollLoop` neard сам не делает, его
  должна вызывать служба или приложение.

Чего нет в стеке ядро NCI + neard: эмуляции карты (HCE), доступа к
secure element (оплата невозможна), произвольного обмена APDU через
neard, MIFARE Classic с ключами. Подробнее в `docs/settings-plan.md`.
