#!/bin/sh
# Экран блокировки Plasma Mobile на OnePlus 6T. От root, копии .orig.
#
# 1. Перевод. Греетер (kscreenlocker_greet) ищет строки только в своём
#    каталоге kscreenlocker_greet, а «Enter PIN» и «Wrong PIN» из
#    LockScreenState.qml переведены в каталоге оболочки
#    plasma_shell_org.kde.plasma.phone. Указываем каталог явно (i18nd).
# 2. Скорость отказа. /etc/pam.d/kde (пакет kscreenlocker ALT) включает
#    system-auth-multi, где после pam_tcb идёт pam_krb5. Области Kerberos
#    на телефоне нет, а pam_krb5 тратит на неверном PIN 5-12 секунд, и всё
#    это время окно не отвечает. Берём system-auth (локальные пароли).
Q=/usr/share/plasma/shells/org.kde.plasma.mobileshell/contents/lockscreen/LockScreenState.qml
P=/etc/pam.d/kde
[ -f $Q.orig ] || cp -a $Q $Q.orig
sed -i 's/\bi18n("\(Enter PIN\|Wrong PIN\)")/i18nd("plasma_shell_org.kde.plasma.phone", "\1")/' $Q
grep -n i18n $Q
[ -f $P.orig ] || cp -a $P $P.orig
sed -i 's/system-auth-multi$/system-auth/' $P
cat $P
