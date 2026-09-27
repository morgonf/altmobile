#!/bin/sh
# Включение стандартных NMEA (GGA, RMC, GSV, GSA, VTG) в службе LOC модема.
# По умолчанию в модеме OnePlus 6T включены только собственные строки
# Qualcomm ($PQWP*, $PQWM1), координат из них ModemManager и geoclue не
# берут. Повторяем до минуты, пока модем не поднимется после загрузки.
for i in $(seq 1 12); do
	if qmicli -p -d qrtr://0 --loc-set-nmea-types="gga|rmc|gsv|gsa|vtg" 2>/dev/null; then
		qmicli -p -d qrtr://0 --loc-get-nmea-types | logger -t alt-gps-nmea
		exit 0
	fi
	sleep 5
done
logger -t alt-gps-nmea "не удалось включить NMEA"
exit 1
