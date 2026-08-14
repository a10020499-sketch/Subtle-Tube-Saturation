function renderVoiceVariants(track, voiceStage, iterId, variants, fileList, srcDir, matchLoudness)
%RENDERVOICEVARIANTS  Render several candidate voicings side by side for a Phase B
%   A/B listening test (SPECIFICATION 4.6, R-ListeningProtocol).
%
%   variants: struct array with
%       .name   short label used in the filename
%       .patch  function handle dof -> dof (applies the variant to the track dof)
%   Every variant is loudness-matched to the DRY file's integrated loudness, so
%   differences heard are timbre, never level. The match gain is monitoring-only
%   and never written back into any parameter. The dry file is written once.
%
%   Program material is processed at its native sample rate.

    cfg = config();
    if nargin < 6 || isempty(srcDir); srcDir = cfg.paths.program; end
    % Loudness matching is mandatory for LISTENING (R-ListeningProtocol) but wrong
    % for measurement probes: to read a spectrum analyser you want the real gain
    % and harmonic levels the processor applies, not a re-levelled version.
    if nargin < 7 || isempty(matchLoudness); matchLoudness = true; end
    progDir = srcDir;
    outDir  = fullfile(cfg.paths.output, track, 'voice', voiceStage, sprintf('iter_%02d', iterId));
    if ~exist(outDir,'dir'); mkdir(outDir); end
    if nargin < 5 || isempty(fileList)
        d = dir(fullfile(progDir,'*.wav'));
        fileList = setdiff({d.name}, {'01_tone_battery.wav'});
    end

    dof0 = cfg.tracks.(track).dof;
    rows = struct('program',{},'variant',{},'match_gain_db',{},'peak',{});

    for i = 1:numel(fileList)
        fn = fileList{i}; base = erase(fn,'.wav');
        [x, fs] = audioread(fullfile(progDir, fn));
        audiowrite(fullfile(outDir, sprintf('%s__0dry.wav', base)), clip(x), fs, 'BitsPerSample',24);
        Ldry = loud(x, fs);

        for v = 1:numel(variants)
            dof = variants(v).patch(dof0);
            y = zeros(size(x));
            for ch = 1:size(x,2)
                y(:,ch) = processSignal(x(:,ch), dof, fs, track);
            end
            if matchLoudness
                gDb = Ldry - loud(y, fs); y = y * 10^(gDb/20);
            else
                gDb = 0;                       % probes: keep the real level
            end
            audiowrite(fullfile(outDir, sprintf('%s__%s.wav', base, variants(v).name)), ...
                       clip(y), fs, 'BitsPerSample',24);
            rows(end+1) = struct('program',fn,'variant',variants(v).name, ...
                'match_gain_db',gDb,'peak',max(abs(y(:)))); %#ok<AGROW>
            fprintf('  %-20s %-14s match %+5.2f dB  peak %.3f\n', fn, variants(v).name, gDb, max(abs(y(:))));
        end
    end

    manifest = struct('track',track,'voice_stage',voiceStage,'iteration',iterId, ...
        'loudness_match','each variant matched to the dry file integrated loudness', ...
        'listening_blinded',false,'variants',{{variants.name}},'items',rows);
    fid=fopen(fullfile(outDir,'listening_manifest.json'),'w');
    fwrite(fid, jsonencode(manifest,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('renderVoiceVariants(%s): %d files x %d variants -> %s\n', ...
        track, numel(fileList), numel(variants), outDir);
end

function y = clip(x); y = max(min(x,1),-1); end
function L = loud(x, fs)
    if exist('integratedLoudness','file'); L = integratedLoudness(x, fs);
    else; L = 20*log10(sqrt(mean(x(:).^2))+eps) - 0.691; end
end
