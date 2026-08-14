function diagnoseThickness(track, fs)
%DIAGNOSETHICKNESS  Why does the HF-clean split sound thinner? (Phase B iter 02)
%   Listener: "B/C/D are more transparent but thinner - tube lost warmth,
%   saturation got thin; want something between A and B."
%
%   A saturator's perceived "thickness" is mostly PEAK COMPRESSION: the curve
%   pulls peaks down, so after loudness matching the programme sits denser. If
%   the split lets HF transients bypass the curve, crest factor rises and the
%   result reads as thinner even though the mid-band distortion is unchanged.
%   This measures that directly, loudness-matched exactly as the audition was.

    if nargin<1||isempty(track); track='subtle_saturation'; end
    if nargin<2||isempty(fs);    fs=48000; end
    cfg=config(); dof0=cfg.tracks.(track).dof;
    files={'EDM_Test.wav','Epic_Drum_Test.wav','Disco_Test.wav'};

    variants={ struct('name','A baseline','fc',0,'beta',0,'drive',1.0), ...
               struct('name','B hf8k',    'fc',8000,'beta',0,'drive',1.0)};

    fprintf('[%s] loudness-matched, as auditioned\n', track);
    fprintf('  %-18s %-12s | crest  peak   dRMSmid  gainRed\n','file','variant');
    for i=1:numel(files)
        [x,fsp]=audioread(fullfile(cfg.paths.program,files{i})); x=x(:,1);
        assert(fsp==fs);
        cd0=crest(x);
        fprintf('  %-18s %-12s | %5.2f %6.2f      -        -\n', files{i}, 'dry', cd0, dbfs(max(abs(x))));
        for v=1:numel(variants)
            d=dof0; vv=variants{v};
            if vv.fc>0
                d.hf_clean.enabled=true; d.hf_clean.freq_hz=vv.fc;
                d.hf_clean.beta=vv.beta; d.hf_clean.gain_match=true;
            end
            d.shaper.drive_k = dof0.shaper.drive_k*vv.drive;
            y=processSignal(x,d,fs,track);
            y=y*10^((loud(x,fs)-loud(y,fs))/20);          % same match as the audition
            % peak-compression amount actually delivered: how much the curve
            % pulled the peaks down relative to a purely linear version
            g=smallSig(d,fs,track);
            gainRed = dbfs(max(abs(y))) - dbfs(max(abs(g*x))) - (loud(x,fs)-loud(g*x,fs));
            fprintf('  %-18s %-12s | %5.2f %6.2f   %+6.2f  %+6.2f\n', '', vv.name, ...
                crest(y), dbfs(max(abs(y))), midRms(y,fs)-midRms(x,fs), gainRed);
        end
    end
end
function c=crest(x); c=20*log10(max(abs(x))/(sqrt(mean(x.^2))+eps)); end
function d=dbfs(v); d=20*log10(max(v,eps)); end
function r=midRms(x,fs)
    N=numel(x); X=abs(fft(x.*hann(N))); X=X(1:floor(N/2)); fr=(0:numel(X)-1)*fs/N;
    r=10*log10(sum(X(fr>=200&fr<2000).^2)+eps);
end
function L=loud(x,fs)
    if exist('integratedLoudness','file'); L=integratedLoudness(x,fs);
    else; L=20*log10(sqrt(mean(x(:).^2))+eps)-0.691; end
end
function g=smallSig(dof,fs,track)
    n=round(0.05*fs); t=(0:n-1)'/fs; p=10^(-60/20)*sin(2*pi*1000*t);
    d=dof; if isfield(d,'hf_clean'); d.hf_clean.enabled=false; end
    q=processSignal(p,d,fs,track); g=sqrt(mean(q.^2))/max(sqrt(mean(p.^2)),eps);
end
