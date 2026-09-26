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
отключается флагом `wizardRun=true` в группе `[General]` файла
`~/.config/plasmamobilerc`, это делает `to-plasma.sh`.

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
мастера повториться не должно.
