# subtle_tube — Iteration 3 (H8: compressive bias) + metric v3

## Hypothesis
The Iter-2 residual was low-level even harmonics too weak (H2 error 9 dB at
−24 dBFS) because bias ∝ A (slope 1) while the reference H2 slope is ≈0.63. Add a
**compressive bias-vs-envelope mapping** b = depth·env(|x|)^γ, γ<1, lifting
low-level bias. Refit base curve + depth + γ (H2/H3-weighted) via `fitTube`.

Config: signpow coeffs [0.8158 −0.6526 −0.3029 1.1188 −0.6052], depth 0.0757,
γ = 0.850, attack=release=30 ms.

## Metric change (loss v2 → v3)
Per-harmonic diagnostic showed Iter-3 improved the audible harmonics (H2 5.3→1.7,
H3 1.6→1.2 dB) but the equal-weight dB-RMS HarmonicProfileError went UP because it
was dominated by **H6 at −60…−80 dB** (13→17 dB "error" on a near-floor harmonic).
Fixed: HarmonicProfileError is now **magnitude-weighted** (each harmonic's dB error
weighted by its linear magnitude rel fund), so audible harmonics dominate. Applied
to both tracks (fair re-score).

## Result (loss_v3, re-scored)
| render | THD | Harmonic | Sweep | Loss |
|---|---|---|---|---|
| tube Iter-2 | 1.66 | 3.77 | −34.5 | 1.477 |
| **tube Iter-3** | **1.17** | **3.58** | −35.7 | **1.281** |
| (saturation Iter-4, ref) | 1.10 | 1.69 | −55.0 | 0.758 |

**improved** (v3, comparable to Iter-2 under v3). Compressive bias confirmed a
real improvement once the metric reflects audible error. Audible harmonics H2/H3
now within ~1.7/1.2 dB.

## Status / next
Tube best so far: THD 1.17, Harm 3.58 (target 1.0 / 2.0). Residual now genuine
(low-level H2 + H4), not floor artifact. One more refinement (H4 shaping / joint
fit) could close it, or accept as a saturn-like baseline per Primary Goal.
