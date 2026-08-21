# Using these colours to get LOUDER — what the measurements say

The Phase B voices were tuned entirely for transparency, punch and air. Those are
**crest-increasing** moves, and loudness at a fixed ceiling is **crest-decreasing**.
So the signed-off voices are not loudness tools, and this note records what is,
with numbers.

Metric throughout: **dLUFS at equal peak** — normalise dry and processed to the
same peak (−1 dBFS), then compare integrated loudness. Positive means "louder for
the same ceiling", which is what a saturator is supposed to buy. `nlHF` is the
8–20 kHz nonlinear residual, i.e. the "prickly/麻" character the HF split was added
to cure. `clamp%` is the share of oversampled samples riding the curve's ceiling.

## 1. The signed-off voices mostly COST loudness

| voice / material | dLUFS | crest | nlHF | clamp% |
|---|---|---|---|---|
| tube `final` / Disco | −0.74 | 10.8 | −18.8 | 0.00 |
| tube `final` / Epic_Drum | −1.15 | 15.2 | −15.6 | 0.10 |
| saturation `final` / Disco | −1.25 | 11.3 | −14.3 | 0.00 |
| saturation `final` / Epic_Drum | **+4.03** | 10.0 | −11.2 | 0.52 |

Three levers are responsible, all deliberately added for tone:

- **`hf_clean.beta`** — the dominant one. HF that bypasses the curve keeps its
  transients, so crest rises. Going from the shipped β to 1.0 is worth about
  **+3.6 dB** of loudness on Disco, and costs about **5 dB** of nlHF. This one
  parameter *is* the loudness-vs-fizz trade.
- **`transient.enabled`** — it exists to protect attacks, which is the opposite of
  what loudness needs. Turning it off is worth up to **+5.2 dB** on transient-dense
  material (tube, Epic_Drum) and almost nothing on dense material.
- **the air shelf** — +5.5 dB above 8 kHz spends peak headroom on content the ear
  barely counts as loud. Removing it is worth about **+1.1 dB** on Disco.

**Drive is NOT a loudness lever here.** The curve already saturates near |u| = 1,
so more drive mostly adds harmonics that raise the peak too: on Disco, drive ×1.6
alone moved dLUFS from −0.14 to −0.31, i.e. slightly *worse*.

## 2. The `loud` presets

`cfg.voice.<track>.loud` (built by `tools/loudVoice.m`) undoes those three levers
and raises drive:

| voice / material | dLUFS | crest | nlHF | clamp% |
|---|---|---|---|---|
| tube `loud` / Disco | **+1.79** | 8.2 | −10.1 | 0.00 |
| tube `loud` / Epic_Drum | **+5.65** | 8.4 | −7.6 | 0.61 |
| saturation `loud` / Disco | **+2.37** | 7.6 | −9.5 | 0.00 |
| saturation `loud` / Epic_Drum | **+7.78** | 6.2 | −6.3 | 1.92 |

The nlHF column is the honest cost: the fizz comes back, by 5–9 dB. That is not a
bug in the preset, it is the trade — the same HF that gets compressed to buy the
loudness is the HF that generates the grit.

## 3. Loudness available is proportional to the source's crest

| material | dry crest | best dLUFS achieved |
|---|---|---|
| Epic_Drum | 14.0 dB | **+7.8** |
| Disco | 10.0 dB | +2.4 |
| EDM | 8.1 dB | **+0.6** |

Already-dense material has nothing left to compress. **If a mix is already limited
(crest under roughly 8 dB), no saturator will make it meaningfully louder** — that
is a limiter's job, and reaching for colour instead just adds distortion for
nothing.

## 4. THE IMPORTANT ONE — use ONE band for loudness, not the multiband split

Same loud voicing, same material, three paths:

| path | Disco | EDM | Epic_Drum |
|---|---|---|---|
| full-band, one core | **+2.37** | **+0.56** | **+7.78** |
| 4-band split, loud voice in every band | −1.66 | −2.93 | −0.78 |
| 1-band through the multiband tool (control) | +2.37 | +0.56 | +7.78 |

The 1-band control reproduces full-band exactly, so the tool is not at fault — the
loss is the **band summation**. Full-band saturation flattens the peaks of the
composite waveform. Split the signal first and each band's peaks are flattened
independently, but peaks in different bands do not occur at the same instant, so
the sum barely loses any peak at all. Roughly **4–8 dB of loudness is thrown away**
by splitting.

It also explains an earlier observation: at moderate multiband settings the output
peaked at 1.307 — band summation *raises* peaks. And note partial wet can peak
higher than full wet, because a dry transient adds on top of the saturated band's
harmonics.

**So:**
- **Loudness → one band, full range, `loud` voice.** Set `cfg.multiband.num_bands = 1`
  or call `processSignal` / the core directly.
- **Tone shaping → the multiband layer with the `final` voices.** Expect it to cost
  loudness rather than add it.
- Wanting both means two instances: a full-band loudness stage and a multiband
  tone stage, in whichever order you prefer.

## 5. Gain staging, and why not a limiter

Multiband summation pushes peaks over 1.0 at ordinary settings (measured 1.307 on
Epic_Drum at 50 % wet), and writing to a fixed-point file hard-clips there. That
needs an **output trim** — a plain gain. It does **not** want a built-in soft-clip
limiter: a limiter is a nonlinearity nobody measured, it would squash exactly the
transients three voice iterations went into protecting, and it makes the tool
impossible to reason about. Your DAW already has a limiter you chose and trust.

An **auto output gain** (match output loudness back to the input) is useful for
A/B auditioning — it is exactly why every Phase B listening set was loudness
matched — but it must default to OFF, because switching it on hands back the
loudness this whole note is about.
