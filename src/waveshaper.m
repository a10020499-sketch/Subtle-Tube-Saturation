function y = waveshaper(x, shaper)
%WAVESHAPER  Static nonlinearity f(k*x) with Even/Odd Blend (H2, H3).
%   shaper fields: type, drive_k, bias, asymmetry, poly_coeffs.
%
%   Even/Odd Blend (SPECIFICATION 3.6, backlog #5): a product-level macro that
%   maps onto (bias, asymmetry). It biases and asymmetrically scales the signal
%   BEFORE the nonlinearity to shift the even/odd harmonic balance, then removes
%   the resulting DC so no static offset leaks downstream (avoids the crude
%   input-bias implementation the backlog warns against).

    k = shaper.drive_k;
    u = k * x;

    % Even/Odd Blend pre-conditioning: DC bias + half-wave asymmetric gain.
    if isfield(shaper,'bias') && shaper.bias ~= 0
        u = u + shaper.bias;
    end
    if isfield(shaper,'asymmetry') && shaper.asymmetry ~= 0
        a = shaper.asymmetry;
        pos = u >= 0;
        u(pos)  = u(pos)  * (1 + a);
        u(~pos) = u(~pos) * (1 - a);
    end

    switch lower(shaper.type)
        case 'tanh'
            y = tanh(u);
        case 'atan'
            y = (2/pi) * atan((pi/2) * u);
        case 'poly'
            % odd+even polynomial; poly_coeffs = [c1 c2 c3 ...] for u^1,u^2,...
            c = shaper.poly_coeffs(:);
            y = zeros(size(u));
            for n = 1:numel(c)
                y = y + c(n) * u.^n;
            end
        case 'softknee'
            % soft-knee limiter-style curve: linear below knee, tanh above
            kn = 0.6;
            y = u;
            over = abs(u) > kn;
            y(over) = sign(u(over)) .* (kn + (1-kn)*tanh((abs(u(over))-kn)/(1-kn)));
        otherwise
            error('waveshaper:type', 'unknown shaper.type "%s"', shaper.type);
    end

    % Remove DC introduced by bias/asymmetry so no static offset propagates.
    y = y - mean(y);
end
