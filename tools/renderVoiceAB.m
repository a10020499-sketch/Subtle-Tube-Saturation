function renderVoiceAB(outName, srcFiles, variants)
%RENDERVOICEAB  Render an A/B set of voice configs, in the source's OWN channel
%   count. Always process every channel: a mono fold-down of a stereo source
%   changes the image as well as the tone, which makes an A/B against a stereo
%   render meaningless (that mistake produced an apparent difference between two
%   files that were in fact processing-identical - peaks matched to 4 decimals).
%
%   variants: struct array with .name and .dof (an explicit coloration config) and
%   .track (which core to use). Nothing is level-matched here - these are raw
%   renders, so the level is whatever the colour actually produces.
    addpath('src'); addpath('.'); addpath('tools');
    cfg=config();
    od=fullfile(cfg.paths.output, outName);
    if ~exist(od,'dir'); mkdir(od); end
    for i=1:numel(srcFiles)
        [x,fs]=audioread(srcFiles{i});
        [~,b]=fileparts(srcFiles{i});
        writeAudioSafe(fullfile(od,sprintf('%s__0dry.wav',b)), x, fs, 24);
        for v=1:numel(variants)
            y=zeros(size(x));
            for ch=1:size(x,2)
                y(:,ch)=processSignal(x(:,ch), variants(v).dof, fs, variants(v).track);
            end
            info=writeAudioSafe(fullfile(od,sprintf('%s__%s.wav',b,variants(v).name)), y, fs, 24);
            fprintf('  %-22s %-22s %dch peak %.4f %s\n', b, variants(v).name, ...
                size(x,2), info.peak, info.format);
        end
    end
    fprintf('-> %s\n', od);
end
