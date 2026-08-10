function run_pipeline(track)
%RUN_PIPELINE  Phase A entry point: state -> asset gate -> process -> measure.
%   run_pipeline('subtle_saturation') | run_pipeline('subtle_tube')
%
%   Order of operations (SPECIFICATION 4.1):
%     READ STATE -> CHECK ASSETS (R1-A) -> [process dry set] -> MEASURE.
%   COMMIT / UPDATE STATE / DECIDE are performed by the loop driver outside
%   MATLAB (git + loop_state.json edits), per the protocol.

    if nargin < 1
        error('run_pipeline:track', 'usage: run_pipeline(''subtle_saturation''|''subtle_tube'')');
    end
    here = fileparts(mfilename('fullpath'));
    addpath(here, fullfile(fileparts(here)));   % src + repo root (config.m)

    cfg   = config();
    fs    = cfg.audio.fs;
    state = jsondecode(fileread(cfg.paths.loop_state));
    tr    = state.tracks.(track);
    iterId = tr.current_iteration;

    manifest = jsondecode(fileread(cfg.paths.dry_manifest));
    dryFiles = {manifest.files.name};

    % ===== CHECK ASSETS (R1-A) =============================================
    refDir  = fullfile(cfg.paths.reference, track);
    missing = {};
    for i = 1:numel(dryFiles)
        if ~isfile(fullfile(refDir, dryFiles{i}))
            missing{end+1} = dryFiles{i}; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        % write hypothesis.md listing exactly what the user must render
        iterDir = fullfile(cfg.paths.loop_iters, track, sprintf('iter_%02d', iterId));
        if ~exist(iterDir,'dir'); mkdir(iterDir); end
        writeMissingReport(fullfile(iterDir,'hypothesis.md'), track, refDir, missing);

        % R1-A anti-spin: set status and HALT. Do not enter the next iteration.
        state.tracks.(track).status = 'awaiting_reference_assets';
        fid = fopen(cfg.paths.loop_state,'w');
        fwrite(fid, jsonencode(state,'PrettyPrint',true),'char'); fclose(fid);

        fprintf('\n==== R1-A REFERENCE ASSET GATE: track "%s" BLOCKED ====\n', track);
        fprintf('Missing Saturn 2 reference renders in %s:\n', refDir);
        for i = 1:numel(missing); fprintf('   - %s\n', missing{i}); end
        fprintf(['\nStatus set to awaiting_reference_assets. Halting this track.\n' ...
                 'Render the dry files through Saturn 2 (this mode), drop them in the\n' ...
                 'folder above with identical filenames, then re-run run_pipeline(''%s'').\n'], track);
        return;
    end

    % ===== PROCESS the dry set =============================================
    dof    = cfg.tracks.(track).dof;
    outDir = fullfile(cfg.paths.output, track, sprintf('iter_%02d', iterId));
    if ~exist(outDir,'dir'); mkdir(outDir); end

    for i = 1:numel(dryFiles)
        fn = dryFiles{i};
        [x, fsr] = audioread(fullfile(cfg.paths.dry, fn));
        assert(fsr == fs, 'dry %s fs %d ~= %d', fn, fsr, fs);
        y = processSignal(x(:,1), dof, fs, track);
        audiowrite(fullfile(outDir, fn), max(min(y,1),-1), fs, 'BitsPerSample', cfg.audio.bit_depth);
    end

    % ===== MEASURE =========================================================
    metrics = analyzeAndCompare(track, iterId);

    % snapshot the config that produced this iteration
    iterDir = fullfile(cfg.paths.loop_iters, track, sprintf('iter_%02d', iterId));
    if ~exist(iterDir,'dir'); mkdir(iterDir); end
    copyfile(fullfile(cfg.repo_root,'config.m'), fullfile(iterDir,'config_snapshot.m'));

    fprintf('run_pipeline(%s) iter %d complete. converged=%d\n', track, iterId, metrics.converged);
end

function writeMissingReport(path, track, refDir, missing)
    fid = fopen(path,'w');
    fprintf(fid, '# Reference Asset Gate (R1-A) - track `%s`\n\n', track);
    fprintf(fid, 'Status: **awaiting_reference_assets**. This track cannot start Phase A\n');
    fprintf(fid, 'Iteration 0 until the Saturn 2 reference renders below exist.\n\n');
    fprintf(fid, '## Files to render and place in `%s`\n\n', refDir);
    for i = 1:numel(missing); fprintf(fid, '- [ ] `%s`\n', missing{i}); end
    fprintf(fid, '\n## Render recipe (SPECIFICATION 4.3)\n\n');
    fprintf(fid, '- Load Saturn 2 on a single band, Full Range, Solo that band.\n');
    fprintf(fid, '- Mode = **%s** (this track).\n', strrep(track,'_',' '));
    fprintf(fid, '- Wet/Mix = 100%%. Use the mode DEFAULT Drive value (do not adjust).\n');
    fprintf(fid, '- Project 48 kHz / 24-bit to match the dry files.\n');
    fprintf(fid, '- Record every panel value in `render_manifest_template.csv`.\n');
    fprintf(fid, '- Keep filenames identical to the dry files.\n');
    fclose(fid);
end
