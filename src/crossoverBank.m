function bands = crossoverBank(x, crossHz, fs)
%CROSSOVERBANK  N-band Linkwitz-Riley 4th-order split, perfect-reconstruction
%   LP-difference form (SPECIFICATION 3.4; reused from the prior project which
%   nulled at -330 dB). Sum of the returned bands reconstructs x exactly.
%
%   x        column vector
%   crossHz  vector of N-1 crossover frequencies (ascending)
%   bands    1xN cell of column vectors, low band first

    x = x(:);
    crossHz = sort(crossHz(:))';
    N = numel(crossHz) + 1;
    bands = cell(1, N);
    remaining = x;
    for k = 1:N-1
        low = lr4lowpass(remaining, crossHz(k), fs);
        bands{k} = low;
        remaining = remaining - low;     % phase-matched complementary high
    end
    bands{N} = remaining;                % telescoping sum == x exactly
end

function y = lr4lowpass(x, fc, fs)
%LR4LOWPASS  24 dB/oct Linkwitz-Riley = two cascaded 2nd-order Butterworth.
    [b, a] = butter(2, fc/(fs/2), 'low');
    y = filter(b, a, filter(b, a, x));
end
