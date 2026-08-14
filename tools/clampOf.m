function p = clampOf(x, dof, fs)
%CLAMPOF  %% of oversampled samples driven past the curve's join point, i.e. the
%   share riding the asymptotic (fully saturated) part of the shaper. Some is
%   normal for a driven saturator; large values mean the Drive control has run out
%   of useful travel and is only limiting.
    if isfield(dof,'hf_clean') && dof.hf_clean.enabled && dof.hf_clean.freq_hz>0
        b = crossoverBank(x, dof.hf_clean.freq_hz, fs);
        beta = 0; if isfield(dof.hf_clean,'beta'); beta = dof.hf_clean.beta; end
        x = b{1} + beta*b{2};
    end
    v = preEQ(x, dof, fs);
    L = dof.oversample.factor;
    if L>1; v = resample(v, L, 1); end
    u = dof.shaper.drive_k * v;
    pw = dof.shaper.powers(:); c = dof.shaper.coeffs(:);
    uu = linspace(1e-4,4,40001)'; dd = zeros(size(uu));
    for i=1:numel(pw); dd = dd + c(i)*pw(i)*uu.^(pw(i)-1); end
    k = find(dd<=0,1);
    if isempty(k); ut = Inf; else; ut = uu(k); end
    uj = min(1.0, ut);
    p = 100*mean(abs(u) > uj);
end
