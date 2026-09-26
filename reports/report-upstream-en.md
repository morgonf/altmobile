# q6voice: echo cancellation on sdm845 is fixed by one missing device tree property

## Environment

- Device: OnePlus 6T (fajita), unlocked bootloader
- Distro: ALT Mobile (Sisyphus), kernel `7.1.0-qualcomm-sdm845-alt0.rc1`
- Kernel fork: https://altlinux.space/alt-mobile/linux branch `alt/sdm845`
- ALSA card: `O6T`

## Symptom

The remote party hears a clear echo of their own voice and noise suppression does
not work. Local audio is fine. This is a known open issue on sdm845 mainline.

## Root cause and fix

**The driver never sends the topology commit command to the DSP.**

`sound/soc/qcom/qdsp6/q6voice.c` has two setup paths:

```c
if (p->v->cvd_v2_3)
	cvp = session_create_v3(...);   /* full */
else
	cvp = session_create(...);      /* stripped down */
```

The full path sends channel info, port media format and, crucially,
`VSS_IVOCPROC_CMD_TOPOLOGY_COMMIT` (`0x00013198`), which activates the selected
processing chain. The stripped path sends none of these, so the vocproc session is
created with a topology id that is never committed. `ECNS` is nominally present
and cancels neither echo nor noise.

The path is selected by a device tree property:

```c
cvd_v2_3 = of_property_read_bool(np, "qcom,cvd-v2.3");   /* q6voice-dai.c */
```

`arch/arm64/boot/dts/qcom/sdm845-oneplus-common.dtsi` does not define it, so
OnePlus 6 and 6T always take the stripped path. The sc7280 device tree does define
it.

**Fix**, verified on device:

```
fdtput <dtb> /remoteproc-adsp/glink-edge/apr/apr-service@9/dais qcom,cvd-v2.3
```

After a reboot the full sequence appears and every command is accepted:

```
0x13169  create session v3      status 0x0
0x1133d  channel info / media format, x4   status 0x0
0x13198  topology commit        status 0x0
0x100c6  enable                 status 0x0
```

Echo disappears **even at factory gain settings**, including the earpiece level at
which echo was previously guaranteed. Noise suppression starts working: the user's
speech comes through over steady background noise. Verified over several live calls.

## Second defect: the range of the in-call volume control

`/usr/share/alsa/ucm2/OnePlus/fajita/VoiceCall.conf` assigns

```
PlaybackVolume "RX0 Digital Volume"
```

whose scale is `dBscale-min=-84.00dB, step=1.00dB, max=124`, so value 84 is 0 dB
and 124 is **+40 dB**. PipeWire maps its percentage range onto the whole control
range, so the upper third of the slider applies positive digital gain and clips.

The consequence is not obvious. Clipping is a nonlinear distortion while the echo
canceller models the echo path linearly, so the residual cannot be cancelled and
**echo comes back**. A user sees "I raised the volume and echo appeared" with no
way to explain it. Reproduced repeatedly.

`SHIFT/axolotl` uses the same control, so this is not OnePlus specific.

Suggestion: assign a control with a sane range, or limit the range in the codec
driver. UCM has no mechanism to cap a volume range.

## Third defect: microphone gain set too low

`BootSequence` in `fajita.conf` sets `DEC7 Volume 75`, which is −9 dB on the
handset microphone, and the remote party hears the user quietly. About 80 (−4 dB)
was comfortable in live testing.

## What remains unsolved

`TX_SM_ECNS_V2` and `TX_DM_FLUENCE` cannot be instantiated: the DSP answers
`ADSP_EFAILED` to `TOPOLOGY_COMMIT`. The reason is that device calibration is never
sent: `q6cvp` has neither shared memory support (`mem_handle = 0` everywhere) nor
any calibration registration command. This is the upstream
`TODO: Implement calibration`.

One finding from parsing the device's own factory calibration
(`/vendor/etc/acdbdata/MTP/MTP_Handset_cal.acdb`) is worth reporting. Its device
property table `DPROPLUT` carries property `0x000113af`, the topology id, per
device:

```
device 4  'HANDSET_MIC'          topology 0x00010f89  TX_SM_ECNS_V2
device 5  'HANDSET_MIC_...'      topology 0x00010f88
device 6  'HANDSET_MIC_ENDFIRE'  topology 0x00010f72  TX_DM_FLUENCE
```

The vendor assigned **ECNS v2** to the handset microphone. `TX_SM_ECNS` v1, which
the driver hardcodes as the default, does not appear in any of the nine calibration
files of this device. So the driver default contradicts the calibration, and the
correct approach is to read the topology from the ACDB the way Android does.

Related: the microphone channel count in `q6cvp` is hardcoded to 1. We turned it
into a module parameter and confirmed the DSP accepts two channels, but
`DM_FLUENCE` still needs calibration.

## Reproduction

```
# before: topology commit is never sent
dmesg | grep -c "opcode 0x13198"        # 0

fdtput <dtb> /remoteproc-adsp/glink-edge/apr/apr-service@9/dais qcom,cvd-v2.3
# reboot, place a call
dmesg | grep "opcode 0x13198"           # status: 0x0, echo gone
```

Extracted calibration, reproduction scripts and an ACDB format parser are available
on request.
