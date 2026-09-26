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
- `q6voice`: `tx_topology`, `cal_restart_delay_ms` (перезапуск модулей
  калибровки после старта, без него ECNS v2 остаётся в обходе),
  `cal_after_start`, `cal_readback`, управление на ходу `live_set` и
  `live_get`, перебор `probe_topologies` по каналам, раскладке и опоре.

Рабочие значения параметров в `../../system/q6voice-echo.conf`, калибровка
`../cal-v2-final.bin`.
