function [lo, hi] = lr4Pair(x, fc, fs)
%LR4PAIR  True Linkwitz-Riley 4th-order complementary pair.
%   lo = two cascaded 2nd-order Butterworth lowpasses
%   hi = two cascaded 2nd-order Butterworth highpasses
%   lo + hi is ALLPASS (flat magnitude, phase shifted) - both bands are -6 dB at
%   fc with proper 24 dB/oct skirts.
%
%   This is deliberately NOT the telescoping form used by crossoverBank
%   (hi = x - lo). That form reconstructs x exactly - which is what the multiband
%   tool's null gate needs - but its "high" band is only a first-order complement
%   and peaks at +3.5 dB at fc (since LR4 lowpass = -0.5 there, 1-(-0.5) = 1.5).
%   When one band is saturated and the other is not, that bump over-weights the
%   clean path around the crossover and brightens the region. For a band-selective
%   voice lever the property that matters is band SEPARATION, not exact
%   reconstruction, so use this pair there and crossoverBank in the multiband tool.

    [bl, al] = butter(2, fc/(fs/2), 'low');
    [bh, ah] = butter(2, fc/(fs/2), 'high');
    lo = filter(bl, al, filter(bl, al, x));
    hi = filter(bh, ah, filter(bh, ah, x));
end
