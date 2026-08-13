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
    % HF-clean split (Phase B voice lever; OFF = the frozen Phase A saturn-like
    % model). When enabled, only content below freq_hz enters the nonlinearity;
    % the complementary high band passes through clean (scaled by the chain's
    % small-signal gain so the linear response stays flat). Removes the
    % intermodulation grit in the highs without dulling them.
    baseDof.hf_clean.enabled    = false;
    baseDof.hf_clean.freq_hz    = 6000;
    baseDof.hf_clean.gain_match = true;
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
    % Iter-04 (H2): signpow basis f = sum c_p sign(x)|x|^p, p=1..5, level-balanced
    % fit. The even-p terms (x|x|, x|x|^3) supply 3rd-harmonic ~A^2 (THD slope 1)
    % that a pure odd polynomial cannot — cutting the low-level under-distortion.
    % Fit rel-RMS residual 0.0020 (vs 0.0082 odd-poly); per-level <=0.007.
    cfg.tracks.subtle_saturation.dof.shaper.type      = 'signpow';
    cfg.tracks.subtle_saturation.dof.shaper.drive_k   = 1.0;
    cfg.tracks.subtle_saturation.dof.shaper.bias      = 0.0;
    cfg.tracks.subtle_saturation.dof.shaper.asymmetry = 0.0;
    cfg.tracks.subtle_saturation.dof.shaper.powers    = [1 2 3 4 5];
    cfg.tracks.subtle_saturation.dof.shaper.coeffs    = [0.8484 -0.6008 0.5004 -0.5529 0.2171];

    % --- subtle_tube --------------------------------------------------------
    cfg.tracks.subtle_tube = struct();
    cfg.tracks.subtle_tube.dof = baseDof;
    % Iter-02 (H8): tube = symmetric signpow base curve + envelope-driven bias
    % drift  y = f(x + depth*env(|x|)). The bias produces the even harmonics and
    % their level growth; the diagnostic showed the memory is nonlinear (loop
    % grows with level), not a linear filter. attack==release makes envelopeFollow
    % a one-pole LPF of |x| settling to depth*(2A/pi) (quasi-DC bias -> frequency-
    % independent even harmonics, as measured). Base curve + depth from fitTube.
    cfg.tracks.subtle_tube.dof.shaper.type      = 'signpow';
    cfg.tracks.subtle_tube.dof.shaper.drive_k   = 1.0;
    cfg.tracks.subtle_tube.dof.shaper.bias      = 0.0;
    cfg.tracks.subtle_tube.dof.shaper.asymmetry = 0.0;
    cfg.tracks.subtle_tube.dof.shaper.powers    = [1 2 3 4 5];
    % Iter-03: added compressive bias mapping gamma<1 (bias=depth*env^gamma) so
    % low-level even harmonics fall slower than A (matches Subtle mode); refit of
    % base curve + depth + gamma via fitTube (H2/H3-weighted). Low-level H2 error
    % 9->3 dB.
    cfg.tracks.subtle_tube.dof.shaper.coeffs    = [0.8158 -0.6526 -0.3029 1.1188 -0.6052];
    cfg.tracks.subtle_tube.dof.dynamic_bias.enabled = true;   % H8
    cfg.tracks.subtle_tube.dof.dynamic_bias.depth   = 0.0757;
    cfg.tracks.subtle_tube.dof.dynamic_bias.gamma   = 0.850;  % compressive bias-vs-envelope
    cfg.tracks.subtle_tube.dof.dynamic_bias.attack_ms  = 30;  % == release -> one-pole LPF(|x|)
    cfg.tracks.subtle_tube.dof.dynamic_bias.release_ms = 30;

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
    % v2 (Iter-02): noise-floor gates (HARM_FLOOR_DB=-80, THD_REF_FLOOR_DB=-70).
    % v3 (subtube Iter-03): HarmonicProfileError is magnitude-weighted so an
    % audible -20 dB harmonic dominates a -70 dB near-floor one (equal-weight dB
    % RMS let floor-level H6 dominate the tube score). v1/v2/v3 Loss NOT comparable.
    cfg.loss.loss_version = 'phase_a_loss_v3';
    cfg.loss.weights = struct('harmonic', 0.5, 'thd', 0.3, 'sweep', 0.2);
end
