function d = lfVariant(d, fc, beta, follow)
%LFVARIANT  Configure the clean-LOWS voice lever (mirror of hfVariant).
%   fc      crossover below which content bypasses the nonlinearity (0 disables)
%   beta    fraction of the low band still driven into the curve
%           (0 = fully clean lows, 1 = no lever)
%   follow  0..1 density follow depth for the clean low band
%
%   Rationale: a memoryless waveshaper compresses a kick transient the instant it
%   arrives and has no attack/release to soften that, so keeping the bottom
%   octave out of the curve is the lever that restores PUNCH. Set fc low enough
%   (80-120 Hz) that the low-mid weight still saturates.
    if fc <= 0
        d.lf_clean.enabled = false; return;
    end
    d.lf_clean.enabled = true;
    d.lf_clean.freq_hz = fc;
    d.lf_clean.gain_match = true;
    d.lf_clean.beta = beta;
    d.lf_clean.follow = follow;
    d.lf_clean.follow_attack_ms  = 1;
    d.lf_clean.follow_release_ms = 30;
end
