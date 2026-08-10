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
        shaper.bias = shaper.bias + dof.dynamic_bias.depth * biasEnv;  % per-sample bias vector
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

function env = envelopeFollow(x, fs, atk_ms, rel_ms)
    atk = exp(-1/(fs*atk_ms/1000));
    rel = exp(-1/(fs*rel_ms/1000));
    ax = abs(x); env = zeros(numel(x),1); e = 0;
    for n = 1:numel(x)
        if ax(n) > e; e = atk*e + (1-atk)*ax(n); else; e = rel*e + (1-rel)*ax(n); end
        env(n) = e;
    end
end
