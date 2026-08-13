# Phase A Measurement Findings

Black-box characterisation of the Saturn 2 reference renders (default Drive,
96 kHz, single band full-range, 100% wet). Diagnostic sub-metrics per §5.2.
Measurement validated: dry-signal THD is −135…−157 dB, so all figures below are
real plug-in behaviour, not measurement floor.

## Iteration 1 — harmonic structure @ 1 kHz

| track | level | THD | H2 (even) | H3 (odd) | H4 (even) | H5 (odd) |
|---|---|---|---|---|---|---|
| subtle_saturation | −24 dBFS | −44.9 | −142.7 | −44.9 | −146.3 | −61.8 |
| subtle_saturation |   0 dBFS | −16.5 | −149.8 | −16.6 | −166.5 | −33.5 |
| subtle_tube | −24 dBFS | −37.4 | −45.8 | −38.1 | −79.2 | −54.5 |
| subtle_tube |   0 dBFS | −18.1 | −29.9 | −18.8 | −43.4 | −29.7 |

(all harmonic columns are dB relative to the fundamental)

### Conclusions

1. **Subtle Saturation is a symmetric, odd-only nonlinearity.** Even harmonics
   (H2, H4) sit at the −145 dB measurement floor across the whole level range;
   only odd orders (H3, H5) are present. The tanh family is the correct waveshaper
   family; `asymmetry` and `bias` should be ≈ 0 for this track.

2. **Subtle Tube is asymmetric with strong even harmonics.** H2 is comparable to
   H3 (at 0 dBFS H2 = −30 dB, H3 = −19 dB; H4 also present at −43 dB). This is the
   classic valve signature and confirms `asymmetry`/`bias` (H3) — and later the
   dynamic-bias question (H8) — as the primary tube levers.

3. **Both curves grow gentler than tanh.** Reference THD rises ≈ +12 dB per +10 dB
   input, whereas a static tanh grows ≈ +20 dB / +10 dB (square law). A single
   `drive_k` therefore cannot fit the whole level range with tanh — `fitDrive`
   pins k to the grid ceiling and leaves a large low-level residual. This is an
   H2 curve-shape signal, not merely a drive-scale one: the waveshaper needs a
   softer onset (e.g. a shape parameter, a gentler function than tanh, or a
   drive-dependent term).

### Implication for the search (updates §3.2-C ordering rationale)

- saturation: fit a symmetric curve whose THD-vs-level slope matches (H2), with
  even-harmonic levers held at zero. `drive_k` (H4) is fitted jointly with the
  shape parameter, not before it.
- tube: fit the symmetric part first, then set the even/odd balance (H3) to match
  the measured H2/H3 ratio and its growth with level; only then probe H8.

## subtle_tube — static-vs-dynamic (Iter-1 diagnostic)

Unlike Subtle Saturation, Subtle Tube is **not** a clean static curve:

- A general polynomial (even+odd, order 7, level-balanced) recovers the transfer
  curve with only 4.5 % rel-RMS residual (vs 0.2 % for saturation), and returns
  near-zero even-power coefficients despite the reference clearly having strong
  even harmonics — i.e. a memoryless asymmetric curve cannot explain the data.
- The input→output scatter shows **hysteresis**: at 0 dBFS/250 Hz the output on a
  rising edge differs from a falling edge at the same input by ~2 % of range.
  Even a rich static basis (order 7 + x|x| + x|x|³) leaves 4 % residual at a
  single level.

### H6 (linear filter) vs H8 (dynamic bias) discriminator

Loop width (rising−falling output at ±0.5·A, as % of output range):

| level @250 Hz | loop % | H2 |   | freq @0 dBFS | loop % | H2 |
|---|---|---|---|---|---|---|
| −20.5 | 0.36 | −43.5 | | 100 Hz | 1.32 | −30.8 |
| −13.5 | 0.56 | −37.8 | | 250 Hz | 2.04 | −30.3 |
| −7 | 1.01 | −33.5 | | 1000 Hz | 0.76 | −29.9 |
| 0 | 2.04 | −30.3 | | 4000 Hz | 0.55 | −30.2 |

**The loop grows ~6× with level** at fixed frequency. A linear filter (H6) would
give a level-independent loop-%-of-range (it scales with amplitude), so the
memory is **nonlinear → H8**. The loop peaks near 250 Hz and falls at HF (a
follower time-constant signature, not a static filter's monotonic phase), and H2
is frequency-independent. Conclusion: Subtle Tube = an **asymmetric static
nonlinearity with an envelope-driven bias drift** (H8). W-H linear EQ is not the
primary mechanism (though a small static tone EQ is not excluded).

## Phase B — the "harsh / fizzy highs" investigation (voice iter 01)

### What the fizz is not
- **Not aliasing.** −130 dB alias energy for 2–8 kHz tones, −70 dB at 11 kHz, and
  oversampling ×4 differs from an ×32 gold reference by −74.8 dB on real EDM.
  (The §3.6 mapping table names aliasing first for this description; measuring it
  first is exactly the caveat that table carries.)
- **Not a modelling error.** Per octave band on pink noise the model tracks the
  Saturn reference within 0.02–0.04 dB. The character is Saturn's own, faithfully
  reproduced — so R-ReferenceFreeze applies and deviating is the intended move.
- **Not HF harmonic generation.** At 48 kHz a single 8 kHz tone through an
  odd-only curve produces no in-band harmonics at all (H2 ≈ 0, H3 at Nyquist).

### What it is
Intermodulation between simultaneous HF partials — inharmonic products, which is
what "fizzy/prickly" describes. Cured by keeping HF out of the nonlinearity.

### Independent review — what survived and what did not
A four-way independent analysis (metric critique / mechanism ranking / fix design
/ adversarial) was run against this work. Outcomes, each settled by measurement:

| review claim | verdict |
|---|---|
| `smooth_eps` branch is broken — it smooths p=1 too, collapsing `c1·u` to a dead zone | **CONFIRMED, fixed.** Rewritten as `Σ c_p·u·(u²+ε²)^((p−1)/2)`, exact for p=1 |
| The two-tone IMD figure overstates the split's benefit (both tones sit above the crossover) | **CONFIRMED.** Honest figure is the projection residual: 6–18 dB, not 50 dB. Headline numbers already used the residual |
| Use a true LR4 pair instead of the telescoping complementary split | **REJECTED.** A true pair sums to an allpass: measured 39.65 dB of comb ripple through a 50 % dry/wet blend versus 0.00 dB for the complementary form. That would wreck the multiband layer's per-band Dry/Wet — a constraint the review did not weigh. Kept complementary; `split_type='lr4'` remains available |
| The complementary form brightens 2–4 kHz by +2.36 dB | **REFUTED.** Measured +0.21…+0.30 dB. The review's figure came from a reproduction without `gain_match`; the shipped path has always had it |
| Saturated path vs clean path are misaligned by the resample round trip | **REFUTED.** Measured path delay 0 samples |
| Eval tool and production chain diverge (`runChain` added `hi` at unity) | **CONFIRMED, fixed.** `runChain` now calls `processSignal` itself |
| β partial drive (let a fraction of HF still saturate) | **ADOPTED** as a continuous control; β = 0 is the hard split, β = 1 the baseline |

Residual note: the linearised null sits at −18.3 dB rather than −60 dB, and the
16–24 kHz row explains it — the unsplit reference loses 1.07 dB up there to the
resample anti-alias rolloff while the split's clean path bypasses it. The
difference is above 16 kHz and makes the split *more* transparent, not less.

### Gates added
`src/verifySplit.m` (null with the waveshaper linearised, effective-EQ tilt,
path delay, dry/wet coherence) and `tools/regressionCheck.m` (frozen Phase A
baselines must re-render bit-identically under any Phase B change).

## Tooling

`tools/fitDrive.m` — fast static-curve `k` fit from the reference THD-vs-level
curve (no full-pipeline render); returns the per-level residual that exposes the
curve-shape mismatch above.
