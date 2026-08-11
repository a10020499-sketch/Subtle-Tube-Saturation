# subtle_tube — Iteration 2 (H8: envelope-driven bias)

## Hypothesis
Tube = symmetric signpow base curve f(x) + envelope-driven bias drift:
y = f(x + depth·env(|x|)). The bias produces even harmonics and their level
growth; attack==release makes the follower a one-pole LPF of |x| settling to
depth·(2A/π), i.e. a quasi-DC bias giving frequency-independent even harmonics
(as measured). Base curve + depth fitted by `tools/fitTube` against the reference
per-segment H2..H5 profile.

Config: shaper signpow powers [1..5] coeffs [0.9586 −0.7593 −0.3636 1.2168 −0.6519],
dynamic_bias depth 0.0615, attack=release=30 ms.

## Result (loss_v2)
| metric | Iter-0 (v1) | Iter-2 (v2) | target |
|---|---|---|---|
| THD_error | 4.96 | **1.66** | < 1.0 |
| HarmonicProfileError | 28.03 | **7.13** | < 2.0 |
| SweepSpectralError | −25.52 | **−34.47** | < −20 ✅ |
| NormalizedLoss | 8.60 (v1) | **2.32** | ~1 |

**improved** (loss_version differs from Iter-0; raw sub-metrics all improved
substantially). H8 dynamic-bias structure confirmed as the right tube model.

## Next
Locate the residual Harmonic error (7.13). Expected: low-level H2 falls a little
too fast (bias ∝ A gives H2 slope ~1 vs reference ~0.63 — the same "subtle-mode
always-on" low-level character seen in saturation), plus possible attack/release
tuning for the sweep. Refine base curve / bias-vs-level mapping next.
