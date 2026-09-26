# Рабочие исходники голосового тракта с эхоподавлением

Полные исходники пяти модулей в том виде, в каком они стоят на телефоне с
26 сентября 2026 и дают звонки без эха. Собираются вне дерева ядра, как
описано в `../oot/README.md`, только брать надо эти файлы, а не накладывать
патчи `0001`..`0005`. Сводный патч от исходников ALT до этого состояния лежит
в `../0006-cumulative-echo-cancellation.patch` (для `q6cvp.h` и `q6voice.h`
исходных копий нет, в патч они не попали, здесь они полные).

Что добавлено поверх `0001`..`0005`:

- `q6cvp`: параметры `media_rate`, `ds_mapping`, `ec_ref_info`, `ec_ref_rx`;
  блок `VSS_PARAM_VOCPROC_EC_REF_CHANNEL_INFO` и формат порта опоры
  `VSS_PARAM_EC_REF_PORT_ENDPOINT_MEDIA_INFO`; чтение параметров
  `q6cvp_get_param` (`VSS_ICOMMON_CMD_GET_PARAM_V2` с нулевым `mem_handle`).
- `q6voice`: `tx_topology`, `cal_poll_ms` с `ready_module`, `ready_param`,
  `ready_size` (опрос готовности модуля и повторная отправка калибровки;
  **в рабочей настройке выключен**, `cal_poll_ms=0`: запись параметров до
  ответа на звонок оставляет ECNS v2 в обходе, перезапуск делает служба
  `system/q6echo-activate.sh` после ответа),
  `cal_after_start`, `cal_readback`, управление на ходу `live_set` и
  `live_get`, перебор `probe_topologies` по каналам, раскладке и опоре.

Рабочие значения параметров в `../../system/q6voice-echo.conf`, калибровка
`../cal-v2-final.bin`.
