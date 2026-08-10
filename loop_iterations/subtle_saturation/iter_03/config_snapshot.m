function cfg = config()
%CONFIG  Single source of truth for paths and tunable parameters.
%   SPECIFICATION R1: no path or algorithm constant may be hard-coded inside a
%   function body. Iterations edit THIS file (and, in Phase B, the per-track
%   voice levers), never the algorithm modules in src/.
%
%   Everything the loop is allowed to search lives under cfg.tracks.<t>.dof.
%   Panel-equivalent "targets" do not exist in this project: there are no Saturn 2
%   internal parameters to lock to (SPECIFICATION R2, black-box version). The only
%   fixed target is the measured reference render.

    here = fileparts(mfilename('fullpath'));
    cfg = struct();
    cfg.repo_root = here;

    % ---- paths (R1: centralised) -------------------------------------------
    cfg.paths = struct();
    cfg.paths.dry            = fullfile(here, 'data', 'dry');
    cfg.paths.reference      = fullfile(here, 'data', 'reference');       % + <mode>/<file>
    cfg.paths.program        = fullfile(here, 'data', 'program_material');
    cfg.paths.output         = fullfile(here, 'output');                  % + <track>/...
    cfg.paths.loop_iters     = fullfile(here, 'loop_iterations');         % + <track>/...
    cfg.paths.logs           = fullfile(here, 'logs');
    cfg.paths.dry_manifest   = fullfile(here, 'data', 'dry', 'dry_signal_manifest.json');
    cfg.paths.loop_state     = fullfile(here, 'loop_state.json');

    % ---- global audio ------------------------------------------------------
    cfg.audio = struct();
    cfg.audio.fs        = 96000;     % must match the dry manifest sample rate
    cfg.audio.bit_depth = 24;

    % ---- dry test-signal design (mirror of generateTestSignals; informational) ----
    cfg.dry_design = struct();
    cfg.dry_design.tone_freqs_hz = [100 250 440 1000 2500 4000 8000];
    cfg.dry_design.tone_levels_db = round(linspace(-24,0,8)*2)/2;
    cfg.dry_design.sweep_f1_hz = 20;
    cfg.dry_design.sweep_f2_hz = 20000;

    % =====================================================================
    % COLORATION CORE — two independent reverse-engineering tracks (R3-A)
    % =====================================================================
    % Default architecture is Wiener-Hammerstein: Pre-EQ H1 -> waveshaper f(x)
    % -> Dynamic Energy Control -> Post-EQ H2, with oversampling around the
    % nonlinear stage (SPECIFICATION 3.1, 3.2-A). Baselines start with H1=H2=
    % identity and DEC bypassed, i.e. the degenerate pure-waveshaper control (R2-A).

    cfg.tracks = struct();

    % --- shared DOF template ------------------------------------------------
    baseDof = struct();
    % oversampling (H1)
    baseDof.oversample.factor        = 4;          % 2/4/8
    baseDof.oversample.filter_order  = 128;        % anti-alias/anti-image FIR taps
    baseDof.oversample.linear_phase  = true;       % affects fractional group delay
    % Pre-EQ H1 (H6) -- identity by default (list of biquad shelf/peak stages)
    baseDof.preEQ.stages  = struct('type', {}, 'freq_hz', {}, 'gain_db', {}, 'q', {});
    % waveshaper (H2) + Even/Odd Blend (H3)
    baseDof.shaper.type      = 'tanh';    % tanh | atan | poly | softknee
    baseDof.shaper.drive_k   = 1.0;       % internal input gain k in f(k*x); fitted per 4.3
    baseDof.shaper.bias      = 0.0;       % Even/Odd Blend: DC bias into the nonlinearity
    baseDof.shaper.asymmetry = 0.0;       % Even/Odd Blend: asymmetric gain of +/- halves
    baseDof.shaper.poly_coeffs = [];      % used when type=poly (odd+even terms)
    % Dynamic Energy Control (H9) -- bypass in Phase A
    baseDof.dec.mode      = 'bypass';     % bypass | soft_compression | env_mod | micro_sag | level_gain
    baseDof.dec.position  = 'post';       % 'pre' or 'post' waveshaper
    baseDof.dec.ratio     = 1.0;          % soft_compression
    baseDof.dec.attack_ms = 30;
    baseDof.dec.release_ms = 100;
    % Post-EQ H2 (H6) -- identity by default
    baseDof.postEQ.stages = struct('type', {}, 'freq_hz', {}, 'gain_db', {}, 'q', {});
    % output gain compensation (H5)
    baseDof.output.mode    = 'fixed';     % fixed | harmonic_auto
    baseDof.output.gain_db = 0.0;
    % W-H normalisation convention (backlog #4): H1 gain fixed 0 dB @ 1 kHz,
    % overall scale carried by output gain so k / H1 / output are identifiable.
    baseDof.normalization = 'H1_0dB_at_1kHz';

    % --- subtle_saturation --------------------------------------------------
    cfg.tracks.subtle_saturation = struct();
    cfg.tracks.subtle_saturation.dof = baseDof;
    % Iter-02 (H2): static transfer curve recovered directly from aligned
    % dry->reference sample pairs (tools/recoverCurve, 250 Hz, all levels, 0.7%
    % rel-RMS residual -> a pure static waveshaper is sufficient). Odd-only
    % polynomial captures the symmetric, odd-harmonic behaviour; c1=0.788 is the
    % linear-region gain (incl. Saturn output trim), so drive_k stays 1.0 and
    % output gain stays 0 dB (curve already maps to the reference output scale).
    cfg.tracks.subtle_saturation.dof.shaper.type       = 'poly';
    cfg.tracks.subtle_saturation.dof.shaper.drive_k    = 1.0;
    cfg.tracks.subtle_saturation.dof.shaper.bias       = 0.0;
    cfg.tracks.subtle_saturation.dof.shaper.asymmetry  = 0.0;
    % Iter-03 (H2 refit): level-balanced weighting (each tone-battery level equal
    % say) so near-origin curvature — which sets low-level THD — is not drowned by
    % high-amplitude samples. c3/c1 rises 1.36->1.54, lifting low-level distortion.
    cfg.tracks.subtle_saturation.dof.shaper.poly_coeffs = [0.7982 0 -1.226 0 2.585 0 -2.977 0 1.235];

    % --- subtle_tube --------------------------------------------------------
    cfg.tracks.subtle_tube = struct();
    cfg.tracks.subtle_tube.dof = baseDof;
    % Tube-specific starting lean (still just a starting point, not a locked target):
    cfg.tracks.subtle_tube.dof.shaper.asymmetry = 0.10;  % tube tends even-harmonic rich
    cfg.tracks.subtle_tube.dof.dynamic_bias.enabled = false;  % H8, Phase A candidate
    cfg.tracks.subtle_tube.dof.dynamic_bias.depth   = 0.0;
    cfg.tracks.subtle_tube.dof.dynamic_bias.attack_ms  = 10;
    cfg.tracks.subtle_tube.dof.dynamic_bias.release_ms = 80;

    % =====================================================================
    % MULTIBAND TOOL LAYER — own feature, NOT matched to Saturn 2 (3.4/3.5)
    % =====================================================================
    cfg.multiband = struct();
    cfg.multiband.num_bands = 4;                    % adjustable 2..6
    cfg.multiband.crossover_hz = [250 1000 4000];   % N-1 crossover points
    cfg.multiband.crossover_type = 'LR4';           % Linkwitz-Riley 4th order
    % per-band: mode / drive / dry-wet (0..1). Populated with sensible defaults.
    for b = 1:cfg.multiband.num_bands
        cfg.multiband.bands(b).mode    = 'bypass';  % bypass | subtle_saturation | subtle_tube
        cfg.multiband.bands(b).drive   = 0.0;
        cfg.multiband.bands(b).dry_wet = 0.0;       % 0=dry ... 1=wet
    end
    cfg.multiband.crossfade = 'equal_power';        % equal_power | linear (see R-DryWet)

    % ---- metric convergence targets (Phase A, 5.1) -------------------------
    cfg.targets = struct();
    cfg.targets.THD_error_db            = 1.0;   % < 1.0 dB
    cfg.targets.HarmonicProfileError_db = 2.0;   % < 2.0 dB RMS
    cfg.targets.SweepSpectralError_db   = -20;   % < -20 dB
    cfg.targets.BroadbandTonalError_db  = -18;   % < -18 dB
    cfg.targets.AlignmentOffsetStability_samples = 2;

    % ---- Phase A NormalizedLoss weights (R-Loss, versioned) ----------------
    cfg.loss = struct();
    % v2 (Iter-02): added noise-floor gates in analyzeAndCompare so absent
    % harmonics / inaudible THD are not scored as phantom floor-vs-floor dB error
    % (HARM_FLOOR_DB=-80, THD_REF_FLOOR_DB=-70). v1 and v2 Loss are NOT comparable.
    cfg.loss.loss_version = 'phase_a_loss_v2';
    cfg.loss.weights = struct('harmonic', 0.5, 'thd', 0.3, 'sweep', 0.2);
end
