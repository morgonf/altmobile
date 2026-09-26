# hexagonrpcd с apps_std_ftell

ADSP на SDM845 при чтении `adsp_avs_config.acdb` вызывает `apps_std_ftell`
(метод 8 интерфейса `apps_std`), а в hexagonrpcd 0.4.0 его нет: служба
печатает `Unsupported method: 8 (08010100)` и выходит, ADSP не загружает
динамические модули `mmecns_module.so.1` (ECNS v2) и
`fluence_voiceplus_module.so.1`. Поэтому в пакете служба rootpd на SDM845
выключена условием с пометкой FIXME.

Патч к тегу `v0.4.0` репозитория https://github.com/linux-msm/hexagonrpc.
Сборка прямо на телефоне, meson не нужен:

```
mkdir -p uapi/misc
cp /lib/modules/$(uname -r)/build/include/uapi/misc/fastrpc.h uapi/misc/
gcc-15 -O2 -Wall -Wno-unused-parameter -DHEXAGONRPC_VERBOSE \
    -Iinclude -Ihexagonrpcd -Iuapi -o hexagonrpcd-ftell \
    hexagonrpcd/*.c libhexagonrpc/context.c libhexagonrpc/fastrpc.c \
    libhexagonrpc/interfaces.c libhexagonrpc/session.c
```

Служба: `../../system/hexagonrpcd-adsp-audio.service`.
