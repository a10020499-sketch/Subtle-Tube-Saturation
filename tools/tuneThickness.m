function tuneThickness(track, fs)
%TUNETHICKNESS  Phase B iter 02: recover the density the HF-clean split gave up,
%   without giving back the HF fizz. Scores every candidate on BOTH axes at once:
%
%     crest  loudness-matched crest factor, dB. Baseline A is the thickness the
%            listener wants back; B is the thin one. LOWER = denser = thicker.
%     nlHF   nonlinear residual 8-20 kHz, dB rel input. B is the cleanliness the
%            listener wants to keep. LOWER = cleaner.
%
%   A candidate wins only if it moves crest back toward A while holding nlHF
%   near B - improving one at the other's expense is what the listener rejected.

    if nargin<1||isempty(track); track='subtle_tube'; end
    if nargin<2||isempty(fs);    fs=48000; end
    cfg=config(); dof0=cfg.tracks.(track).dof;
    files={'EDM_Test.wav','Epic_Drum_Test.wav','Disco_Test.wav'};

    C = {};
    C{end+1}=struct('name','A baseline',      'p',@(d) d);
    C{end+1}=struct('name','B hf8k',          'p',@(d) hf(d,8000,0,0));
    C{end+1}=struct('name','E follow .5',     'p',@(d) hf(d,8000,0,0.5));
    C{end+1}=struct('name','E follow 1.0',    'p',@(d) hf(d,8000,0,1.0));
    C{end+1}=struct('name','F beta .35',      'p',@(d) hf(d,8000,0.35,0));
    C{end+1}=struct('name','G beta.35+fol1',  'p',@(d) hf(d,8000,0.35,1.0));
    C{end+1}=struct('name','H fol1+drive1.15','p',@(d) drv(hf(d,8000,0,1.0),1.15));

    fprintf('[%s]  crest: lower = thicker (target ~A)   nlHF: lower = cleaner (target ~B)\n', track);
    fprintf('  %-17s |', 'variant');
    for i=1:numel(files); fprintf(' %-13s', erase(files{i},'_Test.wav')); end
    fprintf(' |  nlHF\n');
    for c=1:numel(C)
        fprintf('  %-17s |', C{c}.name);
        for i=1:numel(files)
            [x,~]=audioread(fullfile(cfg.paths.program,files{i})); x=x(:,1);
            d=C{c}.p(dof0);
            y=processSignal(x,d,fs,track);
            y=y*10^((loud(x,fs)-loud(y,fs))/20);
            fprintf('  %5.2f       ', crest(y));
        end
        [xe,~]=audioread(fullfile(cfg.paths.program,'EDM_Test.wav')); xe=xe(1:4*fs,1);
        fprintf(' | %6.1f\n', nlHF(@(v) processSignal(v,C{c}.p(dof0),fs,track), xe, fs));
    end
end

function d=hf(d,fc,beta,follow)
    d.hf_clean.enabled=true; d.hf_clean.freq_hz=fc; d.hf_clean.gain_match=true;
    d.hf_clean.beta=beta; d.hf_clean.follow=follow;
    d.hf_clean.follow_attack_ms=1; d.hf_clean.follow_release_ms=30;
end
function d=drv(d,k); d.shaper.drive_k=d.shaper.drive_k*k; end
function c=crest(x); c=20*log10(max(abs(x))/(sqrt(mean(x.^2))+eps)); end
function L=loud(x,fs)
    if exist('integratedLoudness','file'); L=integratedLoudness(x,fs);
    else; L=20*log10(sqrt(mean(x(:).^2))+eps)-0.691; end
end
function d = nlHF(proc, x, fs)
    y=proc(x); n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);
    nfft=4096; hop=nfft/4; w=hann(nfft,'periodic'); g=8192;
    x=x(g:end-g); y=y(g:end-g); n=numel(x);
    nfr=max(1,floor((n-nfft)/hop)+1); X=zeros(nfft/2+1,nfr); Y=X;
    for k=1:nfr
        idx=(k-1)*hop+(1:nfft);
        Fx=fft(x(idx).*w,nfft); Fy=fft(y(idx).*w,nfft);
        X(:,k)=Fx(1:nfft/2+1); Y(:,k)=Fy(1:nfft/2+1);
    end
    H=sum(Y.*conj(X),2)./(sum(abs(X).^2,2)+eps); R=Y-H.*X;
    fr=(0:nfft/2)'*fs/nfft; sel=fr>=8000 & fr<20000;
    d=10*log10(max(sum(sum(abs(R(sel,:)).^2)),eps)/max(sum(sum(abs(X(sel,:)).^2)),eps));
end
