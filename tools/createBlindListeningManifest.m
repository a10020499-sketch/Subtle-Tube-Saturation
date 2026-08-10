function createBlindListeningManifest(setDir)
%CREATEBLINDLISTENINGMANIFEST  Anonymise a listening set for A/B(/X) auditioning
%   (R-ListeningProtocol, blind test is recommended-not-mandatory). Copies the
%   rendered versions in setDir to A/B/C... with a shuffled key, and writes the
%   key into listening_manifest.json (field `blind_key`) so the reveal is logged.
%
%   Single-listener blinding has limited power (noted in the spec); this exists
%   so the option is available, and so `listening_blinded` can honestly be set.

    wavs = dir(fullfile(setDir, '*__*.wav'));
    if isempty(wavs)
        fprintf('createBlindListeningManifest: nothing to anonymise in %s\n', setDir); return;
    end
    rng('shuffle');
    order = randperm(numel(wavs));
    labels = arrayfun(@(k) char('A'+k-1), 1:numel(wavs), 'uni', 0);
    blindDir = fullfile(setDir, 'blind');
    if ~exist(blindDir,'dir'); mkdir(blindDir); end
    key = struct('label', {}, 'source', {});
    for k = 1:numel(order)
        src = wavs(order(k)).name;
        copyfile(fullfile(setDir, src), fullfile(blindDir, [labels{k} '.wav']));
        key(end+1) = struct('label', labels{k}, 'source', src); %#ok<AGROW>
    end
    mf = fullfile(setDir, 'listening_manifest.json');
    if isfile(mf); m = jsondecode(fileread(mf)); else; m = struct(); end
    m.blind_key = key; m.listening_blinded = true;
    fid = fopen(mf,'w'); fwrite(fid, jsonencode(m,'PrettyPrint',true),'char'); fclose(fid);
    fprintf('createBlindListeningManifest: %d files anonymised in %s\n', numel(order), blindDir);
end
