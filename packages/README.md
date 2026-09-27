# Пакеты, пересобранные или добавленные на телефоне

Собираются прямо на телефоне `rpmbuild` от пользователя, сборочные
зависимости ставятся из Sisyphus по `rpm -qpR` исходного пакета ALT.

| Пакет | Что сделано | Зачем |
|---|---|---|
| `plasma-settings` 26.08.1-alt0.2 | спецификация ALT 25.12.0-alt1, версия поднята, исходники `download.kde.org/stable/release-service/26.08.1/src/` | 25.12 показывал на телефоне модули для ПК и X11 (пустые или бессмысленные страницы), с 26.04 это отсеивается; новое разбиение на разделы. alt0.2: патч `plasma-settings-mobile-page-header.patch`, длинный заголовок страницы уходил за экран (контейнер заголовка в `PageHeader.qml` без `Layout.fillWidth`), теперь занимает свободную ширину и переносится по словам в две строки. Собирать `rpmbuild -ba --define "_smp_mflags -j1"` службой `systemd-run --user -p Nice=19 -p MemoryMax=3G`: восемь потоков грели телефон до зависания |
| `libxslt` 1.1.43-alt1 | `rpmbuild --rebuild` исходного пакета Sisyphus с `libxml2-devel` 2.14.6 | в Sisyphus libxslt собран со старой `libxml2.so.2`, а QtWebEngine и WebKit с `libxml2.so.16`; падений браузеров не устранило |

| `plasma-workspace` 6.7.5-alt2, только `kcm_regionandlang` | исходники ALT (`rpmbuild -bp`), патч `plasma-workspace/regionandlang-mobile.patch`, собирается одна цель (`build-kcm-regionandlang.sh`), ставится поверх штатного `.so` с копией `.orig` (`install-kcm-regionandlang.sh`) | текст налезал на кнопки «Изменить…» и обрезался «…»; теперь переносится по словам, кнопки значками |

Правки без пересборки:

- `system/plasma/kirigami-titlesubtitle-wrap.sh`: в `kf6-kirigami` у
  `TitleSubtitle` по умолчанию перенос по словам (`Text.WordWrap`), из
  `qmldir` модуля делегатов убрана строка `prefer`, иначе Qt берёт вшитую
  скомпилированную копию и не видит правку на диске. Оригиналы `.orig`.
- `system/plasma/l10n/kcm_navigation.ru.po`: перевод «Навигации».

Не пересобирать, а доставить:

- `plasma-nm-connect-mobile`: мобильные модули сети (сотовая сеть, Wi-Fi,
  точка доступа, проводная сеть) в ALT вынесены в этот подпакет.
