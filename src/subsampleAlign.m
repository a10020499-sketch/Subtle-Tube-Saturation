function [ref_al, delay_int, delay_frac] = subsampleAlign(ref, dry, clickIdx, fs)
%SUBSAMPLEALIGN  Align a reference render to the dry signal with sub-sample
%   precision (SPECIFICATION R4). Two-stage:
%     1) integer delay from cross-correlation around the calibration click
%     2) fractional delay from the cross-correlation-peak parabolic refinement,
%        applied by sinc (Fourier-domain) fractional-sample shift
%
%   Returns the reference resampled onto the dry timebase, plus the integer and
%   fractional delay components (record both in metrics.json).
%
%   Convention: delay > 0 means the reference lags the dry (plug-in latency).
%   ref_al is the reference advanced by that delay so it lines up with dry.

    ref = ref(:); dry = dry(:);

    % window around the click in both signals for a clean, transient-rich xcorr
    win = round(0.05*fs);                       % +/-50 ms
    lo = max(1, clickIdx-win); hi = min([numel(ref) numel(dry) clickIdx+win]);
    r = ref(lo:hi); d = dry(lo:hi);
    r = r - mean(r); d = d - mean(d);

    [xc, lags] = xcorr(r, d);
    [~, pk] = max(abs(xc));
    delay_int = lags(pk);                        % samples ref lags dry

    % parabolic interpolation on |xc| for the fractional part
    if pk > 1 && pk < numel(xc)
        ym1 = abs(xc(pk-1)); y0 = abs(xc(pk)); yp1 = abs(xc(pk+1));
        denom = (ym1 - 2*y0 + yp1);
        if denom ~= 0
            delta = 0.5*(ym1 - yp1)/denom;       % in (-0.5, 0.5)
        else
            delta = 0;
        end
    else
        delta = 0;
    end
    delay_frac = delta;

    totalDelay = delay_int + delay_frac;
    ref_al = fracDelay(ref, -totalDelay);        % advance ref to match dry
    if numel(ref_al) < numel(dry)
        ref_al(end+1:numel(dry)) = 0;
    else
        ref_al = ref_al(1:numel(dry));
    end
end

function y = fracDelay(x, d)
%FRACDELAY  Shift x by d samples (d may be fractional) via FFT phase ramp.
    N = numel(x);
    Nf = 2^nextpow2(2*N);
    X = fft(x, Nf);
    k = [0:Nf/2-1, -Nf/2:-1]';
    X = X .* exp(-1j*2*pi*k*d/Nf);
    y = real(ifft(X));
    y = y(1:N);
end
