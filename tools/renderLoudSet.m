function renderLoudSet()
%RENDERLOUDSET  Audition set for the loudness voicings, full-band (the only way
%   they buy loudness - see LOUDNESS_NOTES.md section 4).
%
%   Two normalisations per file, because two different questions are being asked:
%     __peaknorm  all versions at the SAME PEAK (-1 dBFS). This is how you would
%                 actually use it, so the louder one really is louder - that
%                 difference IS the benefit.
%     __loudmatch all versions at the same LOUDNESS. Levels out the benefit so the
%                 timbre cost (the "fizz" coming back) can be judged on its own.
    addpath('src'); addpath('.'); addpath('tools');
    cfg=config();
    files={'Disco_Test.wav','Epic_Drum_Test.wav','EDM_Test.wav','Drum_Test.wav'};
    for tr={'subtle_tube','subtle_saturation'}
        t=tr{1};
        od=fullfile(cfg.paths.output,t,'voice','loud','iter_00');
        if ~exist(od,'dir'); mkdir(od); end
        for i=1:numel(files)
            [x,fs]=audioread(fullfile(cfg.paths.program,files{i})); x=x(:,1);
            b=erase(files{i},'.wav');
            V={ {'0dry',x}, ...
                {'final', processSignal(x,cfg.voice.(t).final,fs,t)}, ...
                {'loud',  processSignal(x,cfg.voice.(t).loud, fs,t)} };
            for v=1:numel(V)
                y=V{v}{2};
                audiowrite(fullfile(od,sprintf('%s__%s__peaknorm.wav',b,V{v}{1})), ...
                    clip(y/max(abs(y))*10^(-1/20)), fs, 'BitsPerSample',24);
                g=10^((rmsdb(x)-rmsdb(y))/20);
                audiowrite(fullfile(od,sprintf('%s__%s__loudmatch.wav',b,V{v}{1})), ...
                    clip(y*g), fs, 'BitsPerSample',24);
            end
        end
        fprintf('%s loud set: %d files -> %s\n', t, numel(dir(fullfile(od,'*.wav'))), od);
    end
end
function y=clip(x); y=max(min(x,1),-1); end
function v=rmsdb(x); v=20*log10(sqrt(mean(x.^2))+eps); end
