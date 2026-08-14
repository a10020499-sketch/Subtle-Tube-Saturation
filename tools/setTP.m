function d = setTP(d, depth, fastMs, slowMs, sens)
%SETTP  Enable the transient-preserve lever (frequency-agnostic punch).
%   depth  0..1 - how far the output leans toward the linear path during an attack
%   The steady state stays fully saturated, so the approved warmth is unchanged;
%   only the first milliseconds of a hit pass less compressed. Because it keys off
%   an envelope ratio rather than a crossover, it behaves the same whether the core
%   is fed full-range material or one band from the multiband layer.
    if nargin<3||isempty(fastMs); fastMs=1;  end
    if nargin<4||isempty(slowMs); slowMs=50; end
    if nargin<5||isempty(sens);   sens=0.5;  end
    d.transient.enabled = depth > 0;
    d.transient.depth = depth;
    d.transient.fast_ms = fastMs;
    d.transient.slow_ms = slowMs;
    d.transient.sensitivity = sens;
end
