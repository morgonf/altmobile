/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Заглушка для сборки вне дерева ядра. Настоящий q6afe.h лежит в
 * sound/soc/qcom/qdsp6 и здесь не нужен: из него используется единственная
 * функция.
 */
#ifndef _Q6_AFE_STUB_H
#define _Q6_AFE_STUB_H

int q6afe_get_port_id(int index);

#endif
