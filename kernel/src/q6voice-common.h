/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _Q6_VOICE_COMMON_H
#define _Q6_VOICE_COMMON_H

#include <linux/soc/qcom/apr.h>
#include "q6voice.h"

enum q6voice_service_type {
	Q6VOICE_SERVICE_MVM,
	Q6VOICE_SERVICE_CVP,
	Q6VOICE_SERVICE_CVS,
	Q6VOICE_SERVICE_COUNT
};

struct q6voice_service;

struct q6voice_session {
	struct device *dev;
	struct q6voice_service *svc;
	struct kref refcount;

	u16 port;
	u16 handle;

	wait_queue_head_t wait;

	/* Protect expected_opcode, expected_rsp_opcode, result and rsp */
	spinlock_t lock;
	u32 expected_opcode;
	/*
	 * Some commands are answered by a service specific response carrying a
	 * payload instead of the basic result. Set to the opcode of that
	 * response while such a command is in flight, zero otherwise.
	 */
	u32 expected_rsp_opcode;
	u32 result;
	void *rsp;
	size_t rsp_size;
};

int q6voice_common_probe(struct apr_device *adev, enum q6voice_service_type type);
void q6voice_common_remove(struct apr_device *adev);

int q6voice_common_callback(struct apr_device *adev, const struct apr_resp_pkt *data);
int q6voice_common_send(struct q6voice_session *s, struct apr_hdr *hdr);
int q6voice_common_send_rsp(struct q6voice_session *s, struct apr_hdr *hdr,
			    u32 rsp_opcode, void *rsp, size_t rsp_size);

struct q6voice_session *q6voice_session_create(enum q6voice_service_type type,
					       enum q6voice_path_type path,
					       struct apr_hdr *hdr);
void q6voice_session_release(struct q6voice_session *s);

#endif /* _Q6_VOICE_COMMON_H */
