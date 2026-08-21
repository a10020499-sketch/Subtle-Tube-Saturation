# PHASE B REPORT — subtle_tube

Voice tuning complete. Signed off by the listener at voice iteration 10, variant
**F2_Z2**. Tag: `subtle_tube-v1.0-final`.

Per **R-ReferenceFreeze**, Saturn 2 stopped being an optimisation target the moment
this track entered `voice_tuning`. The Phase A technical metrics below are recorded
as history, not as a score.

## Final configuration (`cfg.voice.subtle_tube.final`)

| stage | setting |
|---|---|
| Waveshaper | `signpow`, powers [1..5], coeffs [0.8158 −0.6526 −0.3029 1.1188 −0.6052] |
| Drive | `drive_k = 1.30` |
| Dynamic bias (H8) | depth `0.0757 × 2.20 = 0.1665`, γ = 0.85, attack = release = 30 ms |
| Bias transient duck | 0 (built and measured, listener chose the version without it) |
| HF-clean split | 8 kHz, β = 0.75, follow = 1.0 (1 ms / 30 ms), gain-matched |
| Transient preserve | depth 1.0, knee 3 dB, range 8 dB, fast release 8 ms, slow 80/250 ms |
| Pre-EQ | identity |
| Post-EQ | identity |
| Dynamic Energy Control | bypass |
| Oversampling | 4× |

## The three levers this track gained in Phase B, and why

**1. HF-clean split.** The listener's first note was that both models sounded
"digital / prickly (麻) in the highs". Two candidate causes were ruled out by
measurement before anything was changed: aliasing (−130 dB for 2–8 kHz tones; ×4
oversampling differs from a ×32 gold reference by −74.8 dB on real material) and a
modelling error (the model tracks the Saturn reference within 0.02–0.04 dB in every
octave band). The grit is intermodulation between HF partials — Saturn's own
character, faithfully reproduced. Keeping the top octaves out of the nonlinearity
cut the 8–20 kHz nonlinear residual by 6–18 dB. A pre/post emphasis pair was tried
first and rejected: it made the residual *worse*, because the post-shelf
re-amplifies the HF products generated from mid content.

**2. Density follow + β.** The split cost body: loudness-matched crest went 7.46 →
11.10 dB on EDM, i.e. ~3.6 dB less dense, because HF transients bypassed the curve
entirely. Mid-band RMS moved only 0.05 dB, so it was density, not tone. β returns
part of the HF band to the curve; `follow` modulates the *clean* band by the gain
reduction the curve is applying, restoring peak compression while generating no HF
harmonics. Together they recovered most of the gap for 0.9 dB of the cleanliness.

**3. Transient preserve.** The listener asked for more kick impact but explicitly
rejected solving it by hardwiring a frequency range to bypass saturation — that
decision belongs to the multiband layer. So the punch lever is frequency-agnostic:
an attack is detected from the ratio of a fast to a slow *peak* follower and the
output leans toward the linear path for those milliseconds only.

TAG (attack-band gain minus sustain-band gain, both referenced to dry; higher is
punchier, 0 is punch-neutral):

| depth | Epic_Drum | Drum_Test |
|---|---|---|
| off | −0.62 | −0.20 |
| 0.5 | +0.07 | +0.57 |
| 0.7 | +0.32 | +0.85 |
| **1.0 (shipped)** | **+0.68** | **+1.24** |

## Character: the two levers are orthogonal

Measured at 1 kHz: drive ×1.30 moves H3 −29.0 → −26.6 dB with H2 unchanged; bias
×1.25 moves H2 −38.7 → −36.8 dB with H3 unchanged. That is why "the breakup is
enough, give me 30% more warmth" was directly dialable — bias ×1.40 → ×1.85 → ×2.20
walked H2 to −32.0 dB while H3 stayed at −26.7.

## Two defects found and fixed during Phase B

- **Curve fold-back.** The fitted polynomial turns over at |u| = 1.0261 and beyond
  it more input gave *less* output with inverted slope — wave folding, landing on
  the loudest transients. One audition set (T2/T3) was affected and withdrawn. Now
  the curve is joined at |u| = 1.0 (the top of the measured range, so the Phase A
  match is untouched) to a monotone asymptotic continuation; verified minimum slope
  +6.4e−6 over u = 0..3, and output at u = 1.0/1.5/2.0/3.0 is
  0.374/0.398/0.415/0.430 where the old clamp sat flat at 0.374. This is what gives
  Drive real travel.
- **Transient detector idled open.** The first version used two symmetric one-pole
  envelopes, so the fast one settled on the peak and the slow one on the mean; for a
  sine those differ by π/2, the ratio idled at 1.26 and half the saturation was
  silently blended away on sustained material (H3 on a steady tone fell 9.1 dB).
  Both detectors are now true peak followers, so the ratio idles at 1 and the steady
  state is preserved to 0.25 dB — and the fix *improved* punch as well
  (+0.23/+0.25 → +0.68/+1.24).

## The one thing the measurements could not settle

The listener preferred bias 2.20's warmth but heard bias 1.85 as punchier. TAG says
the transient is identical (0.88 vs 0.89). A blind A/B was run per
R-ListeningProtocol and they again picked the shallower bias — but a single two-way
trial has a 50 % guess rate, so this is weak evidence. The masking hypothesis was
tested with `tools/attackClarity.m`: the difference is real but only **0.2 dB**, at
or below reliable audibility. A `transient_duck` lever was built that delivers 2.20's
warmth with better-than-1.85 attack clarity (H2 −32.7, clarity −18.1); the listener
auditioned it and chose the plain 2.20 anyway. Recorded, not overridden.

## Phase A metrics, for the record only (R-ReferenceFreeze)

THD_error 1.17 dB · HarmonicProfileError 3.58 dB · SweepSpectralError −35.69 dB
(loss_version `phase_a_loss_v3`). The final voice deliberately departs from these —
drive ×1.30 and bias ×2.20 alone put it far from the Saturn match. That is the
intended outcome, not a regression (**R-Musicality**: `musically_preferred_deviation:
true`).

## Reproducibility

`tools/regressionCheck.m` confirms the frozen Phase A baseline still re-renders at
−119…−126 dB against the archived output, because the voice lives in `cfg.voice`
and never touches `cfg.tracks`.
