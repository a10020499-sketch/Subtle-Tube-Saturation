function d = hfVariant(d, fc, beta, follow)
%HFVARIANT  Configure the HF-clean voice lever in one call (Phase B variants).
%   fc      crossover for the clean-HF split (0 disables the lever entirely)
%   beta    fraction of the HF band still driven into the nonlinearity
%           (0 = fully clean highs, 1 = the unsplit saturn-like baseline)
%   follow  0..1 depth of the density follow: modulates the clean HF band by the
%           gain reduction the curve is applying to the low band, restoring the
%           peak compression ("thickness") that routing HF around the curve gives
%           up, without generating HF harmonics.
    if fc <= 0
        d.hf_clean.enabled = false; return;
    end
    d.hf_clean.enabled = true;
    d.hf_clean.freq_hz = fc;
    d.hf_clean.gain_match = true;
    d.hf_clean.beta = beta;
    d.hf_clean.follow = follow;
    d.hf_clean.follow_attack_ms  = 1;
    d.hf_clean.follow_release_ms = 30;
end
