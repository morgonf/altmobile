#!/bin/sh
# Чтение стандартных команд bq27411 (слова, младший байт первым). Только чтение.
O=/tmp/.private/altlinux/gauge.txt
: > $O
for r in 0x04:Voltage_mV 0x06:Flags 0x08:NAC_mAh 0x0A:FAC_mAh 0x0C:RM_mAh 0x0E:FCC_mAh 0x10:AvgI_mA 0x1C:SOC_pct 0x28:RM_unfilt 0x2A:RM_filt 0x2C:FCC_unfilt 0x2E:FCC_filt 0x30:SOC_unfilt 0x3C:DesignCap; do
  a=${r%%:*}; n=${r#*:}
  v=$(/usr/sbin/i2cget -f -y 10 0x55 $a w 2>&1)
  echo "$n $a $v $(( v )) " >> $O
done
chown altlinux $O
