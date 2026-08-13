function out = diagnoseAliasing(track, fs, osList, progFile)
%DIAGNOSEALIASING  Quantify aliasing in the coloration chain (SPECIFICATION 5.2
%   "high-frequency test tones: any observable aliasing?"; Phase B feedback
%   "digital / harsh highs" -> H1 per the 3.6 mapping table).
%
%   Two independent measurements:
%     1) TONE TEST — a pure HF sine in, everything that is NOT at a harmonic of
%        f0 is aliasing (the input is numerically pure, so non-harmonic energy
%        has nowhere else to come from). Reported in dB relative to the
%        fundamental, per oversampling factor.
%     2) GOLD-REFERENCE TEST — the same program audio processed at a very high
%        oversampling factor is the alias-free ideal; the difference against a
%        lower factor is the audible aliasing error, in dB.
%
%   Defaults to fs = 48000 (the program-material rate the user auditions at,
%   where aliasing is worst) rather than the 96 kHz measurement rate.
%
%   out.tone (freq x os alias table), out.gold (os -> error dB)

    if nargin<1||isempty(track);   track='subtle_saturation'; end
    if nargin<2||isempty(fs);      fs=48000; end
    if nargin<3||isempty(osList);  osList=[4 8 16]; end
    if nargin<4;                   progFile='EDM_Test.wav'; end

    cfg=config(); dof0=cfg.tracks.(track).dof;
    GOLD_OS = 32;

    % ---------- 1) tone test -------------------------------------------------
    tones=[2000 4000 6000 8000 11000];
    dur=0.4; t=(0:round(dur*fs)-1)'/fs; amp=10^(-6/20);
    T=nan(numel(tones),numel(osList));
    fprintf('[%s] TONE alias energy (dB rel fundamental), fs=%d\n', track, fs);
    fprintf('   f0(Hz) |'); fprintf('   OS=%-2d ', osList); fprintf('\n');
    for i=1:numel(tones)
        x=amp*sin(2*pi*tones(i)*t);
        fprintf('   %5d  |', tones(i));
        for j=1:numel(osList)
            dof=dof0; dof.oversample.factor=osList(j);
            y=processSignal(x,dof,fs,track);
            T(i,j)=aliasEnergyDb(y,tones(i),fs);
            fprintf(' %6.1f ', T(i,j));
        end
        fprintf('\n');
    end

    % ---------- 2) gold-reference test on program audio ---------------------
    G=nan(1,numel(osList));
    p=fullfile(cfg.paths.program,progFile);
    if isfile(p)
        [xp,fsp]=audioread(p); xp=xp(1:min(end,round(3*fsp)),1);   % 3 s mono
        dofG=dof0; dofG.oversample.factor=GOLD_OS;
        yg=processSignal(xp,dofG,fsp,track);
        fprintf('\n[%s] GOLD test (%s, %d s @ %d Hz): error vs OS=%d\n', ...
            track, progFile, round(numel(xp)/fsp), fsp, GOLD_OS);
        for j=1:numel(osList)
            dof=dof0; dof.oversample.factor=osList(j);
            y=processSignal(xp,dof,fsp,track);
            n=min(numel(y),numel(yg));
            G(j)=10*log10(max(sum((y(1:n)-yg(1:n)).^2),eps)/max(sum(yg(1:n).^2),eps));
            fprintf('   OS=%-2d : %6.1f dB\n', osList(j), G(j));
        end
    end

    out=struct('track',track,'fs',fs,'os_list',osList,'tones_hz',tones, ...
               'tone_alias_db',T,'gold_error_db',G,'gold_os',GOLD_OS);
end

function d=aliasEnergyDb(y,f0,fs)
%ALIASENERGYDB  energy not at any harmonic of f0, relative to the fundamental.
    y=y(:)-mean(y); N=numel(y); w=hann(N);
    Y=abs(fft(y.*w)); Y=Y(1:floor(N/2)); P=Y.^2;
    fr=(0:numel(P)-1)*fs/N;
    keep=true(size(P));
    keep(fr<20)=false;                                   % ignore DC/subsonic
    tol=max(60, 4*fs/N);                                 % harmonic exclusion halfwidth
    for n=1:floor((fs/2)/f0)
        keep(abs(fr-n*f0)<=tol)=false;                   % exclude real harmonics
    end
    fund=sum(P(abs(fr-f0)<=tol));
    d=10*log10(max(sum(P(keep)),eps)/max(fund,eps));
end
