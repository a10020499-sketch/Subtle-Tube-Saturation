# subtle_saturation — Iteration 0 (baseline)

## Hypothesis
Degenerate Wiener-Hammerstein control (R2-A): pure static `tanh` waveshaper,
`drive_k = 1.0`, H1 = H2 = identity, Dynamic Energy Control bypassed, 4x
oversampling. This is the deliberately-simplest starting model, not a fit.

## Result (vs Saturn 2 Subtle Saturation, default Drive, 96 kHz)
| metric | value | target | note |
|---|---|---|---|
| THD_error | 14.32 dB | < 1.0 | far too much distortion |
| HarmonicProfileError | 34.95 dB | < 2.0 | harmonic magnitudes way off |
| SweepSpectralError | −32.85 dB | < −20 | already passes (low-level sweeps ≈ linear) |
| BroadbandTonalError | −25.22 dB | < −18 | passes |
| AlignmentOffsetStability | 0 samples | ≤ 2 | ✅ DAW compensated plug-in latency |
| NormalizedLoss (v1) | 13.08 | — | baseline reference |

alignment_offset_samples = 0, fractional ≈ 0.

## Diagnosis
`tanh` at unity drive clips hard at the top of the tone battery (0 dBFS) while
Saturn's Subtle Saturation is very gentle → the entire THD/Harmonic error is a
level/drive-scale mismatch, not (yet) a curve-shape or W-H-structure problem.
The sweep metric already passes because the −18 dBFS sweep barely enters the
nonlinearity.

## Next
Iteration 1 = **H4 Drive calibration** (§4.3): fit `drive_k` so the modelled
THD-vs-level curve matches the reference across the tone battery, before touching
curve shape (H2) or Even/Odd Blend (H3).
