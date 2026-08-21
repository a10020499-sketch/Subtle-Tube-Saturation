function y = multibandProcess(x, cfg, fs)
%MULTIBANDPROCESS  Top-level multiband coloration tool (SPECIFICATION 3.1 lower
%   layer, 3.4/3.5). Own feature — NOT matched to Saturn 2.
%     input -> N-band LR4 crossover
%           -> per band: [colour core (mode) pre-gained by Drive] dry/wet-mixed
%              with that band's dry signal
%           -> band summation -> output
%
%   Per-band settings come from cfg.multiband.bands(b): .mode
%   ('bypass'|'subtle_saturation'|'subtle_tube'), .drive (linear input pre-gain
%   into the core), .dry_wet (0..1). Colour cores use each track's frozen
%   signed-off Phase B voice (cfg.voice.<mode>.final), falling back to the frozen
%   Phase A baseline (cfg.tracks.<mode>.dof) only if no voice has been locked yet.

    x  = x(:);
    % fs comes from the CALLER. Programme material is not necessarily at the
    % measurement rate - the dry test set is 96 kHz while real material here is
    % 48 kHz - and defaulting to cfg.audio.fs would silently put every crossover
    % at the wrong frequency (a 250 Hz split landing at 125 Hz on a 48 kHz file).
    if nargin < 3 || isempty(fs); fs = cfg.audio.fs; end
    mb = cfg.multiband;

    bands = crossoverBank(x, mb.crossover_hz, fs);   % 1xN, sum reconstructs x
    assert(numel(bands) == mb.num_bands, 'crossover produced %d bands, expected %d', ...
        numel(bands), mb.num_bands);

    outBands = cell(1, mb.num_bands);
    for b = 1:mb.num_bands
        dryBand = bands{b};
        bp = mb.bands(b);
        switch lower(bp.mode)
            case 'bypass'
                outBands{b} = dryBand;                 % dry/wet irrelevant when bypassed
            case {'subtle_saturation','subtle_tube'}
                drive = 1.0; if isfield(bp,'drive') && ~isempty(bp.drive); drive = bp.drive; end
                wet = processSignal(drive*dryBand, coreDof(cfg, bp.mode, bp), fs, bp.mode);
                outBands{b} = dryWetMixer(dryBand, wet, bp.dry_wet, mb.crossfade);
            otherwise
                error('multibandProcess:mode', 'band %d unknown mode "%s"', b, bp.mode);
        end
    end
    y = bandSummary(outBands);

    % ---- output stage ------------------------------------------------------
    % Band summation raises peaks rather than lowering them (peaks in different
    % bands do not coincide, so the sum keeps them - measured 1.307 on drum
    % material at 50% wet), and writing to a fixed-point file hard-clips above 1.
    % So a trim is needed. It is a plain gain, deliberately not a limiter: a
    % limiter is an unmeasured nonlinearity that would squash exactly the
    % transients the voice tuning protected, and the host already has one.
    ag = 'off';
    if isfield(mb,'auto_gain') && ~isempty(mb.auto_gain); ag = mb.auto_gain; end
    switch lower(ag)
        case 'off'
            % nothing - keep whatever loudness the colour earned. This is the
            % default because matching the output back to the input hands back the
            % loudness that saturation exists to buy.
        case {'rms','lufs'}
            % A/B aid only: equalises perceived level so timbre can be judged
            % without the "louder sounds better" bias. Never leave this on in
            % production if loudness is the goal.
            ri = sqrt(mean(x.^2)); ro = sqrt(mean(y.^2));
            if ro > 0; y = y * (ri/ro); end
        otherwise
            error('multibandProcess:auto_gain', 'unknown auto_gain "%s"', ag);
    end
    if isfield(mb,'output_gain_db') && ~isempty(mb.output_gain_db)
        y = y * 10^(mb.output_gain_db/20);
    end
end

function dof = coreDof(cfg, mode, bp)
%COREDOF  the coloration config for one band, in precedence order:
%     1. bp.voice        - a per-band override (see below)
%     2. cfg.voice.<mode>.final - the signed-off Phase B voice
%     3. cfg.tracks.<mode>.dof  - the frozen Phase A saturn-like baseline
%   Keeping 2 and 3 separate is what lets tools/regressionCheck.m keep verifying
%   Phase A reproducibility while the product ships the tuned voice.
%
%   The per-band override exists because loudness and freedom-from-fizz pull in
%   opposite directions through ONE parameter - hf_clean.beta, how much HF enters
%   the curve. Measured on Disco: beta 1.0 buys +3.6 dB of loudness at equal peak
%   and costs 5 dB of 8-20 kHz nonlinear residual. But the fizz is an HF problem
%   and the loudness is a low/mid one, so a band-split tool can take the loud
%   voicing below the top crossover and the transparent voicing above it, and have
%   both. That is what this override is for.
    if nargin >= 3 && isstruct(bp) && isfield(bp,'voice') && ~isempty(bp.voice)
        dof = bp.voice; return;
    end
    if isfield(cfg,'voice') && isfield(cfg.voice, mode) && isfield(cfg.voice.(mode),'final')
        dof = cfg.voice.(mode).final;
    else
        dof = cfg.tracks.(mode).dof;
    end
end
