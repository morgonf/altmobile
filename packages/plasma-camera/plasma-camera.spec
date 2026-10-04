%define rname plasma-camera

%define sover 0
%define libplasma_camera libplasma-camera%sover

Name: %rname
Version: 2.1.1
Release: alt2.mobile5
%K6init

Group:  Video
Summary: Simple camera application for mobile devices
License: GPL-3.0-only
Url: https://anongit.kde.org/plasma-camera.git

Provides: kde5-plasma-camera = %EVR
Obsoletes: kde5-plasma-camera < %EVR

Requires: qt6-multimedia kf6-kirigami kf6-kirigami-addons
# Video recording (GstRecorder): appsrc, videoconvert, openh264enc, h264parse,
# fdkaacenc, mp4mux, pulsesrc
Requires: gst-plugins-base1.0 gst-plugins-good1.0 gst-plugins-bad1.0

Source: %rname-%version.tar
# ALT Mobile, OnePlus 6T (packages/plasma-camera of the oneplus6t repository)
Source1: plasma-camera.ru-add.po
Source2: mo-merge.py
Patch1: plasma-camera-2.1.1-alt-mobile.patch
Patch2: plasma-camera-switch-segv.patch
Patch3: plasma-camera-single-instance.patch
Patch4: plasma-camera-photo-enhance.patch
Patch5: plasma-camera-zoom-fullsize.patch
Patch6: plasma-camera-screen-rotation.patch
Patch7: plasma-camera-switch-skip.patch
Patch8: plasma-camera-dual-video.patch

BuildRequires(pre): rpm-build-kf6
BuildRequires: qt6-declarative-devel qt6-svg-devel qt6-wayland-devel qt6-multimedia-devel qt6-sensors-devel
BuildRequires: libvulkan-devel
BuildRequires: extra-cmake-modules
BuildRequires: kf6-kcoreaddons-devel kf6-ki18n-devel kf6-kconfig-devel kf6-kirigami-devel kf6-kdbusaddons-devel
BuildRequires: python3
BuildRequires: libcamera-devel libexiv2-devel
BuildRequires: gstreamer1.0-devel gst-plugins1.0-devel

%description
Simple camera application for mobile devices.

%prep
%setup -n %rname-%version
%patch1 -p1
%patch2 -p1
%patch3 -p1
%patch4 -p1
%patch5 -p1
%patch6 -p1
%patch7 -p1
%patch8 -p1

%build
%K6build

%install
%K6install
# Russian strings the catalogue lacks (focus, night mode, zoom, flash)
M=%buildroot%_datadir/locale/ru/LC_MESSAGES/%rname.mo
python3 %SOURCE2 $M %SOURCE1 $M.new
mv $M.new $M

%find_lang --all-name --with-qt %name

%files -f %name.lang
%_K6bin/*camera*
%_K6xdgapp/*camera*.desktop
%_datadir/metainfo/*.xml

%changelog
* Sun Oct 04 2026 morgonf <morgonf@altlinux.org> 2.1.1-alt2.mobile5
- dual video: frames combined in their own thread (DualCompositor), video
  frames turned and pushed to GStreamer in another one; the small picture
  sits in the upper right corner, clear of the controls

* Sun Oct 04 2026 morgonf <morgonf@altlinux.org> 2.1.1-alt2.mobile4
- dual video: the rear and the front camera at once, picture in picture
  (a tap on the small picture swaps them) or split, recorded as one video
- video recording through GStreamer (openh264, AAC) instead of
  QMediaRecorder, whose x264 at its default settings did not keep up;
  the video stream is 1280 wide

* Sun Oct 04 2026 morgonf <morgonf@altlinux.org> 2.1.1-alt2.mobile3
- The switch button goes between the main and the front camera, the
  second rear camera (IMX376) only from the settings

* Sun Oct 04 2026 morgonf <morgonf@altlinux.org> 2.1.1-alt2.mobile2
- Auto-rotation: the viewfinder and tap to focus follow the screen
  orientation; in landscape the controls go to columns at the sides,
  clear of the front camera notch, photo and video by one button

* Sat Oct 03 2026 morgonf <morgonf@altlinux.org> 2.1.1-alt2.mobile1
- ALT Mobile for the OnePlus 6T with libcamera 0.7.2-alt1.mobile1:
  + binned viewfinder, full size photos, tap to focus, AE/AF lock,
    exposure compensation, night mode, flash, zoom up to 8x
  + photo noise reduction, sharpening and contrast curve
  + one instance only, no crash on camera switch
  + missing Russian strings

* Mon Dec 22 2025 Sergey V Turchin <zerg@altlinux.org> 2.1.1-alt2
- fix requires

* Fri Dec 12 2025 Sergey V Turchin <zerg@altlinux.org> 2.1.1-alt1
- new version

* Thu Nov 13 2025 Sergey V Turchin <zerg@altlinux.org> 2.1.0-alt1
- new version

* Thu Jul 31 2025 Sergey V Turchin <zerg@altlinux.org> 2.0.0-alt1
- new version
- rename package

* Tue Nov 14 2023 Sergey V Turchin <zerg@altlinux.org> 1.0-alt2
- package metadata

* Fri Mar 20 2020 Sergey V Turchin <zerg@altlinux.org> 1.0-alt1
- initial build
