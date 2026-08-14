function t = punchScore(y, x, fs, band)
%PUNCHSCORE  TAG - Transient Attenuation Gain, dB. How much gain the chain applies
%   to the kick ATTACK minus how much it applies to the kick BODY, in a band.
%     0 dB  = punch-neutral;  negative = the processor squashed the transient;
%     positive = the transient survives better than the body (more punch).
%
%   Why this and not the crest/transient-to-sustain measures used earlier: TAG is
%   a ratio of ratios referenced to the DRY signal, so the loudness-match gain
%   appears in both terms and cancels exactly. A crest-based score moves when the
%   match gain moves, which is how the earlier sweep concluded that lf_clean hurt
%   punch while a match-invariant score said the opposite.
%
%   Onsets are detected on the DRY signal only, so every candidate is scored at
%   identical instants.

    if nargin<4||isempty(band); band=[50 110]; end
    n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);

    % onsets from dry
    xo = bp(x, fs, 30, 120);
    e  = sqrt(movmean(xo.^2, max(1,round(0.005*fs))));
    thr = 0.25*max(e); minsep = round(0.140*fs);
    idx = find(e > thr);
    onsets = [];
    if ~isempty(idx)
        k = idx(1);
        for i = 2:numel(idx)
            if idx(i) - k > minsep
                onsets(end+1) = backtrack(e, k); %#ok<AGROW>
                k = idx(i);
            elseif e(idx(i)) > e(k)
                k = idx(i);
            end
        end
        onsets(end+1) = backtrack(e, k);
    end
    aN = round(0.015*fs); s1 = round(0.040*fs); s2 = round(0.140*fs);
    onsets = onsets(onsets > 1 & onsets + s2 <= n);
    if isempty(onsets); t = NaN; return; end

    xb = bp(x, fs, band(1), band(2));
    yb = bp(y, fs, band(1), band(2));
    ax=0; ay=0; sx=0; sy=0;
    for o = onsets
        A = o:(o+aN-1); S = (o+s1):(o+s2-1);
        ax = ax + sum(xb(A).^2); ay = ay + sum(yb(A).^2);
        sx = sx + sum(xb(S).^2); sy = sy + sum(yb(S).^2);
    end
    t = 10*log10(max(ay,eps)/max(ax,eps)) - 10*log10(max(sy,eps)/max(sx,eps));
end

function o = backtrack(e, k)
    lim = 0.20*e(k); o = k;
    while o > 1 && e(o) >= lim; o = o - 1; end
    o = max(o,1);
end

function y = bp(x, fs, f1, f2)
    [b1,a1]=butter(2, f2/(fs/2), 'low');
    [b2,a2]=butter(2, f1/(fs/2), 'high');
    y = filtfilt(b2,a2, filtfilt(b1,a1, x));    % zero-phase: no transient smear
end
