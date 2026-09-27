# Пакеты, пересобранные или добавленные на телефоне

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
| `plasma-mobile` 6.7.5-alt1, `mobileshellplugin`, `homescreen.folio`, `TaskSwitcher.qml` | исходники ALT (`rpmbuild -bp --nodeps --define "__ubt_branch_id M110"`), патч `plasma-mobile/plasma-mobile-alt.patch`, сборка `plasma-mobile/build.sh <цели>` (9 минут), установка `plasma-mobile/install.sh` с `.orig` | 1) `StartupFeedbackPanelFill` запускал анимацию высоты при создании, строка состояния и панель навигации до первой смены окна брали тёмные цвета окна на тёмных обоях; 2) значки навигации ×1.25, «Домой» ×1.6; 3) панель ярлыков Folio 4.8 вместо 6 единиц; 4) строка состояния: сигнал и Bluetooth слева у часов, справа Wi‑Fi, звук, батарея, середина под вырез камеры; отступы от углов `plasmamobilerc [Panels][WhenOnTop] statusBarLeftPadding/RightPadding=60`; 5) переключатель задач без русского каталога, свои строки |
| `plasma-pa` 6.7.5-alt1, `kcm_pulseaudio` | исходники ALT, патч `plasma-pa/pulseaudio-mobile.patch`, `plasma-pa/build.sh kcm_pulseaudio` (меньше минуты), установка `scripts/kcm-install.sh` | при масштабе 3 страница «Звук» была пустой: строка устройства (название, порт 10 и профиль 12 единиц шириной, три кнопки с подписями) не помещалась. Порт и профиль своими строками на всю ширину, ползунок на всю ширину, кнопки «Проверить» и «Каналы» значками |
| `kscreen` 6.7.5-alt1, `kcm_kscreen` | исходники ALT, патч `kscreen/kscreen-mobile.patch`, `kscreen/build.sh kcm_kscreen`, установка `scripts/kcm-install.sh` | четвёртая кнопка ориентации уходила за край: кнопки растягивались `Layout.fillWidth`. Ширина по значку |
| `bluedevil` 6.7.5-alt1, `kcm_bluetooth` | исходники ALT, патч `bluedevil/bluedevil-mobile.patch`, `bluedevil/build.sh kcm_bluetooth` | в пустом списке крупная кнопка «Выполнить сопряжение устройства…» (в шапке только значок «+») |
| `kaccounts-integration` 26.08.1-alt1, `kcm_kaccounts` | исходники ALT, патч `kaccounts-integration/kaccounts-mobile.patch`, `kaccounts-integration/build.sh kcm_kaccounts` | «Добавить учётную запись…» было только в мелком меню «⋮», теперь крупной кнопкой в пустом списке |
| `kwin` 6.7.5-alt1, только `kcm_animations` | исходники ALT (`kwin-6.7.5-alt1.src.rpm`, `rpmbuild -bp --nodeps`), патч `kwin/kwin-animations-mobile.patch`, одна цель (`build-kcm-animations.sh`, четыре потока, около минуты), ставится поверх с копией `.orig` (`install-kcm-animations.sh`); для конфигурации доставлены 18 пакетов `-devel` из BuildRequires | в «Анимации» описания эффектов обрезались «…»: флажок Breeze рисует подпись одной строкой, переноса не умеет. Описание вынесено в отдельную подпись с переносом по словам, касание её переключает флажок; у кнопки «Эффекты рабочего стола» снята жёсткая ширина |

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
