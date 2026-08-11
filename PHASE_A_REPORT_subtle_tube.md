# PHASE A REPORT — subtle_tube

**This is a technical baseline, not the final product voice.** Exit reason:
**human_override** (baseline approved as "close enough" per the Primary Goal),
technical thresholds not fully met. Tag: `subtle_tube-v1.0-saturn-baseline-approved`.

## Model (final Phase A configuration)

Symmetric static waveshaper + **envelope-driven bias drift** (H8) — the tube's
defining dynamic character:

- Pre-EQ H1 = identity, Post-EQ H2 = identity (linear filtering ruled out as the
  primary mechanism — see below)
- Waveshaper `signpow`: f(x) = Σ cₚ·sign(x)·|x|^p, p = 1..5
  - coeffs = [0.8158 −0.6526 −0.3029 1.1188 −0.6052]
- **Dynamic bias (H8)**: y = f(x + b(t)), b(t) = depth·env(|x|)^γ
  - depth = 0.0757, γ = 0.850 (compressive envelope→bias mapping)
  - envelope follower attack = release = 30 ms (one-pole LPF of |x| → quasi-DC
    bias so the even harmonics are frequency-independent, as measured)
- Oversampling 4×, output gain 0 dB

## Metrics (loss_version phase_a_loss_v3, magnitude-weighted harmonics)

| metric | value | target | status |
|---|---|---|---|
| THD_error | 1.17 dB | < 1.0 | 0.17 over |
| HarmonicProfileError | 3.58 dB | < 2.0 | 1.58 over (residual in −40…−70 dB H4) |
| SweepSpectralError | −35.69 dB | < −20 | ✅ pass |
| AlignmentOffsetStability | 0 samples | ≤ 2 | ✅ |
| NormalizedLoss | 1.281 | ~1 | near target |

Audible harmonics match well: H2 error ~1.7 dB, H3 ~1.2 dB at 1 kHz.

## What was learned (this is where the tube ≠ saturation story lives)

- **Subtle Tube is not a static curve.** A memoryless asymmetric polynomial
  leaves 4.5 % residual with near-zero even coefficients despite strong even
  harmonics; the input→output map shows hysteresis.
- **The memory is nonlinear (H8), not a linear filter (H6).** The hysteresis loop
  width grows ~6× with level at fixed frequency — a linear filter would give a
  level-independent loop (it scales with amplitude). The loop peaks near a
  follower time-constant frequency and the even harmonics are frequency-
  independent. Conclusion: an asymmetric operating point set by an
  **envelope-driven bias drift** — the classic valve grid-bias / coupling-cap
  behaviour.
- **The bias mapping is compressive (γ ≈ 0.85).** Even harmonics fall slower than
  the input amplitude (H2 slope ≈ 0.63, not 1) — the same "always-present subtle
  character" seen at low level in the saturation track.
- **H2/H3/H8** verified; **H6** (linear EQ) ruled out as primary; **H5** fixed
  0 dB; **H1** 4× sufficient; **H9** bypass (Phase A).

## Residual

The remaining HarmonicProfileError is dominated by H4 (and low-level H2) at
−40…−70 dB — audibly minor. An equal-weight dB metric had masked this behind
near-floor H6; the magnitude-weighted v3 metric shows the audible harmonics are
already within ~1–2 dB. Exited by human override rather than grinding the
inaudible orders (Primary Goal).

## Reproducibility (R6)

Deterministic chain (envelope follower has no RNG); metrics re-measure identically
from the committed config.

## Iteration trail

| iter | change | THD | Harm | Sweep | loss_ver |
|---|---|---|---|---|---|
| 0 | baseline tanh k=1 | 4.96 | 28.03 | −25.52 | v1 |
| 1 | diagnostic: dynamic (H8), not static / not H6 | — | — | — | — |
| 2 | H8 envelope-driven bias | 1.66 | 3.77 | −34.47 | v3 |
| 3 | compressive bias γ=0.85 + magnitude-weighted metric | **1.17** | **3.58** | **−35.69** | v3 |

## Carried into Phase B

`subtle_tube-saturn-like` = this configuration, frozen. Phase B voice tuning
proceeds from here per §4.6; Saturn 2 is no longer an optimization target
(R-ReferenceFreeze).
