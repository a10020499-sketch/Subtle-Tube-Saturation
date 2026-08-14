function m = voiceMetrics(y, x, fs)
%VOICEMETRICS  Perceptual proxies for the Phase B iter-03 requests.
%   All computed on a loudness-matched rendering so level cannot flatter anything.
%
%   punch      transient-to-sustain ratio in the kick band (40-200 Hz), dB.
%              Peak of a 5 ms window over the RMS of the surrounding 150 ms, taken
%              at detected transients and averaged. HIGHER = more punch.
%   air        10-16 kHz level relative to the dry signal's, dB. HIGHER = more air.
%   tail       reverb-tail audibility: the spread between loud and quiet moments,
%              p90 minus p10 of short-term (50 ms) RMS, dB. LOWER = quiet detail
%              sits closer to the loud parts = tails more audible.
%   crest      loudness-matched crest factor, dB. LOWER = denser/thicker.
%   nlHF       nonlinear residual 8-20 kHz vs input, dB. LOWER = less fizz.

    n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);
    m.punch = punchOf(y,fs);
    m.punch_dry = punchOf(x,fs);
    % low-band crest: how far kick peaks stand above the kick-band average.
    % More interpretable than the transient/sustain ratio above and it tracks
    % perceived impact better - report both, they can disagree.
    m.lowcrest = bandCrest(y,fs,40,200);
    m.air   = 10*log10(bandE(y,fs,10000,16000)/bandE(x,fs,10000,16000));
    % kick-band weight relative to dry, dB (does the low end actually get bigger)
    m.lowE  = 10*log10(bandE(y,fs,40,200)/bandE(x,fs,40,200));
    m.tail  = tailSpread(y,fs);
    m.tail_dry = tailSpread(x,fs);
    m.crest = 20*log10(max(abs(y))/(sqrt(mean(y.^2))+eps));
    m.nlHF  = nlResid(y,x,fs,8000,20000);
    % how much saturation character survives in the kick band - guards against
    % buying punch by simply removing the low-end colour the listener wants
    m.nlLOW = nlResid(y,x,fs,40,200);
end

function p = punchOf(x, fs)
    b = bandpass1(x, fs, 40, 200);
    w5 = max(1,round(0.005*fs)); w150 = max(1,round(0.150*fs));
    env = movmax(abs(b), w5);
    sus = sqrt(movmean(b.^2, w150));
    % transients = local maxima of the fast envelope well above the slow one
    r = 20*log10((env+eps)./(sus+eps));
    thr = prctile(r, 97);
    sel = r >= thr;
    if ~any(sel); p = NaN; return; end
    p = mean(r(sel));
end

function c = bandCrest(x, fs, f1, f2)
    b = bandpass1(x, fs, f1, f2);
    c = 20*log10(prctile(abs(b),99.9)/(sqrt(mean(b.^2))+eps));
end

function s = tailSpread(x, fs)
    w = max(1,round(0.050*fs));
    e = sqrt(movmean(x.^2, w));
    e = e(e > max(e)*1e-4);                 % ignore true silence
    s = 20*log10(prctile(e,90)/max(prctile(e,10),eps));
end

function E = bandE(x,fs,f1,f2)
    N=numel(x); X=abs(fft(x.*hann(N))); X=X(1:floor(N/2)); fr=(0:numel(X)-1)*fs/N;
    E=sum(X(fr>=f1&fr<f2).^2)+eps;
end

function y = bandpass1(x, fs, f1, f2)
    [b1,a1]=butter(2, f2/(fs/2), 'low');
    [b2,a2]=butter(2, f1/(fs/2), 'high');
    y = filter(b2,a2, filter(b1,a1, x));
end

function d = nlResid(y, x, fs, f1, f2)
    nfft=4096; hop=nfft/4; w=hann(nfft,'periodic'); g=8192;
    if numel(x) < 4*g; d=NaN; return; end
    x=x(g:end-g); y=y(g:end-g); n=numel(x);
    nfr=max(1,floor((n-nfft)/hop)+1); X=zeros(nfft/2+1,nfr); Y=X;
    for k=1:nfr
        idx=(k-1)*hop+(1:nfft);
        Fx=fft(x(idx).*w,nfft); Fy=fft(y(idx).*w,nfft);
        X(:,k)=Fx(1:nfft/2+1); Y(:,k)=Fy(1:nfft/2+1);
    end
    H=sum(Y.*conj(X),2)./(sum(abs(X).^2,2)+eps); R=Y-H.*X;
    fr=(0:nfft/2)'*fs/nfft; sel=fr>=f1 & fr<f2;
    d=10*log10(max(sum(sum(abs(R(sel,:)).^2)),eps)/max(sum(sum(abs(X(sel,:)).^2)),eps));
end
