function d = setTP(d, depth, kneeDb, rangeDb, slowAtkMs)
%SETTP  Enable the transient-preserve lever (frequency-agnostic punch).
%   depth  0..1 - how far the output leans toward the linear path during an attack
%   The steady state stays fully saturated, so the approved warmth is unchanged;
%   only the first milliseconds of a hit pass less compressed. Because it keys off
%   an envelope ratio rather than a crossover, it behaves the same whether the core
%   is fed full-range material or one band from the multiband layer.
    if nargin<3||isempty(kneeDb);    kneeDb=3;    end
    if nargin<4||isempty(rangeDb);   rangeDb=8;   end
    if nargin<5||isempty(slowAtkMs); slowAtkMs=80; end
    d.transient.enabled = depth > 0;
    d.transient.depth = depth;
    d.transient.knee_db = kneeDb;            % dB the fast peak must exceed the slow
    d.transient.range_db = rangeDb;          % dB above the knee that reaches full depth
    d.transient.fast_release_ms = 8;
    d.transient.slow_attack_ms = slowAtkMs;
    d.transient.slow_release_ms = 250;
end
