# q6cvp: default TX vocproc topology is absent from OEM ACDB calibration (OnePlus 6T, sdm845)

## Environment

- Device: OnePlus 6T (fajita), unlocked bootloader
- Distro: ALT Mobile (Sisyphus), image `alt-mobile-phosh-sdm845-latest-aarch64.tar.xz`
- Kernel: `7.1.0-qualcomm-sdm845-alt0.rc1`, fork at https://altlinux.space/alt-mobile/linux branch `alt/sdm845`
- ALSA card: `O6T`

## Symptom

During a voice call the remote party hears a clear echo of their own voice. Local audio is fine. This is a known open issue on sdm845 mainline.

## Practical fix found, verified on device

**The echo goes away with two lines in the UCM profile, no kernel patch and no calibration needed.** The cause is acoustic, not algorithmic.

The profile distributes gain badly. The earpiece output stage `EAR PA Volume` sits at maximum (4 of 4, +6 dB) while the bottom mic digital gain `DEC7 Volume` is only 75 of 124. The remote party hears the user quietly, the user raises the volume with the volume keys, `RX0 Digital Volume` climbs to 101-110 of 124, the earpiece bleeds into the microphone and the acoustic loop closes. The user hears no echo, the remote party does.

Change in the `BootSequence` of `/usr/share/alsa/ucm2/OnePlus/fajita/fajita.conf`:

```
cset "name='DEC7 Volume' 85"        # was 75
cset "name='EAR PA Volume' 0"       # was 4, minus 6 dB
```

Why this stage. `EAR PA Volume` is referenced neither in `fajita.conf` nor in `VoiceCall.conf`, so neither PipeWire nor the volume keys touch it. Attenuating there shifts the whole volume range down, so running into feedback becomes impossible even at full scale. Lowering the microphone instead does not help, it attenuates speech and echo equally and leaves the ratio unchanged.

After the change, with `RX0` at 110, which is above the level where feedback used to start, there is no echo, the remote party hears the user well and local audio is fine.

Still unsolved: the microphone picks up ambient noise and the remote party hears everything around the user. That is the same non functional `ECNS` chain and it cannot be worked around acoustically. `TX7 HPF cut off` is already at its most aggressive setting `CF_NEG_3DB_150HZ` and no other control remains in the mixer.

## What was established about topologies and calibration

**1. Call audio bypasses userspace.** `/usr/share/alsa/ucm2/OnePlus/fajita/VoiceCall.conf` routes through `SLIMBUS_0_RX Voice Mixer VoiceMMode1` and `VoiceMMode1 Capture Mixer SLIMBUS_0_TX`, so the voice path runs inside the DSP. A PipeWire `module-echo-cancel` cannot be inserted into it.

**2. ECNS is requested but never calibrated.** In `sound/soc/qcom/qdsp6/q6cvp.c`, `q6cvp_session_create()` carries `/* TODO: Implement calibration */` and hardcodes `vocproc_mode = VSS_IVOCPROC_VOCPROC_MODE_EC_INT_MIXING` with `ec_ref_port_id = VSS_IVOCPROC_PORT_ID_NONE`. With internal mixing that `PORT_ID_NONE` is correct, the DSP takes the echo reference from its own RX path, so a missing EC reference port is not the bug.

**3. Global ACDB loading exists in this kernel but is never enabled on these devices.** `q6core` contains `q6core_load_and_register_topologies()`, which reads the `qcom,acdb-name` device tree property and silently returns 0 when the property is absent, then calls `request_firmware()` with that exact name. `arch/arm64/boot/dts/qcom/sdm845-oneplus-common.dtsi` does not define the property, so on OnePlus 6 and 6T no ACDB is ever loaded.

Adding the property manually with `fdtput` and placing the device's own `MTP_Global_cal.acdb` under `/lib/firmware` makes the property visible in `/sys/firmware/devicetree/base/remoteproc-adsp/glink-edge/apr/service@3/qcom,acdb-name`, and neither `failed to load Global_cal.acdb` nor `ACDB parse error` appears in dmesg.

**4. The global ACDB topologies blob contains no vocproc topologies.** Property `0x000131a7` (`ACDB_TOPOLOGIES_BLOB`) sits in `GPROPLUT` at `DATAPOOL` offset 12772, size 864 bytes. A byte level search inside that blob for `0x00010F70`, `0x00010F71`, `0x00010F72`, `0x00010F77` and `0x00010F89` yields no matches. Registering topologies from the global file therefore does not touch the voice path.

**5. Main finding. The driver's default TX topology does not exist in this device's OEM calibration.**

Byte level census over all nine ACDB files from the `vendor_a` partition (`/etc/acdbdata/`):

| Topology | Value | Occurrences |
|---|---|---|
| `VSS_IVOCPROC_TOPOLOGY_ID_TX_SM_ECNS` | `0x00010F71` | **0** |
| `VSS_IVOCPROC_TOPOLOGY_ID_TX_SM_ECNS_V2` | `0x00010F89` | 9, of which 4 in `MTP_Handset_cal.acdb` |
| `VSS_IVOCPROC_TOPOLOGY_ID_TX_DM_FLUENCE` | `0x00010F72` | 14, of which 7 in `MTP_Handset_cal.acdb` |
| `VSS_IVOCPROC_TOPOLOGY_ID_RX_DEFAULT` | `0x00010F77` | **0** |
| `VSS_IVOCPROC_TOPOLOGY_ID_NONE` | `0x00010F70` | 4 |

Full census of the vocproc topology range in `MTP_Handset_cal.acdb`, the handset (earpiece) calibration, which is the voice call path:

```
0x00010f70  x1     VSS_IVOCPROC_TOPOLOGY_ID_NONE
0x00010f72  x7     VSS_IVOCPROC_TOPOLOGY_ID_TX_DM_FLUENCE
0x00010f73  x12
0x00010f74  x14
0x00010f86  x7
0x00010f87  x7
0x00010f88  x7
0x00010f89  x4     VSS_IVOCPROC_TOPOLOGY_ID_TX_SM_ECNS_V2
0x00010f8b  x1
```

The OEM calibrated `TX_SM_ECNS_V2` and `TX_DM_FLUENCE` for this path. `TX_SM_ECNS` v1, which the driver hardcodes as the default, appears in none of the nine files. `RX_DEFAULT` also appears nowhere, although the RX path clearly was calibrated, so the RX topology actually used is probably one of the undeclared values above.

**6. Any other topology breaks the call.** The controls `VoiceMMode1 TX Topology` (numid 99) and `VoiceMMode1 RX Topology` (numid 100) are writable. Defaults are `69489` = `0x00010F71` and `69495` = `0x00010F77`.

Setting TX to `69513` (`SM_ECNS_V2`) or to `69490` (`DM_FLUENCE`) lets the call connect but leaves **no audio in either direction**, so the vocproc session is not created. Restoring `69489` brings audio back without a reboot. This holds both before and after the global ACDB is loaded.

## Reproduction

```
amixer -c O6T cget "name=VoiceMMode1 TX Topology"    # 69489
amixer -c O6T cset "name=VoiceMMode1 TX Topology" 69513
# place a call: connects, silence both ways
amixer -c O6T cset "name=VoiceMMode1 TX Topology" 69489
# place a call: audio works, remote party hears echo
```

## Interpretation and suggestions

The echo is not simply uncalibrated ECNS. The driver selects a processing chain for which no parameters exist on this hardware, while the chains the OEM did calibrate cannot be instantiated because voice calibration from the device ACDB files is never sent to the DSP, which is exactly what the `TODO` in `q6cvp_session_create()` refers to.

Suggestions:

1. Implement voice calibration delivery from the device ACDB files through the CVP calibration commands, resolving the `TODO`.
2. Add `qcom,acdb-name` to the OnePlus 6 and 6T device trees. Today global ACDB loading is silently disabled there.
3. Revisit the default TX topology. `SM_ECNS` v1 appears unused by OEM calibration on this device, while `SM_ECNS_V2` and `DM_FLUENCE` are calibrated.
4. Note that `DM_FLUENCE` needs two microphones, while fajita's `VoiceCall.conf` enables only the bottom mic (`AMIC4`, `MultiMedia2` via `SLIMBUS_0_TX`). Dual mic processing would also require a UCM change.

Extracted ACDB files and the reproduction scripts can be provided on request.
