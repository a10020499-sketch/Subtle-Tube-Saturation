function d = hh(y, fs, k, f0)
%HH  level of the k-th harmonic of f0 relative to the fundamental, dB.
    if nargin<4||isempty(f0); f0=1000; end
    y=y(:)-mean(y); N=numel(y); Y=abs(fft(y.*hann(N))); Y=Y(1:floor(N/2));
    fr=(0:numel(Y)-1)*fs/N; bw=30;
    f=max(Y(fr>=f0-bw & fr<=f0+bw));
    fh=k*f0;
    if fh >= fs/2-bw; d=NaN; return; end
    d=20*log10(max(max(Y(fr>=fh-bw & fr<=fh+bw)),eps)/max(f,eps));
end
