# Свои модули настроек ALT Mobile

Собираются на телефоне в `/home/altlinux/alt-settings/<модуль>` скриптом
`build.sh` модуля (cmake, ECM, KF6), ставятся его `install.sh` от root.
Лицензия MIT.

## kcm_altappearance «Тема и обои» (01.10.2026)

Раздел «Внешний вид». Тёмная или светлая тема ALT Mobile касанием карточки
(`/usr/libexec/alt-mobile/set-color-scheme`, схема Plasma и вид приложений
GTK). Обои рабочего стола и экрана блокировки: строка открывает выбор с
крупным предпросмотром, касание миниатюры только показывает картинку,
записывает кнопка «Установить», переключатель ставит те же обои во второе
место. «Из файлов» копирует картинку в `~/.local/share/wallpapers`. Пакеты
обоев ALT в списке первыми.

Ловушки сборки: ECM без `QT_MAJOR_VERSION 6` ищет qmake Qt5,
`kcmutils_add_qml_kcm` требует `CMAKE_LIBRARY_OUTPUT_DIRECTORY`.
