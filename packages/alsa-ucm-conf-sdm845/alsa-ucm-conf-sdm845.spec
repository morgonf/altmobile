%define _unpackaged_files_terminate_build 1

Name: alsa-ucm-conf-sdm845
Version: 1.2.10
Release: alt1.mobile1
Summary: ALSA UCM configuration for Qualcomm sdm845 based devices
License: BSD-3-Clause
Group: System/Configuration/Hardware
Url: https://gitlab.com/sdm845-mainline/alsa-ucm-conf
VCS: https://gitlab.com/sdm845-mainline/alsa-ucm-conf.git
ExclusiveArch: aarch64

Source: %name-%version.tar
# ALT Mobile, OnePlus 6T: microphone gain and earpiece amplifier against
# the acoustic echo in calls (docs/state.md, docs/measurements.md)
Patch1: %name-fajita-echo.patch

Requires: alsa-ucm-conf

%description
ALSA Use Case Manager configuration files for Qualcomm sdm845 based devices

This package contains ALSA Use Case Manager configuration files needed to get
sound on any sdm845 based phone.

%prep
%setup
%patch1 -p1

%build

%install
mkdir -p %buildroot%_datadir/alsa/ucm2/conf.d/sdm845
mkdir -p %buildroot%_datadir/alsa/ucm2/Samsung
cp -rv ucm2/Google %buildroot%_datadir/alsa/ucm2
cp -rv ucm2/OnePlus %buildroot%_datadir/alsa/ucm2
cp -rv ucm2/Samsung/starqltechn %buildroot%_datadir/alsa/ucm2/Samsung
cp -rv ucm2/SHIFT %buildroot%_datadir/alsa/ucm2
cp -rv ucm2/Xiaomi %buildroot%_datadir/alsa/ucm2
cp -v ucm2/conf.d/sdm845/Google* %buildroot%_datadir/alsa/ucm2/conf.d/sdm845
cp -v ucm2/conf.d/sdm845/OnePlus* %buildroot%_datadir/alsa/ucm2/conf.d/sdm845
cp -v ucm2/conf.d/sdm845/oneplus* %buildroot%_datadir/alsa/ucm2/conf.d/sdm845
cp -v ucm2/conf.d/sdm845/Samsung* %buildroot%_datadir/alsa/ucm2/conf.d/sdm845
cp -v ucm2/conf.d/sdm845/SHIFT* %buildroot%_datadir/alsa/ucm2/conf.d/sdm845
cp -v ucm2/conf.d/sdm845/Xiaomi* %buildroot%_datadir/alsa/ucm2/conf.d/sdm845

%files
%_datadir/alsa/ucm2

%changelog
* Sun Oct 04 2026 morgonf <morgonf@altlinux.org> 1.2.10-alt1.mobile1
- OnePlus 6T (fajita): DEC7 Volume 81, EAR PA Volume 2 against the
  acoustic echo in calls (the values the phone ran with since 26.09)

* Mon Apr 20 2026 Vasiliy Doylov <neko@altlinux.org> 1.2.10-alt1
- Initial package
