function tuneDrive(track)
%TUNEDRIVE  Phase B iter 07: the listener asked for MORE effect at 100% wet
%   ("tube warmer / more broken up by ~20%", "saturation upper-mids and highs more
%   exciting by ~30%") on the grounds that a Wet control lets them dial back.
%
%   Reports, loudness-matched:
%     H2/H3     harmonic content at 1 kHz -12 dBFS, dB rel fundamental. For the
%               tube H2 is the "warmth" (even harmonics from the bias); H3 is the
%               drive/breakup. For saturation H3/H5 are the whole voice.
%     exc       2-8 kHz nonlinear residual vs input, dB - the "exciting" harmonics
%               generated from mid content (harmonically related, unlike the IMD
%               hash the listener rejected earlier)
%     body      200-2000 Hz nonlinear residual, dB - density/thickness
%     air       10-16 kHz level vs dry, dB
%     clamp     %% of oversampled samples riding the curve's saturation ceiling.
%               Non-zero is normal for a driven saturator (the join is C1 so it is
%               a soft limit, not a discontinuity) but large values mean the curve
%               has run out of range and the voice stops changing.

    cfg=config(); fs=48000;
    switch lower(track)
    case 'subtle_tube'
        d0=cfg.tracks.subtle_tube.dof;
        base=@(d) setTP(hfVariant(d,8000,0.75,1.0),1.0);       % the approved U3
        C={ struct('n','U3 (current)','p',@(d) base(d)), ...
            struct('n','drive 1.15',  'p',@(d) drv(base(d),1.15)), ...
            struct('n','drive 1.30',  'p',@(d) drv(base(d),1.30)), ...
            struct('n','bias 1.25',   'p',@(d) bias(base(d),1.25)), ...
            struct('n','drive1.2+bias1.25','p',@(d) bias(drv(base(d),1.2),1.25)), ...
            struct('n','drive1.3+bias1.4', 'p',@(d) bias(drv(base(d),1.3),1.4))};
        file='Disco_Test.wav';
    case 'subtle_saturation'
        d0=cfg.tracks.subtle_saturation.dof;
        base=@(d) withUpward(withEQ(hfVariant(d,8000,0.50,1.0),'post','highshelf',8000,3.0,0.7),1.5,-30,18);
        C={ struct('n','V0 (current)','p',@(d) base(d)), ...
            struct('n','drive 1.15', 'p',@(d) drv(base(d),1.15)), ...
            struct('n','drive 1.30', 'p',@(d) drv(base(d),1.30)), ...
            struct('n','drive 1.45', 'p',@(d) drv(base(d),1.45)), ...
            struct('n','dr1.3+air+1','p',@(d) withEQ(drv(base(d),1.3),'post','highshelf',8000,1.0,0.7)), ...
            struct('n','dr1.3+beta.7','p',@(d) bta(drv(base(d),1.3),0.70))};
        file='Disco_Test.wav';
    end

    [x,fsp]=audioread(fullfile(cfg.paths.program,file)); x=x(:,1); assert(fsp==fs);
    t=(0:round(0.5*fs)-1)'/fs; tone=10^(-12/20)*sin(2*pi*1000*t);
    fprintf('[%s] %s + 1 kHz tone, loudness-matched\n', track, file);
    fprintf('  %-18s%8s%8s%8s%8s%8s%8s\n','variant','H2','H3','exc','body','air','clamp%');
    for k=1:numel(C)
        d=C{k}.p(d0);
        yt=processSignal(tone,d,fs,track);
        y =processSignal(x,d,fs,track);
        y =y*10^((20*log10(sqrt(mean(x.^2)))-20*log10(sqrt(mean(y.^2))))/20);
        m=voiceMetrics(y,x,fs);
        fprintf('  %-18s%8.1f%8.1f%8.1f%8.1f%8.2f%8.2f\n', C{k}.n, ...
            hk(yt,fs,2), hk(yt,fs,3), nlBand(y,x,fs,2000,8000), nlBand(y,x,fs,200,2000), ...
            m.air, clampPct(x,d,fs,track));
    end
end

function d=drv(d,k);  d.shaper.drive_k=d.shaper.drive_k*k; end
function d=bias(d,k); if isfield(d,'dynamic_bias'); d.dynamic_bias.depth=d.dynamic_bias.depth*k; end; end
function d=bta(d,b);  d.hf_clean.beta=b; end

function v=hk(y,fs,k)
    y=y(:)-mean(y); N=numel(y); Y=abs(fft(y.*hann(N))); Y=Y(1:floor(N/2));
    fr=(0:numel(Y)-1)*fs/N; bw=30;
    f=max(Y(fr>=1000-bw&fr<=1000+bw)); h=max(Y(fr>=k*1000-bw&fr<=k*1000+bw));
    v=20*log10(max(h,eps)/max(f,eps));
end

function p=clampPct(x,dof,fs,track) %#ok<INUSD>
    if isfield(dof,'hf_clean') && dof.hf_clean.enabled
        b=crossoverBank(x,dof.hf_clean.freq_hz,fs);
        x=b{1}+dof.hf_clean.beta*b{2};
    end
    v=preEQ(x,dof,fs); L=dof.oversample.factor;
    if L>1; v=resample(v,L,1); end
    u=dof.shaper.drive_k*v;
    pw=dof.shaper.powers(:); c=dof.shaper.coeffs(:);
    uu=linspace(1e-4,4,40001)'; dd=zeros(size(uu));
    for i=1:numel(pw); dd=dd+c(i)*pw(i)*uu.^(pw(i)-1); end
    kk=find(dd<=0,1); if isempty(kk); p=0; return; end
    p=100*mean(abs(u)>uu(kk));
end

function d=nlBand(y,x,fs,f1,f2)
    n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);
    nfft=4096; hop=nfft/4; w=hann(nfft,'periodic'); g=8192;
    x=x(g:end-g); y=y(g:end-g); n=numel(x);
    nfr=max(1,floor((n-nfft)/hop)+1); X=zeros(nfft/2+1,nfr); Y=X;
    for k=1:nfr
        idx=(k-1)*hop+(1:nfft);
        Fx=fft(x(idx).*w,nfft); Fy=fft(y(idx).*w,nfft);
        X(:,k)=Fx(1:nfft/2+1); Y(:,k)=Fy(1:nfft/2+1);
    end
    H=sum(Y.*conj(X),2)./(sum(abs(X).^2,2)+eps); R=Y-H.*X;
    fr=(0:nfft/2)'*fs/nfft; sel=fr>=f1&fr<f2;
    d=10*log10(max(sum(sum(abs(R(sel,:)).^2)),eps)/max(sum(sum(abs(X(sel,:)).^2)),eps));
end
