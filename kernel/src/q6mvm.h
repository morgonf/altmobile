/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _Q6_MVM_H
#define _Q6_MVM_H

#include <linux/types.h>
#include "q6voice.h"

struct q6voice_session;

/*
 * A block of memory shared with the DSP. The allocation covers the mapping
 * table in its first page and the block itself right after it.
 */
struct q6voice_mem {
	void *alloc;
	dma_addr_t alloc_phys;
	size_t alloc_size;

	/* The part visible to the DSP */
	void *data;
	dma_addr_t data_phys;
	size_t size;

	/* Handle the DSP refers to this mapping by, zero if not mapped */
	u32 handle;
};

struct q6voice_session *q6mvm_session_create(enum q6voice_path_type path);

int q6mvm_attach(struct q6voice_session *mvm, struct q6voice_session *cvp,
		 bool state);
int q6mvm_start(struct q6voice_session *mvm, bool state);

int q6mvm_mem_map(struct q6voice_session *mvm, struct q6voice_mem *mem,
		  size_t size);
int q6mvm_mem_unmap(struct q6voice_session *mvm, struct q6voice_mem *mem);

#endif /*_Q6_MVM_H */
