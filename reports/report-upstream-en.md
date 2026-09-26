# q6voice on sdm845 (OnePlus 6T): what it takes to get working echo cancellation

Updated 2026-09-26. An earlier version of this report claimed that the missing
`qcom,cvd-v2.3` device tree property alone fixes the echo. That was wrong. The
property only makes the v1 echo canceller work, and the far end still hears
itself. Everything below was verified on live calls.

## Environment

- Device: OnePlus 6T (fajita), unlocked bootloader
- Distro: ALT Mobile (Sisyphus), kernel `7.1.0-qualcomm-sdm845-alt0.rc1`
- Kernel fork: https://altlinux.space/alt-mobile/linux, branch `alt/sdm845`
- ADSP firmware: vendor image, extracted by `droid-juicer`

## Summary

Echo is gone on this device. Four things were needed, each one on its own is
not enough.

1. `qcom,cvd-v2.3` in the device tree, otherwise `TOPOLOGY_COMMIT` is never sent.
2. A FastRPC file server for the ADSP root PD. The echo canceller the vendor
   assigned to the handset mic is not built into the ADSP image. The ADSP loads
   it from the `dsp` partition over FastRPC, and nothing on the Linux side
   answered.
3. An explicit echo reference taken from the RX AFE port.
4. Enabling the module after the call is established, until calibration is
   registered through shared memory.

## 1. `qcom,cvd-v2.3`

Without it `q6voice-dai` takes the stripped session setup that sends neither
channel info, nor port media format, nor `VSS_IVOCPROC_CMD_TOPOLOGY_COMMIT`
(`0x00013198`). `sdm845-oneplus-common.dtsi` does not set it.

With it the default `TX_SM_ECNS` (`0x10f71`) topology is committed. The v1 canceller
reduces echo but does not remove it. A tone test on the earpiece shows 14 dB
terminal coupling loss, where 3GPP TS 26.131 asks for at least 45 dB.

## 2. ECNS v2 and Fluence are dynamic ADSP modules

The device calibration (`MTP_Handset_cal.acdb`, property `0x000113af` in
`DPROPLUT`) assigns `TX_SM_ECNS_V2` (`0x10f89`) to the handset mic and
`TX_DM_FLUENCE` (`0x10f72`) to the dual mic setup. The DSP rejected both with
`ADSP_EFAILED` regardless of sample rate, channel count or channel map.

The modules implementing them live on the `dsp_a` partition:

```
dsp/adsp/mmecns_module.so.1          capi_v2_voice_sm_ecns_v2_init
dsp/adsp/fluence_voiceplus_module.so.1
```

The ADSP `dlopen`s them and fetches the files from Linux through the FastRPC
`apps_std` interface (Android runs `adsprpcd` for this). hexagonrpcd can serve
it, but its root PD service is disabled on SDM845 with a FIXME. The reason is
that right after attaching, the ADSP reads `adsp_avs_config.acdb` and calls
`apps_std_ftell` (method 8), which hexagonrpcd 0.4.0 does not implement:

```
Unsupported method: 8 (08010100)
```

The daemon exits in the middle of the read and the ADSP stays in the old session
until reboot. With `ftell` implemented (patch against hexagonrpc v0.4.0 in
`tools/hexagonrpc`), the ADSP reads the module registry, loads both libraries,
and `TOPOLOGY_COMMIT` succeeds for `0x10f89` and `0x10f72`.

## 3. Echo reference

With ECNS v2 committed and calibrated, reading parameters back
(`VSS_ICOMMON_CMD_GET_PARAM_V2` `0x1133e` with `mem_handle` 0, in-band reply
`VSS_ICOMMON_RSP_GET_PARAM` `0x11008`) shows the module enabled with vendor
coefficients, yet echo passes untouched. Once the module actually runs, it mutes
the whole uplink. In `EC_INT_MIXING` mode with `ec_ref_port_id` =
`VSS_IVOCPROC_PORT_ID_NONE`, as the driver does now, it gets no reference
(the module has `capi_v2_quartet_gen_far_zeroes` for that case).

External reference from the RX port works, the same way the vendor driver does
with `ec_ref_ext`. The pieces are listed below.

- `vocproc_mode` = `VSS_IVOCPROC_VOCPROC_MODE_EC_EXT_MIXING` (`0x00010f7d`)
- `ec_ref_port_id` = the RX AFE port (`SLIMBUS_0_RX`)
- `VSS_PARAM_VOCPROC_EC_REF_CHANNEL_INFO` (`0x00013290`), which the vendor
  driver always sends
- `VSS_PARAM_EC_REF_PORT_ENDPOINT_MEDIA_INFO` (`0x00013255`)

## 4. Calibration sent in-band does not survive module re-initialisation

The driver sends parameters one by one in-band (`SET_PARAM_V2`, `mem_handle` 0).
The voice path starts when the number is dialled, but the module receives its
media type only when the modem starts passing audio. At that point it
re-initialises with its own defaults (mode word `0x0480002c` becomes
`0x0480032d`) and the earlier enable stays bypassed. Disabling and re-enabling
the module after the call is answered makes it work. Rewriting the calibration
between the first audio and the answer does not help and even prevents later
re-enables from working. The kernel cannot see the answer, since no APR packet
arrives from the ADSP at that moment. Our current workaround is a small service
triggered by the ModemManager `StateChanged` signal.

The proper fix is what the vendor driver does, which is registering calibration
tables in shared memory (`VSS_IVOCPROC_CMD_REGISTER_STATIC_CALIBRATION_DATA`
`0x0001307a` and related), so that the DSP reapplies them on every
re-initialisation. This needs `VSS_IMEMORY` mapping and the table layout
produced by the proprietary `libacdbloader`. That is our next step.

## Codec findings (`wcd934x`)

- `RX0 Digital Volume` goes up to +40 dB. When UCM uses it as the in-call
  volume, the upper third of the slider clips, and clipped echo cannot be
  cancelled by a linear canceller. A patch capping it at 0 dB is in `kernel/wcd`.
- The `ADCn Volume` TLV says 0.25 dB per step. A 1 kHz tone measurement between
  values 20 and 12 gave 14.4 dB, which is about 1.8 dB per step.
- `slim_tx_mixer_get()` returns `tx_port_value[port]` regardless of the DAI, so
  `AIF1_CAP Mixer SLIM TX6` reads `on` while the port is actually in `AIF2_CAP`.

## Available on request

Driver sources with all of the above as module parameters (`kernel/src`), a
cumulative patch against the ALT sources, the hexagonrpc patch, an ACDB parser
and exporter, and scripts for live parameter control during a call
(`live_set`, `live_get`).
