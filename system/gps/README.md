# GPS на OnePlus 6T

Приёмник GNSS в модеме, доступ через ModemManager (QMI LOC). Работает и без
SIM-карты. Проверено 27.09.2026 у окна: 10 спутников видно, 4 в решении,
HDOP 2.7, первое решение за пару минут.

Что мешало и что сделано:

- В службе LOC модема включены только собственные строки Qualcomm
  (`$PQWP1`..`$PQWP6`, `$PQWM1`), стандартных NMEA нет
  (`qmicli --loc-get-nmea-types`: none), и координат нет ни у
  ModemManager, ни у geoclue. Служба `alt-gps-nmea` при загрузке включает
  GGA, RMC, GSV, GSA, VTG.
- geoclue (источник `modem-gps` включён в `/etc/geoclue/geoclue.conf`)
  ждал агента, который разрешает программам доступ, и не отвечал им
  (`NoReply`). В KDE агента для geoclue нет; поставлен `geoclue2-demo`,
  его агент стартует автозапуском. После этого `where-am-i` получает
  координаты с пометкой «GPS GGA+RMC».
- AGPS (`agps-msb`, сервер `supl.google.com:7275`) модем не включает:
  «Failed to receive operation mode indication». Работает автономный
  режим, холодный старт дольше. В бэклоге.

Установка: `install.sh` от root.
