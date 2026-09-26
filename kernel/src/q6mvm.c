// SPDX-License-Identifier: GPL-2.0
// Copyright (c) 2012-2017, The Linux Foundation. All rights reserved.
// Copyright (c) 2020, Stephan Gerhold

#include <linux/dma-mapping.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/soc/qcom/apr.h>
#include "q6mvm.h"
#include "q6voice-common.h"

#define VSS_IMVM_CMD_CREATE_PASSIVE_CONTROL_SESSION	0x000110FF

struct vss_imvm_cmd_create_control_session_cmd {
	struct apr_hdr hdr;

	/* A variable-sized stream name. */
	char name[20];
} __packed;

#define VSS_IMVM_CMD_SET_POLICY_DUAL_CONTROL		0x00011327

/* This command is required to let MVM know who is in control of session. */
struct vss_imvm_cmd_set_policy_dual_control_cmd {
	struct apr_hdr hdr;

	/* Set to TRUE to enable modem state machine control */
	bool enable;
} __packed;

#define VSS_IMVM_CMD_ATTACH_VOCPROC			0x0001123E
#define VSS_IMVM_CMD_DETACH_VOCPROC			0x0001123F

/*
 * Attach/detach a vocproc to the MVM.
 * The MVM will symmetrically connect/disconnect this vocproc
 * to/from all the streams currently attached to it.
 */
struct vss_imvm_cmd_attach_vocproc_cmd {
	struct apr_hdr hdr;

	/* Handle of vocproc being attached. */
	u16 handle;
} __packed;

#define VSS_IMVM_CMD_START_VOICE			0x00011190
#define VSS_IMVM_CMD_STOP_VOICE				0x00011192

#define VSS_IMEMORY_CMD_MAP_PHYSICAL			0x00011334
#define VSS_IMEMORY_RSP_MAP				0x00011336
#define VSS_IMEMORY_CMD_UNMAP				0x00011337

/*
 * Memory shared with the DSP is described by a table that lives in memory of
 * its own. Both the table and the memory blocks it points to must be aligned
 * to the least common multiple of the cache line size, the page alignment and
 * the maximum data width announced in the map command, which comes out as one
 * page for the values used below.
 */
struct vss_imemory_table_descriptor {
	u32 mem_address_lsw;
	u32 mem_address_msw;
	/* Size in bytes of the table, zero if there is no table */
	u32 mem_size;
} __packed;

struct vss_imemory_block {
	u64 mem_address;
	/* Size in bytes, must be a multiple of the page alignment */
	u32 mem_size;
} __packed;

struct vss_imemory_table {
	/* Zeroed, because there is only one table */
	struct vss_imemory_table_descriptor next_table_descriptor;
	struct vss_imemory_block blocks[1];
} __packed;

struct vss_imemory_cmd_map_physical {
	struct apr_hdr hdr;
	struct vss_imemory_table_descriptor table_descriptor;
	/* Not a bool on the wire: one byte, and the fields below are unaligned */
	u8 is_cached;
	u16 cache_line_size;
	/* Bit 0 readable, bit 1 writable */
	u32 access_mask;
	u32 page_align;
	u8 min_data_width;
	u8 max_data_width;
} __packed;

struct vss_imemory_cmd_unmap {
	struct apr_hdr hdr;
	u32 mem_handle;
} __packed;

/*
 * The values below are the ones the factory driver uses on this SoC. The
 * buffer here is coherent, so no cache maintenance is needed on our side,
 * but is_cached is still left as the factory driver sets it: the firmware is
 * known to accept this combination, and a different one is untested.
 */
#define VSS_IMEMORY_CACHE_LINE_SIZE	128
#define VSS_IMEMORY_PAGE_ALIGN		4096
#define VSS_IMEMORY_ACCESS_RW		3
#define VSS_IMEMORY_MIN_DATA_WIDTH	8
#define VSS_IMEMORY_MAX_DATA_WIDTH	64

int q6mvm_mem_map(struct q6voice_session *mvm, struct q6voice_mem *mem,
		  size_t size)
{
	struct vss_imemory_cmd_map_physical cmd = {0};
	struct vss_imemory_table *table;
	u32 handle = 0;
	int ret;

	if (WARN_ON(mem->alloc))
		return -EBUSY;

	size = ALIGN(size, VSS_IMEMORY_PAGE_ALIGN);

	/*
	 * One allocation for both: the table goes into the first page, the
	 * block handed to the DSP starts at the second one. Coherent memory is
	 * page aligned, which is what both of them need.
	 */
	mem->alloc_size = PAGE_SIZE + size;
	mem->alloc = dma_alloc_coherent(mvm->dev, mem->alloc_size,
					&mem->alloc_phys, GFP_KERNEL);
	if (!mem->alloc) {
		dev_err(mvm->dev, "failed to allocate %zu bytes for the DSP\n",
			mem->alloc_size);
		return -ENOMEM;
	}

	mem->data = mem->alloc + PAGE_SIZE;
	mem->data_phys = mem->alloc_phys + PAGE_SIZE;
	mem->size = size;

	table = mem->alloc;
	memset(table, 0, sizeof(*table));
	table->blocks[0].mem_address = mem->data_phys;
	table->blocks[0].mem_size = size;

	cmd.hdr.pkt_size = sizeof(cmd);
	cmd.hdr.opcode = VSS_IMEMORY_CMD_MAP_PHYSICAL;

	cmd.table_descriptor.mem_address_lsw = lower_32_bits(mem->alloc_phys);
	cmd.table_descriptor.mem_address_msw = upper_32_bits(mem->alloc_phys);
	cmd.table_descriptor.mem_size = sizeof(*table);
	cmd.is_cached = true;
	cmd.cache_line_size = VSS_IMEMORY_CACHE_LINE_SIZE;
	cmd.access_mask = VSS_IMEMORY_ACCESS_RW;
	cmd.page_align = VSS_IMEMORY_PAGE_ALIGN;
	cmd.min_data_width = VSS_IMEMORY_MIN_DATA_WIDTH;
	cmd.max_data_width = VSS_IMEMORY_MAX_DATA_WIDTH;

	ret = q6voice_common_send_rsp(mvm, &cmd.hdr, VSS_IMEMORY_RSP_MAP,
				      &handle, sizeof(handle));
	if (ret) {
		dev_err(mvm->dev, "failed to map %zu bytes: %d\n", size, ret);
		goto err;
	}

	if (!handle) {
		dev_err(mvm->dev, "DSP returned no memory handle\n");
		ret = -EIO;
		goto err;
	}

	mem->handle = handle;
	dev_dbg(mvm->dev, "mapped %zu bytes at %pad, handle %#x\n",
		size, &mem->data_phys, handle);
	return 0;

err:
	dma_free_coherent(mvm->dev, mem->alloc_size, mem->alloc, mem->alloc_phys);
	memset(mem, 0, sizeof(*mem));
	return ret;
}
EXPORT_SYMBOL_GPL(q6mvm_mem_map);

int q6mvm_mem_unmap(struct q6voice_session *mvm, struct q6voice_mem *mem)
{
	struct vss_imemory_cmd_unmap cmd;
	int ret = 0;

	if (!mem->alloc)
		return 0;

	if (mem->handle) {
		cmd.hdr.pkt_size = sizeof(cmd);
		cmd.hdr.opcode = VSS_IMEMORY_CMD_UNMAP;
		cmd.mem_handle = mem->handle;

		ret = q6voice_common_send(mvm, &cmd.hdr);
		if (ret)
			dev_err(mvm->dev, "failed to unmap handle %#x: %d\n",
				mem->handle, ret);
	}

	dma_free_coherent(mvm->dev, mem->alloc_size, mem->alloc, mem->alloc_phys);
	memset(mem, 0, sizeof(*mem));
	return ret;
}
EXPORT_SYMBOL_GPL(q6mvm_mem_unmap);

static inline const char *q6mvm_session_name(enum q6voice_path_type path)
{
	switch (path) {
	case Q6VOICE_PATH_VOICE:
		return "default modem voice";
	case Q6VOICE_PATH_VOIP:
		return "10004000";
	case Q6VOICE_PATH_VOLTE:
		return "10C02000";
	case Q6VOICE_PATH_VOICE2:
		return "10DC1000";
	case Q6VOICE_PATH_QCHAT:
		return "10803000";
	case Q6VOICE_PATH_VOWLAN:
		return "10002000";
	case Q6VOICE_PATH_VOICEMMODE1:
		return "11C05000";
	case Q6VOICE_PATH_VOICEMMODE2:
		return "11DC5000";
	default:
		return NULL;
	}
}

static int q6mvm_set_dual_control(struct q6voice_session *mvm)
{
	struct vss_imvm_cmd_set_policy_dual_control_cmd cmd;

	cmd.hdr.pkt_size = sizeof(cmd);
	cmd.hdr.opcode = VSS_IMVM_CMD_SET_POLICY_DUAL_CONTROL;

	cmd.enable = true;

	return q6voice_common_send(mvm, &cmd.hdr);
}

struct q6voice_session *q6mvm_session_create(enum q6voice_path_type path)
{
	struct vss_imvm_cmd_create_control_session_cmd cmd;
	struct q6voice_session *mvm;
	const char *session_name;
	int ret;

	cmd.hdr.pkt_size = sizeof(cmd);
	cmd.hdr.opcode = VSS_IMVM_CMD_CREATE_PASSIVE_CONTROL_SESSION;

	session_name = q6mvm_session_name(path);
	if (session_name)
		strscpy(cmd.name, session_name, sizeof(cmd.name));

	mvm = q6voice_session_create(Q6VOICE_SERVICE_MVM, path, &cmd.hdr);
	if (IS_ERR(mvm))
		return mvm;

	ret = q6mvm_set_dual_control(mvm);
	if (ret) {
		dev_err(mvm->dev, "failed to set dual control: %d\n", ret);
		q6voice_session_release(mvm);
		return ERR_PTR(ret);
	}

	return mvm;
}
EXPORT_SYMBOL_GPL(q6mvm_session_create);

int q6mvm_attach(struct q6voice_session *mvm, struct q6voice_session *cvp,
		 bool state)
{
	struct vss_imvm_cmd_attach_vocproc_cmd cmd;

	cmd.hdr.pkt_size = sizeof(cmd);
	cmd.hdr.opcode = state ? VSS_IMVM_CMD_ATTACH_VOCPROC : VSS_IMVM_CMD_DETACH_VOCPROC;

	cmd.handle = cvp->handle;

	return q6voice_common_send(mvm, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6mvm_attach);

int q6mvm_start(struct q6voice_session *mvm, bool state)
{
	struct apr_pkt cmd;

	cmd.hdr.pkt_size = APR_HDR_SIZE;
	cmd.hdr.opcode = state ? VSS_IMVM_CMD_START_VOICE : VSS_IMVM_CMD_STOP_VOICE;

	return q6voice_common_send(mvm, &cmd.hdr);
}
EXPORT_SYMBOL_GPL(q6mvm_start);

static int q6mvm_probe(struct apr_device *adev)
{
	int ret;

	ret = q6voice_common_probe(adev, Q6VOICE_SERVICE_MVM);
	if (ret)
		return ret;

	/*
	 * APR devices carry no DMA configuration of their own, so their
	 * coherent mask is zero and coherent allocations for memory shared
	 * with the DSP get refused. The DSP reads that memory by physical
	 * address with no IOMMU in the way, so any mask would do; 32 bits is
	 * the conservative choice, because it keeps the buffer below 4 GB
	 * where the address fits the lower half of the descriptor on its own.
	 */
	ret = dma_coerce_mask_and_coherent(&adev->dev, DMA_BIT_MASK(32));
	if (ret) {
		dev_err(&adev->dev, "failed to set the DMA mask: %d\n", ret);
		return ret;
	}

	return of_platform_populate(adev->dev.of_node, NULL, NULL, &adev->dev);
}

static void q6mvm_remove(struct apr_device *adev)
{
	of_platform_depopulate(&adev->dev);
	q6voice_common_remove(adev);
}

static const struct of_device_id q6mvm_device_id[]  = {
	{ .compatible = "qcom,q6mvm" },
	{},
};
MODULE_DEVICE_TABLE(of, q6mvm_device_id);

static struct apr_driver qcom_q6mvm_driver = {
	.probe = q6mvm_probe,
	.remove = q6mvm_remove,
	.callback = q6voice_common_callback,
	.driver = {
		.name = "qcom-q6mvm",
		.of_match_table = of_match_ptr(q6mvm_device_id),
	},
};

module_apr_driver(qcom_q6mvm_driver);
MODULE_DESCRIPTION("Q6 Multimode Voice Manager");
MODULE_LICENSE("GPL");
