function runMultiband(inPath, outPath, mbOverride)
%RUNMULTIBAND  Apply the multiband coloration tool to an audio file.
%   runMultiband(inPath, outPath)             uses cfg.multiband from config.m
%   runMultiband(inPath, outPath, mbOverride)  overlays fields of mbOverride onto
%                                              cfg.multiband (num_bands, crossover_hz,
%                                              crossfade, bands(b).mode/drive/dry_wet)
%
%   Colour cores use each track's frozen saturn-like Phase A config. Once Phase B
%   sign-off exists this will switch to the -final voice configs (SPECIFICATION 4.5).
%   NOTE: this is the scaffold entry point; final multiband voice integration is
%   gated on both voice_signoff.final (loop_state multiband_tool).

    here = fileparts(mfilename('fullpath'));
    addpath(here, fileparts(here));
    cfg = config();
    if nargin >= 3 && ~isempty(mbOverride)
        f = fieldnames(mbOverride);
        for i = 1:numel(f); cfg.multiband.(f{i}) = mbOverride.(f{i}); end
    end

    [x, fs] = audioread(inPath);
    assert(fs == cfg.audio.fs, 'input fs %d ~= config fs %d', fs, cfg.audio.fs);
    y = zeros(size(x));
    for ch = 1:size(x,2)
        y(:,ch) = multibandProcess(x(:,ch), cfg);
    end
    if ~exist(fileparts(outPath),'dir') && ~isempty(fileparts(outPath)); mkdir(fileparts(outPath)); end
    audiowrite(outPath, max(min(y,1),-1), fs, 'BitsPerSample', cfg.audio.bit_depth);
    fprintf('runMultiband: %s -> %s (%d bands, crossovers [%s] Hz)\n', ...
        inPath, outPath, cfg.multiband.num_bands, num2str(cfg.multiband.crossover_hz));
end
