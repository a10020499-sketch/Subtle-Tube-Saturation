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

## Tooling

`tools/fitDrive.m` — fast static-curve `k` fit from the reference THD-vs-level
curve (no full-pipeline render); returns the per-level residual that exposes the
curve-shape mismatch above.
