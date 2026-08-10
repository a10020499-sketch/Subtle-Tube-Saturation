function [h, ir] = harmonicSeparation(y, farina, maxOrder)
%HARMONICSEPARATION  Farina exponential-sweep harmonic deconvolution.
%   Given the recorded response y of a Farina ESS (farina = struct with f1,f2,
%   duration_sec/T, fs from the dry manifest), build the inverse filter and
%   deconvolve to a compound impulse response whose harmonic images appear at
%   known negative-time offsets. Returns per-order IRs h{1..maxOrder}.
%
%   The n-th harmonic impulse sits ahead of the linear IR by
%   dt_n = L*ln(n) seconds, where L = T/ln(f2/f1) (Farina 2000, Novak et al).

    if nargin < 3; maxOrder = 6; end
    fs = farina.fs_hz;
    f1 = farina.f1_hz; f2 = farina.f2_hz;
    T  = farina.duration_sec;
    L  = T/log(f2/f1);
    N  = round(T*fs);

    t = (0:N-1)'/fs;
    s = sin(2*pi*f1*L*(exp(t/L)-1));

    % inverse filter: time-reversed sweep with +6 dB/oct amplitude envelope
    inv = flipud(s) .* exp(-t/L);            % amplitude modulation for flat inverse
    % normalise inverse so linear convolution gives unit-ish IR
    inv = inv / (f1 * 2*pi * L) ; %#ok<NASGU>  % scale (informational; peak-norm below)

    ir = fftfilt(flipud(s).*exp(-t/L), [y(:); zeros(N,1)]);
    ir = ir / max(abs(ir));                  % peak-normalise for comparison stability

    % linear IR is the main peak; harmonic n peaks earlier by L*ln(n)
    [~, p0] = max(abs(ir));
    h = cell(1, maxOrder);
    halfWin = round(0.02*fs);                % +/-20 ms window per harmonic
    for n = 1:maxOrder
        dt = round(L*log(n)*fs);
        c  = p0 - dt;
        lo = max(1, c-halfWin); hi = min(numel(ir), c+halfWin);
        seg = zeros(2*halfWin+1,1);
        idx = (lo:hi) - c + halfWin + 1;
        seg(idx) = ir(lo:hi);
        h{n} = seg;
    end
end
