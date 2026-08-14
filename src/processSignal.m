function y = processSignal(x, dof, fs, track)
%PROCESSSIGNAL  Full Wiener-Hammerstein coloration chain (SPECIFICATION 3.1).
%   x     column vector, base sample rate
%   dof   cfg.tracks.<track>.dof
%   fs    base sample rate
%   track 'subtle_saturation' | 'subtle_tube'
%
%   Chain:  preEQ(H1) -> [DEC if pre] -> up-sample -> waveshaper f(x)[+dyn bias]
%           -> down-sample -> [DEC if post] -> postEQ(H2) -> output gain
%   Factored out of run_pipeline so configs can be scored without writing WAVs.

    x = x(:);

    % -1) TRANSIENT PRESERVE (Phase B voice lever) - frequency-agnostic punch.
    % A memoryless curve squashes an attack the instant it arrives and has no
    % attack/release to soften it, so impact is lost. Band-splitting the lows out
    % of the curve would restore it, but that hardwires a frequency range to
    % bypass saturation, which belongs to the downstream multiband layer, not to
    % the core. Instead: detect an attack (fast envelope running well above the
    % slow one) and momentarily lean the output toward the linear path. The steady
    % state stays fully saturated - the approved warmth is untouched - and only
    % the first milliseconds of a hit pass less compressed. Works on whatever band
    % it is fed, so it behaves the same full-range or inside one multiband band.
    if isfield(dof,'transient') && dof.transient.enabled && dof.transient.depth > 0
        tp = dof.transient;
        dofNoTP = dof; dofNoTP.transient.enabled = false;
        wet = processSignal(x, dofNoTP, fs, track);

        % Residual form: y = wet + a*(lin - wet). The modulated quantity is what
        % the CURVE removed, so it vanishes with the signal - fast changes in 'a'
        % cannot click, unlike modulating a plain gain. 'lin' is the same chain
        % with the waveshaper reduced to its linear term, so it carries any pre/
        % post EQ too; using g*x instead would comb as soon as an EQ stage exists.
        lin = processSignal(x, linearise(dofNoTP), fs, track);

        % BOTH detectors are PEAK followers, differing only in their time
        % constants, so in true steady state both converge to the peak and the
        % ratio converges to 1 -> tr = 0 -> output is bit-identical to wet. (A
        % symmetric one-pole for the slow envelope settles on the MEAN instead,
        % which for a sine sits pi/2 below the peak: the ratio then idles at 1.26,
        % tr at 0.52, and half the saturation is silently blended away on
        % sustained material - measured as 9.1 dB of lost H3 before this fix.)
        fastRel = getf(tp,'fast_release_ms', 8);
        slowAtk = getf(tp,'slow_attack_ms', 80);
        slowRel = getf(tp,'slow_release_ms',250);
        kneeDb  = getf(tp,'knee_db',   3);
        rangeDb = getf(tp,'range_db',  8);
        ef = peakFollow(x, fs, 0,       fastRel);   % instantaneous attack
        es = peakFollow(x, fs, slowAtk, slowRel);
        detDb = 20*log10(max(ef,eps) ./ max(es,eps));
        u  = min(max((detDb - kneeDb) / max(rangeDb,eps), 0), 1);
        tr = u.^2 .* (3 - 2*u);                     % smoothstep: C1, no corner
        a  = tp.depth * tr;

        n = min([numel(wet) numel(lin) numel(a)]);
        y = wet(1:n) + a(1:n) .* (lin(1:n) - wet(1:n));
        return;
    end

    % 0) BAND-LIMITED DRIVE (Phase B voice levers, not part of the Saturn match).
    % Content outside [lf_clean.freq_hz, hf_clean.freq_hz] can be kept out of the
    % nonlinearity and passed through clean:
    %   * clean HIGHS  - stops the intermodulation grit that reads as "digital /
    %     fizzy highs" on dense bright material.
    %   * clean LOWS   - a memoryless curve compresses a kick transient the instant
    %     it arrives and has no attack/release to soften that; keeping the bottom
    %     octave out of the curve is the only lever that restores PUNCH. (Measured:
    %     changing the follow attack from 1 ms to 30 ms moved punch by 0.00 dB,
    %     because the follow only touches the band above the HF crossover.)
    % Each clean band has its own beta (fraction still driven) and follow (density
    % restoration), so either can be blended continuously rather than switched.
    hasHF = isfield(dof,'hf_clean') && dof.hf_clean.enabled && dof.hf_clean.freq_hz > 0;
    hasLF = isfield(dof,'lf_clean') && dof.lf_clean.enabled && dof.lf_clean.freq_hz > 0;
    if hasHF || hasLF
        dofCore = dof;                                   % recurse once, core only
        if hasHF; dofCore.hf_clean.enabled = false; end
        if hasLF; dofCore.lf_clean.enabled = false; end
        g = 1;
        gm = (~hasHF || ~isfield(dof.hf_clean,'gain_match') || dof.hf_clean.gain_match) && ...
             (~hasLF || ~isfield(dof.lf_clean,'gain_match') || dof.lf_clean.gain_match);
        if gm; g = smallSignalGain(dofCore, fs, track); end

        mid = x; loClean = zeros(size(x)); hiClean = zeros(size(x));
        betaL = 0; betaH = 0;
        if hasLF
            % split off the clean bottom first, then band the remainder
            [loClean, mid] = splitAt(mid, dof.lf_clean, fs);
            betaL = getf(dof.lf_clean,'beta',0);
        end
        if hasHF
            [mid, hiClean] = splitAt(mid, dof.hf_clean, fs);
            betaH = getf(dof.hf_clean,'beta',0);
        end

        % Linear region: g*(mid + bL*lo + bH*hi) + g*(1-bL)*lo + g*(1-bH)*hi
        %              = g*(mid+lo+hi) = g*x  -> flat by construction, any beta.
        driven  = mid + betaL*loClean + betaH*hiClean;
        yMid    = processSignal(driven, dofCore, fs, track);
        ref     = g*driven;                     % the driven path had it stayed linear
        loOut   = g*(1-betaL)*loClean;
        hiOut   = g*(1-betaH)*hiClean;

        % Density follow. A saturator's perceived THICKNESS comes largely from peak
        % compression; routing a band around the curve lets its transients through
        % uncompressed, crest factor rises and - once loudness-matched - the result
        % reads as thinner. Modulating a clean band by the gain reduction the curve
        % is applying restores that density while generating no extra harmonics.
        % Envelope-rate (ms), never sample-rate, so it does not itself distort.
        if hasHF; hiOut = applyFollow(hiOut, yMid, ref, dof.hf_clean, fs); end
        if hasLF; loOut = applyFollow(loOut, yMid, ref, dof.lf_clean, fs); end

        y = yMid + loOut + hiOut;
        return;
    end

    % 1) Pre-EQ H1
    v = preEQ(x, dof, fs);

    % 2) DEC (pre-waveshaper placement)
    if strcmpi(dof.dec.position, 'pre')
        v = dynamicEnergyControl(v, dof, fs);
    end

    % 3) Oversample up
    L = dof.oversample.factor;
    if L > 1
        vo = resample(v, L, 1);
    else
        vo = v;
    end

    % 4) Waveshaper at high rate, with optional dynamic bias (H8, tube)
    shaper = dof.shaper;
    if strcmpi(track, 'subtle_tube') && isfield(dof,'dynamic_bias') ...
            && dof.dynamic_bias.enabled && dof.dynamic_bias.depth ~= 0
        biasEnv = envelopeFollow(vo, fs*L, dof.dynamic_bias.attack_ms, dof.dynamic_bias.release_ms);
        g = 1;
        if isfield(dof.dynamic_bias,'gamma'); g = dof.dynamic_bias.gamma; end
        % compressive bias-vs-envelope mapping (gamma<1 lifts low-level bias so the
        % even harmonics fall slower than A, matching the Subtle mode; H8, Iter-3)
        shaper.bias = shaper.bias + dof.dynamic_bias.depth * biasEnv.^g;  % per-sample bias vector
    end
    wo = waveshaper(vo, shaper);

    % 5) Oversample down
    if L > 1
        w = resample(wo, 1, L);
    else
        w = wo;
    end
    if numel(w) > numel(x); w = w(1:numel(x)); end
    if numel(w) < numel(x); w = [w; zeros(numel(x)-numel(w),1)]; end

    % 6) DEC (post-waveshaper placement)
    if strcmpi(dof.dec.position, 'post')
        w = dynamicEnergyControl(w, dof, fs);
    end

    % 7) Post-EQ H2
    w = postEQ(w, dof, fs);

    % 8) Output gain compensation (H5)
    switch lower(dof.output.mode)
        case 'fixed'
            g = 10^(dof.output.gain_db/20);
        case 'harmonic_auto'
            % match output RMS to input RMS (energy-preserving auto gain)
            ri = sqrt(mean(x.^2)); ro = sqrt(mean(w.^2));
            g = (ro>0) * ri/max(ro,eps) + (ro==0);
        otherwise
            error('processSignal:output', 'unknown output.mode "%s"', dof.output.mode);
    end
    y = w * g;
end

function d = linearise(d)
%LINEARISE  same config with the waveshaper reduced to its linear term, so the
%   rest of the chain (EQ, oversampling, splits, gain) is preserved exactly.
    if strcmpi(d.shaper.type,'signpow')
        d.shaper.powers = d.shaper.powers(1);
        d.shaper.coeffs = d.shaper.coeffs(1);
    else
        d.shaper.type = 'signpow'; d.shaper.powers = 1; d.shaper.coeffs = 1;
    end
    if isfield(d,'dynamic_bias'); d.dynamic_bias.enabled = false; end
end

function env = peakFollow(x, fs, atk_ms, rel_ms)
%PEAKFOLLOW  true peak follower: rises toward the peak, then DECAYS - it never
%   pulls back toward the instantaneous sample. That distinction is what lets a
%   fast and a slow instance agree in steady state (both sit at the peak), which
%   is what makes a ratio detector idle at exactly 1.
    ax = abs(x(:));
    if atk_ms <= 0; ca = 0; else; ca = exp(-1/(fs*atk_ms/1000)); end
    cr = exp(-1/(fs*rel_ms/1000));
    env = zeros(numel(ax),1); e = 0;
    for n = 1:numel(ax)
        if ax(n) > e; e = ax(n) + (e - ax(n))*ca;   % rise toward the peak
        else;         e = e*cr;                      % decay only
        end
        env(n) = e;
    end
end

function v = getf(s, name, dflt)
    if isfield(s,name) && ~isempty(s.(name)); v = s.(name); else; v = dflt; end
end

function [lo, hi] = splitAt(x, spec, fs)
%SPLITAT  Split x at spec.freq_hz. Default is the telescoping complementary form
%   (lo+hi == x exactly). A true LR4 pair separates the bands slightly better but
%   sums to an ALLPASS, which measured 39.7 dB of comb ripple through a 50%
%   dry/wet blend versus 0.00 dB here (verifySplit test 4) - that would wreck the
%   multiband layer's per-band Dry/Wet. Phase transparency wins; 'lr4' stays
%   available for single-band, always-100%-wet experiments.
    if isfield(spec,'split_type') && strcmpi(spec.split_type,'lr4')
        [lo, hi] = lr4Pair(x, spec.freq_hz, fs);
    else
        b = crossoverBank(x, spec.freq_hz, fs); lo = b{1}; hi = b{2};
    end
end

function bandOut = applyFollow(bandOut, yDriven, refDriven, spec, fs)
%APPLYFOLLOW  Modulate a clean band by the gain reduction the curve is applying
%   to the driven band. Fast attack so a transient is ducked with the hit that
%   caused it; slower release so the modulation stays well below audio rate.
    follow = getf(spec,'follow',0);
    if follow <= 0; return; end
    atk = getf(spec,'follow_attack_ms', 1);
    rel = getf(spec,'follow_release_ms',30);
    eOut = envelopeFollow(yDriven,   fs, atk, rel);
    eRef = envelopeFollow(refDriven, fs, atk, rel);
    gr = min(max(eOut ./ max(eRef, eps), 0.25), 1.5);   % guard pathological ratios
    bandOut = bandOut .* (1 + follow*(gr - 1));
end

function g = smallSignalGain(dof, fs, track)
%SMALLSIGNALGAIN  linear-region gain of the coloration chain, measured by probing
%   it with a quiet tone (well below any saturation), so the HF-clean split can
%   keep the overall linear response flat. Cached: the probe render is otherwise
%   repeated on every call.
    persistent cache
    if isempty(cache); cache = containers.Map('KeyType','char','ValueType','double'); end
    key = sprintf('%s|%d|%s', track, fs, jsonencode(dof.shaper));
    if isfield(dof,'output'); key = [key '|' jsonencode(dof.output)]; end
    if isKey(cache, key); g = cache(key); return; end
    n = round(0.05*fs); t = (0:n-1)'/fs;
    a = 10^(-60/20); p = a*sin(2*pi*1000*t);
    q = processSignal(p, dof, fs, track);
    g = sqrt(mean(q.^2)) / max(sqrt(mean(p.^2)), eps);
    cache(key) = g;
end

function env = envelopeFollow(x, fs, atk_ms, rel_ms)
    atk = exp(-1/(fs*atk_ms/1000));
    rel = exp(-1/(fs*rel_ms/1000));
    ax = abs(x); env = zeros(numel(x),1); e = 0;
    for n = 1:numel(x)
        if ax(n) > e; e = atk*e + (1-atk)*ax(n); else; e = rel*e + (1-rel)*ax(n); end
        env(n) = e;
    end
end
