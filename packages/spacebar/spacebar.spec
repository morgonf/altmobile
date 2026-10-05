Name: spacebar
Version: 6.7.5
Release: alt1.mobile1
%K6init

Group: Communications
Summary: SMS and MMS application for Plasma Mobile
License: GPL-2.0-or-later
Url: https://invent.kde.org/plasma-mobile/spacebar

Requires: kf6-kirigami kf6-kirigami-addons ModemManager

# ALT Mobile, OnePlus 6T (packages/spacebar of the oneplus6t repository)
Source: https://download.kde.org/stable/plasma/%version/%name-%version.tar.xz

BuildRequires(pre): rpm-build-kf6
BuildRequires: extra-cmake-modules qt6-base-devel qt6-declarative-devel
BuildRequires: kf6-kirigami-devel kf6-ki18n-devel kf6-kcontacts-devel kf6-kpeople-devel
BuildRequires: kf6-knotifications-devel kf6-kconfig-devel kf6-kcoreaddons-devel kf6-kdbusaddons-devel
BuildRequires: kf6-modemmanager-qt-devel kf6-kio-devel kf6-kwindowsystem-devel kf6-kcrash-devel
BuildRequires: kf6-kirigami-addons-devel libphonenumber-devel libcurl-devel libcares-devel
BuildRequires: futuresql-qt6-devel qcoro6-devel

%description
SMS and MMS application for Plasma Mobile, with a background daemon
that receives messages from ModemManager.

%prep
%setup

%build
%K6build

%install
%K6install
# The test server is for development only
rm -f %buildroot%_K6bin/spacebar-fakeserver
%find_lang --all-name --with-qt %name

%files -f %name.lang
%_K6bin/spacebar
%_K6start/org.kde.spacebar.daemon.desktop
%_prefix/libexec/spacebar-daemon
%_K6xdgapp/org.kde.spacebar.desktop
%_iconsdir/hicolor/*/apps/org.kde.spacebar.*
%_K6notif/spacebar.notifyrc
%_datadir/metainfo/org.kde.spacebar.appdata.xml

%changelog
* Mon Oct 05 2026 morgonf <morgonf@altlinux.org> 6.7.5-alt1.mobile1
- initial build for ALT Mobile (OnePlus 6T)
