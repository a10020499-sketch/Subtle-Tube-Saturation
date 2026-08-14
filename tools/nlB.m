function d = nlB(y, x, fs, f1, f2)
%NLB  nonlinear (uncorrelated) residual in a band, dB relative to the input.
%   Per-bin complex projection H(k)=<Y,X>/<X,X> absorbs every linear difference
%   (level, EQ, phase, delay) exactly, so the residual R = Y - H*X is purely what
%   the nonlinearity generated. Higher = more harmonic/IMD content in that band.
    n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);
    nfft=4096; hop=nfft/4; w=hann(nfft,'periodic'); g=8192;
    if n < 4*g; d=NaN; return; end
    x=x(g:end-g); y=y(g:end-g); n=numel(x);
    nfr=max(1,floor((n-nfft)/hop)+1); X=zeros(nfft/2+1,nfr); Y=X;
    for k=1:nfr
        idx=(k-1)*hop+(1:nfft);
        Fx=fft(x(idx).*w,nfft); Fy=fft(y(idx).*w,nfft);
        X(:,k)=Fx(1:nfft/2+1); Y(:,k)=Fy(1:nfft/2+1);
    end
    H=sum(Y.*conj(X),2)./(sum(abs(X).^2,2)+eps); R=Y-H.*X;
    fr=(0:nfft/2)'*fs/nfft; sel=fr>=f1 & fr<f2;
    d=10*log10(max(sum(sum(abs(R(sel,:)).^2)),eps)/max(sum(sum(abs(X(sel,:)).^2)),eps));
end
