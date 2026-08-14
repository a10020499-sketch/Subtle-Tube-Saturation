function d = setBD(d, driveMul, biasMul)
%SETBD  Scale the two orthogonal character levers together.
%   driveMul  multiplies shaper.drive_k       -> drive/breakup (raises H3, body)
%   biasMul   multiplies dynamic_bias.depth   -> tube warmth   (raises H2 only)
%
%   Measured to be independent: at 1 kHz, x1.30 drive moved H3 -29.0 -> -26.6 dB
%   with H2 unchanged, while x1.25 bias moved H2 -38.7 -> -36.8 dB with H3
%   unchanged. So "warmer" and "more broken up" are separately dialable.
%   biasMul is ignored on tracks without a dynamic bias (subtle_saturation).
    if nargin<2||isempty(driveMul); driveMul=1; end
    if nargin<3||isempty(biasMul);  biasMul=1;  end
    d.shaper.drive_k = d.shaper.drive_k * driveMul;
    if isfield(d,'dynamic_bias') && isfield(d.dynamic_bias,'depth')
        d.dynamic_bias.depth = d.dynamic_bias.depth * biasMul;
    end
end
