function report = verifyMultiband(cfg)
%VERIFYMULTIBAND  Multiband-layer validation gates (SPECIFICATION 5.3, R-DryWet).
%   Own-feature checks (no Saturn 2 reference). Runs against synthetic signals:
%     1) full-bypass reconstruction through multibandProcess      (< -60 dB)
%     2) crossover-only reconstruction (bandSummary of split)      (< -60 dB)
%     3) per-band Wet=0%% equals that band's dry-filtered signal    (< -80 dB)
%     4) per-band Wet=100%% equals the colour-core output exactly   (< -80 dB)
%     5) mixed-mode render is finite/bounded and click-free (max |Δ| sane)
%     6) a bypassed band ignores its own output trim, so the all-bypass
%        reconstruction holds whatever trims are left configured  (< -60 dB)
%   Returns a struct of dB errors and pass flags.

    if nargin < 1 || isempty(cfg); cfg = config(); end
    fs = cfg.audio.fs; mb = cfg.multiband;
    rng(7);
    x = randn(round(0.5*fs),1); x = x/max(abs(x))*0.5;

    % --- 1) full bypass through the top-level processor ---------------------
    cfgB = cfg;
    for b=1:mb.num_bands; cfgB.multiband.bands(b).mode='bypass'; end
    yB = multibandProcess(x, cfgB, fs);
    e1 = reldb(yB, x);

    % --- 2) crossover-only reconstruction ----------------------------------
    recon = bandSummary(crossoverBank(x, mb.crossover_hz, fs));
    e2 = reldb(recon, x);

    % --- 3/4) per-band dry/wet endpoints (use band 2, subtle_tube) ----------
    bands = crossoverBank(x, mb.crossover_hz, fs);
    bi = min(2, mb.num_bands); dryBand = bands{bi};
    coreCfg = cfg.tracks.subtle_tube.dof;
    if isfield(cfg,'voice') && isfield(cfg.voice,'subtle_tube'); coreCfg = cfg.voice.subtle_tube.final; end
    core = processSignal(dryBand, coreCfg, fs, 'subtle_tube');
    y0   = dryWetMixer(dryBand, core, 0, mb.crossfade);   % wet 0%
    y100 = dryWetMixer(dryBand, core, 1, mb.crossfade);   % wet 100%
    e3 = reldb(y0, dryBand);
    e4 = reldb(y100, core);

    % --- 5) mixed-mode render: finite, bounded, click-free ------------------
    cfgM = cfg; modes = {'subtle_tube','subtle_saturation','bypass','subtle_saturation'};
    for b=1:mb.num_bands
        cfgM.multiband.bands(b).mode = modes{min(b,numel(modes))};
        cfgM.multiband.bands(b).dry_wet = 1.0; cfgM.multiband.bands(b).drive = 1.0;
    end
    yM = multibandProcess(x, cfgM, fs);
    finite_ok = all(isfinite(yM)); bounded_ok = max(abs(yM)) < 4;
    % click proxy: the colored/summed output must not introduce sample-to-sample
    % steps far larger than the input already has (broadband input has large jumps
    % inherently, so judge relative to the input, not an absolute threshold).
    maxJump = max(abs(diff(yM))); jump_ok = maxJump < 3*max(abs(diff(x)));

    % --- 6) bypass must ignore a per-band trim -----------------------------
    % The all-bypass reconstruction guarantee has to hold whatever else is left
    % configured, so a stale per-band trim must not leak through a bypassed band.
    % Without this the gate above passes only because the trims happen to be zero.
    cfgT = cfg; trims = [-6 +4 -2 +3];
    for b=1:mb.num_bands
        cfgT.multiband.bands(b).mode = 'bypass';
        cfgT.multiband.bands(b).output_gain_db = trims(min(b,numel(trims)));
    end
    e6 = reldb(multibandProcess(x, cfgT, fs), x);

    report = struct('bypass_recon_db', e1, 'crossover_recon_db', e2, ...
        'wet0_db', e3, 'wet100_db', e4, ...
        'mixed_finite', finite_ok, 'mixed_bounded', bounded_ok, ...
        'mixed_maxjump', maxJump, 'mixed_clickfree', jump_ok, ...
        'bypass_ignores_trim_db', e6);
    report.pass = e1 < -60 && e2 < -60 && e3 < -80 && e4 < -80 && e6 < -60 && ...
                  finite_ok && bounded_ok && jump_ok;

    fprintf(['multiband verify:\n' ...
        '  1 full-bypass recon   = %7.1f dB  (<-60)\n' ...
        '  2 crossover recon     = %7.1f dB  (<-60)\n' ...
        '  3 band Wet=0%%%%         = %7.1f dB  (<-80)\n' ...
        '  4 band Wet=100%%%%       = %7.1f dB  (<-80)\n' ...
        '  5 mixed-mode: finite=%d bounded=%d maxjump=%.3f clickfree=%d\n' ...
        '  6 bypass ignores trim= %7.1f dB  (<-60)\n' ...
        '  PASS=%d\n'], e1,e2,e3,e4, finite_ok,bounded_ok,maxJump,jump_ok, e6, report.pass);
end

function d = reldb(a, b)
    n = min(numel(a), numel(b)); a=a(1:n); b=b(1:n);
    d = 10*log10(max(sum((a-b).^2),eps) / max(sum(b.^2),eps));
end
