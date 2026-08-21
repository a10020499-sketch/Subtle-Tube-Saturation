function loudnessMode()
%LOUDNESSMODE  Isolate each anti-loudness lever, so the trade can be chosen rather
%   than bundled. Loudness at a fixed ceiling comes from peak compression; every
%   lever added during voice tuning for transparency and impact works against it.
%
%     dLUFS  loudness change at equal peak (POSITIVE = louder for the same ceiling)
%     crest  loudness-matched crest factor, dB (lower = denser)
%     nlHF   8-20 kHz nonlinear residual, dB (the "fizz" the HF split was added to cure)

    addpath('src'); addpath('.'); addpath('tools');
    cfg=config();
    files={'Disco_Test.wav','EDM_Test.wav','Epic_Drum_Test.wav'};
    for tr={'subtle_tube','subtle_saturation'}
        t=tr{1};
        V={};
        V{end+1}=struct('n','A final (signed off)','p',@(d) d);
        V{end+1}=struct('n','B transient off',     'p',@(d) tpOff(d));
        V{end+1}=struct('n','C no air',            'p',@(d) noAir(d));
        V{end+1}=struct('n','D = B + C',           'p',@(d) noAir(tpOff(d)));
        V{end+1}=struct('n','E = D + drive1.3',    'p',@(d) drv(noAir(tpOff(d)),1.3));
        V{end+1}=struct('n','F = D + drive1.6',    'p',@(d) drv(noAir(tpOff(d)),1.6));
        V{end+1}=struct('n','G = F + beta1.0',     'p',@(d) bta(drv(noAir(tpOff(d)),1.6),1.0));
        fprintf('\n[%s]\n  %-22s', t, 'voicing');
        for i=1:numel(files); fprintf('%22s', erase(files{i},'_Test.wav')); end
        fprintf('\n');
        for k=1:numel(V)
            fprintf('  %-22s', V{k}.n);
            for i=1:numel(files)
                [x,fs]=audioread(fullfile(cfg.paths.program,files{i})); x=x(:,1);
                d=V{k}.p(cfg.voice.(t).final);
                y=processSignal(x,d,fs,t);
                dl=lufsAtPeak(y,fs)-lufsAtPeak(x,fs);
                ym=y*10^((rmsdb(x)-rmsdb(y))/20);
                fprintf('%8.2f%7.1f%7.1f', dl, crest(ym), nlB(ym,x,fs,8000,20000));
            end
            fprintf('\n');
        end
    end
    fprintf('\n  per material: dLUFS | crest | nlHF     (dry crest: Disco 10.0, EDM 8.1, Epic 14.0 dB)\n');
end
function d=tpOff(d); if isfield(d,'transient'); d.transient.enabled=false; end; end
function d=bta(d,b);  if isfield(d,'hf_clean'); d.hf_clean.beta=b; end; end
function d=noAir(d);  d.postEQ.stages=struct('type',{},'freq_hz',{},'gain_db',{},'q',{}); end
function d=drv(d,k);  d.shaper.drive_k=d.shaper.drive_k*k; end
function L=lufsAtPeak(x,fs)
    x=x/max(abs(x))*10^(-1/20);
    if exist('integratedLoudness','file'); L=integratedLoudness(x,fs);
    else; L=20*log10(sqrt(mean(x.^2))+eps)-0.691; end
end
function c=crest(x); c=20*log10(max(abs(x))/(sqrt(mean(x.^2))+eps)); end
function v=rmsdb(x); v=20*log10(sqrt(mean(x.^2))+eps); end
