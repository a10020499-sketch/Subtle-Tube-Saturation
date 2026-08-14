function t = tiltReport(y, x, fs, edges)
%TILTREPORT  The effective linear response the processing applied, per octave, in
%   dB, AFTER loudness matching - i.e. exactly the tonal shift a listener hears
%   once level is taken out. Computed from the per-bin optimal gain
%   H(k) = <Y,X>/<X,X>, so it is unaffected by the nonlinear residual.
%
%   Use it to answer "the highs came up, did the mids drop and by how much" with a
%   number instead of a guess.

    if nargin<4||isempty(edges); edges=[60 125 250 500 1000 2000 4000 8000 16000]; end
    n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);
    nfft=4096; hop=nfft/4; w=hann(nfft,'periodic'); g=8192;
    x=x(g:end-g); y=y(g:end-g); n=numel(x);
    nfr=max(1,floor((n-nfft)/hop)+1);
    X=zeros(nfft/2+1,nfr); Y=X;
    for k=1:nfr
        idx=(k-1)*hop+(1:nfft);
        Fx=fft(x(idx).*w,nfft); Fy=fft(y(idx).*w,nfft);
        X(:,k)=Fx(1:nfft/2+1); Y(:,k)=Fy(1:nfft/2+1);
    end
    H=sum(Y.*conj(X),2)./(sum(abs(X).^2,2)+eps);
    fr=(0:nfft/2)'*fs/nfft; t=zeros(1,numel(edges)-1);
    for b=1:numel(edges)-1
        sel=fr>=edges(b)&fr<edges(b+1);
        t(b)=20*log10(mean(abs(H(sel)))+eps);
    end
end
