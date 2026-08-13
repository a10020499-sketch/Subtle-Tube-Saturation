function out = evalHFOptions(track, fs, progFile)
%EVALHFOPTIONS  Compare candidate cures for the Phase B "harsh / fizzy highs"
%   (數位感、高頻麻麻的) feedback, with metrics that actually capture it.
%
%   WHY THE OBVIOUS METRICS DON'T WORK
%   * "HF harmonic energy of a tone" is useless here: at 48 kHz an 8 kHz tone
%     through an odd-only curve produces no in-band harmonics (H2~0 because the
%     curve is odd, H3 sits at/above Nyquist). The audible grit on real material
%     is INTERMODULATION between simultaneous partials - inharmonic products,
%     which is exactly what "fizzy" describes.
%   * "loudness-match then subtract" charges a strategy for changing spectral
%     balance, not for adding junk. Any candidate that changes the tonal balance
%     (e.g. saturating only the lows) is unfairly penalised.
%
%   THE METRIC USED HERE - nonlinear residual via per-bin complex projection.
%   STFT the input and output; for every frequency bin solve the optimal complex
%   gain H(k) = <Y,X>/<X,X> over frames. H(k) absorbs ALL linear behaviour
%   (level, EQ, phase, delay) exactly, so the residual R = Y - H*X is purely the
%   nonlinearly-generated content. Reported per band relative to input power:
%       nlHF   nonlinear residual in 8-20 kHz, dB rel input  (the "fizz")
%       nlMID  nonlinear residual in 200-2000 Hz, dB rel input
%              (the wanted warmth/character - should be PRESERVED, not minimised)
%   Immune to linear differences, so strategies with different tonal balance are
%   compared fairly.
%
%   IMD is measured at three tone pairs deliberately placed relative to a
%   band-split crossover, because a pair sitting entirely above the crossover
%   never reaches the nonlinearity and would flatter a band-split strategy:
%       imdHI   7.0 + 8.0 kHz   (both above a 4-6 kHz crossover)
%       imdX    3.0 + 3.5 kHz   (straddles / just below a 4 kHz crossover)
%       imdLO   0.9 + 1.0 kHz   (both well below - sanity check that the wanted
%                                mid-band distortion is still there)
%   plus a dense multitone (non-harmonically spaced) closer to real material.

    if nargin<1||isempty(track);    track='subtle_saturation'; end
    if nargin<2||isempty(fs);       fs=48000; end
    if nargin<3||isempty(progFile); progFile='EDM_Test.wav'; end

    cfg=config(); dof0=cfg.tracks.(track).dof;
    [xp,fsp]=audioread(fullfile(cfg.paths.program,progFile));
    xp=xp(1:min(end,round(4*fsp)),1);
    assert(fsp==fs,'program fs %d ~= %d',fsp,fs);

    cand = {};
    cand{end+1} = struct('name','baseline','dof',dof0,'split',0);
    for g=[5 8]
        d=dof0;
        d.preEQ.stages  = struct('type','highshelf','freq_hz',4000,'gain_db',-g,'q',0.6);
        d.postEQ.stages = struct('type','highshelf','freq_hz',4000,'gain_db', g,'q',0.6);
        cand{end+1} = struct('name',sprintf('emphasis 4k -%ddB',g),'dof',d,'split',0); %#ok<AGROW>
    end
    for fc=[4000 6000 8000]
        cand{end+1} = struct('name',sprintf('HF-clean split %dk',fc/1000),'dof',dof0,'split',fc); %#ok<AGROW>
    end
    d=dof0; d.shaper.drive_k=0.7;
    cand{end+1} = struct('name','drive 0.7','dof',d,'split',0);

    fprintf('[%s] %s @ %d Hz   (all dB; nlMID should stay HIGH = character kept)\n', track, progFile, fs);
    fprintf('  %-22s | nlHF    nlMID  | imdHI  imdX   imdLO  multi\n','strategy');
    rows={};
    for i=1:numel(cand)
        c=cand{i};
        proc=@(x) runChain(x, c.dof, fs, track, c.split);
        [nlHF,nlMID] = nonlinResidual(proc, xp, fs);
        imdHI = imdPair(proc, fs, 7000, 8000);
        imdX  = imdPair(proc, fs, 3000, 3500);
        imdLO = imdPair(proc, fs,  900, 1000);
        multi = imdMultitone(proc, fs);
        fprintf('  %-22s |%6.1f %7.1f  |%6.1f %6.1f %6.1f %6.1f\n', ...
            c.name, nlHF, nlMID, imdHI, imdX, imdLO, multi);
        rows{end+1}=struct('name',c.name,'nlHF',nlHF,'nlMID',nlMID, ...
            'imdHI',imdHI,'imdX',imdX,'imdLO',imdLO,'multi',multi); %#ok<AGROW>
    end
    out=struct('track',track,'rows',{rows});
end

% ---- chain: always the SHIPPED path, so the table describes what we ship ----
function y = runChain(x, dof, fs, track, splitHz)
    if splitHz > 0
        dof.hf_clean.enabled = true;
        dof.hf_clean.freq_hz = splitHz;
        dof.hf_clean.gain_match = true;    % the earlier local copy omitted this
    end
    y = processSignal(x, dof, fs, track);
end

% ---- metrics --------------------------------------------------------------
function [nlHF, nlMID] = nonlinResidual(proc, x, fs)
%NONLINRESIDUAL  nonlinear (uncorrelated) residual per band, dB rel input power.
%   Per-bin complex projection removes every linear difference exactly.
    y = proc(x); n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);
    nfft=4096; hop=nfft/4; w=hann(nfft,'periodic');
    nfr=max(1,floor((n-nfft)/hop)+1);
    X=zeros(nfft/2+1,nfr); Y=X;
    for k=1:nfr
        idx=(k-1)*hop+(1:nfft);
        Fx=fft(x(idx).*w,nfft); Fy=fft(y(idx).*w,nfft);
        X(:,k)=Fx(1:nfft/2+1); Y(:,k)=Fy(1:nfft/2+1);
    end
    num=sum(Y.*conj(X),2); den=sum(abs(X).^2,2)+eps;
    H=num./den;                                  % optimal linear response per bin
    R=Y-H.*X;                                    % purely nonlinear residual
    fr=(0:nfft/2)'*fs/nfft;
    nlHF  = bandRatio(R,X,fr,8000,20000);
    nlMID = bandRatio(R,X,fr,200,2000);
end
function d = bandRatio(R,X,fr,f1,f2)
    sel=fr>=f1 & fr<f2;
    d=10*log10( max(sum(sum(abs(R(sel,:)).^2)),eps) / max(sum(sum(abs(X(sel,:)).^2)),eps) );
end

function d = imdPair(proc, fs, f1, f2)
%IMDPAIR  two equal tones; energy in bins that are neither tone nor a harmonic of
%   either -> intermodulation products, dB rel the tone pair.
    t=(0:round(0.5*fs)-1)'/fs;
    x=0.35*(sin(2*pi*f1*t)+sin(2*pi*f2*t));
    d=inharmonicEnergy(proc(x), fs, [f1 f2]);
end

function d = imdMultitone(proc, fs)
%IMDMULTITONE  dense, mutually non-harmonic partials (closer to real material).
    f=[311 523 881 1367 2153 3391 5387 8069];    % no simple integer ratios
    t=(0:round(0.5*fs)-1)'/fs; x=zeros(size(t));
    for i=1:numel(f); x=x+sin(2*pi*f(i)*t + 0.7*i); end
    x=0.7*x/max(abs(x));
    d=inharmonicEnergy(proc(x), fs, f);
end

function d = inharmonicEnergy(y, fs, tones)
    y=y(:)-mean(y); N=numel(y);
    Y=abs(fft(y.*hann(N))); Y=Y(1:floor(N/2)); P=Y.^2; fr=(0:numel(P)-1)*fs/N;
    tol=max(60,4*fs/N);
    keep=true(size(P)); keep(fr<20)=false; tone=0;
    for f=tones
        tone=tone+sum(P(abs(fr-f)<=tol));
        keep(abs(fr-f)<=tol)=false;
        for n=2:6; if n*f<fs/2; keep(abs(fr-n*f)<=tol)=false; end; end
    end
    d=10*log10(max(sum(P(keep)),eps)/max(tone,eps));
end
