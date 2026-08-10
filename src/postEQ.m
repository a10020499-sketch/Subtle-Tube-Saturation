function y = postEQ(x, dof, fs)
%POSTEQ  Wiener-Hammerstein post-filter H2(f) (H6). Identity when no stages (R2-A).
    y = biquadEQ(x, dof.postEQ.stages, fs);
end
