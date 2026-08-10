# subtle_saturation — Iteration 4 (H2: signpow basis)

## Hypothesis
The low-level under-distortion (Iter-2/3) is because a pure odd polynomial's
lowest term x³ forces 3rd-harmonic ∝ A³ (THD slope 2), while the reference shows
THD slope ≈1 at low level → H3 ∝ A². The odd, degree-2-homogeneous term **x·|x|**
supplies exactly that. Fit the unified basis f(x) = Σ c_p·sign(x)·|x|^p, p=1..5
(odd powers → x^p; even powers → x|x|^(p-1)), level-balanced.

Recovered: powers [1 2 3 4 5], coeffs [0.8484 −0.6008 0.5004 −0.5529 0.2171],
fit rel-RMS 0.0020 (vs 0.0082 odd-poly); per-level residual ≤ 0.007.

## Result (loss_v2)
| metric | Iter-3 | Iter-4 | target |
|---|---|---|---|
| THD_error | 3.49 | **1.10** | < 1.0 |
| HarmonicProfileError | 17.55 | **2.33** | < 2.0 |
| SweepSpectralError | −44.17 | **−55.04** | < −20 ✅ |
| BroadbandTonalError | — | (see metrics) | < −18 |
| NormalizedLoss | 5.45 | **0.917** | ~1 |

**improved** (same loss_version v2 as Iter-2/3, directly comparable). Loss fell
5.45 → 0.917. Sweep and Broadband pass; THD and Harmonic are 0.10 / 0.33 dB over
threshold — essentially at the (deliberately relaxed) Phase A target.

## Status
Near technical convergence. Remaining residual is the last sliver of low-level /
high-frequency curve error. Per Primary Goal + the spec's "don't grind Phase A"
rule, one small refinement (higher signpow order, or folding more probe
frequencies into the fit) would cross the line; otherwise this is an acceptable
saturn-like baseline.
