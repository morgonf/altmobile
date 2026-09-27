#!/bin/sh
# Отметка успешной загрузки слота A/B, от root. Без неё заводской загрузчик
# OnePlus 6T после семи перезагрузок помечает слот незагружаемым и остаётся
# в fastboot (снималось `fastboot --set-active=a`). Пакет qbootctl из Sisyphus
# приносит службу qbootctl-mark-successful.service (`qbootctl -m` при каждой
# загрузке). Предупреждение «Couldn't find cmdline arg: slot_suffix» не
# мешает: U-Boot не передаёт androidboot.slot_suffix, qbootctl берёт
# активный слот. Включено 27.09.2026, слот _a стал Successful: 1.
apt-get install -y qbootctl
systemctl enable --now qbootctl-mark-successful.service
qbootctl
