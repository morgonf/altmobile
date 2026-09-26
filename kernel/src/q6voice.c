// SPDX-License-Identifier: GPL-2.0
// Copyright (c) 2012-2017, The Linux Foundation. All rights reserved.
// Copyright (c) 2020, Stephan Gerhold

#include <linux/device.h>
#include <linux/firmware.h>
#include <linux/hex.h>
#include <linux/limits.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/string.h>
#include <linux/workqueue.h>
#include "q6afe.h"
#include "q6cvp.h"
#include "q6cvs.h"
#include "q6mvm.h"
#include "q6voice-common.h"

#define VSS_IVOCPROC_TOPOLOGY_ID_TX_SM_ECNS		0x00010F71
#define VSS_IVOCPROC_TOPOLOGY_ID_RX_DEFAULT		0x00010F77

/*
 * Voice processing calibration, experimental.
 *
 * Topologies other than the defaults need calibration parameters that only
 * exist in the proprietary ACDB files of the device. The factory software
 * hands the whole calibration table to the DSP in shared memory, in a format
 * produced by a closed userspace library. Here the parameters are extracted
 * from the ACDB files beforehand (see tools/acdb.py in the research repo) and
 * sent one by one in-band, which needs neither shared memory nor knowledge of
 * that table format.
 *
 * Off unless a firmware file name is given, since the parameters are specific
 * to one device pair and one set of sample rates.
 */
static char *cal_firmware;
module_param(cal_firmware, charp, 0644);
MODULE_PARM_DESC(cal_firmware,
		 "File with voice processing parameters to send after topology commit");

/*
 * Map a page of memory to the DSP when a call starts, log the handle and
 * unmap it again. Checks the VSS_IMEMORY path on its own, since there is
 * nothing to carry in that memory yet: the layout of the calibration table
 * the DSP expects there is produced by a closed userspace library and is not
 * known.
 */
static bool mem_map_test;
module_param(mem_map_test, bool, 0644);
MODULE_PARM_DESC(mem_map_test,
		 "Map and unmap DSP shared memory when a call starts, to test the IMEMORY path");

/*
 * Пройти набор сочетаний топологии передачи и идентификатора сети за один
 * звонок и записать в журнал, какие из них процессор принимает. Каждое
 * сочетание это отдельная сессия vocproc, которая создаётся, получает формат,
 * пробует TOPOLOGY_COMMIT и уничтожается. Иначе на каждую догадку уходит
 * отдельный звонок.
 */
/*
 * Отправить калибровку ещё раз после q6mvm_start. Заводской драйвер не шлёт
 * параметры по одному, а регистрирует таблицу калибровки, и процессор сам
 * применяет её при каждой перенастройке vocproc, в том числе при запуске
 * сессии под частоту вокодера. Параметры, отправленные нами до запуска, при
 * такой перенастройке могут теряться.
 */
static bool cal_after_start;
module_param(cal_after_start, bool, 0644);
MODULE_PARM_DESC(cal_after_start,
		 "Send the calibration again after the voice session has started");

/*
 * После запуска сессии прочитать из процессора каждый параметр калибровки и
 * сравнить с отправленным. Статус 0 на SET_PARAM значит лишь, что команда
 * принята, а не что модуль работает с этими значениями.
 */
/*
 * Через столько миллисекунд после запуска сессии выключить модули, которые
 * включает калибровка, и отправить калибровку заново. Модуль ECNS v2
 * (0x10f1f) принимает включение до получения формата звука, откладывает его
 * и остаётся в обходе; по-настоящему он включается только повторным
 * выключением и включением в идущем разговоре. 0 выключает этот шаг.
 */
static unsigned int cal_restart_delay_ms = 1000;
module_param(cal_restart_delay_ms, uint, 0644);
MODULE_PARM_DESC(cal_restart_delay_ms,
		 "Delay after start to disable calibrated modules and resend the calibration, 0 to skip");

/* Топология передачи по умолчанию, пока её не сменят элементом микшера */
static unsigned int tx_topology = 0x00010F71;
module_param(tx_topology, uint, 0444);
MODULE_PARM_DESC(tx_topology, "Default TX topology of the voice paths");

static bool cal_readback;
module_param(cal_readback, bool, 0644);
MODULE_PARM_DESC(cal_readback,
		 "Read calibration parameters back from the DSP after start and compare");

static bool probe_topologies;
module_param(probe_topologies, bool, 0644);
MODULE_PARM_DESC(probe_topologies,
		 "Try a set of TX topology and network id combinations at call start and log which ones commit");

static const u32 probe_topo_list[] = {
	0x00010F71,	/* TX_SM_ECNS, это работает, нужен для сверки */
	0x00010F89,	/* TX_SM_ECNS_V2, под него калибровано устройство 4 */
	0x00010F72,	/* TX_DM_FLUENCE, устройство 6 */
};

/*
 * Частота формата порта на отказ не влияет, это проверено перебором 8000,
 * 16000, 32000 и 48000 на звонке 26 сентября 2026. Теперь перебираются число
 * каналов передачи, раскладка каналов и блок каналов опоры эхоподавителя,
 * в которых наш драйвер расходится с заводским.
 */
static const u32 probe_channels_list[] = { 1, 2 };

#define Q6VOICE_CAL_MAGIC	"Q6VCAL01"
#define Q6VOICE_CAL_VERSION	1

struct q6voice_cal_header {
	u8 magic[8];
	__le32 version;
	__le32 tx_device;
	__le32 rx_device;
	__le32 tx_rate;
	__le32 rx_rate;
	__le32 count;
	__le32 data_size;
} __packed;

struct q6voice_cal_param {
	__le32 module_id;
	__le32 param_id;
	__le32 size;
	u8 data[];
} __packed;

enum q6voice_cal_mode {
	Q6VOICE_CAL_SEND,
	Q6VOICE_CAL_CHECK,
	/* Выключить модули, которые калибровка включает (0x10e00 не ноль) */
	Q6VOICE_CAL_DISABLE,
};

#define Q6VOICE_PARAM_MODULE_ENABLE	0x00010E00

static int q6voice_send_cal_mode(struct q6voice_session *cvp,
				 enum q6voice_cal_mode mode)
{
	bool check = mode == Q6VOICE_CAL_CHECK;
	struct device *dev = cvp->dev;
	const struct q6voice_cal_header *hdr;
	const struct firmware *fw;
	unsigned int i, count, sent = 0;
	size_t pos;
	int ret;

	if (!cal_firmware || !*cal_firmware)
		return 0;

	ret = request_firmware(&fw, cal_firmware, dev);
	if (ret) {
		dev_err(dev, "failed to load calibration '%s': %d\n",
			cal_firmware, ret);
		return ret;
	}

	if (fw->size < sizeof(*hdr)) {
		dev_err(dev, "calibration '%s' is truncated\n", cal_firmware);
		ret = -EINVAL;
		goto out;
	}

	hdr = (const struct q6voice_cal_header *)fw->data;
	if (memcmp(hdr->magic, Q6VOICE_CAL_MAGIC, sizeof(hdr->magic)) ||
	    le32_to_cpu(hdr->version) != Q6VOICE_CAL_VERSION) {
		dev_err(dev, "calibration '%s' is not in a known format\n",
			cal_firmware);
		ret = -EINVAL;
		goto out;
	}

	count = le32_to_cpu(hdr->count);
	dev_info(dev, "calibration '%s': devices %u/%u, %u parameters\n",
		 cal_firmware, le32_to_cpu(hdr->tx_device),
		 le32_to_cpu(hdr->rx_device), count);

	pos = sizeof(*hdr);
	for (i = 0; i < count; i++) {
		const struct q6voice_cal_param *p;
		u32 module_id, param_id, size;

		if (pos + sizeof(*p) > fw->size) {
			dev_err(dev, "calibration ends after %u parameters\n", i);
			ret = -EINVAL;
			goto out;
		}

		p = (const struct q6voice_cal_param *)(fw->data + pos);
		module_id = le32_to_cpu(p->module_id);
		param_id = le32_to_cpu(p->param_id);
		size = le32_to_cpu(p->size);

		if (size > U16_MAX ||
		    pos + sizeof(*p) + ALIGN(size, 4) > fw->size) {
			dev_err(dev, "parameter %u has bad size %u\n", i, size);
			ret = -EINVAL;
			goto out;
		}

		if (mode == Q6VOICE_CAL_DISABLE) {
			static const u32 off;

			if (param_id == Q6VOICE_PARAM_MODULE_ENABLE && size == 4 &&
			    memcmp(p->data, &off, 4)) {
				ret = q6cvp_send_param(cvp, module_id, param_id,
						       &off, 4);
				dev_info(dev, "module %#x disabled for restart: %d\n",
					 module_id, ret);
				if (!ret)
					sent++;
			}
		} else if (check) {
			u8 *buf = kzalloc(size, GFP_KERNEL);

			if (!buf) {
				ret = -ENOMEM;
				goto out;
			}
			ret = q6cvp_get_param(cvp, module_id, param_id, buf, size);
			if (ret < 0) {
				dev_info(dev, "readback %#x/%#x: failed %d\n",
					 module_id, param_id, ret);
			} else {
				bool same = ret == size &&
					    !memcmp(buf, p->data, size);

				dev_info(dev, "readback %#x/%#x: %d bytes, %s: %*ph\n",
					 module_id, param_id, ret,
					 same ? "same" : "DIFFERS",
					 min_t(int, ret, 16), buf);
				if (!same)
					dev_info(dev, "  sent %u bytes: %*ph\n",
						 size, min_t(int, size, 16),
						 p->data);
				else
					sent++;
			}
			kfree(buf);
		} else {
			ret = q6cvp_send_param(cvp, module_id, param_id,
					       p->data, size);
			if (ret)
				dev_warn(dev,
					 "module %#x parameter %#x (%u bytes) rejected: %d\n",
					 module_id, param_id, size, ret);
			else
				sent++;
		}

		pos += sizeof(*p) + ALIGN(size, 4);
	}

	if (mode == Q6VOICE_CAL_DISABLE)
		ret = 0;
	else if (check)
		dev_info(dev, "readback: %u of %u parameters match\n", sent, count);
	else
		dev_info(dev, "calibration: %u of %u parameters accepted\n",
			 sent, count);
	ret = sent ? 0 : -EIO;

out:
	release_firmware(fw);
	return ret;
}

static int q6voice_send_cal(struct q6voice_session *cvp)
{
	return q6voice_send_cal_mode(cvp, Q6VOICE_CAL_SEND);
}

struct q6voice_path_runtime {
	struct q6voice_session *sessions[Q6VOICE_SERVICE_COUNT];
	unsigned int started;
};

struct q6voice_path {
	struct q6voice *v;

	enum q6voice_path_type type;
	int tx_port, rx_port;
	u32 tx_topo, rx_topo;
	/* Serialize access to voice path session */
	struct mutex lock;
	struct q6voice_path_runtime *runtime;
	struct delayed_work cal_restart;
};

struct q6voice {
	struct device *dev;
	bool cvd_v2_3;
	struct q6voice_path paths[Q6VOICE_PATH_COUNT];
};

static inline struct q6voice_session *session_create(enum q6voice_path_type type,
						     int tx_port, int rx_port,
						     u32 tx_topo, u32 rx_topo)
{
	return q6cvp_session_create(type, tx_port, rx_port, tx_topo, rx_topo);
}

static struct q6voice_session *session_create_v3(enum q6voice_path_type type,
						 int tx_port, int rx_port,
						 u32 tx_topo, u32 rx_topo)
{
	struct q6voice_session *cvp;

	cvp = q6cvp_session_create_v3(type, tx_port, rx_port, tx_topo, rx_topo);
	if (cvp == NULL)
		return NULL;

	q6cvp_send_channel_info(cvp, false);
	q6cvp_send_channel_info(cvp, true);
	q6cvp_send_ec_ref_channel_info(cvp);

	q6cvp_send_media_format(cvp, rx_port, false);
	q6cvp_send_media_format(cvp, tx_port, true);
	if (q6cvp_send_ec_ref_media_format(cvp, rx_port))
		dev_warn(cvp->dev, "EC reference media format refused\n");

	q6cvp_topology_commit(cvp);

	q6voice_send_cal(cvp);

	return cvp;
}

static void q6voice_probe_topologies(struct q6voice_path *p, int tx_port,
				     int rx_port)
{
	struct device *dev = p->v->dev;
	unsigned int i, j, k;
	unsigned int good = 0;

	dev_info(dev, "probe: trying %zu topologies against %zu channel counts, 2 mappings, with and without EC reference info\n",
		 ARRAY_SIZE(probe_topo_list), ARRAY_SIZE(probe_channels_list));

	for (i = 0; i < ARRAY_SIZE(probe_topo_list); i++) {
		for (j = 0; j < ARRAY_SIZE(probe_channels_list); j++) {
			for (k = 0; k < 4; k++) {
				struct q6voice_session *cvp;
				u32 topo = probe_topo_list[i];
				u32 ch = probe_channels_list[j];
				bool ds_map = k & 1;
				bool ec_ref = k & 2;
				int ret;

				q6cvp_set_layout(ch, ds_map, ec_ref);

				cvp = q6cvp_session_create_v3(p->type, tx_port,
							      rx_port, topo,
							      p->rx_topo);
				if (IS_ERR(cvp)) {
					dev_info(dev, "probe: topology %#x channels %u mapping %s ec_ref %d: session not created, %ld\n",
						 topo, ch, ds_map ? "ds" : "old",
						 ec_ref, PTR_ERR(cvp));
					continue;
				}

				q6cvp_send_channel_info(cvp, false);
				q6cvp_send_channel_info(cvp, true);
				ret = q6cvp_send_ec_ref_channel_info(cvp);
				if (ret)
					dev_info(dev, "probe: EC reference info refused, %d\n",
						 ret);
				q6cvp_send_media_format(cvp, rx_port, false);
				q6cvp_send_media_format(cvp, tx_port, true);

				ret = q6cvp_topology_commit(cvp);
				if (ret) {
					dev_info(dev, "probe: topology %#x channels %u mapping %s ec_ref %d: commit failed, %d\n",
						 topo, ch, ds_map ? "ds" : "old",
						 ec_ref, ret);
				} else {
					dev_info(dev, "probe: topology %#x channels %u mapping %s ec_ref %d: COMMIT OK\n",
						 topo, ch, ds_map ? "ds" : "old",
						 ec_ref);
					good++;
				}

				q6voice_session_release(cvp);
			}
		}
	}

	dev_info(dev, "probe: %u combinations committed\n", good);
}

static int q6voice_path_start(struct q6voice_path *p)
{
	struct device *dev = p->v->dev;
	struct q6voice_session *mvm, *cvp;
	int ret;

	dev_info(dev, "start path %d: tx topology %#x on port %d, rx topology %#x on port %d\n",
		 p->type, p->tx_topo, p->tx_port, p->rx_topo, p->rx_port);

	mvm = p->runtime->sessions[Q6VOICE_SERVICE_MVM];
	if (!mvm) {
		mvm = q6mvm_session_create(p->type);
		if (IS_ERR(mvm))
			return PTR_ERR(mvm);
		p->runtime->sessions[Q6VOICE_SERVICE_MVM] = mvm;
	}

	if (mem_map_test) {
		struct q6voice_mem mem = {0};

		if (q6mvm_mem_map(mvm, &mem, PAGE_SIZE) == 0) {
			dev_info(dev, "memory map test: handle %#x for %zu bytes at %pad\n",
				 mem.handle, mem.size, &mem.data_phys);
			q6mvm_mem_unmap(mvm, &mem);
		}
	}

	if (probe_topologies) {
		q6voice_probe_topologies(p, q6afe_get_port_id(p->tx_port),
					 q6afe_get_port_id(p->rx_port));
		/* вернуть настройки, которые выставил пользователь */
		q6cvp_set_profile_id(0x0001135E);
		q6cvp_set_media_rate(48000);
		q6cvp_set_layout(1, false, false);
	}

	cvp = p->runtime->sessions[Q6VOICE_SERVICE_CVP];
	if (!cvp) {
		if (p->v->cvd_v2_3)
			cvp = session_create_v3(p->type,
						q6afe_get_port_id(p->tx_port),
						q6afe_get_port_id(p->rx_port),
						p->tx_topo, p->rx_topo);
		else
			cvp = session_create(p->type,
					     q6afe_get_port_id(p->tx_port),
					     q6afe_get_port_id(p->rx_port),
					     p->tx_topo, p->rx_topo);

		if (IS_ERR(cvp))
			return PTR_ERR(cvp);
		p->runtime->sessions[Q6VOICE_SERVICE_CVP] = cvp;
	}

	ret = q6cvp_enable(cvp, true);
	if (ret) {
		dev_err(dev, "failed to enable cvp: %d\n", ret);
		goto cvp_err;
	}

	ret = q6mvm_attach(mvm, cvp, true);
	if (ret) {
		dev_err(dev, "failed to attach cvp to mvm: %d\n", ret);
		goto attach_err;
	}

	ret = q6mvm_start(mvm, true);
	if (ret) {
		dev_err(dev, "failed to start voice: %d\n", ret);
		goto start_err;
	}

	if (cal_after_start) {
		dev_info(dev, "sending calibration again after start\n");
		q6voice_send_cal(cvp);
	}

	if (cal_readback)
		q6voice_send_cal_mode(cvp, Q6VOICE_CAL_CHECK);

	if (cal_restart_delay_ms)
		schedule_delayed_work(&p->cal_restart,
				      msecs_to_jiffies(cal_restart_delay_ms));

	return ret;

start_err:
	q6mvm_start(mvm, false);
attach_err:
	q6mvm_attach(mvm, cvp, false);
cvp_err:
	q6cvp_enable(cvp, false);
	return ret;
}

int q6voice_start(struct q6voice *v, enum q6voice_path_type path, bool capture)
{
	struct q6voice_path *p = &v->paths[path];
	int ret = 0;

	mutex_lock(&p->lock);
	if (!p->runtime) {
		p->runtime = kzalloc_obj(*p->runtime, GFP_KERNEL);
		if (!p->runtime) {
			ret = -ENOMEM;
			goto out;
		}
	}

	if (p->runtime->started & BIT(capture)) {
		ret = -EALREADY;
		goto out;
	}

	p->runtime->started |= BIT(capture);

	/* FIXME: For now we only start if both RX/TX are active */
	if (p->runtime->started != 3)
		goto out;

	ret = q6voice_path_start(p);
	if (ret) {
		p->runtime->started &= ~BIT(capture);
		dev_err(v->dev, "failed to start path %d: %d\n", path, ret);
		goto out;
	}

out:
	mutex_unlock(&p->lock);
	return ret;
}
EXPORT_SYMBOL_GPL(q6voice_start);

static void q6voice_path_stop(struct q6voice_path *p)
{
	struct device *dev = p->v->dev;
	struct q6voice_session *mvm = p->runtime->sessions[Q6VOICE_SERVICE_MVM];
	struct q6voice_session *cvp = p->runtime->sessions[Q6VOICE_SERVICE_CVP];
	int ret;

	dev_dbg(dev, "stop path %d\n", p->type);

	ret = q6mvm_start(mvm, false);
	if (ret)
		dev_err(dev, "failed to stop voice: %d\n", ret);

	ret = q6mvm_attach(mvm, cvp, false);
	if (ret)
		dev_err(dev, "failed to detach cvp from mvm: %d\n", ret);

	ret = q6cvp_enable(cvp, false);
	if (ret)
		dev_err(dev, "failed to disable cvp: %d\n", ret);
}

static void q6voice_path_destroy(struct q6voice_path *p)
{
	struct q6voice_path_runtime *runtime = p->runtime;
	enum q6voice_service_type svc;

	for (svc = 0; svc < Q6VOICE_SERVICE_COUNT; ++svc) {
		if (runtime->sessions[svc])
			q6voice_session_release(runtime->sessions[svc]);
	}

	p->runtime = NULL;
	kfree(runtime);
}

int q6voice_stop(struct q6voice *v, enum q6voice_path_type path, bool capture)
{
	struct q6voice_path *p = &v->paths[path];
	int ret = 0;

	mutex_lock(&p->lock);
	if (!p->runtime || !(p->runtime->started & BIT(capture)))
		goto out;

	if (p->runtime->started == 3)
		q6voice_path_stop(p);

	p->runtime->started &= ~BIT(capture);

	if (p->runtime->started == 0)
		q6voice_path_destroy(p);

out:
	mutex_unlock(&p->lock);
	return ret;
}
EXPORT_SYMBOL_GPL(q6voice_stop);

static void q6voice_cal_restart_work(struct work_struct *work)
{
	struct q6voice_path *p = container_of(to_delayed_work(work),
					      struct q6voice_path, cal_restart);
	struct q6voice_session *cvp;

	mutex_lock(&p->lock);
	/* Разговор мог закончиться, пока ждали */
	if (!p->runtime || !p->runtime->sessions[Q6VOICE_SERVICE_CVP])
		goto out;

	cvp = p->runtime->sessions[Q6VOICE_SERVICE_CVP];
	dev_info(p->v->dev, "restarting calibrated modules\n");
	q6voice_send_cal_mode(cvp, Q6VOICE_CAL_DISABLE);
	q6voice_send_cal(cvp);
out:
	mutex_unlock(&p->lock);
}

/* Экземпляр для управления на ходу через параметры live_set и live_get */
static struct q6voice *q6voice_live;

/* Найти путь с живой сессией vocproc. Возвращается с захваченным p->lock. */
static struct q6voice_session *q6voice_live_cvp(struct q6voice_path **pp)
{
	struct q6voice *v = q6voice_live;
	enum q6voice_path_type path;

	if (!v)
		return NULL;

	for (path = 0; path < Q6VOICE_PATH_COUNT; ++path) {
		struct q6voice_path *p = &v->paths[path];

		mutex_lock(&p->lock);
		if (p->runtime && p->runtime->sessions[Q6VOICE_SERVICE_CVP]) {
			*pp = p;
			return p->runtime->sessions[Q6VOICE_SERVICE_CVP];
		}
		mutex_unlock(&p->lock);
	}

	return NULL;
}

/*
 * Запись "модуль параметр значение" отправляет параметр в идущий разговор.
 * Значение это либо одно число (слово u32), либо hex:ааббвв... Числа
 * модуля и параметра шестнадцатеричные. Пример:
 *   echo "10f1f 10e00 0" > /sys/module/q6voice/parameters/live_set
 */
static int q6voice_live_set(const char *val, const struct kernel_param *kp)
{
	struct q6voice_session *cvp;
	struct q6voice_path *p;
	char value[520];
	u8 *data;
	u32 module_id, param_id, word;
	int size, ret;

	if (sscanf(val, "%x %x %519s", &module_id, &param_id, value) != 3)
		return -EINVAL;

	if (!strncmp(value, "hex:", 4)) {
		size = strlen(value + 4) / 2;
		if (!size || size > 256)
			return -EINVAL;
		data = kzalloc(size, GFP_KERNEL);
		if (!data)
			return -ENOMEM;
		if (hex2bin(data, value + 4, size)) {
			kfree(data);
			return -EINVAL;
		}
	} else {
		if (kstrtou32(value, 0, &word))
			return -EINVAL;
		size = sizeof(word);
		data = kmemdup(&word, size, GFP_KERNEL);
		if (!data)
			return -ENOMEM;
	}

	cvp = q6voice_live_cvp(&p);
	if (!cvp) {
		kfree(data);
		return -ENODEV;
	}

	ret = q6cvp_send_param(cvp, module_id, param_id, data, size);
	dev_info(p->v->dev, "live set %#x/%#x (%d bytes): %d\n",
		 module_id, param_id, size, ret);
	mutex_unlock(&p->lock);
	kfree(data);

	return ret;
}

/*
 * Запись "модуль параметр размер" читает параметр из идущего разговора и
 * пишет его в журнал ядра целиком.
 */
static int q6voice_live_get(const char *val, const struct kernel_param *kp)
{
	struct q6voice_session *cvp;
	struct q6voice_path *p;
	u32 module_id, param_id, size;
	u8 *data;
	int ret, i;

	if (sscanf(val, "%x %x %u", &module_id, &param_id, &size) != 3 ||
	    !size || size > 1024)
		return -EINVAL;

	data = kzalloc(size, GFP_KERNEL);
	if (!data)
		return -ENOMEM;

	cvp = q6voice_live_cvp(&p);
	if (!cvp) {
		kfree(data);
		return -ENODEV;
	}

	ret = q6cvp_get_param(cvp, module_id, param_id, data, size);
	dev_info(p->v->dev, "live get %#x/%#x: %d\n", module_id, param_id, ret);
	for (i = 0; ret > 0 && i < min_t(int, ret, size); i += 32)
		dev_info(p->v->dev, "  %04x: %*ph\n", i,
			 min_t(int, 32, min_t(int, ret, size) - i), data + i);
	mutex_unlock(&p->lock);
	kfree(data);

	return ret < 0 ? ret : 0;
}

static const struct kernel_param_ops q6voice_live_set_ops = {
	.set = q6voice_live_set,
};

static const struct kernel_param_ops q6voice_live_get_ops = {
	.set = q6voice_live_get,
};

module_param_cb(live_set, &q6voice_live_set_ops, NULL, 0200);
MODULE_PARM_DESC(live_set, "Send \"module param value\" to the running vocproc");
module_param_cb(live_get, &q6voice_live_get_ops, NULL, 0200);
MODULE_PARM_DESC(live_get, "Read \"module param size\" from the running vocproc into the log");

static void q6voice_free(void *data)
{
	struct q6voice *v = data;
	enum q6voice_path_type path;

	if (q6voice_live == v)
		q6voice_live = NULL;

	for (path = 0; path < Q6VOICE_PATH_COUNT; ++path)
		cancel_delayed_work_sync(&v->paths[path].cal_restart);

	for (path = 0; path < Q6VOICE_PATH_COUNT; ++path) {
		struct q6voice_path *p = &v->paths[path];

		mutex_lock(&p->lock);
		if (p->runtime) {
			dev_warn(v->dev,
				 "q6voice_remove() called while path %d is active\n",
				 path);

			if (p->runtime->started == 3)
				q6voice_path_stop(p);
			q6voice_path_destroy(p);
		}
		mutex_unlock(&p->lock);
		mutex_destroy(&p->lock);
	}
}

struct q6voice *q6voice_create(struct device *dev, bool cvd_v2_3)
{
	struct q6voice *v;
	enum q6voice_path_type path;
	int ret;

	v = devm_kzalloc(dev, sizeof(*v), GFP_KERNEL);
	if (!v)
		return ERR_PTR(-ENOMEM);

	v->dev = dev;
	v->cvd_v2_3 = cvd_v2_3;

	for (path = 0; path < Q6VOICE_PATH_COUNT; ++path) {
		struct q6voice_path *p = &v->paths[path];

		p->v = v;
		p->type = path;
		p->tx_topo = tx_topology;
		p->rx_topo = VSS_IVOCPROC_TOPOLOGY_ID_RX_DEFAULT;
		mutex_init(&p->lock);
		INIT_DELAYED_WORK(&p->cal_restart, q6voice_cal_restart_work);
	}

	q6voice_live = v;

	ret = devm_add_action(dev, q6voice_free, v);
	if (ret)
		return ERR_PTR(ret);

	return v;
}
EXPORT_SYMBOL_GPL(q6voice_create);

int q6voice_get_port(struct q6voice *v, enum q6voice_path_type path,
		     bool capture)
{
	struct q6voice_path *p = &v->paths[path];

	if (capture)
		return p->tx_port;
	else
		return p->rx_port;
}
EXPORT_SYMBOL_GPL(q6voice_get_port);

void q6voice_set_port(struct q6voice *v, enum q6voice_path_type path,
		      bool capture, int index)
{
	struct q6voice_path *p = &v->paths[path];

	if (capture)
		p->tx_port = index;
	else
		p->rx_port = index;
}
EXPORT_SYMBOL_GPL(q6voice_set_port);

u32 q6voice_get_topology(struct q6voice *v, enum q6voice_path_type path,
			 bool capture)
{
	struct q6voice_path *p = &v->paths[path];

	if (capture)
		return p->tx_topo;
	else
		return p->rx_topo;
}
EXPORT_SYMBOL_GPL(q6voice_get_topology);

void q6voice_set_topology(struct q6voice *v, enum q6voice_path_type path,
			  bool capture, u32 topo)
{
	struct q6voice_path *p = &v->paths[path];

	if (capture)
		p->tx_topo = topo;
	else
		p->rx_topo = topo;
}
EXPORT_SYMBOL_GPL(q6voice_set_topology);

MODULE_AUTHOR("Stephan Gerhold <stephan@gerhold.net>");
MODULE_DESCRIPTION("Q6Voice driver");
MODULE_LICENSE("GPL");
