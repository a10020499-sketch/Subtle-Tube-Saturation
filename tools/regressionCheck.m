function ok = regressionCheck()
%REGRESSIONCHECK  Guard the frozen Phase A baselines (R6 reproducibility).
%   Re-renders the dry set through the CURRENT code with each track's config and
%   compares against the archived output of that track's frozen Phase A
%   iteration. Any Phase B lever that leaks into the default path shows up here.
%   Run after every change to src/.

    cfg=config(); fs=cfg.audio.fs;
    frozen = struct('subtle_saturation',4,'subtle_tube',3);
    files = {'04_pink_noise_broadband_-12dBFS.wav','02_log_sweep_moderate_-18dBFS.wav'};
    ok = true;
    fprintf('Phase A regression (current code vs frozen iteration output):\n');
    for tr = fieldnames(frozen)'
        t = tr{1}; it = frozen.(t);
        for i = 1:numel(files)
            p = fullfile(cfg.paths.output, t, sprintf('iter_%02d',it), files{i});
            if ~isfile(p); fprintf('  %-18s %-34s (no archive)\n', t, files{i}); continue; end
            x = audioread(fullfile(cfg.paths.dry, files{i})); x = x(:,1);
            yNew = processSignal(x, cfg.tracks.(t).dof, fs, t);
            yOld = audioread(p); yOld = yOld(:,1);
            n = min(numel(yNew), numel(yOld));
            d = 10*log10(max(sum((yNew(1:n)-yOld(1:n)).^2),eps)/max(sum(yOld(1:n).^2),eps));
            pass = d < -100;                       % -100 dB = 24-bit archive quantisation
            ok = ok && pass;
            fprintf('  %-18s %-34s %7.1f dB  %s\n', t, files{i}, d, tf(pass));
        end
    end
    fprintf('REGRESSION %s\n', tf(ok));
end
function s = tf(v); if v; s='PASS'; else; s='FAIL'; end; end
