Name: plasma-dialer
Version: 6.7.5
Release: alt1.mobile1
%K6init

Group: Communications
Summary: Phone dialer for Plasma Mobile
License: GPL-2.0-or-later
Url: https://invent.kde.org/plasma-mobile/plasma-dialer

Requires: kf6-kirigami kf6-kirigami-addons ModemManager callaudiod

# ALT Mobile, OnePlus 6T (packages/plasma-dialer of the oneplus6t repository)
Source: https://download.kde.org/stable/plasma/%version/%name-%version.tar.xz

BuildRequires(pre): rpm-build-kf6
BuildRequires: extra-cmake-modules qt6-base-devel qt6-declarative-devel qt6-wayland-devel qt6-multimedia-devel
BuildRequires: kf6-kirigami-devel kf6-ki18n-devel kf6-kcontacts-devel kf6-kpeople-devel
BuildRequires: kf6-knotifications-devel kf6-kconfig-devel kf6-kcoreaddons-devel kf6-kdbusaddons-devel
BuildRequires: kf6-modemmanager-qt-devel kf6-kio-devel kf6-kwindowsystem-devel kf6-kcrash-devel
BuildRequires: kf6-kirigami-addons-devel libphonenumber-devel libcallaudio-devel
BuildRequires: plasma-wayland-protocols wayland-devel

%description
Phone dialer for Plasma Mobile: calls through ModemManager, call
history, USSD, with background daemons for the modem and telephony.

%prep
%setup

%build
%K6build

%install
%K6install
# Development only: the test server and the static helper library
rm -f %buildroot%_K6bin/plasma-dialer-fakeserver
rm -f %buildroot%_libdir/libktelephonymetatypes.a
rm -rf %buildroot%_includedir/KF6/kTelephonyMetaTypes
%find_lang --all-name --with-qt %name

%files -f %name.lang
%_K6bin/plasma-dialer
%_K6start/org.kde.modem.daemon.desktop
%_K6start/org.kde.telephony.daemon.desktop
%_prefix/libexec/kde-telephony-daemon
%_prefix/libexec/modem-daemon
%_K6qml/org/kde/telephony/
%_K6xdgapp/org.kde.plasma.dialer.desktop
%_K6dbus_iface/org.kde.telephony.*.xml
%_K6dbus_srv/org.kde.modemdaemon.service
%_K6dbus_srv/org.kde.telephony.service
%_iconsdir/hicolor/*/apps/dialer.*
%_K6notif/plasma-dialer.notifyrc
%_datadir/metainfo/org.kde.plasma.dialer.appdata.xml

%changelog
* Mon Oct 05 2026 morgonf <morgonf@altlinux.org> 6.7.5-alt1.mobile1
- initial build for ALT Mobile (OnePlus 6T)
