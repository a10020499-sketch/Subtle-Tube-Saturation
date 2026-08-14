function d = withUpward(d, ratio, thrDb, rangeDb)
%WITHUPWARD  Enable H9 upward compression: lift material BELOW threshold so
%   reverb tails and low-level detail come forward, without squashing transients.
%
%   The attack is deliberately FAST and the release slow. With a slow attack the
%   envelope still reads a transient as "quiet" and applies the lift to it, which
%   amplifies peaks instead of tails (measured: crest 10.0 -> 16.3 dB at a 20 ms
%   attack). Fast attack withdraws the lift the instant the signal rises.
    d.dec.mode = 'upward';
    d.dec.position = 'post';
    d.dec.ratio = ratio;
    d.dec.threshold_db = thrDb;
    d.dec.range_db = rangeDb;
    d.dec.attack_ms = 2;
    d.dec.release_ms = 300;
end
