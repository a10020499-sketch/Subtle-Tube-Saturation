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

## The gate that is currently blocking everything — R1-A

Both coloration tracks are at `status: awaiting_reference_assets`. Phase A
**cannot start** until the user renders the four dry files through Saturn 2 and
drops them, with identical filenames, into:

- `data/reference/subtle_saturation/`
- `data/reference/subtle_tube/`

`run_pipeline` enforces this: if any reference file is missing it writes the
needed-file list to `loop_iterations/<track>/iter_00/hypothesis.md`, sets the
status, and **halts** — it must not spin (R1-A anti-spin). See
`render_manifest_template.csv` for the render recipe.

## Run one iteration (once references exist)

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

**Phase A COMPLETE for both tracks** (human_override saturn-like baselines, tagged
`subtle_saturation-v1.0-saturn-baseline-approved`, `subtle_tube-v1.0-saturn-baseline-approved`).
Remote: `github.com/a10020499-sketch/Subtle-Tube-Saturation` (public, LFS). Dry set
is 96 kHz.

- **subtle_saturation**: static `signpow` odd curve (the `x|x|` square-law term is
  the key to low-level THD; W-H EQ H6 not needed). THD 1.10 / Harm 1.69 / Sweep −55.
- **subtle_tube**: `signpow` base + **H8 envelope-driven compressive bias**
  (γ=0.85). Tube memory is nonlinear (loop grows with level), not a linear filter.
  THD 1.17 / Harm 3.58.
- Metric evolved v1→v3 (floor gates, then magnitude-weighted HarmonicProfileError).
- Both tracks `phase=voice_tuning`, `voice_stage=saturn_like`.
- **Multiband tool scaffold complete**: `multibandProcess`/`runMultiband` +
  expanded `verifyMultiband` (all §5.3 gates pass; bypass recon −185 dB). Default
  4 bands, crossovers 250/1k/4k Hz (config 2–6). Final integration still gated on
  both `voice_signoff.final`.

**Next = Phase B (Voice Tuning, §4.6)**: needs user program material in
`data/program_material/` (vocal/bass/drumbus/mixbus) + human loudness-matched
listening. Saturn 2 is frozen (R-ReferenceFreeze).

Extra tooling beyond spec: `tools/fitDrive.m`, `tools/recoverCurve.m`
(basis oddpoly/genpoly/signpow), `tools/fitTube.m` (H8 fit),
`src/multibandProcess.m`, `src/runMultiband.m`.
