function dof = withHFClean(dof, freqHz)
%WITHHFCLEAN  Return dof with the HF-clean split enabled at freqHz (0 = off).
%   Small helper so Phase B variant lists stay readable.
    dof.hf_clean.enabled = freqHz > 0;
    if freqHz > 0; dof.hf_clean.freq_hz = freqHz; end
    dof.hf_clean.gain_match = true;
end
