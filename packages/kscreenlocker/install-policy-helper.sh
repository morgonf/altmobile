#!/bin/sh
# Установка помощника KAuth для «Требований к коду» (запись
# /etc/passwdqc.conf) и пересобранного kcm_screenlocker. От root.
# Политику polkit собрать заранее:
# kauth-policy-gen kcm/helper/org.altmobile.passwordpolicy.actions BUILD/kcm/helper/org.altmobile.passwordpolicy.policy
B=/home/altlinux/RPM/BUILD/kscreenlocker-6.7.5/BUILD
set -e
strip --strip-debug -o /tmp/pph.tmp $B/bin/passwordpolicyhelper
install -m 755 /tmp/pph.tmp /usr/libexec/kf6/kauth/passwordpolicyhelper
rm -f /tmp/pph.tmp
install -m 644 $B/kcm/helper/org.altmobile.passwordpolicy.conf /usr/share/dbus-1/system.d/
install -m 644 $B/kcm/helper/org.altmobile.passwordpolicy.service /usr/share/dbus-1/system-services/
install -m 644 $B/kcm/helper/org.altmobile.passwordpolicy.policy /usr/share/polkit-1/actions/
[ -f /etc/passwdqc.conf.orig ] || cp -a /etc/passwdqc.conf /etc/passwdqc.conf.orig
/home/altlinux/kcm-install.sh $B/bin/plasma/kcms/systemsettings/kcm_screenlocker.so
ls -l /usr/libexec/kf6/kauth/passwordpolicyhelper /usr/share/polkit-1/actions/org.altmobile.passwordpolicy.policy /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_screenlocker.so
