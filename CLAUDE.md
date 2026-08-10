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

Iteration −1 scaffold is **complete**: directory tree, `config.m`,
`loop_state.json`, the full `src/` chain, Phase B tools, `.gitignore/.gitattributes`,
and the four `data/dry/` test signals (regenerated from
`tools/generateTestSignals.m`, 48 kHz / 24-bit). Both tracks are **blocked on
R1-A** awaiting user Saturn 2 renders. The multiband layer passes its −60 dB
reconstruction gate. Nothing has been committed to a remote yet (no GitHub repo
created — see spec §6.1; local git only until the user sets up `origin`).
