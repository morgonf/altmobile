# Интерфейс CVD для калибровки: что выяснено по исходникам

Всё ниже прочитано в исходниках заводского ядра, не по памяти. Источник:
техпак audio для msm-4.9 OnePlus 6/6T, репозиторий
`OnePlusOSS/android_kernel_oneplus_sdm845_techpack_audio`, ветка
`oneplus/SDM845_O_8.1`, файлы `include/dsp/q6voice.h` (2073 строки),
`dsp/q6voice.c` (9197 строк), `include/uapi/linux/msm_audio_calibration.h`,
`dsp/audio_cal_utils.c`. В самом дереве ядра этих файлов нет, звук вынесен в
отдельный техпак, поэтому путь `sound/soc/msm/qdsp6v2/q6voice.h` отдаёт 404.

## Отображение памяти

```
VSS_IMEMORY_CMD_MAP_PHYSICAL   0x00011334
VSS_IMEMORY_RSP_MAP            0x00011336
VSS_IMEMORY_CMD_UNMAP          0x00011337
```

Команда уходит на MVM. Дескриптор приходит первым словом тела ответа
`VSS_IMEMORY_RSP_MAP`, запросы различаются по токену команды.

Таблица отображения это шесть слов по 32 бита, лежащих в отдельном буфере,
и сама команда указывает на этот буфер:

```
слово 0, 1   адрес следующей таблицы, 64 бита, нули если её нет
слово 2      размер следующей таблицы, ноль если её нет
слово 3, 4   адрес блока памяти, 64 бита
слово 5      размер блока памяти
```

Поля команды, значения взяты из `voice_map_memory_physical_cmd`:

```
table_descriptor.mem_address_lsw/msw   адрес самой таблицы
table_descriptor.mem_size              24, то есть дескриптор плюс один блок
is_cached                              true
cache_line_size                        128
access_mask                            3, чтение и запись
page_align                             4096
min_data_width                         8
max_data_width                         64
```

Блоков в таблице один (`NUM_OF_MEMORY_BLOCKS` равен 1). Адрес блока и адрес
таблицы должны быть выровнены по наименьшему общему кратному размера строки
кэша, выравнивания страницы и максимальной ширины данных, а размер блока
кратен выравниванию страницы.

## Регистрация калибровки

```
VSS_IVOCPROC_CMD_REGISTER_DEVICE_CONFIG              0x00011371
VSS_IVOCPROC_CMD_DEREGISTER_DEVICE_CONFIG            0x00011372
VSS_IVOCPROC_CMD_REGISTER_CALIBRATION_DATA_V2        0x00011373
VSS_IVOCPROC_CMD_DEREGISTER_CALIBRATION_DATA         0x00011276
VSS_IVOCPROC_CMD_REGISTER_VOL_CALIBRATION_DATA       0x00011374
VSS_IVOCPROC_CMD_DEREGISTER_VOL_CALIBRATION_DATA     0x00011375
VSS_IVOCPROC_CMD_REGISTER_STATIC_CALIBRATION_DATA    0x00013079
VSS_IVOCPROC_CMD_DEREGISTER_STATIC_CALIBRATION_DATA  0x0001307A
VSS_IVOCPROC_CMD_REGISTER_DYNAMIC_CALIBRATION_DATA   0x0001307B
VSS_IVOCPROC_CMD_DEREGISTER_DYNAMIC_CALIBRATION_DATA 0x0001307C
```

Отдельных структур у static и dynamic нет, они переиспользуют структуры от V2
и VOL, различается только опкод. Выбор пары идёт по флагу
`is_per_vocoder_cal_enabled`, а тот выставляется по версии данных, пришедших
из пользовательского пространства.

Конфигурация устройства это четыре слова:

```
mem_handle, mem_address_lsw, mem_address_msw, mem_size
```

Статическая и динамическая калибровка добавляют к этим четырём словам
`column_info` фиксированного размера 324 байта.

## Порядок настройки vocproc

Из `voice_setup_vocproc`, строки 4198..4300:

```
CREATE_FULL_CONTROL_SESSION_V3 (в команде идут идентификаторы топологий)
channel info, затем media format для RX, TX и, если нужно, EC_REF
TOPOLOGY_COMMIT
MFC config, только если каналов приёма больше одного
регистрация калибровки потока на CVS
REGISTER_DEVICE_CONFIG
REGISTER_STATIC_CALIBRATION_DATA либо REGISTER_CALIBRATION_DATA_V2
REGISTER_DYNAMIC_CALIBRATION_DATA либо REGISTER_VOL_CALIBRATION_DATA
VSS_IVOCPROC_CMD_ENABLE
ATTACH_VOCPROC
```

Важное следствие. Регистрация калибровки идёт **после** `TOPOLOGY_COMMIT`.
Значит отказ `ADSP_EFAILED` на `TOPOLOGY_COMMIT` вылечить калибровкой нельзя,
к моменту отказа её ещё никто не отправлял. Причину отказа надо искать
отдельно, и это меняет порядок работ.

Ещё одна деталь. Возвращаемые значения всех четырёх регистраций заводской
драйвер не проверяет, отказ регистрации настройку не прерывает.

## Чего в исходниках ядра нет

Ядро **не формирует** содержимое блока калибровки и формата его не знает.
Оно передаёт процессору только дескриптор отображения, физический адрес,
размер и скопированный из пользовательского пространства `column_info`. Сам
буфер заполняет `libacdbloader` в пользовательском пространстве и передаёт
ядру через ioctl `/dev/msm_audio_cal`, а ядро импортирует его по
ION-дескриптору. Из ACDB ядро берёт только метаданные: идентификаторы
устройств TX и RX, частоты, набор признаков.

То есть путь через разделяемую память упирается в неизвестный формат таблицы,
и одних опкодов для него мало.

## Что такое `column_info` и как это связано с нашим разбором ACDB

Структура ключа столбцов, `msm_audio_calibration.h`:

```c
#define MAX_VOICE_COLUMNS	20

struct audio_cal_col {
	uint32_t id;
	uint32_t type;
	union audio_cal_col_na na_value;   /* 8, 16, 32 или 64 бита */
};

struct audio_cal_col_data {
	uint32_t num_columns;
	struct audio_cal_col column[MAX_VOICE_COLUMNS];
};
```

Это описание столбцов таблицы калибровки, которую отдают процессору. Сказано,
сколько столбцов, чем каждый является и какое значение считать неприменимым.
Процессор по этим столбцам сам выбирает строку под текущие условия звонка.

Здесь сходится наш разбор ACDB. Запись секции `VPSTCVD0` это ровно семь слов,
а `VPDYCVD0` восемь, и это и есть значения столбцов для строки таблицы:
идентификатор сети, частоты передачи и приёма, два неразобранных поля, тип
вокодера и ещё одно поле, а у динамической таблицы добавляется ступень
громкости. Отсюда и название секции, `CVD0` означает ключ со стороны Core Voice
Driver.

Заодно понятно, зачем в `VPSTOFST` набор из 75 вариантов на одну пару
устройств. Процессору отдают всю таблицу сразу, а выбор строки делает он.

Подтвердить связь `VPSTCVD0` с `column_info` по исходникам ядра нельзя. Имён
секций ACDB в ядре нет вообще, они живут в проприетарной библиотеке. Сходство
по числу и смыслу полей сильное, но это сопоставление, а не доказательство.

## Чего нет в mainline

В дереве `sc7280-mainline/linux`, ветка `sc7280-7.2.y`, каталог
`sound/soc/qcom/qdsp6`, поиск на `IMEMORY`, `CALIBRATION`, `cal_`,
`DEVICE_CONFIG`, `acdb` не даёт ни одного совпадения. Поддержки отображения
памяти и калибровки нет. В апстримном Linux файлов q6voice, q6cvp, q6cvs,
q6mvm нет вовсе.
