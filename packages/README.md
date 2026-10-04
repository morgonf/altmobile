# Пакеты, пересобранные или добавленные на телефоне

## Свои RPM (пункт 2.7 `docs/phosh-exit-and-tuning.md`)

С 04.10.2026 правки ставятся пакетами, а не файлами поверх чужих пакетов.
Спецификация каждого лежит в каталоге пакета: спецификация ALT плюс наши
патчи (`scripts/mkspec-altmobile.py` для пакетов Plasma, Source900+
накладываются в конце `%prep`). Выпуск `<выпуск ALT>.mobileN`: новее
штатного, но любое обновление ALT новее нашего, поэтому пакеты остаются в
`RPM::Hold` (`system/apt`). Собирать на телефоне `scripts/build-queue.sh`
одной службой со сторожами `build-thermal-guard.sh` и `batt-guard.sh`.

| Пакет | Выпуск | Состояние |
|---|---|---|
| libcamera | 0.7.2-alt1.mobile4 | установлен 04.10, `rpm -V` чистый |
| plasma-camera | 2.1.1-alt2.mobile3 | установлен 04.10 |
| iio-sensor-proxy | 3.9-alt1.3 | установлен 04.10, SSC включён в спецификации, Has* рассылаются всем клиентам |
| plasma-settings | 26.08.1-alt0.3 | установлен 04.10, с раскладкой групп |
| kernel-modules-altmobile-qualcomm-sdm845 | 1.0-alt1.mobile1 | установлен 04.10, работа модулей проверяется после перезагрузки; прежние в `/var/lib/altmobile/updates-backup-<ядро>` |
| neard | 0.20-alt1.1 | пакет с 01.10 |
| plasma-pa, kscreen, bluedevil, kaccounts-integration, kscreenlocker, plasma-mobile, kwin, plasma-workspace | `.mobile1` | спецификации готовы, деревья по ним совпали с рабочими (`scripts/bp-compare.sh`), собираются очередью с 04.10 01:41 |
| kf6-kirigami, plasma-keyboard, gnome-compass, alsa-ucm-conf-sdm845 | | правки файлами поверх пакетов, спецификаций ещё нет |

Пакетная сборка libcamera ALT идёт с включёнными проверками (ASSERT) и
вскрыла три гонки при остановке камеры, которые сборка `buildtype=release`
пропускала (0031-0033).

Собираются прямо на телефоне `rpmbuild` от пользователя, сборочные
зависимости ставятся из Sisyphus по `rpm -qpR` исходного пакета ALT.

| Пакет | Что сделано | Зачем |
|---|---|---|
| `plasma-settings` 26.08.1-alt0.2 | спецификация ALT 25.12.0-alt1, версия поднята, исходники `download.kde.org/stable/release-service/26.08.1/src/` | 25.12 показывал на телефоне модули для ПК и X11 (пустые или бессмысленные страницы), с 26.04 это отсеивается; новое разбиение на разделы. alt0.2: патч `plasma-settings-mobile-page-header.patch`, длинный заголовок страницы уходил за экран (контейнер заголовка в `PageHeader.qml` без `Layout.fillWidth`), теперь занимает свободную ширину и переносится по словам в две строки. Собирать `rpmbuild -ba --define "_smp_mflags -j1"` службой `systemd-run --user -p Nice=19 -p MemoryMax=3G`: восемь потоков грели телефон до зависания |
| `libxslt` 1.1.43-alt1 | `rpmbuild --rebuild` исходного пакета Sisyphus с `libxml2-devel` 2.14.6 | в Sisyphus libxslt собран со старой `libxml2.so.2`, а QtWebEngine и WebKit с `libxml2.so.16`; падений браузеров не устранило |

| `plasma-workspace` 6.7.5-alt2, только `kcm_regionandlang` | исходники ALT (`rpmbuild -bp`), патч `plasma-workspace/regionandlang-mobile.patch`, собирается одна цель (`build-kcm-regionandlang.sh`), ставится поверх штатного `.so` с копией `.orig` (`install-kcm-regionandlang.sh`) | текст налезал на кнопки «Изменить…» и обрезался «…». С 27.09 главная страница в мобильном стиле карточек FormCard, как «Дата и время»: разделы «Язык» и «Форматы», строка целиком открывает выбор, значение переносится по словам. Заголовка «Formats» нет в русском каталоге модуля, в QML запасной вариант «Форматы» |
| `plasma-workspace` 6.7.5-alt2, `kcm_notifications` | то же дерево, что для `kcm_regionandlang`, патч `plasma-workspace/notifications-mobile.patch`, цель `kcm_notifications`, установка `scripts/kcm-install.sh <.so>` | настольная FormLayout не влезала в экран, подписи уходили за край. Карточки FormCard: «Параметры для системы/приложений» строками вместо пунктов меню «⋮», переключатели вместо флажков. Выбор места всплывающих окон, сочетание клавиш «Не беспокоить» и значки в панели задач убраны: на телефоне не действуют |
| `plasma-workspace` 6.7.5-alt2, `kcm_nighttime` | то же дерево, патч `plasma-workspace/nighttime-mobile.patch` (`main.qml`, `WorldMap.qml`), цель `kcm_nighttime` | «Смена дня и ночи» не влезала: ряд из переключателя и двух полей координат, карта шириной 30 единиц. Карточки FormCard, выбор источника диалогом, карта по ширине страницы с пропорцией 2:1. Подписи карты с `Layout.preferredWidth: 0`: привязка к ширине карты давала петлю и раздувала страницу |
| `plasma-workspace` 6.7.5-alt2, `kcm_componentchooser` | то же дерево, патч `plasma-workspace/componentchooser-mobile.patch`, цель `kcm_componentchooser` | «Приложения по умолчанию»: карточки FormCard по разделам, выбор приложения `FormComboBoxDelegate` (на телефоне диалогом) вместо узких выпадающих списков |
| `plasma-mobile` 6.7.5-alt1, `mobileshellplugin`, `homescreen.folio`, `TaskSwitcher.qml` | исходники ALT (`rpmbuild -bp --nodeps --define "__ubt_branch_id M110"`), патч `plasma-mobile/plasma-mobile-alt.patch`, сборка `plasma-mobile/build.sh <цели>` (9 минут), установка `plasma-mobile/install.sh` с `.orig` | 1) `StartupFeedbackPanelFill` запускал анимацию высоты при создании и не сбрасывался, если окно появилось раньше сигнала о запуске; строка состояния и панель навигации оставались в тёмных цветах окна на тёмных обоях. Теперь анимация только по сигналу и страховочный сброс через секунду, если окна нет; 2) значки навигации ×1.25, «Домой» ×1.6; кнопки навигации всегда включены (доступность действия проверяется при нажатии), иначе значок неактивной кнопки серый; 3) панель ярлыков Folio 4.8 вместо 6 единиц; 4) строка состояния: сигнал и Bluetooth слева у часов, справа Wi‑Fi, звук, батарея, середина под вырез камеры; отступы от углов `plasmamobilerc [Panels][WhenOnTop] statusBarLeftPadding/RightPadding=60`; 5) переключатель задач без русского каталога, свои строки |
| `plasma-pa` 6.7.5-alt1, `kcm_pulseaudio` | исходники ALT, патч `plasma-pa/pulseaudio-mobile.patch`, `plasma-pa/build.sh kcm_pulseaudio` (меньше минуты), установка `scripts/kcm-install.sh` | при масштабе 3 страница «Звук» была пустой: строка устройства (название, порт 10 и профиль 12 единиц шириной, три кнопки с подписями) не помещалась. Порт и профиль своими строками на всю ширину, ползунок на всю ширину, кнопки «Проверить» и «Каналы» значками |
| `kscreen` 6.7.5-alt1, `kcm_kscreen` | исходники ALT, патч `kscreen/kscreen-mobile.patch`, `kscreen/build.sh kcm_kscreen`, установка `scripts/kcm-install.sh` | четвёртая кнопка ориентации уходила за край: кнопки растягивались `Layout.fillWidth`. Ширина по значку |
| `bluedevil` 6.7.5-alt1, `kcm_bluetooth` | исходники ALT, патч `bluedevil/bluedevil-mobile.patch`, `bluedevil/build.sh kcm_bluetooth` | в пустом списке крупная кнопка «Выполнить сопряжение устройства…» (в шапке только значок «+») |
| `kaccounts-integration` 26.08.1-alt1, `kcm_kaccounts` | исходники ALT, патч `kaccounts-integration/kaccounts-mobile.patch`, `kaccounts-integration/build.sh kcm_kaccounts` | «Добавить учётную запись…» было только в мелком меню «⋮», теперь крупной кнопкой в пустом списке |
| `plasma-workspace` 6.7.5-alt2, `kcm_colors` | то же дерево, патч `plasma-workspace/colors-mobile.patch`, цель `kcm_colors` | выбор цвета выделения (список и образцы в одну строку) был шире экрана; теперь друг под другом |
| `kwin` 6.7.5-alt1, только `kcm_animations` | исходники ALT (`kwin-6.7.5-alt1.src.rpm`, `rpmbuild -bp --nodeps`), патч `kwin/kwin-animations-mobile.patch`, одна цель (`build-kcm-animations.sh`, четыре потока, около минуты), ставится поверх с копией `.orig` (`install-kcm-animations.sh`); для конфигурации доставлены 18 пакетов `-devel` из BuildRequires | в «Анимации» описания эффектов обрезались «…»: флажок Breeze рисует подпись одной строкой, переноса не умеет. Описание вынесено в отдельную подпись с переносом по словам, касание её переключает флажок; у кнопки «Эффекты рабочего стола» снята жёсткая ширина |
| `iio-sensor-proxy` 3.9-alt1.3 | патчи `iio-sensor-proxy-ssc-compass-mag.patch` (компас из сырых магнитометра и акселерометра SSC, калибровка на ходу) и `iio-sensor-proxy-has-broadcast.patch` (наличие датчиков сообщается всем клиентам) | у SLPI sdm845 нет готового компаса, подробности в `system/sensors/README.md`; без рассылки KWin не видел акселерометр после перезапуска службы |
| `gnome-compass` 0.4.0 | патч `gnome-compass-iio-sensor-proxy.patch`, ставится `packages/gnome-compass/install.sh` поверх файлов пакета | приложение знало только магнитометры PinePhone и Librem 5 в sysfs и без них рисовало случайную стрелку; теперь берёт направление из iio-sensor-proxy |
| `kscreenlocker` 6.7.5-alt1, только `kscreenlocker_greet` | исходники ALT (`rpmbuild -bp --nodeps`), патч `kscreenlocker/kscreenlocker-greet-rearm.patch` к коду `kcheckpass` из ALT, `kscreenlocker/build.sh` (одна цель, около пяти минут), установка `kscreenlocker/install.sh` от root с копией `.orig` | экран блокировки после сна иногда переставал принимать PIN. Греетер по PrepareForSleep (и при засыпании, и при пробуждении) отменяет запрос пароля, `kcheckpass` отвечает AuthAbort, а состояние остаётся Authenticating, и новый запрос не начинается. Введённый PIN уходит в пустоту, кнопки вибрируют, цифры не появляются. Теперь после отмены запрос пароля открывается заново, а на AuthError окно получает отказ вместо вечного ожидания. Воспроизведено и после установки проверено 01.10.2026 через `systemctl suspend` с будильником RTC, после каждой отмены греетер снова просит пароль (`rtcwake` идёт мимо logind и ошибку не показывает) |
| `kscreenlocker` 6.7.5-alt1, `kcm_screenlocker` | то же дерево, патч `kscreenlocker/kscreenlocker-kcm-mobile.patch`, `kscreenlocker/build.sh kcm_screenlocker`, установка `scripts/kcm-install.sh` | «Блокировка экрана» стала «Блокировка и PIN-код» в мобильных карточках FormCard. Раздел «PIN-код» открывает смену кода с цифровой клавиатурой (текущий, новый, повтор, от 4 до 16 цифр). Текущий код проверяет `kcheckpass` по протоколу греетера (SIGUSR1 блокируется до fork, иначе kill успевает раньше и убивает kcheckpass), новый записывает AccountsService `SetPassword` с хешем gost-yescrypt, как «Пользователи» ALT (passwdqc при этом не участвует). polkit требует для этого пароль (`auth_self`), и системный агент открывал окно «Требуется аутентификация». Теперь на время смены процесс регистрирует своего агента polkit (`pinagent.cpp`) и отвечает уже проверенным текущим PIN, правила polkit не ослаблены. Автоблокировка, «Блокировать после сна», «Спрашивать PIN-код» (в том числе «Не спрашивать») сохраняются сразу. Сочетание клавиш убрано |
| `plasma-mobile` 6.7.5-alt1, `plasma-mobile-envmanager` | то же дерево, патч `plasma-mobile/envmanager-alt-lnf.patch`, `plasma-mobile/build.sh plasma-mobile-envmanager`, установка `plasma-mobile/install.sh` | закрепляет глобальную тему `org.altlinux.mobile` вместо `org.kde.breeze.mobile`, иначе при пустых обоях Plasma берёт Next |
| `plasma-mobile` 6.7.5-alt1, `kcm_mobile_info` | то же дерево, патч `plasma-mobile/info-device-name.patch`, `plasma-mobile/build.sh kcm_mobile_info`, установка `scripts/kcm-install.sh`, затем `system/hostname/install.sh` от root (правило polkit, русские строки) | в «Сведениях о системе» строки «Имя устройства» и «Модель». Имя пишется в systemd-hostnamed («красивое» как есть, сетевое латиницей, кириллица по ГОСТ 7.79 Б) и в Alias адаптеров Bluetooth: BlueZ за именем системы не следит. Правило polkit `50-altmobile-hostname.rules` разрешает смену имени пользователю из wheel в активном локальном сеансе без пароля root. Проверено 04.10.2026 запуском из пользовательского менеджера, как запускаются приложения оболочки: имя «OnePlus 6T», сеть `oneplus-6t`, Bluetooth «OnePlus 6T». Xwayland после смены имени работает (в ключе есть запись для любого имени) |
| `plasma-settings` 26.08.1, только бинарник | дерево ALT, патч `plasma-settings/plasma-settings-alt-layout.patch`, `make plasma-settings` в `BUILD`, установка `system/plasma/settings-layout/install.sh` | группы и порядок модулей из `/etc/xdg/plasma-settings-alt-layoutrc` вместо вшитых в модули, см. `system/plasma/settings-layout/README.md` |
| `neard` 0.20-alt1.1 | исходный пакет Sisyphus, патчи upstream `neard/0001`, `0002`, `rpmbuild -ba` | neard отключался шиной D-Bus на метке без UID и не перезапускался, NFC пропадал до перезагрузки |
| `plasma-keyboard` 6.7.5 | `packages/plasma-keyboard/install.sh`: в стиле Breeze `languagePopupListEnabled: false`; языки ru и en в `system/plasma/keyboard.sh` | кнопка языка открывала меню вместо переключения; языки выбрать было негде, модуль настроек помечен только для ПК |

Правки без пересборки:

- `system/plasma/kirigami-titlesubtitle-wrap.sh`: в `kf6-kirigami` у
  `TitleSubtitle` по умолчанию перенос по словам (`Text.WordWrap`), из
  `qmldir` модуля делегатов убрана строка `prefer`, иначе Qt берёт вшитую
  скомпилированную копию и не видит правку на диске. Оригиналы `.orig`.
- `system/plasma/l10n/kcm_navigation.ru.po`: перевод «Навигации».

Не пересобирать, а доставить:

- `plasma-nm-connect-mobile`: мобильные модули сети (сотовая сеть, Wi-Fi,
  точка доступа, проводная сеть) в ALT вынесены в этот подпакет.

Сборку на телефоне запускать службой `systemd-run --user` вместе со
сторожем температуры `scripts/build-thermal-guard.sh <служба>`: выше 85 °C
он замораживает службу (`systemctl --user freeze`), ниже 70 °C продолжает.
На четырёх потоках температура скачет до 91–94 °C, сторож срабатывает.
