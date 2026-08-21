function info = writeAudioSafe(path, y, fs, bits)
%WRITEAUDIOSAFE  Write audio without silently damaging it.
%   A tool that never normalises must not quietly hard-clip on the way out either.
%   If the signal fits in the requested fixed-point format it is written as asked;
%   if it exceeds full scale the file is written as 32-bit FLOAT instead, which
%   stores values above 1.0 exactly, and the overshoot is reported so the trim can
%   be set deliberately (tools/suggestTrim.m gives the value).
%
%   Returns info.peak, info.format, info.overshoot_db.

    if nargin<4||isempty(bits); bits=24; end
    pk = max(abs(y(:)));
    info = struct('peak', pk, 'overshoot_db', 20*log10(max(pk,eps)), 'format', '');
    if pk > 1
        [p,n,~] = fileparts(path);
        path = fullfile(p, [n '.wav']);
        audiowrite(path, y, fs, 'BitsPerSample', 32);     % 32-bit float
        info.format = 'float32';
        warning('writeAudioSafe:overshoot', ...
            ['peak %.3f (%+.2f dBFS) exceeds full scale - written as 32-bit FLOAT ' ...
             'rather than clipped. Set an output trim (see tools/suggestTrim.m) ' ...
             'if a fixed-point file is wanted.'], pk, info.overshoot_db);
    else
        audiowrite(path, y, fs, 'BitsPerSample', bits);
        info.format = sprintf('int%d', bits);
    end
end
