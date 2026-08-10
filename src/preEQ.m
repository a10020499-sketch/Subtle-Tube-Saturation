function y = preEQ(x, dof, fs)
%PREEQ  Wiener-Hammerstein pre-filter H1(f) (H6). Identity when no stages (R2-A).
%   Normalisation convention (backlog #4): H1 is fixed to 0 dB @ 1 kHz; overall
%   scale is carried by output gain, keeping k / H1 / output identifiable.
    y = biquadEQ(x, dof.preEQ.stages, fs);
end
