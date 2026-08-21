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

## 6. The output stage as built

`cfg.multiband.output_gain_db` — a plain trim on the summed output, default 0.
`tools/suggestTrim.m` measures the true peak across your material with the current
settings and tells you the value to use. Example, 4 bands at 50 % wet:

```
  Disco_Test.wav             0.699  ( -3.11 dBFS)
  Epic_Drum_Test.wav         1.334  ( +2.50 dBFS) <-- would clip
  EDM_Test.wav               0.856  ( -1.36 dBFS)
  suggested output_gain_db = -3.50   (ceiling -1 dBFS)
```

Note how material-dependent that is — the drum file needs 3.5 dB of trim while the
disco file has 3 dB spare. That is why it is a control and not a fixed constant.

`cfg.multiband.auto_gain` — `'off'` (default) / `'rms'` / `'lufs'`. Off on purpose.
Turning it on matches the output back to the input, which is the right thing when
A/B-ing timbre and the wrong thing when loudness is the point.

## 7. Audition sets

`output/<track>/voice/loud/iter_00/` holds both voices on four programme files,
rendered two ways:

- `__peaknorm` — everything at the same peak (−1 dBFS). This is how the tool is
  actually used, so the loudness difference is audible. That difference is the
  benefit.
- `__loudmatch` — everything at the same loudness. Cancels the benefit so the
  timbre cost can be judged on its own.

## 8. Making the level path honest (implemented)

The requirement: adding colour should change the level by exactly as much as the
colour actually contributes — nothing in the signal path matching or normalising —
with manual trims to pull it back.

**Dry/Wet law changed to `linear`.** An equal-power law assumes the two sides are
uncorrelated; a saturator's dry and wet are the same signal plus harmonics, so
equal-power sums them above unity mid-knob. Measured on Disco_Test, relative to
fully dry:

| law | 25 % | 50 % | 75 % | 100 % |
|---|---|---|---|---|
| equal_power (old default) | +2.52 | **+3.35** | +2.81 | +0.70 |
| **linear (new default)** | +0.17 | +0.34 | +0.52 | **+0.70** |

The +3.35 dB hump had nothing to do with the colour. Linear rises monotonically to
+0.70 dB, which is exactly what these harmonics contribute at 100 % wet. Both laws
still hit the endpoints exactly, re-verified: wet=0 % nulls against dry at
−188.7 dB, and the multiband gates are unchanged.

**Per-band trim added**: `cfg.multiband.bands(b).output_gain_db`, applied after that
band's dry/wet mix. Verified against an analytic expectation at −6 / −3 / +3 dB:
error −187 to −191 dB.

**A bypassed band ignores its own trim.** Bypass has to mean the band is untouched,
or the §3.4/5.3 guarantee that an all-bypass setting sums back to the input would
silently depend on no stale trim being left behind. The first version of the trim
applied to bypassed bands too (the thinking was "balance a band without colouring
it"), and the existing gate did not catch it because it happened to test with all
trims at zero. Fixed, and `verifyMultiband` gained test 6: set a non-zero trim on
every band, bypass them all, and the reconstruction must still null. It measures
−185.4 dB, and −321.4 dB on real material with −6 dB trims left on all four bands,
while a coloured band still honours its trim to exactly −6.0 dB.

### Still open, from the same audit

- **`drive_k` doubles as a linear gain.** Saturation's voice carries +3.00 dB of
  pure linear gain (drive 1.65 × the curve's c1 = 0.8484), so turning Drive up is
  partly just "louder" rather than "more saturated". Fixing it means a *static*
  calibration — define Drive so the linear region stays unity — which is a constant,
  not program-dependent matching, so it does not conflict with the requirement. It
  would change the absolute level of the current voices without changing their tone.
- **The upward compressor adds up to +6 dB on quiet material** (saturation voice,
  tapering to zero by −20 dBFS). Working as designed and chosen for reverb tails,
  but it is level from dynamics, not from harmonics — worth knowing it is there.
- **`output.mode = 'harmonic_auto'`** still exists in the core as an option. It
  matches output RMS to input RMS, i.e. it is automatic matching, and should be
  removed from the shipping path or clearly marked audition-only.
- **`runMultiband` hard-clips on write** (`max(min(y,1),-1)`). For a tool that never
  normalises, it should warn or write float rather than silently damage the file.

## 9. Drive made a saturation control, and no more silent clipping

**Writing.** `src/writeAudioSafe.m` replaces the `max(min(y,1),-1)` in
`runMultiband`. If the signal fits the requested fixed-point format it is written as
asked; if it exceeds full scale the file is written as **32-bit float**, which
stores the overshoot exactly, and a warning names the peak. Verified: a pushed
4-band setting peaking at 1.086 wrote float32 with 1.086 intact in the file, while
the same setting with a −6 dB trim wrote int24 at 0.544. A tool that never
normalises should not quietly clip on the way out either.

**Drive.** `shaper.drive_compensate` divides the curve output by `drive_k`, so the
linear region no longer moves with Drive:

| voice | drive 1.00 | 1.30 | 1.65 | 2.00 |
|---|---|---|---|---|
| tube | −1.81 dB | −1.82 | −1.84 | −1.86 |
| saturation | −1.40 dB | −1.41 | −1.43 | −1.45 |

Drive now changes only the *amount* of saturation. It divides by `drive_k` rather
than `drive_k·c1` on purpose: at drive 1.0 the compensation is exactly 1, so the
fitted curve and the frozen Phase A baseline are untouched (regression still PASS).
The residual −1.4/−1.8 dB is the curve's own `c1`, inherited from the Saturn fit;
add output gain if unity is wanted.

Effect on the shipped voices — the level drops, the tone does not:

| voice | level change | tone difference once level-matched |
|---|---|---|
| tube final | −2.28 dB | **−190.5 dB** (identical) |
| saturation final | −4.35 dB | −49.7 dB |

**Why saturation is not an exact null, and it matters.** Its upward compressor has
an *absolute* threshold (−30 dB). Compensation is applied right after the
waveshaper, so the compressor now sees a 4.35 dB quieter signal and lifts slightly
more. Consequences measured: tone differs by −49.7 dB (about 0.3 % RMS) and the
`loud` preset's benefit moves from +2.37 to +1.77 dB at equal peak.

That placement is deliberate and is the better of the two options: compensating
after the waveshaper means everything downstream sees a level that does not depend
on Drive, so Drive cannot smuggle a change into the compressor. Compensating at the
very end would leave the compressor seeing a drive-scaled signal, i.e. Drive would
still change the dynamics. If the pre-compensation compressor behaviour is wanted
back exactly, shift `dec.threshold_db` by the same amount (−30 → −25.65 dB).

## 10. Reverted to the signed-off voices

`drive_compensate` is now OFF everywhere, including the shipped voices, at the
listener's request: the voices are back at exactly the approved **Tube = F2_Z2** and
**Saturation = Y1**. The mechanism and the code stay in the repo for a future voice
— it is the right fix for Drive doubling as a level control — but it is not applied
to an already-approved sound, because enabling it moves the level (tube −2.28 dB,
saturation −4.35 dB) and nudges saturation's dynamics by ~0.3 % RMS.

Everything else from sections 6–9 is kept, because none of it changes an approved
voice: the 48 kHz sample-rate fix (which was blocking the tool on real material),
the output trim and `suggestTrim`, the per-band trim, the linear dry/wet law, the
bypass-ignores-trim fix, and `writeAudioSafe`.

**Verified back at the approved sound** by reproducing the archived audition renders
end to end:

| voice | material | vs archive |
|---|---|---|
| tube F2_Z2 | Disco | −125.8 dB |
| tube F2_Z2 | Epic_Drum | −128.2 dB * |
| saturation Y1 | Disco | −125.8 dB |
| saturation Y1 | Epic_Drum | −128.1 dB |

\* first measured −81.4 dB, which turned out to be the *archive* being wrong, not
the voice: the loudness-matched tube render peaks at 1.0127 and the old writer
hard-clipped 3 samples to 1.0000. Applying the same clip to the reproduction nulls
at −128.2 dB. A neat demonstration of why `writeAudioSafe` was needed — that render
would now be written as float with a warning instead of being silently shaved.

## 11. A mono/stereo mistake in an audition set

The listener noticed `Disco_Test__subtle_saturation__1before.wav` (the drive-
compensation A/B set) sounding different from `Disco_Test__final_raw.wav` (the final
pack), and was right to ask. Cause: the A/B render took `x = x(:,1)` — **left
channel only** — while the final pack processed both channels. Peaks were identical
to four decimals (0.5369 vs 0.5369) and RMS matched to 0.01 dB, so the colour was
never different; the audible difference was the image collapsing to mono, and
nothing in the filename said so.

Replaced by `tools/renderVoiceAB.m`, which always processes every channel of the
source and prints the channel count, peak and written format for each file. The new
stereo FINAL render nulls against the final pack at **−201.4 dB**. The misleading
mono folder was deleted.

Lesson for any future audition set: process the source's own channel count. A mono
fold-down changes the image as well as the tone, which makes an A/B against a stereo
render meaningless — and it looks like a processing difference.
