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

Об этом стоит сообщить сопровождающему пакета `plasma-mobile`.

## Как искали

KWin запрещает себе дампы и трассировку, поэтому стек удалось снять только
подменой `/usr/bin/kwin_wayland` обёрткой, которая запускает настоящий
бинарник под gdb. Имя бинарника менять нельзя: модуль платформы KWin
загружается, только если путь программы оканчивается на `kwin_wayland`.

Звонки под Plasma принимает прежний `gnome-calls` (`plasma-dialer` в Sisyphus
нет), эхоподавление от оболочки не зависит.
