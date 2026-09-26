// SPDX-License-Identifier: GPL-2.0
// Copyright (c) 2012-2017, The Linux Foundation. All rights reserved.
// Copyright (c) 2020, Stephan Gerhold

#include <linux/module.h>
#include <linux/of.h>
#include <linux/slab.h>
#include <linux/soc/qcom/apr.h>
#include "q6cvp.h"
#include "q6voice-common.h"

static unsigned int tx_channels = 1;
module_param(tx_channels, uint, 0644);
MODULE_PARM_DESC(tx_channels, "Number of TX (microphone) channels for voice processing (1 or 2)");

/*
 * The voice calibration in the ACDB files of this device exists for network
 * ids 0x1135F to 0x11363 only, never for VSS_ICOMMON_CAL_NETWORK_ID_NONE,
 * which is what gets sent here. Topologies that need calibration may well be
 * refused because of that, so make the field adjustable.
 */
static unsigned int profile_id = 0x0001135E;
module_param(profile_id, uint, 0644);
MODULE_PARM_DESC(profile_id, "Calibration network id sent in the create session command");

/*
 * Частота формата порта. Раньше стояла жёстко 48000, а заводской драйвер берёт
 * её из калибровки, для каждой топологии свою. Прошивка при этом прерывает
 * создание топологии на установке размера кадра, который от частоты и зависит,
 * так что это первый подозреваемый в отказе TOPOLOGY_COMMIT.
 */
static unsigned int media_rate = 48000;
module_param(media_rate, uint, 0644);
MODULE_PARM_DESC(media_rate, "Sample rate announced in the port media format");

/*
 * Раскладка каналов как у заводского драйвера: один канал это центр
 * (PCM_CHANNEL_FC), два канала это левый и правый. Прежняя раскладка ставила
 * одиночный канал левым, а два канала приёма оба левыми.
 */
static bool ds_mapping;
module_param(ds_mapping, bool, 0644);
MODULE_PARM_DESC(ds_mapping, "Use the channel mapping of the downstream driver (mono is FC, stereo is FL FR)");

/*
 * Заводской драйвер перед TOPOLOGY_COMMIT всегда отправляет третий блок
 * каналов, для опоры эхоподавителя, с раскладкой приёма. Прошивка при
 * создании топологии передачи принимает число опорных каналов, без этого
 * блока оно, видимо, ноль.
 */
static bool ec_ref_info;
module_param(ec_ref_info, bool, 0644);
MODULE_PARM_DESC(ec_ref_info, "Send EC reference channel info before topology commit, as downstream does");

/*
 * Опора эхоподавителя с порта приёма. В режиме внутреннего смешения
 * подавитель на этом телефоне опоры не получает: включённый по-настоящему,
 * он глушит весь тракт передачи. Здесь опора указывается явно, портом AFE,
 * как у заводского драйвера при ec_ref_ext. Нужен vocproc_mode=0x10F7D.
 */
static bool ec_ref_rx;
module_param(ec_ref_rx, bool, 0644);
MODULE_PARM_DESC(ec_ref_rx, "Use the RX AFE port as external EC reference port");

/* EC_INT_MIXING by default, EC_EXT_MIXING is 0x00010F7D */
static unsigned int vocproc_mode = 0x00010F7C;
module_param(vocproc_mode, uint, 0644);
MODULE_PARM_DESC(vocproc_mode, "Vocproc mode sent in the create session command");

#define VSS_IVOCPROC_DIRECTION_RX	0
#define VSS_IVOCPROC_DIRECTION_TX	1
#define VSS_IVOCPROC_DIRECTION_RX_TX	2

#define VSS_IVOCPROC_PORT_ID_NONE	0xFFFF

#define VSS_IVOCPROC_TOPOLOGY_ID_NONE			0x00010F70
#define VSS_IVOCPROC_TOPOLOGY_ID_TX_SM_ECNS		0x00010F71
#define VSS_IVOCPROC_TOPOLOGY_ID_TX_DM_FLUENCE		0x00010F72

#define VSS_IVOCPROC_TOPOLOGY_ID_RX_DEFAULT		0x00010F77

#define VSS_IVOCPROC_VOCPROC_MODE_EC_INT_MIXING		0x00010F7C
#define VSS_IVOCPROC_VOCPROC_MODE_EC_EXT_MIXING		0x00010F7D

#define VSS_ICOMMON_CAL_NETWORK_ID_NONE			0x0001135E

#define VSS_IVOCPROC_CMD_ENABLE				0x000100C6
#define VSS_IVOCPROC_CMD_DISABLE			0x000110E1

#define VSS_IVOCPROC_CMD_CREATE_FULL_CONTROL_SESSION_V2	0x000112BF
#define VSS_IVOCPROC_CMD_CREATE_FULL_CONTROL_SESSION_V3	0x00013169

#define VSS_IVOCPROC_CMD_TOPOLOGY_COMMIT		0x00013198

#define VSS_ICOMMON_CMD_SET_PARAM_V2			0x0001133D
#define VSS_ICOMMON_CMD_GET_PARAM_V2			0x0001133E
#define VSS_ICOMMON_RSP_GET_PARAM			0x00011008

#define VSS_MODULE_CVD_GENERIC				0x0001316E

#define VSS_PARAM_VOCPROC_RX_CHANNEL_INFO		0x0001328F
#define VSS_PARAM_VOCPROC_TX_CHANNEL_INFO		0x0001328E
#define VSS_PARAM_RX_PORT_ENDPOINT_MEDIA_INFO		0x00013254
#define VSS_PARAM_TX_PORT_ENDPOINT_MEDIA_INFO		0x00013253
#define VSS_PARAM_VOCPROC_EC_REF_CHANNEL_INFO		0x00013290
#define VSS_PARAM_EC_REF_PORT_ENDPOINT_MEDIA_INFO	0x00013255

#define PCM_CHANNEL_FL	1
#define PCM_CHANNEL_FR	2
#define PCM_CHANNEL_FC	3

#define VOC_SET_MEDIA_FORMAT_PARAM_TOKEN		2

/*
 * Upper bound for a single command packet. The largest parameter seen in the
 * factory calibration of this device is 392 bytes, so this is not tight.
 */
#define Q6CVP_MAX_PKT_SIZE				4096

#define VSS_NUM_CHANNELS_MAX 8

struct vss_ivocproc_cmd_create_full_control_session_v2_cmd {
	struct apr_hdr hdr;

	/*
	 * Vocproc direction. The supported values:
	 * VSS_IVOCPROC_DIRECTION_RX
	 * VSS_IVOCPROC_DIRECTION_TX
	 * VSS_IVOCPROC_DIRECTION_RX_TX
	 */
	u16 direction;

	/*
	 * Tx device port ID to which the vocproc connects. If a port ID is
	 * not being supplied, set this to #VSS_IVOCPROC_PORT_ID_NONE.
	 */
	u16 tx_port_id;

	/*
	 * Tx path topology ID. If a topology ID is not being supplied, set
	 * this to #VSS_IVOCPROC_TOPOLOGY_ID_NONE.
	 */
	u32 tx_topology_id;

	/*
	 * Rx device port ID to which the vocproc connects. If a port ID is
	 * not being supplied, set this to #VSS_IVOCPROC_PORT_ID_NONE.
	 */
	u16 rx_port_id;

	/*
	 * Rx path topology ID. If a topology ID is not being supplied, set
	 * this to #VSS_IVOCPROC_TOPOLOGY_ID_NONE.
	 */
	u32 rx_topology_id;

	/* Voice calibration profile ID. */
	u32 profile_id;

	/*
	 * Vocproc mode. The supported values:
	 * VSS_IVOCPROC_VOCPROC_MODE_EC_INT_MIXING
	 * VSS_IVOCPROC_VOCPROC_MODE_EC_EXT_MIXING
	 */
	u32 vocproc_mode;

	/*
	 * Port ID to which the vocproc connects for receiving echo
	 * cancellation reference signal. If a port ID is not being supplied,
	 * set this to #VSS_IVOCPROC_PORT_ID_NONE. This parameter value is
	 * ignored when the vocproc_mode parameter is set to
	 * VSS_IVOCPROC_VOCPROC_MODE_EC_INT_MIXING.
	 */
	u16 ec_ref_port_id;

	/*
	 * Session name string used to identify a session that can be shared
	 * with passive controllers (optional).
	 */
	char name[20];
} __packed;

struct vss_param_endpoint_media_format_info {
	u32 port_id;
	u16 num_channels;
	u16 bits_per_sample;
	u32 sample_rate;
	u8 channel_mapping[VSS_NUM_CHANNELS_MAX];
} __packed;

struct vss_param_vocproc_dev_channel_info {
	u32 num_channels;
	u32 bits_per_sample;
	u8 channel_mapping[VSS_NUM_CHANNELS_MAX];
} __packed;

struct vss_icommon_param_data {
	u32 module_id;
	u32 param_id;
	u16 param_size;
	u16 reserved;

	union {
		struct vss_param_endpoint_media_format_info media_format_info;
		struct vss_param_vocproc_dev_channel_info channel_info;
	};
} __packed;

/*
 * Same command as below, but with a variable sized parameter payload following
 * the header. Used to send calibration parameters of arbitrary size in-band.
 */
struct vss_icommon_cmd_set_param_v2_hdr {
	struct apr_hdr hdr;

	u32 mem_handle;
	u64 mem_address;
	u32 mem_size;

	u32 module_id;
	u32 param_id;
	u16 param_size;
	u16 reserved;
} __packed;

/* Нулевой mem_handle: процессор возвращает данные в самом ответе */
struct vss_icommon_cmd_get_param_v2 {
	struct apr_hdr hdr;

	u32 mem_handle;
	u64 mem_address;
	u16 mem_size;
	u32 module_id;
	u32 param_id;
} __packed;

struct vss_icommon_rsp_get_param {
	u32 status;
	u32 module_id;
	u32 param_id;
	u16 param_size;
	u16 reserved;
	u8 data[];
} __packed;

struct vss_icommon_cmd_set_param_v2_cmd {
	struct apr_hdr hdr;

	/*
	 * Pointer to the unique identifier for an address. What type of
	 * address? DMA? Device-specific memory? Please direct inquiries of
	 * this type to the SoC manufacturer.
	 *
	 * Anyway, the most important information for this parameter is that
	 * this field is set to zero if the data is in-band, i.e. in the same
	 * packet.
	 */
	u32 mem_handle;

	/*
	 * This field is ignored if you are only paying attention to this
	 * documentation of the fields. Otherwise, refer to your own
	 * documentation. I did not ask for this, and will not fully document
	 * it if its accuracy cannot be measured.
	 */
	u64 mem_address;

	/*
	 * Just set this to the size of the parameter data.
	 */
	u32 mem_size;

	struct vss_icommon_param_data param_data;
} __packed;

/* Чтобы перебирать значения из q6voice.c, не меняя устоявшийся вид вызовов */
void q6cvp_set_profile_id(u32 id)
{
	profile_id = id;
}
EXPORT_SYMBOL_GPL(q6cvp_set_profile_id);

void q6cvp_set_media_rate(u32 rate)
{
	media_rate = rate;
}
EXPORT_SYMBOL_GPL(q6cvp_set_media_rate);

void q6cvp_set_layout(u32 channels, bool downstream_mapping, bool ec_ref)
{
	tx_channels = channels;
	ds_mapping = downstream_mapping;
	ec_ref_info = ec_ref;
}
EXPORT_SYMBOL_GPL(q6cvp_set_layout);

static void q6cvp_fill_mapping(u8 *map, unsigned int channels, bool is_tx)
{
	memset(map, 0, VSS_NUM_CHANNELS_MAX);

	if (ds_mapping) {
		if (channels == 1) {
			map[0] = PCM_CHANNEL_FC;
		} else {
			map[0] = PCM_CHANNEL_FL;
			map[1] = PCM_CHANNEL_FR;
		}
		return;
	}

	map[0] = PCM_CHANNEL_FL;
	if (is_tx)
		map[1] = (channels > 1) ? PCM_CHANNEL_FR : 0;
	else
		map[1] = PCM_CHANNEL_FL;
}

struct q6voice_session *q6cvp_session_create(enum q6voice_path_type path,
					     u16 tx_port, u16 rx_port,
					     u32 tx_topo, u32 rx_topo)
{
	struct vss_ivocproc_cmd_create_full_control_session_v2_cmd cmd;

	cmd.hdr.pkt_size = sizeof(cmd);
	cmd.hdr.opcode = VSS_IVOCPROC_CMD_CREATE_FULL_CONTROL_SESSION_V2;

	cmd.tx_topology_id = tx_topo;
	cmd.rx_topology_id = rx_topo;

	cmd.direction = VSS_IVOCPROC_DIRECTION_RX_TX;
	cmd.tx_port_id = tx_port;
	cmd.rx_port_id = rx_port;
	cmd.profile_id = profile_id;
	cmd.vocproc_mode = vocproc_mode;
	cmd.ec_ref_port_id = ec_ref_rx ? rx_port : VSS_IVOCPROC_PORT_ID_NONE;

	return q6voice_session_create(Q6VOICE_SERVICE_CVP, path, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6cvp_session_create);

struct q6voice_session *q6cvp_session_create_v3(enum q6voice_path_type path,
						u16 tx_port, u16 rx_port,
						u32 tx_topo, u32 rx_topo)
{
	/*
	 * According to downstream, the v3 parameters are the exact same, with
	 * the only difference being the opcode.
	 */
	struct vss_ivocproc_cmd_create_full_control_session_v2_cmd cmd;

	cmd.hdr.pkt_size = sizeof(cmd);
	cmd.hdr.opcode = VSS_IVOCPROC_CMD_CREATE_FULL_CONTROL_SESSION_V3;

	cmd.tx_topology_id = tx_topo;
	cmd.rx_topology_id = rx_topo;

	cmd.direction = VSS_IVOCPROC_DIRECTION_RX_TX;
	cmd.tx_port_id = tx_port;
	cmd.rx_port_id = rx_port;
	cmd.profile_id = profile_id;
	cmd.vocproc_mode = vocproc_mode;
	cmd.ec_ref_port_id = ec_ref_rx ? rx_port : VSS_IVOCPROC_PORT_ID_NONE;

	return q6voice_session_create(Q6VOICE_SERVICE_CVP, path, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6cvp_session_create_v3);

int q6cvp_send_channel_info(struct q6voice_session *cvp, bool is_tx)
{
	struct vss_icommon_cmd_set_param_v2_cmd cmd;

	cmd.hdr.pkt_size = offsetof(struct vss_icommon_cmd_set_param_v2_cmd,
				    param_data.channel_info)
			 + sizeof(struct vss_param_vocproc_dev_channel_info);
	cmd.hdr.opcode = VSS_ICOMMON_CMD_SET_PARAM_V2;

	cmd.mem_handle = 0;
	cmd.mem_size = offsetof(struct vss_icommon_param_data, channel_info)
		     + sizeof(struct vss_param_vocproc_dev_channel_info);

	cmd.param_data.module_id = VSS_MODULE_CVD_GENERIC;
	cmd.param_data.param_id = is_tx ? VSS_PARAM_VOCPROC_TX_CHANNEL_INFO
					: VSS_PARAM_VOCPROC_RX_CHANNEL_INFO;
	cmd.param_data.param_size = sizeof(struct vss_param_vocproc_dev_channel_info);
	cmd.param_data.reserved = 0;

	if (is_tx)
		cmd.param_data.channel_info.num_channels = tx_channels;
	else
		cmd.param_data.channel_info.num_channels = 2;

	cmd.param_data.channel_info.bits_per_sample = 16;
	q6cvp_fill_mapping(cmd.param_data.channel_info.channel_mapping,
			   cmd.param_data.channel_info.num_channels, is_tx);

	return q6voice_common_send(cvp, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6cvp_send_channel_info);

/* Раскладка опоры повторяет приём, как в заводском voice_send_cvp_channel_info_v2 */
int q6cvp_send_ec_ref_channel_info(struct q6voice_session *cvp)
{
	struct vss_icommon_cmd_set_param_v2_cmd cmd;

	if (!ec_ref_info)
		return 0;

	cmd.hdr.pkt_size = offsetof(struct vss_icommon_cmd_set_param_v2_cmd,
				    param_data.channel_info)
			 + sizeof(struct vss_param_vocproc_dev_channel_info);
	cmd.hdr.opcode = VSS_ICOMMON_CMD_SET_PARAM_V2;

	cmd.mem_handle = 0;
	cmd.mem_size = offsetof(struct vss_icommon_param_data, channel_info)
		     + sizeof(struct vss_param_vocproc_dev_channel_info);

	cmd.param_data.module_id = VSS_MODULE_CVD_GENERIC;
	cmd.param_data.param_id = VSS_PARAM_VOCPROC_EC_REF_CHANNEL_INFO;
	cmd.param_data.param_size = sizeof(struct vss_param_vocproc_dev_channel_info);
	cmd.param_data.reserved = 0;

	cmd.param_data.channel_info.num_channels = 2;
	cmd.param_data.channel_info.bits_per_sample = 16;
	q6cvp_fill_mapping(cmd.param_data.channel_info.channel_mapping, 2, false);

	return q6voice_common_send(cvp, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6cvp_send_ec_ref_channel_info);

/* Формат порта опоры, как voice_send_cvp_media_format_cmd(EC_REF_PATH) */
int q6cvp_send_ec_ref_media_format(struct q6voice_session *cvp, int port_id)
{
	struct vss_icommon_cmd_set_param_v2_cmd cmd;

	if (!ec_ref_rx)
		return 0;

	cmd.hdr.pkt_size = offsetof(struct vss_icommon_cmd_set_param_v2_cmd,
				    param_data.media_format_info)
			 + sizeof(struct vss_param_endpoint_media_format_info);
	cmd.hdr.opcode = VSS_ICOMMON_CMD_SET_PARAM_V2;

	cmd.mem_handle = 0;
	cmd.mem_size = offsetof(struct vss_icommon_param_data, media_format_info)
		     + sizeof(struct vss_param_endpoint_media_format_info);

	cmd.param_data.module_id = VSS_MODULE_CVD_GENERIC;
	cmd.param_data.param_id = VSS_PARAM_EC_REF_PORT_ENDPOINT_MEDIA_INFO;
	cmd.param_data.param_size = sizeof(struct vss_param_endpoint_media_format_info);
	cmd.param_data.reserved = 0;

	cmd.param_data.media_format_info.port_id = port_id;
	cmd.param_data.media_format_info.num_channels = 2;
	cmd.param_data.media_format_info.bits_per_sample = 16;
	cmd.param_data.media_format_info.sample_rate = media_rate;
	q6cvp_fill_mapping(cmd.param_data.media_format_info.channel_mapping,
			   2, false);

	return q6voice_common_send(cvp, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6cvp_send_ec_ref_media_format);

int q6cvp_send_media_format(struct q6voice_session *cvp, int port_id, bool is_tx)
{
	struct vss_icommon_cmd_set_param_v2_cmd cmd;

	cmd.hdr.pkt_size = offsetof(struct vss_icommon_cmd_set_param_v2_cmd,
				    param_data.media_format_info)
			 + sizeof(struct vss_param_endpoint_media_format_info);
	cmd.hdr.opcode = VSS_ICOMMON_CMD_SET_PARAM_V2;

	cmd.mem_handle = 0;
	cmd.mem_size = offsetof(struct vss_icommon_param_data, media_format_info)
		     + sizeof(struct vss_param_endpoint_media_format_info);

	cmd.param_data.module_id = VSS_MODULE_CVD_GENERIC;
	cmd.param_data.param_id = is_tx ? VSS_PARAM_TX_PORT_ENDPOINT_MEDIA_INFO
					: VSS_PARAM_RX_PORT_ENDPOINT_MEDIA_INFO;
	cmd.param_data.param_size = sizeof(struct vss_param_endpoint_media_format_info);
	cmd.param_data.reserved = 0;

	cmd.param_data.media_format_info.port_id = port_id;

	if (is_tx)
		cmd.param_data.media_format_info.num_channels = tx_channels;
	else
		cmd.param_data.media_format_info.num_channels = 2;

	cmd.param_data.media_format_info.bits_per_sample = 16;
	cmd.param_data.media_format_info.sample_rate = media_rate;
	q6cvp_fill_mapping(cmd.param_data.media_format_info.channel_mapping,
			   cmd.param_data.media_format_info.num_channels, is_tx);

	return q6voice_common_send(cvp, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6cvp_send_media_format);

/*
 * Send a single processing parameter to the vocproc in-band. The factory
 * software sends calibration as one table in shared memory, which requires
 * both memory mapping and the table format used by the proprietary
 * acdb-loader. Individual parameters, on the other hand, go through the same
 * command that is already used for channel info and media format above.
 */
int q6cvp_send_param(struct q6voice_session *cvp, u32 module_id, u32 param_id,
		     const void *data, u16 size)
{
	struct vss_icommon_cmd_set_param_v2_hdr *cmd;
	u32 param_bytes = ALIGN(size, 4);
	u32 pkt_size = sizeof(*cmd) + param_bytes;
	int ret;

	if (pkt_size > Q6CVP_MAX_PKT_SIZE)
		return -EMSGSIZE;

	cmd = kzalloc(pkt_size, GFP_KERNEL);
	if (!cmd)
		return -ENOMEM;

	cmd->hdr.pkt_size = pkt_size;
	cmd->hdr.opcode = VSS_ICOMMON_CMD_SET_PARAM_V2;

	/* Zero memory handle means the parameter is in this very packet */
	cmd->mem_handle = 0;
	/* Size of the parameter block: its 12 byte header plus the payload */
	cmd->mem_size = sizeof(*cmd)
		      - offsetof(struct vss_icommon_cmd_set_param_v2_hdr,
				 module_id)
		      + param_bytes;

	cmd->module_id = module_id;
	cmd->param_id = param_id;
	cmd->param_size = size;
	cmd->reserved = 0;
	memcpy((u8 *)cmd + sizeof(*cmd), data, size);

	ret = q6voice_common_send(cvp, &cmd->hdr);
	kfree(cmd);
	return ret;
}
EXPORT_SYMBOL_GPL(q6cvp_send_param);

/*
 * Read a parameter back from the vocproc. Returns the size reported by the
 * DSP, or a negative error. At most size bytes are copied to data. A reply
 * shorter than requested is dropped by the common layer and ends in a
 * timeout, so the caller has to ask for the size it expects.
 */
int q6cvp_get_param(struct q6voice_session *cvp, u32 module_id, u32 param_id,
		    void *data, u16 size)
{
	struct vss_icommon_cmd_get_param_v2 cmd = { };
	struct vss_icommon_rsp_get_param *rsp;
	size_t rsp_size = sizeof(*rsp) + size;
	int ret;

	rsp = kzalloc(rsp_size, GFP_KERNEL);
	if (!rsp)
		return -ENOMEM;

	cmd.hdr.pkt_size = sizeof(cmd);
	cmd.hdr.opcode = VSS_ICOMMON_CMD_GET_PARAM_V2;
	cmd.mem_handle = 0;
	cmd.mem_address = 0;
	cmd.mem_size = 12 + ALIGN(size, 4);
	cmd.module_id = module_id;
	cmd.param_id = param_id;

	ret = q6voice_common_send_rsp(cvp, &cmd.hdr, VSS_ICOMMON_RSP_GET_PARAM,
				      rsp, rsp_size);
	if (ret)
		goto out;

	if (rsp->status) {
		dev_info(cvp->dev, "get param %#x/%#x: status %#x\n",
			 module_id, param_id, rsp->status);
		ret = -EIO;
		goto out;
	}

	memcpy(data, rsp->data, min_t(u16, size, rsp->param_size));
	ret = rsp->param_size;
out:
	kfree(rsp);
	return ret;
}
EXPORT_SYMBOL_GPL(q6cvp_get_param);

int q6cvp_topology_commit(struct q6voice_session *cvp)
{
	struct apr_pkt cmd;

	cmd.hdr.pkt_size = APR_HDR_SIZE;
	cmd.hdr.opcode = VSS_IVOCPROC_CMD_TOPOLOGY_COMMIT;

	return q6voice_common_send(cvp, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6cvp_topology_commit);

int q6cvp_enable(struct q6voice_session *cvp, bool state)
{
	struct apr_pkt cmd;

	cmd.hdr.pkt_size = APR_HDR_SIZE;
	cmd.hdr.opcode = state ? VSS_IVOCPROC_CMD_ENABLE : VSS_IVOCPROC_CMD_DISABLE;

	return q6voice_common_send(cvp, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6cvp_enable);

static int q6cvp_probe(struct apr_device *adev)
{
	return q6voice_common_probe(adev, Q6VOICE_SERVICE_CVP);
}

static const struct of_device_id q6cvp_device_id[]  = {
	{ .compatible = "qcom,q6cvp" },
	{},
};
MODULE_DEVICE_TABLE(of, q6cvp_device_id);

static struct apr_driver qcom_q6cvp_driver = {
	.probe = q6cvp_probe,
	.remove = q6voice_common_remove,
	.callback = q6voice_common_callback,
	.driver = {
		.name = "qcom-q6cvp",
		.of_match_table = of_match_ptr(q6cvp_device_id),
	},
};

module_apr_driver(qcom_q6cvp_driver);

MODULE_AUTHOR("Stephan Gerhold <stephan@gerhold.net>");
MODULE_DESCRIPTION("Q6 Core Voice Processor");
MODULE_LICENSE("GPL");
