# Установка ALT Mobile на OnePlus 6T с нуля

Порядок, в котором телефон доводится до текущего состояния. Каждый шаг
ссылается на скрипт или документ, где подробности. Скрипты из `system/`
запускаются от root из своего каталога, если не сказано иное. Репозиторий
удобно держать на телефоне клоном в `/home/altlinux/oneplus6t`.

Состояние на 04.10.2026. Пункт 1 бэклога (`docs/plasma-plan.md`).

## 1. Прошивка и первый вход

1. Образ ALT Mobile для sdm845 (beta.altlinux.org/mobile/sisyphus/latest,
   суммы в `B2SUM` и `GOST12SUM`) и U-Boot по инструкции altmobile.org.
   Распаковку на раздел лучше делать с компьютера `scripts/alt-install.sh`
   (телефон отдан как USB-накопитель меню U-Boot, раздел `userdata` виден
   как `/dev/sda17`, пути к архиву в начале скрипта), он проверяет каждый
   шаг. В инструкции три недочёта, каждый ломает установку молча.
   - После `mkfs.btrfs` нет проверки. Если форматирование не прошло,
     `mount` берёт старую ext4 Android, у раздела нет метки `ROOT`, и
     initramfs ждёт корень вечно. Проверять `blkid`.
   - `tar xfpv` без `-C` распаковывает в текущий каталог.
   - `/etc/fstab` в образе говорит `f2fs`, а раздел `btrfs`. Строку надо
     поправить после распаковки.
2. Загрузчик 6T считает неудачные загрузки и через семь помечает слот
   негодным. `scripts/boot-mark-successful.sh` включает `qbootctl` и
   отметку удачной загрузки. Если телефон всё же упал в fastboot, его
   поднимают `fastboot --set-active=a` и `fastboot reboot`.
3. Сеть (Wi‑Fi), `apt-get update`, ssh по ключу.

## 2. Наши пакеты

Пакеты собираются на телефоне (`packages/<пакет>/build-rpm.sh` или очередь
`scripts/build-queue.sh` со сторожами температуры `scripts/build-thermal-guard.sh`
и батареи `scripts/batt-guard.sh`). kwin и plasma-workspace собираются по
несколько часов, остальные минуты.

1. `apt-get install apt-repo-tools`, затем от root
   `scripts/local-repo.sh` собирает локальный репозиторий из
   `~altlinux/RPM/RPMS` и прописывает его в
   `/etc/apt/sources.list.d/altmobile.list`.
2. Проще всего `scripts/install-built.sh` от root (сначала с `-n`, чтобы
   посмотреть список): репозиторий, установка всех наших пакетов, которые
   уже стоят в системе, уборка временных подмен, `rpm -V`. Затем
   перезагрузка. Вручную: `apt-get update`, затем установка наших версий, например
   `apt-get install libcamera gst-plugins-libcamera1.0 plasma-camera
   iio-sensor-proxy plasma-settings gnome-compass alsa-ucm-conf-sdm845
   kernel-modules-altmobile-qualcomm-sdm845 kwin plasma-pa kscreen bluedevil
   kscreenlocker plasma-mobile plasma-workspace kf6-kirigami plasma-keyboard`.
   apt берёт сборку `alt1.mobileN` вместо `alt1` из Sisyphus сам.
3. `system/apt/install.sh`: RPM::Hold, чтобы `apt-get dist-upgrade` не
   заменил наши пакеты новыми из Sisyphus. Ядро в том же списке, пакет
   модулей собран под его версию (`packages/kernel-modules-altmobile`).

Состав и выпуски пакетов в `packages/README.md`.

## 3. Система по слоям

Порядок слоёв как в `docs/boot-order.md`.

| Шаг | Скрипт | Что делает |
|---|---|---|
| Загрузка | `system/boot/install.sh` | цель `alt-mobile.target` и порядок служб |
| Звонки | `system/echo-install.sh` (затем перезагрузка) | модули q6voice с эхоподавлением, калибровка, UCM, служба ADSP; подробности в `docs/voice-calls.md` |
| SIM | `system/sim/install.sh` | SIM на ходу, уведомление о PIN |
| GPS | `system/gps/install.sh` | NMEA при загрузке, агент geoclue |
| Датчики | `system/sensors/install.sh` | SSC через hexagonrpcd, правила udev, порядок запуска |
| Камера | `system/camera/install.sh` | вспышка (udev) |
| NFC | `system/nfc/install.sh` | neard, служба alt-nfc, плитка шторки |
| Имя телефона | `system/hostname/install.sh` | правило polkit для смены имени |
| Экран блокировки | `system/lockscreen/install.sh` | перевод греетера, блокировка после включения |
| Настройка под 6T | `system/tuning/install.sh` | zram, журнал, шрифт консоли |

## 4. Plasma Mobile

1. `system/plasma/to-plasma.sh` переключает сеанс с Phosh на Plasma
   Mobile и ставит пакеты, которых не тянет `plasma-mobile`.
2. Тема ALT: `system/plasma/alt-theme/install.sh` (root), затем
   `apply-alt-theme.sh` от пользователя.
3. Русские каталоги, которых нет в пакетах:
   `system/plasma/l10n/install-l10n.sh`.
4. Шторка: `system/plasma/quicksetting-location/install.sh` (root),
   `system/plasma/quicksettings.sh` (пользователь, состав кнопок).
5. Группы «Параметров»: `system/plasma/settings-layout/install.sh`.
6. От пользователя внутри сеанса: `plasma-look.sh` (масштаб, шрифты,
   отступы строки состояния), `keyboard.sh` (языки ru и en),
   `default-apps.sh`. От root: `browsers.sh` (масштаб Firefox и Chromium),
   `hide-apps.sh` (лишнее из меню).
7. Свои модули «Тема и обои», «NFC», «Доступ по SSH», «Хранилище» и
   «Местоположение»: `packages/alt-settings/*/build.sh` и `install.sh`
   (у SSH и «Хранилища» ещё помощники KAuth, их ставит тот же
   `install.sh`).

## Ещё не пакетами

Эти части пока ставятся скриптами поверх файлов системы. Их стоит
перевести в пакеты, тогда шаги 3 и 4 сократятся.

- Модули q6voice с эхоподавлением (`kernel/`, `scripts/q6install.sh`) и
  калибровка. Модули камеры и NFC уже в пакете
  `kernel-modules-altmobile-qualcomm-sdm845`.
- Свои модули настроек `packages/alt-settings` (пять модулей и два
  помощника KAuth).
- Тема ALT, каталоги переводов, службы SIM, GPS и NFC.

## Проверка

`alt-mobile-status` показывает состояние по слоям. `rpm -V` по нашим
пакетам должен молчать, кроме конфигурационных файлов.
