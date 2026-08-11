function y = multibandProcess(x, cfg)
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
%   saturn-like Phase A config (cfg.tracks.<mode>.dof) until Phase B -final exists.

    x  = x(:);
    fs = cfg.audio.fs;
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
                wet = processSignal(drive*dryBand, cfg.tracks.(bp.mode).dof, fs, bp.mode);
                outBands{b} = dryWetMixer(dryBand, wet, bp.dry_wet, mb.crossfade);
            otherwise
                error('multibandProcess:mode', 'band %d unknown mode "%s"', b, bp.mode);
        end
    end
    y = bandSummary(outBands);
end
