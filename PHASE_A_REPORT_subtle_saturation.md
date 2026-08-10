# PHASE A REPORT — subtle_saturation

**This is a technical baseline, not the final product voice.** Exit reason:
**human_override** (baseline approved as "close enough" per the Primary Goal),
technical thresholds not fully met. Tag: `subtle_saturation-v1.0-saturn-baseline-approved`.

## Model (final Phase A configuration)

Pure static Wiener-Hammerstein *degenerate* form — a single static waveshaper,
no Pre/Post EQ, no dynamics:

- Pre-EQ H1 = identity, Post-EQ H2 = identity (no W-H filtering needed — see below)
- Dynamic Energy Control = bypass
- Oversampling = 4×, linear-phase FIR
- Waveshaper `signpow`: f(x) = Σ cₚ·sign(x)·|x|^p, p = 1..5
  - powers = [1 2 3 4 5]
  - coeffs = [0.8484 −0.6008 0.5004 −0.5529 0.2171]
  - drive_k = 1.0, bias = 0, asymmetry = 0 (curve already carries Saturn's
    input/output scaling; c1 = 0.848 ≈ −1.4 dB linear-region gain)
- Output gain = 0 dB

## Metrics (loss_version phase_a_loss_v2)

| metric | value | target | status |
|---|---|---|---|
| THD_error | 1.10 dB | < 1.0 | 0.10 over |
| HarmonicProfileError | 2.33 dB | < 2.0 | 0.33 over |
| SweepSpectralError | −55.04 dB | < −20 | ✅ pass (huge margin) |
| BroadbandTonalError | pass | < −18 | ✅ |
| AlignmentOffsetStability | 0 samples | ≤ 2 | ✅ |
| NormalizedLoss | 0.917 | ~1 | at target |

## Verified hypotheses / what was learned

- **H4 (drive)**: no manual k guessing — the curve (with its internal gain) was
  recovered directly from aligned dry→reference sample pairs.
- **H2 (curve form)**: Subtle Saturation is a **symmetric, odd-only** static
  nonlinearity (even harmonics H2/H4 at the −145 dB floor at all levels). A pure
  odd polynomial fails at low level because its lowest term x³ forces THD ∝ A²
  (slope 2), whereas the reference THD grows with slope ≈1 at low level. The
  **odd square-law basis x·|x|** (3rd-harmonic ∝ A²) resolved this; the unified
  `signpow` basis fits the transfer curve to 0.2 % RMS.
- **H6 (W-H EQ)**: **not required.** The recovered curve is frequency-independent
  — THD_error is uniform (~1.07 dB) across 100 Hz–4 kHz (8 kHz 1.28 dB). No
  pre/post EQ was needed to fit either the sweep or the per-frequency THD.
- **H5 (output gain)**: fixed 0 dB; the curve carries the level scaling.
- **H1 (oversampling)**: 4× sufficient; no aliasing artefacts observed.
- **H9 (dynamics)**: bypass in Phase A, as specified.

## Residual error analysis (frequency / level distribution)

The entire remaining error is at **low level**, not at any frequency:

| level | THD_error | | level | THD_error |
|---|---|---|---|---|
| −24 dBFS | 2.26 dB | | −10.5 dBFS | 0.89 dB |
| −20.5 | 2.08 | | −7 | 0.34 |
| −17 | 1.79 | | −3.5 | 0.05 |
| −13.5 | 1.36 | | 0 | 0.05 |

From −7 dBFS up the model matches the reference to ≤ 0.34 dB. The residual sits at
−13…−24 dBFS where the distortion is only 1–2 % (−34…−40 dB) — a subtle,
always-present character of the Subtle mode whose THD-vs-level slope rises from
≈1.0 (low) to ≈1.5 (high), i.e. not perfectly reproducible by a single static
curve. Judged musically irrelevant for a bus saturator, so Phase A was exited by
human override rather than grinding tenths of a dB (per the spec's Primary Goal).

## Reproducibility (R6)

The chain is fully deterministic (no RNG); metrics re-measure identically from the
committed config. A clean-tree re-checkout of the tag is recommended before any
downstream release build.

## Iteration trail

| iter | change | THD | Harm | Sweep | loss_ver |
|---|---|---|---|---|---|
| 0 | baseline tanh k=1 | 14.32 | 34.95 | −32.85 | v1 |
| 2 | recovered odd-poly curve + metric floor gates | 4.02 | 18.82 | −46.02 | v2 |
| 3 | level-balanced refit | 3.49 | 17.55 | −44.17 | v2 |
| 4 | signpow basis (x\|x\| terms) | **1.10** | **2.33** | **−55.04** | v2 |

## Carried into Phase B

`subtle_saturation-saturn-like` = this configuration, frozen. Phase B voice
tuning (Even/Odd Blend, dynamics, etc.) proceeds from here per §4.6; Saturn 2 is
no longer an optimization target (R-ReferenceFreeze).
