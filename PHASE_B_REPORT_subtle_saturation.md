# PHASE B REPORT — subtle_saturation

Voice tuning complete. Signed off by the listener at voice iteration 8, variant
**Y1**. Tag: `subtle_saturation-v1.0-final`.

Per **R-ReferenceFreeze**, Saturn 2 stopped being an optimisation target the moment
this track entered `voice_tuning`. The Phase A metrics below are history, not a score.

## Final configuration (`cfg.voice.subtle_saturation.final`)

| stage | setting |
|---|---|
| Waveshaper | `signpow`, powers [1..5], coeffs [0.8484 −0.6008 0.5004 −0.5529 0.2171] |
| Drive | `drive_k = 1.65` |
| HF-clean split | 8 kHz, β = 0.50, follow = 1.0 (1 ms / 30 ms), gain-matched |
| Transient preserve | off |
| Pre-EQ | identity |
| Post-EQ | two high shelves at 8 kHz, +3.0 dB and +2.5 dB, Q 0.7 (+5.5 dB total) |
| Dynamic Energy Control | **upward** 1.5:1, threshold −30 dB, range 18 dB, 2 ms / 300 ms, post |
| Oversampling | 4× |

## How this voice was arrived at

**1. HF-clean split (shared with the tube track).** "Digital / prickly highs" was
diagnosed as intermodulation between HF partials, after ruling out aliasing
(−130 dB for 2–8 kHz tones; ×4 vs a ×32 gold reference differs by −74.8 dB) and a
modelling error (the model matches the Saturn reference within 0.02–0.04 dB per
octave — the grit is Saturn's own character). β = 0.50 sat where the listener
settled between cleanliness and density.

**2. Air, via shelves — not midrange EQ.** The listener wanted "highs more exciting
but not prickly, and reverb tails more audible with more air". A high shelf delivers
that with zero added distortion by construction. +3.0 dB then +2.5 dB were added
across two iterations.

**3. Upward compression for the tails.** Reverb-tail audibility is an upward-
dynamics problem, so H9 Dynamic Energy Control was enabled — the spec reserved it
for exactly this stage. On the decay-tail probe it pulled the dynamic spread from
31.95 to 26.29 dB (below the dry signal's own 29.05), with crest still near dry.
Getting there required fixing the module: its `soft_compression` had no threshold
and derived gain from the absolute envelope, so quieter passages were boosted more
and — because the envelope lags — peaks were boosted too. It *expanded* transients
(crest 10.0 → 18.3 dB at ratio 1.5). It now has threshold/knee/makeup, and a new
`upward` mode. The same lag trap reappeared there: a 20 ms attack amplified
transients (crest → 16.3); a fast attack (2 ms) with a slow release (300 ms) fixes it.

**4. Drive 1.65 — the lever that solved two complaints at once.** The listener
liked variant V0's openness but found it slightly thin, and separately wanted ~30 %
more upper-mid excitement. An earlier attempt to restore body with a 250 Hz peak
(V1–V3) *worked* but closed the openness, and the listener rejected it. Measurement
then showed drive does both jobs with no EQ in the midrange at all: on Disco, ×1.30
moved the 2–8 kHz nonlinear residual (the exciting, harmonically-related content)
from −20.5 to −18.2 dB **and** the 200–2000 Hz residual (body) from −20.4 to
−18.1 dB. Pushed to ×1.65 for the final.

A targeted alternative was also measured — a pre-EQ peak at 3.5 kHz raises upper-mid
excitement (+2.5 dB) far more than overall breakup (+1.1 dB), which matches the
listener's ratio better than uniform drive. They auditioned it (Y2) and preferred
the uniform version (Y1). Recorded, not overridden.

## Measured effect of the final voice vs the saturn-like baseline

On Disco_Test, loudness-matched: 2–8 kHz nonlinear residual −20.5 → about −16 dB,
200–2000 Hz residual −20.4 → about −16 dB, 10–16 kHz level +1.9 dB vs dry, decay
spread 31.95 → 26.29 dB on the tail probe. Effective linear response confirmed by
`tools/tiltReport.m` to be unchanged in the low-mids and mids — the "thinner mids"
the listener reported at one point was a *relative* effect of the HF lift, not a
loss, and was fixed by adding body via drive rather than by boosting the mids.

## Phase A metrics, for the record only (R-ReferenceFreeze)

THD_error 1.10 dB · HarmonicProfileError 1.69 dB · SweepSpectralError −55.04 dB
(loss_version `phase_a_loss_v3`). Drive ×1.65 plus +5.5 dB of shelf put the final
voice far from that match by design (**R-Musicality**:
`musically_preferred_deviation: true`).

## Reproducibility

`tools/regressionCheck.m` confirms the frozen Phase A baseline still re-renders at
−120…−126 dB against the archived output, because the voice lives in `cfg.voice`
and never touches `cfg.tracks`.
