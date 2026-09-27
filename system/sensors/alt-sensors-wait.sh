#!/bin/sh
# Ждать, пока процессор датчиков (SLPI) через hexagonrpcd реально отдаёт
# акселерометр. hexagonrpcd стартует на ~12-й секунде, данные датчиков идут
# с ~30-й. Если iio-sensor-proxy и KWin стартуют раньше, KWin читает
# ориентацию "undefined" и автоповорот не работает до перезапуска сеанса.
for i in $(seq 1 30); do
	if timeout 5 ssccli --sensor accelerometer --timeout 3 2>/dev/null | grep -q "measurement"; then
		logger -t alt-sensors-wait "акселерометр готов через $((i*2)) с"
		exit 0
	fi
	sleep 2
done
logger -t alt-sensors-wait "акселерометр не ответил за 60 с, продолжаем без него"
exit 0
