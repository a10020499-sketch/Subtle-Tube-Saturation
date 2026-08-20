function d = attackClarity(y, x, fs)
%ATTACKCLARITY  How much nonlinear material the processor piles onto the ATTACK,
%   dB relative to the dry attack energy. The transient itself can be intact (TAG
%   flat) while extra harmonics around it blunt its apparent clarity - masking.
%   Lower = cleaner attack. Onsets are detected on the dry signal.
    n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);
    [b1,a1]=butter(2,120/(fs/2),'low'); [b2,a2]=butter(2,30/(fs/2),'high');
    xo=filtfilt(b2,a2,filtfilt(b1,a1,x));
    e=sqrt(movmean(xo.^2,max(1,round(0.005*fs))));
    thr=0.25*max(e); minsep=round(0.140*fs);
    idx=find(e>thr); on=[];
    if ~isempty(idx)
        k=idx(1);
        for i=2:numel(idx)
            if idx(i)-k>minsep; on(end+1)=k; k=idx(i); elseif e(idx(i))>e(k); k=idx(i); end
        end
        on(end+1)=k;
    end
    aN=round(0.030*fs);                      % 30 ms attack region
    on=on(on>1 & on+aN<=n);
    if isempty(on); d=NaN; return; end
    % gain-match then take the residual after removing the best linear fit
    g=(y'*x)/max(x'*x,eps); r=y-g*x;
    num=0; den=0;
    for o=on
        w=o:(o+aN-1);
        num=num+sum(r(w).^2); den=den+sum(x(w).^2);
    end
    d=10*log10(max(num,eps)/max(den,eps));
end
