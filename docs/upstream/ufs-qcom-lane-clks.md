# Черновик сообщения: утечка часов в ufs-qcom

Черновик для разработчиков ядра (04.10.2026). Не отправлен. Куда:
списки `linux-scsi@vger.kernel.org` и `linux-arm-msm@vger.kernel.org`,
сопровождающие `drivers/ufs/host/ufs-qcom.c` (Manivannan Sadhasivam,
см. `scripts/get_maintainer.pl`). Перед отправкой собрать ядро с правкой
и проверить на телефоне, что счётчик часов больше не растёт и при
засыпании доходит до нуля.

## Что найдено

На OnePlus 6T (SDM845, ядро 7.1.0-rc1 ALT) счётчик включений часов UFS
(`gcc_ufs_phy_axi_clk`, `gcc_ufs_phy_unipro_core_clk`,
`gcc_ufs_phy_ice_core_clk`) растёт в простое примерно на 4 в минуту и за
часы работы достигает сотен. Часы накопителя поэтому никогда не
гасятся, ни при gating, ни в s2idle, и держат голос за XO
(`qcom_stats` aosd и cxsd всё время 0).

kprobe на `clk_enable` с фильтром по имени часов за 60 с: 24 включения,
из них 4 со стеком `ufs_qcom_resume` ← `__ufshcd_wl_resume` ←
`ufshcd_runtime_resume`, счётчик вырос на 4. На runtime resume
`ufshcd_setup_clocks(hba, true)` уже включил часы линий через
`ufs_qcom_setup_clocks(PRE_CHANGE)` (линк в HIBERN8), затем
`ufs_qcom_resume()` вызывает `ufs_qcom_enable_lane_clks()` ещё раз без
проверки. `ufs_qcom_disable_lane_clks()` проверяет
`is_lane_clks_enabled` и выключает один раз.

## Патч (черновик)

```
From: morgonf <morgonf@altlinux.org>
Subject: [PATCH] scsi: ufs: qcom: Don't enable the lane clocks twice

ufs_qcom_resume() enables the lane clocks unconditionally, but on a
runtime resume ufshcd_setup_clocks() has already enabled them in
ufs_qcom_setup_clocks(PRE_CHANGE) with the link in hibern8.
ufs_qcom_disable_lane_clks() only disables them once, guarded by
is_lane_clks_enabled, so every runtime suspend/resume cycle leaks one
enable of all the host clocks. On SDM845 (OnePlus 6T) the enable count
of the UFS clocks grows by about four per minute when idle, the clocks
are never gated and keep the XO vote in system suspend.

Make ufs_qcom_enable_lane_clks() a no-op when the clocks are already
enabled, like its counterpart.

Signed-off-by: morgonf <morgonf@altlinux.org>
---
 drivers/ufs/host/ufs-qcom.c | 3 +++
 1 file changed, 3 insertions(+)

--- a/drivers/ufs/host/ufs-qcom.c
+++ b/drivers/ufs/host/ufs-qcom.c
@@ static int ufs_qcom_enable_lane_clks(struct ufs_qcom_host *host)
 {
 	int err;
 
+	if (host->is_lane_clks_enabled)
+		return 0;
+
 	err = clk_bulk_prepare_enable(host->num_clks, host->clks);
 	if (err)
 		return err;
```

Заголовок `Fixes:` подобрать по истории файла (когда в `ufs_qcom_resume`
появился безусловный вызов). Проверить, не держит ли кто-то другой
расчёт на двойное включение (ICE).
