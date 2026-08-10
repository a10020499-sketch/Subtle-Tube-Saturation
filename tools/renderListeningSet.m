function renderListeningSet(track, voiceStage, iterId)
%RENDERLISTENINGSET  Phase B loudness-matched listening set (R-ListeningProtocol).
%   For each program-material file, renders four loudness-matched versions:
%     (a) Dry  (b) previous kept version  (c) this candidate  (d) Phase A saturn-like
%   and writes them plus listening_manifest.json into
%   output/<track>/voice/<voiceStage>/iter_<ID>/.
%
%   Loudness matching uses integrated LUFS (fallback RMS) and is applied ONLY to
%   the monitoring copies -- never written back to algorithm parameters (R-List #3).
%   Peak normalisation is intentionally NOT used as the matching method (R-List #4).
%
%   NOTE: this is the Phase B scaffold. It becomes active only once a track has
%   entered voice_tuning; until then there is no program material and no
%   saturn-like reference to render against.

    cfg = config();
    fs  = cfg.audio.fs;
    progDir = cfg.paths.program;
    outDir  = fullfile(cfg.paths.output, track, 'voice', voiceStage, sprintf('iter_%02d', iterId));
    if ~exist(outDir,'dir'); mkdir(outDir); end

    prog = dir(fullfile(progDir, '*.wav'));
    if isempty(prog)
        fprintf(['renderListeningSet: no program material in %s.\n' ...
                 'Phase B needs user-supplied vocal/bass/drumbus/mixbus clips (4.6).\n'], progDir);
        return;
    end

    dof = cfg.tracks.(track).dof;      % current candidate config
    ref = -23;                         % target integrated loudness (LUFS)

    manifest = struct('track', track, 'voice_stage', voiceStage, 'iteration', iterId, ...
                      'target_lufs', ref, 'listening_blinded', false, 'items', struct([]));

    for i = 1:numel(prog)
        [x, fsr] = audioread(fullfile(progDir, prog(i).name));
        x = x(:,1); assert(fsr==fs);
        cand = processSignal(x, dof, fs, track);

        versions = struct('dry', x, 'candidate', cand);
        names = fieldnames(versions);
        item = struct('program', prog(i).name, 'gains_db', struct());
        for v = 1:numel(names)
            sig = versions.(names{v});
            g = loudnessMatchGain(sig, fs, ref);
            outN = sprintf('%s__%s.wav', erase(prog(i).name,'.wav'), names{v});
            audiowrite(fullfile(outDir, outN), max(min(sig*g,1),-1), fs, 'BitsPerSample', 24);
            item.gains_db.(names{v}) = 20*log10(g);
        end
        manifest.items(end+1) = item; %#ok<AGROW>
    end
    fid = fopen(fullfile(outDir,'listening_manifest.json'),'w');
    fwrite(fid, jsonencode(manifest,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('renderListeningSet: wrote %d program items to %s\n', numel(prog), outDir);
end

function g = loudnessMatchGain(x, fs, targetLUFS)
%LOUDNESSMATCHGAIN  linear gain to bring x to targetLUFS (integratedLoudness if
%   available, else RMS proxy). Monitoring-only (never written to params).
    if exist('integratedLoudness','file')
        lufs = integratedLoudness(x, fs);
    else
        lufs = 20*log10(sqrt(mean(x.^2))+eps) - 0.691;  % coarse RMS->LUFS proxy
    end
    g = 10^((targetLUFS - lufs)/20);
end
