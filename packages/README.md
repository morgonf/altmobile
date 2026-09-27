# Пакеты, пересобранные или добавленные на телефоне

Собираются прямо на телефоне `rpmbuild` от пользователя, сборочные
зависимости ставятся из Sisyphus по `rpm -qpR` исходного пакета ALT.

| Пакет | Что сделано | Зачем |
|---|---|---|
| `plasma-settings` 26.08.1-alt0.2 | спецификация ALT 25.12.0-alt1, версия поднята, исходники `download.kde.org/stable/release-service/26.08.1/src/` | 25.12 показывал на телефоне модули для ПК и X11 (пустые или бессмысленные страницы), с 26.04 это отсеивается; новое разбиение на разделы. alt0.2: патч `plasma-settings-mobile-page-header.patch`, длинный заголовок страницы уходил за экран (контейнер заголовка в `PageHeader.qml` без `Layout.fillWidth`), теперь занимает свободную ширину и переносится по словам в две строки. Собирать `rpmbuild -ba --define "_smp_mflags -j1"` службой `systemd-run --user -p Nice=19 -p MemoryMax=3G`: восемь потоков грели телефон до зависания |
| `libxslt` 1.1.43-alt1 | `rpmbuild --rebuild` исходного пакета Sisyphus с `libxml2-devel` 2.14.6 | в Sisyphus libxslt собран со старой `libxml2.so.2`, а QtWebEngine и WebKit с `libxml2.so.16`; падений браузеров не устранило |

| `plasma-workspace` 6.7.5-alt2, только `kcm_regionandlang` | исходники ALT (`rpmbuild -bp`), патч `plasma-workspace/regionandlang-mobile.patch`, собирается одна цель (`build-kcm-regionandlang.sh`), ставится поверх штатного `.so` с копией `.orig` (`install-kcm-regionandlang.sh`) | текст налезал на кнопки «Изменить…» и обрезался «…»; теперь переносится по словам, кнопки значками |
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
