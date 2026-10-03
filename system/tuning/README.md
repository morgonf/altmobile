# Настройка системы под OnePlus 6T

Пункты 2.2 и 2.4 `docs/phosh-exit-and-tuning.md`. Установка `install.sh`
от root, применяется сразу, без перезагрузки.

- **zram.** `zram-generator` из Sisyphus, `/etc/systemd/zram-generator.conf`:
  половина ОЗУ (3,7 ГБ), lz4, приоритет 100; `vm.swappiness = 100`. До этого
  подкачки не было совсем. zram и все его алгоритмы встроены в ядро ALT.
- **Журнал.** `SystemMaxUse=100M` (было 622 МБ к 03.10.2026).
- **Waydroid.** `waydroid-container.service` выключен из автозапуска:
  Waydroid не настроен (пункт 23 бэклога), служба стартовала впустую.
  Пакет не удалён.

Включено 04.10.2026.
