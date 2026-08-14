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
    if isfield(shaper,'bias') && any(shaper.bias(:) ~= 0)
        u = u + shaper.bias;   % bias may be scalar or a per-sample vector (dynamic bias, H8)
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
        case 'signpow'
            % odd basis  f(u) = sum_i coeffs(i) * sign(u) * |u|^powers(i).
            % Unifies polynomial (odd powers -> u^p) and "odd square-law" terms
            % (even powers -> u|u|^(p-1)); the latter give 3rd-harmonic ~ A^2,
            % i.e. THD slope 1, which pure odd polynomials cannot represent (H2,
            % Iter-4). All terms are odd, so only odd harmonics are produced.
            % smooth_eps > 0 rounds the corner the even-power terms have at u=0.
            % Written as  c_p * u * (u^2+eps^2)^((p-1)/2)  so that p=1 stays
            % EXACTLY c1*u (a naive sqrt(u^2+eps^2)-eps form multiplies the linear
            % term by 1-eps/sqrt(u^2+eps^2), which collapses to a dead zone at low
            % level). For |u| >> eps every term matches sign(u)|u|^p; only the
            % high-order tail (H7 and above) is shortened.
            % NOTE: this is a curve-accuracy lever, NOT the cure for the perceived
            % HF fizz -- aliasing was measured at -130 dB (2-8 kHz) / -70 dB
            % (11 kHz), so the kink's radiated tail is not folding back audibly.
            p = shaper.powers(:); c = shaper.coeffs(:);
            % MONOTONIC GUARD. These coefficients were fitted over the measured
            % amplitude range only; outside it the polynomial is unconstrained and
            % turns over (tube at |u|=1.026, saturation at |u|=1.053). Past the
            % turnover more input gives LESS output with inverted slope - wave
            % folding, which sounds far worse than clipping and lands exactly on
            % the loudest transients. Any lever that raises drive (drive_k, a
            % pre-EQ boost, per-band drive in the multiband layer) can walk the
            % signal there, so clamp the magnitude at the turnover: the curve then
            % saturates and holds. The join is C1 because the slope is zero there.
            ut = signpowTurnover(p, c);
            u  = sign(u) .* min(abs(u), ut);
            eps_s = 0;
            if isfield(shaper,'smooth_eps') && ~isempty(shaper.smooth_eps)
                eps_s = shaper.smooth_eps;
            end
            y = zeros(size(u));
            if eps_s > 0
                r2 = u.^2 + eps_s^2;
                for i = 1:numel(p)
                    y = y + c(i) * u .* r2.^((p(i)-1)/2);
                end
            else
                su = sign(u); au = abs(u);
                for i = 1:numel(p)
                    y = y + c(i) * su .* au.^p(i);
                end
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

% =========================================================================
function ut = signpowTurnover(p, c)
%SIGNPOWTURNOVER  smallest |u| > 0 at which d/du sum(c_p*|u|^p) reaches zero,
%   i.e. where the fitted curve stops being monotonic. Inf if it never does.
%   Cached per coefficient set, since this is called on every block.
    persistent cache
    if isempty(cache); cache = containers.Map('KeyType','char','ValueType','double'); end
    key = sprintf('%.10g,', [p(:)' c(:)']);
    if isKey(cache, key); ut = cache(key); return; end
    u = linspace(1e-4, 4, 40001)';
    d = zeros(size(u));
    for i = 1:numel(p); d = d + c(i)*p(i)*u.^(p(i)-1); end     % f'(u)
    k = find(d <= 0, 1);
    if isempty(k); ut = Inf; else; ut = u(k); end
    cache(key) = ut;
end
