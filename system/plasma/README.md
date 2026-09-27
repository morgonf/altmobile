# Plasma Mobile вместо Phosh

Переключение графического сеанса OnePlus 6T под ALT Mobile на Plasma Mobile 6.7.5
из Sisyphus. Phosh остаётся установленным, вернуть его можно скриптом
`to-phosh.sh`. Оба скрипта запускаются от root.

Сеанс запускает `plasma-mobile.service` по образцу `phosh.service`: автовход
пользователя 1000 на tty1, без дисплейного менеджера. Скрипт
`plasma-mobile-session` передаёт переменные сеанса пользовательскому systemd,
как это обычно делает SDDM, затем запускает `startplasmamobile`.

## Недостающие зависимости

Пакет `plasma-mobile` в Sisyphus 26 сентября 2026 не тянет за собой пакеты,
без которых сеанс не работает.

- `plasma6-integration`. Без модуля тем `KDEPlasmaPlatformTheme6.so` Qt при
  `QT_QPA_PLATFORMTHEME=KDE` берёт встроенную запасную тему, и KWin падает с
  SIGSEGV ещё в конструкторе приложения. Стек из-под gdb:
  `QKdeTheme::createKdeTheme` -> `processThemeChanged` -> `handleThemeChanged`,
  вызванные из `QGuiApplicationPrivate::createPlatformIntegration` в
  `KWin::Application::Application`. Сеанс перезапускался каждые несколько
  секунд, ничего не рисовалось.
- `plasma6-breeze`, `qqc2-breeze-style`, `icon-theme-breeze`: оформление,
  стиль QML (`startplasmamobile` выставляет `QT_QUICK_CONTROLS_STYLE=org.kde.breeze`)
  и иконки.

- `powerdevil`. Без него кнопку питания никто не перехватывает, и её
  обрабатывает logind действием по умолчанию: короткое нажатие, чтобы
  погасить экран, **выключало телефон**, а от зарядки он включался снова.
  Выглядело как перезагрузки.
- `plasma-nm`, `plasma-pa`, `kscreen`, `bluedevil`, `xdg-desktop-portal-kde`:
  сеть, громкость, экран, Bluetooth и порталы в интерфейсе.

Об этом стоит сообщить сопровождающему пакета `plasma-mobile`.

Сон при простое в `powerdevilrc` выключен, как раньше под Phosh: сон рвал
связь.

## Как искали

KWin запрещает себе дампы и трассировку, поэтому стек удалось снять только
подменой `/usr/bin/kwin_wayland` обёрткой, которая запускает настоящий
бинарник под gdb. Имя бинарника менять нельзя: модуль платформы KWin
загружается, только если путь программы оканчивается на `kwin_wayland`.

Звонки под Plasma принимает прежний `gnome-calls` (`plasma-dialer` в Sisyphus
нет), эхоподавление от оболочки не зависит.

## Мастер первого запуска

`plasma-mobile-initial-start` на шаге мобильной связи без конца запускал
подключение `mts` заново, каждая попытка обрывала предыдущую на `need-auth`,
а окно запроса секрета от `plasma-nm` открывалось и закрывалось. Мастер
отключается флагом `wizardRun=true` в группе **`[InitialStart]`** файла
`~/.config/plasmamobilerc`, это делает `to-plasma.sh`.

Сначала флаг по ошибке записали в `[General]`. Мастер его там не ищет
(`Settings::shouldStartWizard()` в `initialstart/settings.cpp` читает
`InitialStart`) и 27.09.2026 после перезагрузки запустился снова. SIM была
заблокирована PIN-кодом, мастер дёргал `mts` десятки раз в секунду (в
журнале NetworkManager `connection-activate ... pid=` мастера), за десять
минут набралось 4800 активаций. Оболочка перестала отвечать на касания,
экран блокировки не принимал цифры, окна PIN-кода SIM и «пароля МТС»
мигали. Лечение: флаг в правильную группу, мастер завершить,
`plasmashell` перезапустить. Проверка: `plasma-mobile-initial-start`
сразу выходит с сообщением «Wizard will not be started…».

На SIM этого телефона включён режим разрешённых номеров, ModemManager
показывает `lock: sim-pin2`. NetworkManager может принять это за запрос
PIN-кода и спросить секрет. Вводить в такое окно PIN2 наугад не стоит:
после трёх неверных попыток понадобится PUK2.

Последствие шквала переподключений. `plasmashell` (NetworkManagerQt)
запомнил исчезнувшие активные подключения (`ActiveConnection/241`, `245`,
`246`) и по 20 раз в секунду запрашивал их свойства. Поток D-Bus оболочки
занимал 74% процессора, и оболочка не отвечала на касания, хотя KWin сенсор
видел и получал. Лечится перезапуском оболочки
(`systemctl --user restart plasma-plasmashell.service`), после отключения
мастера повториться не должно. Искать `pgrep -f` по имени мастера надо
шаблоном `[p]lasma-mobile-initial-start`, иначе находится своя же команда.

## Браузеры

- **27.09**: Chromium под Wayland шире экрана (минимальная ширина около
  500 точек при 360 доступных), теперь запускается через XWayland с
  масштабом 2.1 (`browsers.sh`, `/etc/chromium/default` с
  `CHROMIUM_DISABLE_WAYLAND=1`, иначе `/usr/bin/chromium` дописывает
  `--ozone-platform=wayland` последним). Firefox 156 через Wayland
  помещается, отключён вопрос о браузере по умолчанию (его окно шире
  экрана). Экранная клавиатура в X11-окне Chromium может не выскакивать
  сама, в панели навигации появляется кнопка её вызова; пользователю
  вызвать её не удалось, Chromium в бэклоге. Браузер по умолчанию Firefox.
- Firefox: включён учёт `<meta name="viewport">` (`dom.meta-viewport.enabled`),
  иначе адаптивные сайты (Хабр) открывались в версии для ПК; щипок
  масштабирует (`apz.allow_zooming`). Неадаптивные сайты (вики ALT)
  остаются широкими, это их вёрстка.
- Firefox: единый системный размер шрифта интерфейса 11 pt через
  `firefox/userChrome.css` (mobile-config-firefox задаёт адресной строке
  9 pt, а панели, меню и уведомления Firefox уменьшены сами). Общий
  масштаб системный: `layout.css.devPixelsPerPx` 3.3 увеличивал всё
  равномерно, но разнобой адресной строки и вкладок оставался. Размеры в
  pt, а не em, иначе вложенные элементы перемножаются. Шрифт страниц по
  умолчанию PT Root UI. Проверять только после полного перезапуска:
  главный процесс `/usr/bin/firefox`, `pkill -f` по пути ловит свою же
  оболочку, закрывать `pkill -x firefox` без `-9` (иначе Firefox
  предлагает безопасный режим).

- **Chromium 154** работает, назначен браузером по умолчанию.
- **Angelfish** (QtWebEngine 6.11.2) и **Epiphany** (WebKitGTK 2.54): падает
  процесс отрисовки, `QtWebEngineProcess` по 25..40 раз за 20 секунд даже на
  `about:blank`. Не помогают `--disable-gpu`, отключение песочницы, отключение
  JIT (`--js-flags=--jitless`, `JSC_useJIT=false`), отключение DMA-BUF у
  WebKit. Место падения в `libQt6WebEngineCore.so.6`, смещение `0x1fd756c`
  от начала кода, `ldrb w2, [x2]` по указателю `0xfeef80808083`. Отладочных
  символов QtWebEngine в Sisyphus нет. Страница памяти ядра 4 КБ.
- Попутно найдено несоответствие в Sisyphus: `libxslt-1.1.43-alt1` собран со
  старой `libxml2.so.2` (2.12), а QtWebEngine и WebKit с новой `libxml2.so.16`
  (2.14), и в процесс загружаются обе. На телефоне libxslt пересобран из
  `libxslt-1.1.43-alt1.src.rpm` с `libxml2-devel` 2.14.6 (`rpmbuild --rebuild`),
  падения отрисовки это **не** устранило. Сообщить в Bugzilla ALT всё равно
  стоит. Вернуть пакет из репозитория: `apt-get install --reinstall libxslt`.

## Прочее

- Масштаб экрана 3 (`kscreen-doctor output.DSI-1.scale.3`), логически 360x780.
- Установлены `plasma-settings` (настройки Plasma Mobile), `qmlkonsole`,
  `kalk`, `calindori`, `krecorder`, `koko`, `spectacle`.
- `/etc/tmpfiles.d/private-tmp.conf` (в `system/`): часы при загрузке
  показывают август или 1970 год, личная временная папка pam_mktemp
  выглядела старой и удалялась через 15 минут после загрузки, программы
  теряли TMPDIR (так не запускался Chromium).

## Падение plasmashell при открытии настроек виджета

Оболочка падала (экран гас и возвращался) при открытии настроек любого
виджета. Стек из-под gdb с отладочной информацией из `RPMS.debuginfo`:

```
toVariant                          qv4engine.cpp:1567
QQmlBindPrivate::postEvalEntry     qqmlbind.cpp:1456
QQmlBind::eval / componentComplete qqmlbind.cpp:1500 / 1283
PlasmaQuick::ConfigView::setSource configview.cpp:278   (libplasma 6.7.5)
```

Виновник `Binding` с группированными целями `root.Window.window.flags` и
`root.Window.window.visibility` в
`/usr/share/plasma/shells/org.kde.plasma.mobileshell/contents/configuration/AppletConfiguration.qml`
(пакет `plasma-mobile` 6.7.5, Qt 6.11.2). Заменён обычным кодом, который
выставляет те же свойства при появлении окна, файл
`AppletConfiguration.qml` здесь, оригинал рядом с суффиксом `.orig`.
Проверено 27 сентября: настройки часов открываются. Стоит сообщить в KDE
(plasma-mobile) и Qt (qtdeclarative, `QQmlBind`).

Отладочная информация ставится из раздела
`rpm [alt] http://ftp.altlinux.org/pub/distributions/ALTLinux Sisyphus/aarch64 debuginfo`
(`/etc/apt/sources.list.d/debuginfo.list`), исходники приходят вместе с ней в
`/usr/src/debug`.
