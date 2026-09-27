#!/bin/sh
# Состав шторки быстрых настроек (выбор пользователя 28.09.2026), от
# пользователя. Меняется потом в «Параметры» → «Оболочка» → «Быстрые
# настройки». Оболочка читает список только при запуске, а при выходе
# пишет свой, поэтому её останавливаем на время записи.
# Кнопку «Местоположение» ставит quicksetting-location/install.sh (root).
Q=org.kde.plasma.quicksetting
E=""; for q in wifi mobiledata bluetooth flashlight screenrotation donotdisturb airplanemode hotspot; do E="$E${E:+,}$Q.$q"; done
E="$E,ru.altlinux.quicksetting.location,$Q.powermenu"
D=""; for q in battery audio settingsapp docked autohidepanels kscreenosd keyboardtoggle caffeine record waydroid screenshot nightcolor; do D="$D${D:+,}$Q.$q"; done
systemctl --user stop plasma-plasmashell.service
kwriteconfig6 --file plasmamobilerc --group QuickSettings --key enabledQuickSettings "$E"
kwriteconfig6 --file plasmamobilerc --group QuickSettings --key disabledQuickSettings "$D"
systemctl --user start plasma-plasmashell.service
