function renderListeningSet(track, voiceStage, iterId, fileList)
%RENDERLISTENINGSET  Phase B loudness-matched listening set (R-ListeningProtocol).
%   For each program-material file, renders loudness-matched versions:
%     (a) Dry, (b) candidate (current <track> config)
%   into output/<track>/voice/<voiceStage>/iter_<ID>/, plus listening_manifest.json.
%
%   Loudness matching (MANDATORY, R-List): the candidate is gain-matched to the
%   dry file's own integrated loudness (LUFS; RMS fallback) so "better" cannot be
%   an artefact of "louder". The match gain is monitoring-only and is NOT written
%   back to any algorithm parameter. Peak normalisation is deliberately not used.
%
%   Program material is processed at its NATIVE sample rate (the coloration model
%   is rate-agnostic: memoryless curve, ms-based dynamic bias, relative
%   oversampling), so 48 kHz clips are auditioned at 48 kHz.
%
%   fileList (optional): cellstr of filenames under data/program_material to use;
%   default = all *.wav except the dry tone battery / pure-tone probes.

    cfg = config();
    progDir = cfg.paths.program;
    outDir  = fullfile(cfg.paths.output, track, 'voice', voiceStage, sprintf('iter_%02d', iterId));
    if ~exist(outDir,'dir'); mkdir(outDir); end

    if nargin < 4 || isempty(fileList)
        d = dir(fullfile(progDir, '*.wav'));
        fileList = {d.name};
        skip = {'01_tone_battery.wav'};   % misplaced dry signal
        fileList = fileList(~ismember(fileList, skip));
    end
    if isempty(fileList)
        fprintf('renderListeningSet: no program material to render in %s\n', progDir); return;
    end

    dof = cfg.tracks.(track).dof;
    items = struct('program',{},'fs',{},'candidate_match_gain_db',{},'dry_peak',{},'candidate_peak_after_match',{});

    for i = 1:numel(fileList)
        fn = fileList{i};
        [x, fs] = audioread(fullfile(progDir, fn));
        cand = zeros(size(x));
        for ch = 1:size(x,2)
            cand(:,ch) = processSignal(x(:,ch), dof, fs, track);
        end
        % loudness-match candidate to dry
        [gDb, gLin] = matchLoudness(cand, x, fs);
        cand = cand * gLin;

        base = erase(fn, '.wav');
        audiowrite(fullfile(outDir, sprintf('%s__dry.wav', base)),       clip(x),    fs, 'BitsPerSample',24);
        audiowrite(fullfile(outDir, sprintf('%s__%s.wav', base, track)), clip(cand), fs, 'BitsPerSample',24);

        items(i) = struct('program', fn, 'fs', fs, 'candidate_match_gain_db', gDb, ...
                    'dry_peak', max(abs(x(:))), 'candidate_peak_after_match', max(abs(cand(:)))); %#ok<AGROW>
        fprintf('  %-22s match %+5.2f dB  cand peak %.3f\n', fn, gDb, max(abs(cand(:))));
    end
    manifest = struct('track', track, 'voice_stage', voiceStage, 'iteration', iterId, ...
                      'loudness_match', 'candidate matched to dry integrated loudness', ...
                      'listening_blinded', false, 'items', items);
    fid = fopen(fullfile(outDir,'listening_manifest.json'),'w');
    fwrite(fid, jsonencode(manifest,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('renderListeningSet(%s/%s): %d items -> %s\n', track, voiceStage, numel(fileList), outDir);
end

function y = clip(x); y = max(min(x,1),-1); end

function [gDb, gLin] = matchLoudness(cand, dry, fs)
%MATCHLOUDNESS  gain to bring cand to dry's integrated loudness.
    lc = loud(cand, fs); ld = loud(dry, fs);
    gDb = ld - lc; gLin = 10^(gDb/20);
end
function L = loud(x, fs)
    if exist('integratedLoudness','file')
        L = integratedLoudness(x, fs);
    else
        L = 20*log10(sqrt(mean(x(:).^2))+eps) - 0.691;  % coarse RMS->LUFS proxy
    end
end
