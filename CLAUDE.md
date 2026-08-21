# CLAUDE.md — Task Protocol Entry Point

Loop Engineering task protocol for the **FabFilter Saturn 2 Subtle Saturation /
Subtle Tube Multiband Colorizer**. The full specification is
[SPECIFICATION.md](SPECIFICATION.md); this file is the operating manual for the
code in this repository.

## Start here, every session

1. Read `loop_state.json`. It is the single source of truth: per-track `phase`,
   `current_iteration`, `best_metrics`, `status`, and the hypothesis queue.
   **[R0]** — never infer loop state from memory or the working tree.
2. `git log --oneline` reconstructs the experiment history; every commit message
   carries its own metrics (section 6.3 of the spec).

## The R1-A reference-asset gate

The Saturn 2 reference renders are in place, so this gate is satisfied and both
tracks have completed Phase A. `run_pipeline` still enforces it: if any reference
file goes missing it writes the needed-file list to
`loop_iterations/<track>/iter_00/hypothesis.md`, sets
`status: awaiting_reference_assets`, and **halts** rather than spinning. See
`render_manifest_template.csv` for the render recipe that produced them.

## Run one Phase A iteration

```bash
matlab -batch "addpath('src'); run_pipeline('subtle_saturation')"
```

`run_pipeline('<track>')` reads `config.m` + `loop_state.json`, clears the R1-A
gate, renders the dry set through the coloration core, and calls
`analyzeAndCompare('<track>', iterId)` which writes
`loop_iterations/<track>/iter_<ID>/metrics.json`.

## Layout

| Path | Role |
|---|---|
| `config.m` | **The only file an iteration edits.** Paths, per-track DOF, targets, loss weights. |
| `src/run_pipeline.m` | Entry point: state → R1-A gate → process → measure |
| `src/processSignal.m` | Full W-H chain (preEQ→shaper→DEC→postEQ+oversampling), scored without writing WAVs |
| `src/saturationCore_subtle{Saturation,Tube}.m` | Mode-named cores over `processSignal` |
| `src/waveshaper.m` | Static nonlinearity f(k·x) + Even/Odd Blend (H2/H3) |
| `src/preEQ.m` / `src/postEQ.m` / `src/biquadEQ.m` | W-H filters H1/H2 (H6), identity by default |
| `src/dynamicEnergyControl.m` | H9 umbrella; Phase A bypass, soft-compression implemented |
| `src/crossoverBank.m` | LR4 perfect-reconstruction split (multiband layer) |
| `src/dryWetMixer.m` / `src/bandSummary.m` | Per-band blend + summation |
| `src/multibandProcess.m` | Top-level multiband tool (crossover→per-band color/drywet→sum) |
| `src/runMultiband.m` | File entry point for the multiband tool |
| `src/analyzeAndCompare.m` | THD / harmonic / sweep / broadband metrics + NormalizedLoss |
| `src/harmonicSeparation.m` | Farina sweep harmonic deconvolution |
| `src/subsampleAlign.m` | Integer + fractional-sample alignment (R4) |
| `src/verifyMultiband.m` | −60 dB reconstruction + dry/wet endpoint gates (5.3) |
| `tools/generateTestSignals.m` | Regenerate `data/dry/` (reproducibility) |
| `tools/renderListeningSet.m` | Phase B loudness-matched listening set (R-ListeningProtocol) |
| `tools/createBlindListeningManifest.m` | Phase B anonymised A/B set |

## The rules that bind every iteration

- **R0** Read `loop_state.json` first.
- **R1** No path or tunable constant inside an algorithm function — edit `config.m`.
- **R1-A** No reference asset → set `awaiting_reference_assets`, list needed files, **halt** (no spinning).
- **R2** No locked Saturn 2 target values exist; the only fixed target is the measured reference render.
- **R3** One variable per iteration (Phase A). On regression, return to the last best commit.
- **R4** Sub-sample align (integer + fractional) before any metric; record both offsets.
- **R5** No credential/token in any committed file, message, log, or report.
- **R6** Re-checkout the tag in a clean tree and re-run before declaring convergence / sign-off.

## Two phases

- **Phase A — Saturn Matching** (machine-convergent). Targets (5.1): THD_error
  < 1.0 dB, HarmonicProfileError < 2.0 dB, SweepSpectralError < −20 dB.
  `improved/regressed` decided by versioned `NormalizedLoss` (R-Loss).
- **Phase B — Voice Tuning** (human-in-the-loop). After a track enters
  `voice_tuning`, Saturn 2 stops being an optimization target (R-ReferenceFreeze);
  loudness-matched listening is mandatory (R-ListeningProtocol); "measures worse
  but sounds better" changes are kept and tagged `musically_preferred_deviation`
  (R-Musicality). Human sign-off gates `enhanced → final` (R-VoiceGate).

## Commit message format (6.3)

```
[<track>-Iter-<ID>] <summary> | THD_error=<v>dB | HarmonicProfileError=<v>dB | SweepSpectralError=<v>dB | <improved|regressed|converged>
```
`<track>` ∈ `subsat` / `subtube` / `multiband`.

## Current state — read this before resuming

**PHASE A and PHASE B are both COMPLETE.** Remote:
`github.com/a10020499-sketch/Subtle-Tube-Saturation`. Dry set is 96 kHz; programme
material and probes are 48 kHz.

### The two shipped voices (tags `subtle_*-v1.0-final`)

The frozen Phase A baselines stay in `cfg.tracks.<t>.dof` so `tools/regressionCheck.m`
and the R6 check keep meaning something. The voices the product ships are separate,
in `cfg.voice.<t>.final`, and `multibandProcess` resolves them via `coreDof()`.

| | subtle_tube (F2_Z2) | subtle_saturation (Y1) |
|---|---|---|
| drive_k | 1.30 | 1.65 |
| dynamic bias | depth 0.1665, γ 0.85 | n/a (symmetric curve) |
| HF-clean split | 8 kHz, β 0.75, follow 1.0 | 8 kHz, β 0.50, follow 1.0 |
| transient preserve | depth 1.0 | off |
| post-EQ | identity | two high shelves @8 kHz, +3.0 and +2.5 dB |
| dynamics (H9) | bypass | upward 1.5:1 @ −30 dB, 2/300 ms |

`PHASE_B_REPORT_*.md` records how every value was arrived at, the two defects found
mid-phase (curve fold-back above the measured range; the transient detector idling
open and silently removing half the saturation on sustained material), and the one
question the measurements could not settle (bias 2.20 vs 1.85 punch — 0.2 dB of
masking, single-trial blind A/B, listener's choice kept).

### Verification status — all green

| gate | result |
|---|---|
| Phase A regression (`tools/regressionCheck.m`) | PASS, −119.4…−126.4 dB |
| R6: clean checkout of the tag vs working tree | PASS, −125.6…−128.3 dB |
| Multiband bypass / crossover reconstruction | −185.4 dB (gate −60) |
| Per-band Wet=0% / Wet=100% | −168.5 / −168.9 dB (gate −80) |
| Mixed-mode render | finite, bounded, click-free |
| Drive headroom (`tools/checkDriveHeadroom.m`) | clamp 0.10% tube / 0.52% saturation, no fold-back |

Caveat worth knowing: running `regressionCheck` *inside* a clean clone reports
"no archive" and proves nothing, because `output/` is gitignored. The meaningful R6
proof is the sample-exact comparison of the final renders listed above.

### What is next

`multiband_tool` is **ready** and already loads the final voices. Open tool-design
item: driven hard, a hot programme peaks at 0.92 through the tube path, so the tool
wants an output trim / gain-staging control before real use. Per-band Drive and
Dry/Wet already exist; crossover default is 4 bands at 250 / 1k / 4k Hz (2–6
configurable in `config.m`).

Extra tooling beyond what the spec names: `fitDrive`, `recoverCurve`, `fitTube`,
`diagnoseAliasing`, `evalHFOptions`, `voiceMetrics`, `punchScore` (the TAG metric),
`attackClarity`, `tiltReport`, `clampOf`, `nlB`, `hh`, `checkDriveHeadroom`,
`regressionCheck`, `generateSpectrumProbes`, `renderVoiceVariants`, plus the
`setTP` / `setDuck` / `setBD` / `withEQ` / `withUpward` / `hfVariant` / `lfVariant`
config helpers.
