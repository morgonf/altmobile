Name: plasma-phonebook
Version: 26.08.1
Release: alt1.mobile2
%K6init

Group: Communications
Summary: Contacts application for Plasma Mobile
License: GPL-3.0-or-later
Url: https://invent.kde.org/plasma-mobile/plasma-phonebook

Requires: kf6-kirigami kf6-kirigami-addons

# ALT Mobile, OnePlus 6T (packages/plasma-phonebook of the oneplus6t repository)
Source: https://download.kde.org/stable/release-service/%version/src/%name-%version.tar.xz

BuildRequires(pre): rpm-build-kf6
BuildRequires: extra-cmake-modules qt6-base-devel qt6-declarative-devel qt6-svg-devel
BuildRequires: kf6-kcoreaddons-devel kf6-kirigami-devel kf6-kpeople-devel kf6-kcontacts-devel
BuildRequires: kf6-kconfig-devel kf6-ki18n-devel kf6-kirigami-addons-devel

%description
Contacts application for Plasma Mobile: list, search, add and edit
contacts of the address book (KPeople).

%prep
%setup

%build
%K6build

%install
%K6install
%find_lang --all-name --with-qt %name

%files -f %name.lang
%_K6bin/plasma-phonebook
%_K6plug/kpeople/actions/phonebook_kpeople_plugin.so
%_K6xdgapp/org.kde.phonebook.desktop
%_iconsdir/hicolor/*/apps/org.kde.phonebook.*
%_datadir/metainfo/org.kde.phonebook.metainfo.xml

%changelog
* Mon Oct 05 2026 morgonf <morgonf@altlinux.org> 26.08.1-alt1.mobile2
- no explicit kf6-kpeople requirement (no such package, the library
  dependency is automatic)

* Mon Oct 05 2026 morgonf <morgonf@altlinux.org> 26.08.1-alt1.mobile1
- initial build for ALT Mobile (OnePlus 6T)
