# subtle_tube — Iteration 0 (baseline)

## Hypothesis
Degenerate Wiener-Hammerstein control (R2-A): static `tanh` waveshaper,
`drive_k = 1.0`, `asymmetry = 0.10` (tube starting lean toward even harmonics),
H1 = H2 = identity, Dynamic Energy Control bypassed, dynamic bias (H8) OFF,
4x oversampling. Simplest tube-leaning starting model, not a fit.

## Result (vs Saturn 2 Subtle Tube, default Drive, 96 kHz)
| metric | value | target | note |
|---|---|---|---|
| THD_error | 4.96 dB | < 1.0 | too much distortion, but closer than saturation baseline |
| HarmonicProfileError | 28.03 dB | < 2.0 | profile off |
| SweepSpectralError | −25.52 dB | < −20 | already passes |
| BroadbandTonalError | see metrics.json | < −18 | — |
| AlignmentOffsetStability | 0 samples | ≤ 2 | ✅ |
| NormalizedLoss (v1) | 8.60 | — | baseline reference |

## Diagnosis
Same level/drive-scale mismatch as the saturation track, milder here (the Subtle
Tube reference carries more harmonic energy at default Drive than Subtle
Saturation does). Curve-shape and dynamic-bias (H8) questions cannot be judged
until `drive_k` is calibrated.

## Next
Iteration 1 = **H4 Drive calibration** (§4.3): fit `drive_k` from the THD-vs-level
curve, then H2 (curve form) / H3 (Even/Odd Blend). H8 dynamic bias stays OFF
until the static model is stable enough to isolate its effect (per 3.2-C).
