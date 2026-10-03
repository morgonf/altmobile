#!/bin/sh
set -e
D=$(dirname "$(readlink -f "$0")")
P=$(rpm --eval %_specdir); mkdir -p "$P"
cp "$D/iio-sensor-proxy.spec" "$P"/
exec rpmbuild -ba --define "_smp_mflags -j2" "$P"/iio-sensor-proxy.spec
