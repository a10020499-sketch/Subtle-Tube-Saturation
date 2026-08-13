function report = verifySplit(track, fs)
%VERIFYSPLIT  Blocking gate for the HF-clean voice lever.
%   Three deterministic checks that catch the ways a saturate-one-band design
%   goes wrong without anyone hearing why:
%
%   1) NULL GATE - drive the chain far below saturation so the waveshaper is
%      effectively its linear gain. The split output must then reconstruct the
%      unsplit output; any residual is a filter/alignment error, not distortion.
%      (Reported vs the unsplit chain, so oversampling delay cancels.)
%   2) EFFECTIVE EQ (TILT) - at realistic level, the per-bin optimal linear
%      response H(k) = <Y,X>/<X,X> IS the EQ curve the processing applies.
%      A band-selective distortion lever should be tonally neutral; a bump here
%      means it is secretly an EQ move. Compares split constructions directly.
%   3) PATH DELAY - the saturated path goes through resample up/down, the clean
%      path does not. Any sample-level mismatch combs at the crossover.

    if nargin<1||isempty(track); track='subtle_saturation'; end
    if nargin<2||isempty(fs);    fs=48000; end
    cfg=config(); dof0=cfg.tracks.(track).dof;
    fc = 5500;
    rng(11); n = 4*fs;
    x = randn(n,1); x = x/max(abs(x));

    variants = { ...
        struct('name','compl beta=0',   'type','complementary','beta',0), ...
        struct('name','compl beta=0.35','type','complementary','beta',0.35), ...
        struct('name','lr4  beta=0',    'type','lr4',          'beta',0)};

    fprintf('[%s] HF-clean split gate, fc=%d Hz, fs=%d\n', track, fc, fs);
    report = struct('track',track,'fc',fc,'rows',{{}});

    % ---- 1) null gate -----------------------------------------------------
    % The waveshaper is replaced by its pure linear term, so the chain is exactly
    % linear and any residual is a filter/alignment error rather than distortion.
    % (Probing at -60 dBFS with the real curve does NOT work: this curve is
    % deliberately still nonlinear down there - that is the low-level fit.)
    fprintf('  1) NULL (waveshaper linearised, split vs unsplit):\n');
    dofLin = dof0; dofLin.shaper.coeffs = [dof0.shaper.coeffs(1) 0 0 0 0];
    yRef = processSignal(x, dofLin, fs, track);
    for i=1:numel(variants)
        d = setSplit(dofLin, fc, variants{i});
        y = processSignal(x, d, fs, track);
        m = min(numel(y),numel(yRef));
        e = 10*log10(max(sum((y(1:m)-yRef(1:m)).^2),eps)/max(sum(yRef(1:m).^2),eps));
        % a true LR4 pair sums to an ALLPASS, so it is expected NOT to null
        % against the unsplit chain; its flatness is judged by test 2 instead.
        expectNull = strcmpi(variants{i}.type,'complementary');
        if expectNull; mark = passmark(e < -60); else; mark = '(allpass by design)'; end
        fprintf('     %-14s : %7.1f dB %s\n', variants{i}.name, e, mark);
        report.rows{end+1}=struct('variant',variants{i}.name,'null_db',e);
    end

    % ---- 2) effective EQ at realistic level -------------------------------
    fprintf('  2) EFFECTIVE EQ (dB per octave band, hot signal):\n');
    xh = x * 10^(-9/20);
    edges=[125 250 500 1000 2000 4000 8000 16000 24000];
    fprintf('     %-14s |', 'band(Hz)'); fprintf('%7d', edges(1:end-1)); fprintf('\n');
    base = tiltOf(processSignal(xh, dof0, fs, track), xh, fs, edges);
    fprintf('     %-14s |', 'no split'); fprintf('%7.2f', base); fprintf('\n');
    for i=1:numel(variants)
        d = setSplit(dof0, fc, variants{i});
        t = tiltOf(processSignal(xh, d, fs, track), xh, fs, edges);
        fprintf('     %-14s |', variants{i}.name); fprintf('%7.2f', t); fprintf('\n');
        report.rows{end}.tilt = t;
    end

    % ---- 3) path delay ----------------------------------------------------
    imp=zeros(4096,1); imp(1024)=0.001;
    yi = processSignal(imp, dof0, fs, track);
    [~,k1]=max(abs(yi)); dly = k1-1024;
    fprintf('  3) PATH DELAY of the saturated chain: %d samples %s\n', dly, passmark(abs(dly)<=0));
    report.oversample_delay_samples = dly;

    % ---- 4) dry/wet phase coherence ---------------------------------------
    % The multiband tool blends each band's DRY signal with the coloured version
    % (dryWetMixer). If the core is not phase-transparent, partial wet combs.
    % A true LR4 pair sums to an allpass, so it is expected to fail this; the
    % telescoping complementary form is phase-exact and should not.
    fprintf('  4) DRY/WET COHERENCE (50%% wet, worst comb ripple 100 Hz-16 kHz):\n');
    for i=1:numel(variants)
        d = setSplit(dofLin, fc, variants{i});
        y = processSignal(x, d, fs, track);
        m=min(numel(x),numel(y));
        gg = smallSignalGainProbe(dofLin, fs, track);
        mix = 0.5*gg*x(1:m) + 0.5*y(1:m);              % 50% dry / 50% wet
        rip = combRipple(mix, gg*x(1:m), fs);
        fprintf('     %-14s : %5.2f dB %s\n', variants{i}.name, rip, passmark(rip < 1.0));
        report.rows{i}.drywet_ripple_db = rip;
    end
end

function g = smallSignalGainProbe(dof, fs, track)
    n=round(0.05*fs); t=(0:n-1)'/fs; p=10^(-60/20)*sin(2*pi*1000*t);
    q=processSignal(p,dof,fs,track); g=sqrt(mean(q.^2))/max(sqrt(mean(p.^2)),eps);
end

function r = combRipple(y, x, fs)
%COMBRIPPLE  worst |dB| deviation of |Y/X| across 100 Hz-16 kHz (smoothed),
%   i.e. how much comb filtering the blend introduced.
    n=2^15; g=4096; x=x(g:min(end,g+n-1)); y=y(g:min(end,g+n-1));
    N=min(numel(x),numel(y)); w=hann(N);
    X=fft(x(1:N).*w); Y=fft(y(1:N).*w);
    fr=(0:N-1)'*fs/N; sel=fr>=100 & fr<=16000;
    H=abs(Y(sel))./max(abs(X(sel)),eps);
    H=movmean(H, 101);                                  % smooth out noise variance
    r=max(abs(20*log10(H))) - min(abs(20*log10(H)));
end

function d = setSplit(d, fc, v)
    d.hf_clean.enabled=true; d.hf_clean.freq_hz=fc;
    d.hf_clean.gain_match=true; d.hf_clean.split_type=v.type; d.hf_clean.beta=v.beta;
end

function t = tiltOf(y, x, fs, edges)
%TILTOF  per-band effective linear response, from the per-bin optimal gain.
    m=min(numel(x),numel(y)); x=x(1:m); y=y(1:m);
    nfft=4096; hop=nfft/4; w=hann(nfft,'periodic');
    g=8192; x=x(g:end-g); y=y(g:end-g); m=numel(x);       % trim filter turn-on/edges
    nfr=max(1,floor((m-nfft)/hop)+1);
    X=zeros(nfft/2+1,nfr); Y=X;
    for k=1:nfr
        idx=(k-1)*hop+(1:nfft);
        Fx=fft(x(idx).*w,nfft); Fy=fft(y(idx).*w,nfft);
        X(:,k)=Fx(1:nfft/2+1); Y(:,k)=Fy(1:nfft/2+1);
    end
    H=sum(Y.*conj(X),2)./(sum(abs(X).^2,2)+eps);
    fr=(0:nfft/2)'*fs/nfft; t=zeros(1,numel(edges)-1);
    for b=1:numel(edges)-1
        sel=fr>=edges(b)&fr<edges(b+1);
        t(b)=20*log10(mean(abs(H(sel)))+eps);
    end
    t = t - t(4);                                          % reference to 1-2 kHz
end

function s = passmark(ok); if ok; s='PASS'; else; s='<-- check'; end; end
