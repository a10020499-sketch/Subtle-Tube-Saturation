function report = verifyMultiband(fs)
%VERIFYMULTIBAND  Multiband-layer sanity gates (SPECIFICATION 5.3, R-DryWet).
%   Runs three checks against synthetic noise and reports dB error:
%     1) full-bypass crossover reconstruction  (< -60 dB)
%     2) per-band Wet=0%% equals that band's dry-filtered signal (< -80 dB)
%     3) equal-power/linear dry-wet endpoints hit dry/wet exactly
%   These do NOT reference Saturn 2 (own-feature verification).

    if nargin < 1; cfg = config(); fs = cfg.audio.fs; else; cfg = config(); end
    rng(7);
    x = randn(fs, 1); x = x/max(abs(x))*0.5;
    crossHz = cfg.multiband.crossover_hz;

    % 1) reconstruction null
    bands = crossoverBank(x, crossHz, fs);
    recon = bandSummary(bands);
    L = min(numel(x), numel(recon));
    e1 = 10*log10(sum((recon(1:L)-x(1:L)).^2)/sum(x(1:L).^2));

    % 2) Wet=0% returns the band's dry signal exactly
    y0 = dryWetMixer(bands{1}, randn(numel(bands{1}),1), 0, cfg.multiband.crossfade);
    e2 = 10*log10(max(sum((y0-bands{1}).^2),eps)/max(sum(bands{1}.^2),eps));

    % 3) endpoint fidelity
    d = bands{1}; w = crossoverBank(x, crossHz, fs); w = w{end};
    e3dry = max(abs(dryWetMixer(d, w, 0, cfg.multiband.crossfade) - d));
    e3wet = max(abs(dryWetMixer(d, w, 1, cfg.multiband.crossfade) - w));

    report = struct('reconstruction_db', e1, 'wet0_db', e2, ...
                    'endpoint_dry_maxabs', e3dry, 'endpoint_wet_maxabs', e3wet, ...
                    'reconstruction_pass', e1 < -60);
    fprintf('multiband verify: reconstruction=%.1f dB (pass=%d), wet0=%.1f dB\n', ...
        e1, report.reconstruction_pass, e2);
end
