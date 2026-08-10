function y = dryWetMixer(dry, wet, mix, mode)
%DRYWETMIXER  Per-band dry/wet blend (SPECIFICATION 3.5, R-DryWet).
%   mix  in [0,1] (0 = fully dry, 1 = fully wet)
%   mode 'equal_power' (default) | 'linear'
%
%   Boundary guarantees (R-DryWet): mix=0 returns dry exactly; mix=1 returns wet
%   exactly (both crossfade laws pass these endpoints to within float epsilon).

    if nargin < 4 || isempty(mode); mode = 'equal_power'; end
    dry = dry(:); wet = wet(:);
    n = min(numel(dry), numel(wet)); dry = dry(1:n); wet = wet(1:n);
    switch lower(mode)
        case 'equal_power'
            gd = cos(mix*pi/2); gw = sin(mix*pi/2);
        case 'linear'
            gd = 1-mix; gw = mix;
        otherwise
            error('dryWetMixer:mode', 'unknown mix mode "%s"', mode);
    end
    y = gd*dry + gw*wet;
end
