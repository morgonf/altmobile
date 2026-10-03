# ALT Mobile, OnePlus 6T: out-of-tree modules for the ALT sdm845 kernel
%define kflavour qualcomm-sdm845
%define kver 7.1.0
%define krel alt0.rc1
%define kname %kver-%kflavour-%krel

Name: kernel-modules-altmobile-%kflavour
Version: 1.0
Release: alt1.mobile1
Summary: OnePlus 6T camera focus, camera sensor and NFC modules
License: GPL-2.0-only
Group: System/Kernel and hardware
Url: https://github.com/morgonf/altmobile

# sa3103 (own driver), imx371.c and imx376.c from sdm845-mainline
# 85f1df2a4ec71d7a91dd95a7a49f889d1595ffa8, net/nfc/nci and drivers/nfc/nxp-nci
# from Linux v7.0 (the same as in the %kname kernel)
Source: altmobile-kmodules-%version.tar
Patch1: imx37x-alt-mobile.patch
Patch2: nci-skip-classic-t2t.patch
Patch3: nxp-nci-remove-deadlock.patch

ExclusiveArch: aarch64
BuildRequires: kernel-headers-modules-%kflavour = %kver-%krel
BuildRequires: gcc make git-core
Requires: kernel-image-%kflavour = %kver-%krel
Requires(post,postun): kmod

%description
Kernel modules for ALT Mobile on the OnePlus 6T (sdm845), built for the
%kname kernel and installed to /lib/modules/%kname/updates:
- sa3103: SA3103 lens focus motors (the device tree says LC898217XC);
- imx371, imx376: front and secondary rear camera sensors with binned and
  full size modes, Quad Bayer full size for the IMX371, gain up to 16x;
- nci, nxp-nci, nxp-nci_i2c: NFC without the nxp-nci unbind deadlock and
  without MIFARE Classic reads that hung the PN553.

%prep
%setup -n altmobile-kmodules-%version
(cd imx37x && git apply -p1 %PATCH1)
(cd nfc/nci && git apply -p4 %PATCH2)
cd nfc/nxp-nci
# The ALT kernel patch changes only this line of firmware.c
sed -i 's/\tstrcpy(fw_info->name, firmware_name);/\tstrscpy(fw_info->name, firmware_name);/' firmware.c
git apply -p4 %PATCH3

%build
K=/lib/modules/%kname/build
for d in sa3103 imx37x nfc/nci nfc/nxp-nci; do
	%make_build -C $K M=$PWD/$d modules
done

%install
D=%buildroot/lib/modules/%kname/updates
mkdir -p $D
install -m 644 sa3103/*.ko imx37x/*.ko nfc/nci/*.ko nfc/nxp-nci/*.ko $D/

%post
depmod -a %kname

%postun
depmod -a %kname

%files
/lib/modules/%kname/updates/*.ko

%changelog
* Sun Oct 04 2026 morgonf <morgonf@altlinux.org> 1.0-alt1.mobile1
- sa3103, imx371, imx376, nci, nxp-nci as a package instead of files
  copied by hand to updates/
