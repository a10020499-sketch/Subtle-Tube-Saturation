function y = biquadEQ(x, stages, fs)
%BIQUADEQ  Cascade of RBJ biquad shelf/peak stages (used by preEQ/postEQ).
%   stages: struct array with fields type ('lowshelf'|'highshelf'|'peaking'),
%   freq_hz, gain_db, q. Empty stages -> identity (W-H degenerate case, R2-A).

    y = x;
    if isempty(stages); return; end
    for s = 1:numel(stages)
        [b, a] = rbjCoeffs(stages(s), fs);
        y = filter(b, a, y);
    end
end

function [b, a] = rbjCoeffs(st, fs)
    A  = 10^(st.gain_db/40);
    w0 = 2*pi*st.freq_hz/fs;
    cw = cos(w0); sw = sin(w0);
    Q  = st.q;
    alpha = sw/(2*Q);
    switch lower(st.type)
        case 'peaking'
            b0 = 1 + alpha*A;   b1 = -2*cw;           b2 = 1 - alpha*A;
            a0 = 1 + alpha/A;   a1 = -2*cw;           a2 = 1 - alpha/A;
        case 'lowshelf'
            sq = 2*sqrt(A)*alpha;
            b0 =    A*((A+1) - (A-1)*cw + sq);
            b1 =  2*A*((A-1) - (A+1)*cw);
            b2 =    A*((A+1) - (A-1)*cw - sq);
            a0 =       (A+1) + (A-1)*cw + sq;
            a1 =   -2*((A-1) + (A+1)*cw);
            a2 =       (A+1) + (A-1)*cw - sq;
        case 'highshelf'
            sq = 2*sqrt(A)*alpha;
            b0 =    A*((A+1) + (A-1)*cw + sq);
            b1 = -2*A*((A-1) + (A+1)*cw);
            b2 =    A*((A+1) + (A-1)*cw - sq);
            a0 =       (A+1) - (A-1)*cw + sq;
            a1 =    2*((A-1) - (A+1)*cw);
            a2 =       (A+1) - (A-1)*cw - sq;
        otherwise
            error('biquadEQ:type', 'unknown stage type "%s"', st.type);
    end
    b = [b0 b1 b2]/a0;
    a = [1 a1/a0 a2/a0];
end
