function generateTestSignals(outDir, fs)
%GENERATETESTSIGNALS  Regenerate the four dry test signals + manifest.
%   generateTestSignals()                 -> writes to <repo>/data/dry at 48 kHz
%   generateTestSignals(outDir)           -> custom output directory
%   generateTestSignals(outDir, fs)       -> custom sample rate (e.g. 96000)
%
%   Produces (see SPECIFICATION 2, 4.3, Appendix A):
%     01_tone_battery.wav              7 freq x 8 level sine segments + lead click
%     02_log_sweep_moderate_-18dBFS.wav  20 Hz-20 kHz Farina ESS, moderate level
%     03_log_sweep_hot_-3dBFS.wav        20 Hz-20 kHz Farina ESS, near full-scale
%     04_pink_noise_broadband_-12dBFS.wav broadband pink noise (tonal sanity check)
%     dry_signal_manifest.json           exact sample positions + synthesis params
%
%   All files are 24-bit PCM. Every file begins with an identical calibration
%   click (a single impulse) so analyzeAndCompare/subsampleAlign can recover the
%   per-file alignment offset (SPECIFICATION R4). Generation is deterministic:
%   the RNG is seeded so pink noise is bit-reproducible across runs.
%
%   NOTE ON LEVELS: dBFS for sine tones = peak amplitude in dBFS. For the sweeps
%   dBFS = peak amplitude. For pink noise the label is RMS dBFS (crest factor of
%   pink noise makes peak the less meaningful "level"); the achieved peak is
%   recorded in the manifest and kept below 0 dBFS.

    if nargin < 1 || isempty(outDir)
        here   = fileparts(mfilename('fullpath'));
        outDir = fullfile(fileparts(here), 'data', 'dry');
    end
    if nargin < 2 || isempty(fs)
        fs = 48000;
    end
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    rng(20260811, 'twister');          % determinism for pink noise (R6 reproducibility)
    bitDepth = 24;

    % ---- shared calibration click ------------------------------------------
    leadSilenceSec = 0.25;
    clickAmp       = 0.5;              % below FS so plug-in headroom is untouched
    leadN          = round(leadSilenceSec * fs);
    clickIdx       = leadN + 1;        % 1-based sample index of the impulse
    postClickSec   = 0.25;            % settle time after the click
    postClickN     = round(postClickSec * fs);

    manifest = struct();
    manifest.schema_version   = '1.0';
    manifest.sample_rate_hz   = fs;
    manifest.bit_depth        = bitDepth;
    manifest.channels         = 1;
    manifest.generated_by     = 'tools/generateTestSignals.m';
    manifest.rng_seed         = 20260811;
    manifest.calibration_click = struct( ...
        'description', 'single-sample impulse, identical in every file, for alignment', ...
        'amplitude',   clickAmp, ...
        'sample_index_1based', clickIdx);
    manifest.level_convention = struct( ...
        'tone_battery', 'peak dBFS', ...
        'sweeps',       'peak dBFS', ...
        'pink_noise',   'RMS dBFS (achieved peak also recorded)');
    manifest.files = struct([]);

    % ======================================================================
    % 01  TONE BATTERY
    % ======================================================================
    freqs   = [100 250 440 1000 2500 4000 8000];               % Hz
    % 8 levels spanning -24..0 dBFS inclusive (SPECIFICATION 4.3).
    levelsDb = round(linspace(-24, 0, 8) * 2) / 2;             % 0.5 dB grid, hits both endpoints
    toneSec  = 2.5;                                            % steady portion
    gapSec   = 0.5;                                            % silence between segments
    fadeSec  = 0.010;                                          % raised-cosine edges (anti-click)

    toneN = round(toneSec * fs);
    gapN  = round(gapSec  * fs);
    fadeN = round(fadeSec * fs);
    win   = ones(toneN, 1);
    ramp  = 0.5 - 0.5*cos(pi*(0:fadeN-1)'/fadeN);             % 0->1
    win(1:fadeN)         = ramp;
    win(end-fadeN+1:end) = flipud(ramp);

    x = zeros(leadN + postClickN, 1);
    x(clickIdx) = clickAmp;

    segments = struct('freq_hz', {}, 'level_dbfs', {}, ...
                      'start_sample_1based', {}, 'end_sample_1based', {});
    for fi = 1:numel(freqs)
        for li = 1:numel(levelsDb)
            f   = freqs(fi);
            amp = 10^(levelsDb(li)/20);
            t   = (0:toneN-1)' / fs;
            seg = amp * sin(2*pi*f*t) .* win;
            startIdx = numel(x) + 1;
            x = [x; seg; zeros(gapN,1)]; %#ok<AGROW>
            endIdx = startIdx + toneN - 1;
            segments(end+1) = struct('freq_hz', f, 'level_dbfs', levelsDb(li), ...
                'start_sample_1based', startIdx, 'end_sample_1based', endIdx); %#ok<AGROW>
        end
    end
    fname01 = '01_tone_battery.wav';
    writeWav(fullfile(outDir, fname01), x, fs, bitDepth);
    manifest.files(end+1).name = fname01; %#ok<*STRNU>
    manifest.files(end).kind   = 'tone_battery';
    manifest.files(end).length_samples = numel(x);
    manifest.files(end).length_sec = numel(x)/fs;
    manifest.files(end).steady_analysis_guard_sec = fadeSec; % skip edges when measuring THD
    manifest.files(end).segments = segments;

    % ======================================================================
    % 02 / 03  FARINA EXPONENTIAL SINE SWEEPS
    % ======================================================================
    sweepSec = 12;
    f1 = 20; f2 = 20000;
    [sweep, invParams] = farinaSweep(f1, f2, sweepSec, fs);   % unit-peak sweep

    for cfg = struct('name', {'02_log_sweep_moderate_-18dBFS.wav', '03_log_sweep_hot_-3dBFS.wav'}, ...
                     'db',   {-18, -3})
        amp = 10^(cfg.db/20);
        body = amp * sweep;
        xs = [zeros(leadN,1); zeros(0,1)];
        xs(clickIdx) = clickAmp;
        xs = [xs; zeros(postClickN,1); body; zeros(round(0.25*fs),1)];
        sweepStart = leadN + postClickN + 1;
        writeWav(fullfile(outDir, cfg.name), xs, fs, bitDepth);
        manifest.files(end+1).name = cfg.name;
        manifest.files(end).kind   = 'log_sweep_farina';
        manifest.files(end).level_dbfs_peak = cfg.db;
        manifest.files(end).length_samples = numel(xs);
        manifest.files(end).length_sec = numel(xs)/fs;
        manifest.files(end).sweep_start_sample_1based = sweepStart;
        manifest.files(end).sweep_end_sample_1based   = sweepStart + numel(body) - 1;
        manifest.files(end).farina = invParams;   % f1,f2,T,fs -> lets harmonicSeparation build inverse filter
    end

    % ======================================================================
    % 04  BROADBAND PINK NOISE
    % ======================================================================
    pinkSec = 6;
    pinkN   = round(pinkSec * fs);
    if exist('pinknoise', 'file')
        pn = pinknoise(pinkN);
    else
        pn = voss_pink(pinkN);         % fallback if Audio Toolbox pinknoise unavailable
    end
    pn = pn(:) - mean(pn);
    targetRmsDb = -12;
    rms0 = sqrt(mean(pn.^2));
    pn   = pn * (10^(targetRmsDb/20) / rms0);
    pk   = max(abs(pn));
    if pk > 10^(-0.5/20)               % keep at least 0.5 dB headroom
        pn = pn * (10^(-0.5/20) / pk);
    end
    achievedRms = 20*log10(sqrt(mean(pn.^2)));
    achievedPk  = 20*log10(max(abs(pn)));
    xp = zeros(leadN + postClickN, 1);
    xp(clickIdx) = clickAmp;
    xp = [xp; pn; zeros(round(0.25*fs),1)];
    pinkStart = leadN + postClickN + 1;
    fname04 = '04_pink_noise_broadband_-12dBFS.wav';
    writeWav(fullfile(outDir, fname04), xp, fs, bitDepth);
    manifest.files(end+1).name = fname04;
    manifest.files(end).kind   = 'pink_noise';
    manifest.files(end).level_target_rms_dbfs = targetRmsDb;
    manifest.files(end).achieved_rms_dbfs = achievedRms;
    manifest.files(end).achieved_peak_dbfs = achievedPk;
    manifest.files(end).length_samples = numel(xp);
    manifest.files(end).length_sec = numel(xp)/fs;
    manifest.files(end).noise_start_sample_1based = pinkStart;

    % ---- write manifest ----------------------------------------------------
    txt = jsonencode(manifest, 'PrettyPrint', true);
    fid = fopen(fullfile(outDir, 'dry_signal_manifest.json'), 'w');
    fwrite(fid, txt, 'char'); fclose(fid);

    fprintf('Generated 4 dry test signals + manifest in %s (fs=%d)\n', outDir, fs);
end

% =========================================================================
function writeWav(path, x, fs, bits)
    x = max(min(x, 1), -1);            % hard safety clamp
    audiowrite(path, x, fs, 'BitsPerSample', bits);
end

function [s, params] = farinaSweep(f1, f2, T, fs)
%FARINASWEEP  Exponential sine sweep (Farina 2000), unit peak amplitude.
    N = round(T*fs);
    t = (0:N-1)'/fs;
    L = T / log(f2/f1);
    s = sin(2*pi*f1*L*(exp(t/L) - 1));
    % raised-cosine fades to suppress start/stop transients
    fN = round(0.02*fs);
    r  = 0.5 - 0.5*cos(pi*(0:fN-1)'/fN);
    s(1:fN)         = s(1:fN).*r;
    s(end-fN+1:end) = s(end-fN+1:end).*flipud(r);
    params = struct('f1_hz', f1, 'f2_hz', f2, 'duration_sec', T, ...
                    'fs_hz', fs, 'method', 'farina_exponential_sine_sweep', ...
                    'L', L, 'fade_sec', 0.02);
end

function y = voss_pink(N)
%VOSS_PINK  Fallback pink-noise generator (Voss-McCartney), used only if the
%   Audio Toolbox pinknoise() is unavailable. Deterministic under the caller rng.
    nRows = 16;
    y = zeros(N,1);
    rows = zeros(nRows,1);
    for i = 1:nRows; rows(i) = randn; end
    running = sum(rows);
    for n = 1:N
        k = find(bitand(n, 2.^(0:nRows-1)) == 0, 1); % lowest zero bit
        if isempty(k); k = nRows; end
        running = running - rows(k);
        rows(k) = randn;
        running = running + rows(k);
        y(n) = running;
    end
    y = y / max(abs(y));
end
