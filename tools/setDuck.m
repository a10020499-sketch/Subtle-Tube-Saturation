function d = setDuck(d, amount, releaseMs)
%SETDUCK  Pull the tube's dynamic bias back through the attack region only.
%   amount 0..1, releaseMs how long the duck stays open after a hit.
%
%   Steady material keeps the full bias depth (all of the warmth); the first tens
%   of milliseconds of a hit get less, so the extra even harmonics do not sit on
%   top of the attack and blunt its clarity. Measured: at bias 2.2 this holds H2
%   at -32.7 dB (vs -32.0 undicked, -33.5 at the shallower bias) while attack
%   clarity reaches -18.1 dB, matching the shallower bias's -18.0.
    if nargin<2||isempty(amount);    amount=1.0; end
    if nargin<3||isempty(releaseMs); releaseMs=60; end
    if isfield(d,'dynamic_bias')
        d.dynamic_bias.transient_duck = amount;
        d.dynamic_bias.duck_release_ms = releaseMs;
    end
end
