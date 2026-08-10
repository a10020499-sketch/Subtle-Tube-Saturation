function out = fitDrive(track, shaperType, kGrid)
%FITDRIVE  Fit the waveshaper input gain k from the reference THD-vs-level curve
%   (SPECIFICATION 4.3 Drive baseline mapping protocol, H4). Fast: it does NOT
%   run the full pipeline. It measures the reference tone-battery THD per
%   (freq,level) segment, then for each candidate k synthesises tanh/atan(k*A*sin)
%   at the matching amplitude and compares THD curves. The k minimising the mean
%   |dB| THD-curve error is returned, together with the per-level residual so the
%   caller can judge whether the *shape* (H2) fits at any single k.
%
%   out.k_best, out.thd_err_db (at best k), out.residual_by_level, out.ref_curve

    if nargin < 2 || isempty(shaperType); shaperType = 'tanh'; end
    if nargin < 3 || isempty(kGrid); kGrid = logspace(log10(0.05), log10(2), 40); end

    cfg = config(); fs = cfg.audio.fs;
    m = jsondecode(fileread(cfg.paths.dry_manifest));
    tb = m.files(1); segs = tb.segments;
    ref = audioread(fullfile(cfg.paths.reference, track, tb.name));
    dry = audioread(fullfile(cfg.paths.dry, tb.name));
    ref = ref(:,1); dry = dry(:,1);
    [ref, ~, ~] = subsampleAlign(ref, dry, m.calibration_click.sample_index_1based, fs);

    guard = round(tb.steady_analysis_guard_sec*fs) + round(0.05*fs);
    nseg = numel(segs);
    refTHD = zeros(nseg,1); amp = zeros(nseg,1); frq = zeros(nseg,1);
    for s = 1:nseg
        a = segs(s).start_sample_1based + guard;
        b = segs(s).end_sample_1based - guard;
        frq(s) = segs(s).freq_hz; amp(s) = 10^(segs(s).level_dbfs/20);
        refTHD(s) = thd(ref(a:b), frq(s), fs);
    end
    refDb = 20*log10(max(refTHD,eps));

    % candidate-k search using a synthetic steady tone at each segment amplitude
    N = round(0.5*fs); t = (0:N-1)'/fs;
    err = zeros(numel(kGrid),1);
    for ki = 1:numel(kGrid)
        k = kGrid(ki); e = 0; c = 0;
        for s = 1:nseg
            x = amp(s)*sin(2*pi*frq(s)*t);
            y = shape(k*x, shaperType);
            mTHD = thd(y, frq(s), fs);
            if refTHD(s) > 10^(-80/20)          % ignore segments with negligible ref THD
                e = e + abs(20*log10(max(mTHD,eps)) - refDb(s)); c = c + 1;
            end
        end
        err(ki) = e / max(c,1);
    end
    [bestErr, bi] = min(err); kBest = kGrid(bi);

    % per-level residual at best k (averaged over frequency)
    lv = unique(amp,'stable'); resid = zeros(numel(lv),1);
    for li = 1:numel(lv)
        idx = find(abs(amp-lv(li))<1e-9); e=0;c=0;
        for j = idx'
            x = amp(j)*sin(2*pi*frq(j)*t); y = shape(kBest*x, shaperType);
            if refTHD(j) > 10^(-80/20)
                e=e+abs(20*log10(max(thd(y,frq(j),fs),eps))-refDb(j)); c=c+1;
            end
        end
        resid(li) = e/max(c,1);
    end

    out = struct('track', track, 'shaper', shaperType, 'k_best', kBest, ...
                 'thd_curve_err_db', bestErr, 'levels_dbfs', 20*log10(lv), ...
                 'residual_by_level_db', resid, 'ref_thd_db', refDb, 'k_grid', kGrid, 'err_grid', err);
    fprintf('[fitDrive %s/%s] k_best=%.4f  THD-curve err=%.2f dB\n', track, shaperType, kBest, bestErr);
end

function y = shape(u, type)
    switch lower(type)
        case 'tanh'; y = tanh(u);
        case 'atan'; y = (2/pi)*atan((pi/2)*u);
        otherwise;   y = tanh(u);
    end
end

function v = thd(x, f0, fs)
    x = x(:)-mean(x); N=numel(x); X=abs(fft(x.*hann(N))); X=X(1:floor(N/2));
    fr=(0:numel(X)-1)*fs/N; bw=30; mag=zeros(6,1);
    for n=1:6
        fh=n*f0; if fh>=fs/2-bw; mag(n)=NaN; continue; end
        mag(n)=max(X(fr>=fh-bw & fr<=fh+bw));
    end
    fund=mag(1); h=mag(2:end); h=h(~isnan(h)); v=sqrt(sum(h.^2))/max(fund,eps);
end
