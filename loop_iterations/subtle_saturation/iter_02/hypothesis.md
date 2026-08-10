# subtle_saturation — Iteration 2 (H2: recovered static curve)

## Hypothesis
Subtle Saturation is a pure static odd waveshaper. Recover f(x) directly from
aligned dry→reference sample pairs (`tools/recoverCurve`, 250 Hz, all 8 levels,
odd-only 9th-order poly) and install it as the waveshaper. drive_k=1, asym=0,
H1=H2=identity, DEC bypass.

Recovered curve: f(x) = 0.788x − 1.072x³ + 1.995x⁵ − 2.164x⁷ + 0.866x⁹
(sample-domain rel-RMS residual 0.7%).

## Metric change this iteration (loss v1 → v2)
Discovered `HarmonicProfileError` was inflated by floor-vs-floor dB comparison of
absent even harmonics (H2/H4/H6 sit at −145…−167 dB in both model and reference,
but their dB difference is pure noise). Added floor gates to `analyzeAndCompare`:
harmonics scored only if either side > −80 dB rel fund; THD segments scored only
if reference THD > −70 dB. `loss_version = phase_a_loss_v2`. v1/v2 Loss are not
directly comparable.

## Result (loss_v2)
| metric | Iter-0 (v1) | Iter-2 (v2) | target |
|---|---|---|---|
| THD_error | 14.32 | 4.02 | < 1.0 |
| HarmonicProfileError | 34.95 | 18.82 | < 2.0 |
| SweepSpectralError | −32.85 | **−46.02** | < −20 ✅ |
| BroadbandTonalError | −25.22 | −27.83 | < −18 ✅ |
| Alignment | 0 / stable | 0 / stable | ≤ 2 ✅ |

Marked **improved** on raw sub-metrics (loss_version changed, so NormalizedLoss
not directly comparable to Iter-0 per R-Loss).

## Diagnosis (the residual is level-localised)
Per-level THD error @ 1 kHz: 0 dBFS 0.1 dB, −3.5 0.2, −7 0.6, −10.5 0.8, −13.5
2.9, −17 5.9, −20.5 9.2, −24 12.6. The model is essentially exact from −10 to
0 dBFS (the region a saturator is actually driven) but **under-distorts at low
level**. Reference THD-vs-level slope rises from ≈1.0 (low) to ≈1.5 (high),
whereas a static saturating curve has slope ≈2 at low level falling as it
saturates — the opposite trend. So the low-level excess is **not reproducible by
a single static curve**; it is a subtle always-present character of the Subtle
mode (candidate mechanisms: near-origin curvature richer than the global fit,
or a small level-independent/dynamic term).

## Next options
1. Iter-3: bin-averaged curve refit (equal weight per amplitude bin) to capture
   near-origin curvature the RMS fit under-weights — cheap, should cut low-level
   error materially.
2. If (1) plateaus: accept per Primary Goal (match is exact where driven; the
   mismatch is at −13…−24 dBFS, ≈0.5% THD) and Human-Override toward Phase B, or
   model the low-level term explicitly (small W-H / dynamic component).
