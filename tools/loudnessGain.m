function loudnessGain()
%LOUDNESSGAIN  How much LOUDNESS each voice buys at equal peak - the number that
%   matters when saturation is being used as a loudness tool.
%
%   Method: normalise dry and processed to the SAME peak (-1 dBFS), then compare
%   integrated loudness. Saturation lowers peak relative to RMS, so after
%   peak-normalising you end up louder; that difference is the loudness the
%   colour earned you. (Loudness-MATCHING the output, as an auto-gain would, hands
%   that back - correct for A/B auditioning, wrong for production use.)
    addpath('src'); addpath('.'); addpath('tools');
    cfg=config();
    files={'Disco_Test.wav','EDM_Test.wav','Epic_Drum_Test.wav'};
    fprintf('Loudness gain at equal peak (dB LUFS; higher = louder for the same ceiling)\n');
    fprintf('  %-20s%9s%9s%9s%9s%9s\n','material','tube50','tube100','sat50','sat100','both100');
    for i=1:numel(files)
        [x,fsp]=audioread(fullfile(cfg.paths.program,files{i})); x=x(:,1); fs=fsp;
        L0=lufsAtPeak(x,fs); c0=crest(x);
        fprintf('  %-20s', files{i});
        for s={'tube50','tube100','sat50','sat100','both100'}
            c=cfg;
            for b=1:c.multiband.num_bands
                switch s{1}
                case 'tube50';   md='subtle_tube';        w=0.5;
                case 'tube100';  md='subtle_tube';        w=1.0;
                case 'sat50';    md='subtle_saturation';  w=0.5;
                case 'sat100';   md='subtle_saturation';  w=1.0;
                case 'both100';  if b<=2; md='subtle_tube'; else; md='subtle_saturation'; end; w=1.0;
                end
                c.multiband.bands(b).mode=md; c.multiband.bands(b).dry_wet=w; c.multiband.bands(b).drive=1;
            end
            y=multibandProcess(x,c,fs);
            fprintf('%9.2f', lufsAtPeak(y,fs)-L0);
        end
        fprintf('   (dry crest %.1f dB)\n', c0);
    end
end
function L=lufsAtPeak(x,fs)
    x=x/max(abs(x))*10^(-1/20);          % same peak ceiling for everything
    if exist('integratedLoudness','file'); L=integratedLoudness(x,fs);
    else; L=20*log10(sqrt(mean(x.^2))+eps)-0.691; end
end
function c=crest(x); c=20*log10(max(abs(x))/(sqrt(mean(x.^2))+eps)); end
