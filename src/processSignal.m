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

    % 0) HF-clean split (Phase B voice lever, not part of the Saturn match).
    % Keeping the top octaves out of the nonlinearity stops intermodulation grit
    % being generated up there, which is what reads as "digital/fizzy highs" on
    % dense bright material; the low band still saturates normally so the warmth
    % is untouched. The clean high band is scaled by the chain's small-signal gain
    % so the linear response stays flat (transparent) rather than tilting bright.
    if isfield(dof,'hf_clean') && dof.hf_clean.enabled && dof.hf_clean.freq_hz > 0
        b  = crossoverBank(x, dof.hf_clean.freq_hz, fs);   % phase-matched, sums to x
        lo = b{1}; hi = b{2};
        dofCore = dof; dofCore.hf_clean.enabled = false;   % recurse once, core only
        g = 1;
        if ~isfield(dof.hf_clean,'gain_match') || dof.hf_clean.gain_match
            g = smallSignalGain(dofCore, fs, track);
        end
        y = processSignal(lo, dofCore, fs, track) + g*hi;
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

function g = smallSignalGain(dof, fs, track)
%SMALLSIGNALGAIN  linear-region gain of the coloration chain, measured by probing
%   it with a quiet tone (well below any saturation), so the HF-clean split can
%   keep the overall linear response flat.
    n = round(0.05*fs); t = (0:n-1)'/fs;
    a = 10^(-60/20); p = a*sin(2*pi*1000*t);
    q = processSignal(p, dof, fs, track);
    g = sqrt(mean(q.^2)) / max(sqrt(mean(p.^2)), eps);
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
