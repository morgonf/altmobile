# Исходные замеры системы

Часть 0 плана `docs/phosh-exit-and-tuning.md`. Снято 03.10.2026 скриптом
`scripts/baseline.sh` (батарея `scripts/battlog.sh`). Телефон работал
1 сутки 22 часа без перезагрузки, Plasma Mobile 6.7.5, ядро
7.1.0-qualcomm-sdm845-alt0.rc1, Wi‑Fi подключён, SIM на месте.

## Пакеты и место

- Установлено 2799 пакетов, из них 52 относятся к Phosh и GNOME (список в
  `rpm-gnome.txt` замера). Это phosh, phoc, phosh-antispam, phosh-tour,
  phosh-mobile-settings, alt-tweaks, tuner, foldy, chatty, gnome-calls,
  gnome-contacts, gnome-settings-daemon, gnome-session, gnome-software,
  gnome-control-center и программы GNOME.
- Корень btrfs 111 ГБ, занято 20 ГБ (данные 18,9 ГБ).

## Загрузка

`systemd-analyze` 4,7 с ядро плюс 19,8 с пространство пользователя,
всего 24,5 с до `graphical.target`.

Цепочка до сеанса упирается в датчики:

```
graphical.target @19.794s
└─plasma-mobile.service @17.465s +2.324s
  └─iio-sensor-proxy.service @5.451s +11.999s
```

`iio-sensor-proxy` стартует 12 с (ждёт SSC через hexagonrpcd-sdsp), и
оболочка всё это время ждёт его. Это половина пользовательской части
загрузки, первый кандидат для пункта 2.5. Дальше по `blame`
alt-gps-nmea 5,1 с, hexagonrpcd-sdsp 3,1 с, plasma-mobile 2,3 с.

## Службы

Включено 50 единиц системы и 10 пользователя, работает 33 службы
системы и 34 пользователя. Из Phosh и GNOME сейчас запущены
автозапуском демоны Chatty и GNOME Calls, phosh-antispam, FoldyService,
evolution-source-registry и evolution-addressbook-factory (тянет
Chatty), xdg-desktop-portal-gtk. В `/etc/xdg/autostart` лежит и
PhoshTour, но под Plasma он не запускается.

Кандидаты пункта 2.2 из работающих: avahi-daemon, bluetooth, neard
(NFC, нужен для плитки), waydroid-container, udisks2, power-profiles-daemon.

## Память

После уборки временных файлов (в `/tmp`, это tmpfs, лежало 2,8 ГБ
пробных кадров камеры от 02.10 и 03.10; без уборки «доступно» было
2,2 ГБ):

```
               total        used        free      shared  buff/cache   available
Mem:            7545        2512        3897         534        1859        5032
```

Сумма PSS всех процессов 1324 МБ. Крупнейшие plasmashell 349 МБ,
chatty 132, plasma-keyboard 86, kded6 60, gnome-calls 51,
evolution-source-registry 43, wireplumber 42, Xwayland 40.
Phosh и GNOME (chatty, gnome-calls, evolution, phosh-antispam,
FoldyService, xdg-desktop-portal-gtk) вместе около 310 МБ.

Подкачки нет (ни раздела, ни zram).

## Пробуждения в простое

Экран выключен, сон запрещён, 60 с. Прерываний 26576 (около 440 в
секунду), переключений контекста 17931.

| Источник | за 60 с |
|---|---|
| arch_timer | 12375 |
| IPI вызовы функций | 6544 |
| arch_mem_timer | 4932 |
| IPI широковещательный таймер | 619 |
| glink-smem (обмен с сопроцессорами) | 577 |
| apps_rsc | 497 |
| WLAN_CE_1 | 225 |
| i2c a88000 | 78 |
| ufshcd | 61 |

glink-smem около 10 раз в секунду при выключенном экране может быть
опросом датчиков через SSC, это проверить в пункте 2.3.

## Батарея

Показания bq27411 в начале замера: напряжение 4,13 В, CHARGE_NOW
2167 мА·ч, CHARGE_FULL 2366 мА·ч (по паспорту 3640), CAPACITY 95 %.
Отфильтрованные значения датчика испорчены, см. пункт 2.1 плана.

Ток по журналу `battlog.sh` (отсчёт каждые 10 с, Wi‑Fi подключён,
ssh-сессий во время замера нет):

| Режим | Время | По счётчику заряда | Средний CURRENT_NOW |
|---|---|---|---|
| экран выключен, сон запрещён | 22 мин (21:48–22:10) | 84 мА | 81 мА |
| экран включён, главный экран | 3 мин | | 173 мА |
| сон s2idle (`rtcwake -m freeze`) | 60 мин (22:21–23:21) | 40 мА | |

84 мА при погасшем экране означают примерно сутки без сна (2132 мА·ч
по счётчику). Для простоя это много, ожидалось 20–40 мА. Ток почти
ровный (73–85 мА), с отдельными всплесками до 95–110 мА. Причину искать
в пункте 2.1 вместе с пробуждениями (около 440 прерываний в секунду).

Сон снят `scripts/sleeptest.sh` от root. Телефон проспал весь час одним
засыпанием (ни одного раннего пробуждения, `suspend_stats` без сбоев),
заряд по счётчику 2091 → 2051 мА·ч. 40 мА во сне дают около двух суток
простоя на полной батарее. Это тоже много для s2idle, сон экономит
только половину тока простоя. Что остаётся включённым во сне (модем,
Wi‑Fi, датчики SSC, регуляторы), разбирать в пункте 2.1.

Во сне телефон недоступен по сети (Wi‑Fi его не будит). Будят ли его
входящий звонок и SMS, не проверено, это первый вопрос пункта 2.1.
