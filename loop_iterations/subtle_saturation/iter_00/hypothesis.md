# Reference Asset Gate (R1-A) - track `subtle_saturation`

Status: **awaiting_reference_assets**. This track cannot start Phase A
Iteration 0 until the Saturn 2 reference renders below exist.

## Files to render and place in `F:\Matlab Project\Saturation_0811\data\reference\subtle_saturation`

- [ ] `01_tone_battery.wav`
- [ ] `02_log_sweep_moderate_-18dBFS.wav`
- [ ] `03_log_sweep_hot_-3dBFS.wav`
- [ ] `04_pink_noise_broadband_-12dBFS.wav`

## Render recipe (SPECIFICATION 4.3)

- Load Saturn 2 on a single band, Full Range, Solo that band.
- Mode = **subtle saturation** (this track).
- Wet/Mix = 100%. Use the mode DEFAULT Drive value (do not adjust).
- Project 48 kHz / 24-bit to match the dry files.
- Record every panel value in `render_manifest_template.csv`.
- Keep filenames identical to the dry files.
