function metrics = analyzeAndCompare(track, iterId)
%ANALYZEANDCOMPARE  Phase A metric engine (SPECIFICATION 5.1/5.2, R4, R-Loss).
%   Compares the model output for <track>/iter_<iterId> against the user-supplied
%   Saturn 2 reference renders. Every metric is computed only AFTER sub-sample
%   alignment (R4). Writes loop_iterations/<track>/iter_<ID>/metrics.json.
%
%   Requires the reference assets to exist; run_pipeline enforces the R1-A gate
%   before this is ever called.

    cfg = config();
    fs  = cfg.audio.fs;
    manifest = jsondecode(fileread(cfg.paths.dry_manifest));
    clickIdx = manifest.calibration_click.sample_index_1based;

    outDir = fullfile(cfg.paths.output, track, sprintf('iter_%02d', iterId));
    refDir = fullfile(cfg.paths.reference, track);

    files = {manifest.files.name};
    kinds = {manifest.files.kind};

    thdErrs = []; harmErrs = []; offsets = []; fracs = [];
    sweepErrs = []; broadErr = NaN;
    perFile = struct([]);

    for i = 1:numel(files)
        fn = files{i};
        outPath = fullfile(outDir, fn);
        refPath = fullfile(refDir, fn);
        if ~isfile(outPath) || ~isfile(refPath); continue; end
        [yout, ~]  = audioread(outPath);
        [yref, fsr] = audioread(refPath);
        assert(fsr == fs, 'reference %s sample rate %d ~= %d', fn, fsr, fs);
        yout = yout(:,1); yref = yref(:,1);

        [yref_al, dInt, dFrac] = subsampleAlign(yref, yout, clickIdx, fs);
        offsets(end+1) = dInt; fracs(end+1) = dFrac; %#ok<AGROW>

        switch kinds{i}
            case 'tone_battery'
                segs = manifest.files(i).segments;
                guard = round(manifest.files(i).steady_analysis_guard_sec*fs) + round(0.05*fs);
                te = []; he = [];
                for s = 1:numel(segs)
                    a = segs(s).start_sample_1based + guard;
                    b = segs(s).end_sample_1based - guard;
                    f0 = segs(s).freq_hz;
                    [thO, hO] = measureTHD(yout(a:b),    f0, fs, 6);
                    [thR, hR] = measureTHD(yref_al(a:b), f0, fs, 6);
                    te(end+1) = abs(db(thO) - db(thR)); %#ok<AGROW>
                    hmask = ~isnan(hO) & ~isnan(hR);
                    if any(hmask)
                        he(end+1) = sqrt(mean((db(hO(hmask)) - db(hR(hmask))).^2)); %#ok<AGROW>
                    end
                end
                thdErrs = te; harmErrs = he;
                perFile(end+1).name = fn; perFile(end).THD_error_db = mean(te); %#ok<AGROW>
                perFile(end).HarmonicProfileError_db = sqrt(mean(he.^2));

            case 'log_sweep_farina'
                far = manifest.files(i).farina;
                a = manifest.files(i).sweep_start_sample_1based;
                b = manifest.files(i).sweep_end_sample_1based;
                hO = harmonicSeparation(yout(a:b),    far, 6);
                hR = harmonicSeparation(yref_al(a:b), far, 6);
                e = sweepSpectralError(hO, hR);
                sweepErrs(end+1) = e; %#ok<AGROW>
                perFile(end+1).name = fn; perFile(end).SweepSpectralError_db = e; %#ok<AGROW>

            case 'pink_noise'
                a = manifest.files(i).noise_start_sample_1based;
                broadErr = stftSpectralError(yout(a:end), yref_al(a:end), fs);
                perFile(end+1).name = fn; perFile(end).BroadbandTonalError_db = broadErr; %#ok<AGROW>
        end
    end

    metrics = struct();
    metrics.track = track;
    metrics.iteration = iterId;
    metrics.THD_error_db            = mean(thdErrs);
    metrics.HarmonicProfileError_db = sqrt(mean(harmErrs.^2));
    metrics.SweepSpectralError_db   = mean(sweepErrs);
    metrics.BroadbandTonalError_db  = broadErr;
    metrics.alignment_offset_samples    = median(offsets);
    metrics.alignment_offset_fractional = median(fracs);
    metrics.AlignmentOffsetStability_samples = max(offsets) - min(offsets);
    metrics.per_file = perFile;

    % ---- NormalizedLoss (R-Loss, versioned) --------------------------------
    t = cfg.targets; w = cfg.loss.weights;
    thd_norm  = metrics.THD_error_db            / t.THD_error_db;
    harm_norm = metrics.HarmonicProfileError_db / t.HarmonicProfileError_db;
    sweep_norm = 10^((metrics.SweepSpectralError_db - t.SweepSpectralError_db)/20);
    metrics.normalized = struct('thd', thd_norm, 'harmonic', harm_norm, 'sweep', sweep_norm);
    metrics.NormalizedLoss = w.harmonic*harm_norm + w.thd*thd_norm + w.sweep*sweep_norm;
    metrics.loss_version = cfg.loss.loss_version;
    metrics.weights = w;

    % ---- convergence check -------------------------------------------------
    metrics.converged = metrics.THD_error_db < t.THD_error_db && ...
                        metrics.HarmonicProfileError_db < t.HarmonicProfileError_db && ...
                        metrics.SweepSpectralError_db < t.SweepSpectralError_db && ...
                        metrics.AlignmentOffsetStability_samples <= t.AlignmentOffsetStability_samples;

    mfile = fullfile(cfg.paths.loop_iters, track, sprintf('iter_%02d', iterId), 'metrics.json');
    if ~exist(fileparts(mfile),'dir'); mkdir(fileparts(mfile)); end
    fid = fopen(mfile,'w'); fwrite(fid, jsonencode(metrics,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('[%s iter %d] THD=%.2fdB Harm=%.2fdB Sweep=%.2fdB Loss=%.3f converged=%d\n', ...
        track, iterId, metrics.THD_error_db, metrics.HarmonicProfileError_db, ...
        metrics.SweepSpectralError_db, metrics.NormalizedLoss, metrics.converged);
end

% =========================================================================
function v = db(x); v = 20*log10(max(x, eps)); end

function [thd, harm] = measureTHD(x, f0, fs, maxOrder)
%MEASURETHD  THD ratio and per-harmonic magnitudes (H1..maxOrder) of a tone.
    x = x(:) - mean(x);
    N = numel(x); w = hann(N); xw = x.*w;
    X = abs(fft(xw)); X = X(1:floor(N/2));
    fr = (0:numel(X)-1)*fs/N;
    mag = zeros(1, maxOrder);
    bwHz = 30;                                   % search band around each harmonic
    for n = 1:maxOrder
        fh = n*f0;
        if fh >= fs/2 - bwHz; mag(n) = NaN; continue; end
        band = fr >= fh-bwHz & fr <= fh+bwHz;
        mag(n) = max(X(band));
    end
    fund = mag(1);
    harm = mag ./ max(fund, eps);                % normalised to fundamental
    hpow = mag(2:end); hpow = hpow(~isnan(hpow));
    thd  = sqrt(sum(hpow.^2)) / max(fund, eps);
end

function e = sweepSpectralError(hO, hR)
%SWEEPSPECTRALERROR  dB spectral error between separated harmonic IR sets.
    num = 0; den = 0;
    for n = 1:numel(hO)
        a = hO{n}; b = hR{n};
        L = min(numel(a), numel(b));
        A = abs(fft(a(1:L))); B = abs(fft(b(1:L)));
        num = num + sum((A-B).^2); den = den + sum(B.^2);
    end
    e = 10*log10(max(num,eps)/max(den,eps));
end

function e = stftSpectralError(yo, yr, fs)
%STFTSPECTRALERROR  energy-normalised STFT magnitude error in dB (5.1).
    L = min(numel(yo), numel(yr)); yo = yo(1:L); yr = yr(1:L);
    nfft = 4096; ov = round(0.75*nfft); win = hann(nfft);
    So = abs(stftMag(yo, win, ov, nfft));
    Sr = abs(stftMag(yr, win, ov, nfft));
    So = So / sqrt(sum(So(:).^2)); Sr = Sr / sqrt(sum(Sr(:).^2));  % energy normalise
    e = 10*log10(max(sum((So(:)-Sr(:)).^2),eps) / max(sum(Sr(:).^2),eps));
end

function S = stftMag(x, win, ov, nfft)
    hop = nfft - ov; N = numel(x);
    nfr = max(1, floor((N-nfft)/hop)+1);
    S = zeros(nfft/2+1, nfr);
    for k = 1:nfr
        seg = x((k-1)*hop + (1:nfft)) .* win;
        F = fft(seg, nfft); S(:,k) = abs(F(1:nfft/2+1));
    end
end
