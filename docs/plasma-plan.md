# Plasma Mobile на OnePlus 6T: состояние и план

Снимок на 27 сентября 2026, 13:20, перед очисткой контекста. Начинать
продолжение с этого файла. Подробности по каждой находке в
`system/plasma/README.md`, пересобранные пакеты в `packages/README.md`.

## Где стоим

Телефон под Plasma Mobile 6.7.5 (Sisyphus), Phosh установлен, но выключен.
Работает: сеанс, касания, кнопка питания (PowerDevil), настройки виджетов,
мобильный интернет МТС, Chromium, эхоподавление в звонках.

Внешний вид, одобрен пользователем: масштаб 3 (360x780), шрифт Noto Sans 11
везде (Plasma и GTK), мелкие подписи 10, моноширинный Noto Sans Mono 11,
значки Folio 72 (три столбца в ящике). Всё в `system/plasma/plasma-look.sh`.
Масштаб 2.75 пробовали, пользователю мелко: **налезание лечить переносом
слов (`Text.WordWrap`, целыми словами), а не уменьшением.**

Сделано на телефоне поверх пакетов (у каждого оригинал `.orig`):

- `plasma-settings` 26.08.1-alt0.1 собран из исходников (`packages/plasma-settings`);
- `kcm_regionandlang.so` пересобран из `plasma-workspace` с патчем переноса
  (`packages/plasma-workspace`), исходники развёрнуты в
  `~/RPM/BUILD/plasma-workspace-6.7.5`, сборка одной цели скриптом
  `~/rlbuild.sh`, установка `~/rlinst.sh`;
- Kirigami `delegates/TitleSubtitle.qml` перенос по словам по умолчанию,
  из `delegates/qmldir` убран `prefer` (`system/plasma/kirigami-titlesubtitle-wrap.sh`);
- `AppletConfiguration.qml` мобильной оболочки: обход падения Qt 6.11.2;
- `kcm_navigation.mo` русский (строки модуль переводчикам не отдаёт);
- `libxslt` пересобран с libxml2 2.14 (падений браузеров не устранило);
- `/etc/tmpfiles.d/private-tmp.conf`: при сбитых часах не удалять личные
  временные папки.

Отладочное, пока оставлено: раздел `debuginfo` в
`/etc/apt/sources.list.d/debuginfo.list`, пакеты `gdb`, `systemd-coredump`,
`spectacle`, отладочная информация Qt QML и Plasma (660 МБ).

## Сбой 27.09.2026 и временные меры

В 13:16 телефон замер во время `rpmbuild -ba plasma-settings` и оказался в
fastboot (слот снят `fastboot --set-active=a`). Журнал обрывается без
следов нехватки памяти или паники, причина не установлена. Пересобирать
только в один поток и с низким приоритетом (`nice -n 19`, `-j1`).

После перезагрузки мастер первого запуска снова крутил `mts`: флаг
`wizardRun` стоял не в той группе, исправлено (см. `system/plasma/README.md`).

Временно, вернуть после разбора:

- автоблокировка выключена (`kscreenlockerrc`: `Autolock=false`,
  `LockOnResume=false`): экран блокировки не принимал цифры PIN-кода,
  три процесса `kcheckpass` висели;
- `powerdevilrc` `[BatteryManagement] BatteryCriticalAction=0`: датчик
  bq27411 показывает 1–7 %, хотя `charge_now/charge_full` около 50 % и
  напряжение 4,1 В; иначе PowerDevil может выключить телефон «по разряду».

На SIM включён PIN-код, после каждой перезагрузки его спрашивают.

## Что делать дальше, по порядку

1. **Заголовок страницы в «Параметрах» вылезает за экран** («Региональные и
   языковые параметры»). Рисует `src/qml/components/PageHeader.qml` в
   `plasma-settings` (исходники `~/RPM/BUILD/plasma-settings-26.08.1`).
   Причина видна: `Control { id: titleDelegateContainer }` в `RowLayout` без
   `Layout.fillWidth` и без `Layout.minimumWidth: 0`, ширина по содержимому.
   Правка: контейнеру заголовка `Layout.fillWidth: true`,
   `Layout.minimumWidth: 0`, у `Kirigami.ActionToolBar` убрать
   `Layout.fillWidth` (оставить ширину по кнопкам), у заголовка перенос по
   словам или `elide`. Пересобрать пакет (`rpmbuild -ba` в `~/RPM/SPECS`,
   поднять выпуск до alt0.2), поставить, проверить снимком. Патч
   `plasma-settings-mobile-page-header.patch` и спецификация alt0.2 уже
   лежат на телефоне в `~/RPM/SOURCES` и `~/RPM/SPECS`, осталось собрать.
2. **«Анимация» обрезает подписи** (`kcm_animations`, пакет `kwin`).
   Развернуть исходники kwin так же, как plasma-workspace, найти QML,
   добавить перенос, собрать одну цель, поставить поверх с `.orig`.
3. **Единый мобильный стиль модулей настроек.** Пользователю нравятся
   «Дата и время» и «Оболочка» (карточки `kirigami-addons` FormCard). Модули
   из настольного Plasma выглядят как для ПК. Переводить вёрстку на
   FormCard по одному, начиная с тех, которыми пользуются; сначала спросить
   пользователя порядок. Кандидаты: региональные параметры, звук,
   уведомления, Bluetooth, экран, приложения по умолчанию, анимация,
   смена дня и ночи (не влезает на экран), учётные записи (мелкие «три
   точки»).
4. Браузеры на QtWebEngine (Angelfish) и WebKit (Epiphany) падают в
   процессе отрисовки, место падения в `libQt6WebEngineCore` найдено,
   отладочная информация для него не ставится («битые пакеты»: нужна
   `debug64(libxslt.so.1)`, а libxslt пересобран локально).
5. Звонилка `plasma-dialer`, SMS `spacebar`, контакты `plasma-phonebook`:
   собрать из исходников, почти все зависимости в Sisyphus есть (нет
   `futuresql` для spacebar).
6. Отчёты разработчикам: ALT (недостающие зависимости plasma-mobile,
   `-x all` не проблема, libxslt/libxml2, старый plasma-settings), KDE
   (перевод kcm_navigation, Binding в AppletConfiguration.qml, вёрстка
   регион-модуля для телефона), Qt (QQmlBind в 6.11.2).

## Как снимать экран и проверять

Снимок: `spectacle -b -n -f -o файл` (весь экран) или `-a` (активное окно)
в окружении сеанса, окружение брать из `/proc/$(pgrep -x plasmashell)/environ`.
Отдельный модуль: `plasma-settings -s -m kcm_имя`. Готовый скрипт
`~/shots2.sh kcm_имя...` кладёт снимки в `/tmp/.private/altlinux/sh_*.png`.
Внимание: `pkill -f` с шаблоном, который есть в собственной командной
строке, убивает свою же ssh-оболочку, писать `[g]db`.
