function out = fitTube()
%FITTUBE  Fit the Subtle Tube H8 model — a symmetric odd base curve plus an
%   envelope-driven bias  y = f(x + b),  b_steady = depth * (2A/pi)  — to the
%   reference per-segment harmonic profile (H2..H5 vs level & frequency). Fast:
%   evaluates each tone-battery segment as an oversampled steady sine through the
%   static-with-bias model and measures harmonics; no full-file pipeline render.
%   Attack/release do not affect steady tones, so only the base curve (5 signpow
%   coeffs) and bias depth are fit here; the follower time constants are set
%   afterwards from the loop-vs-frequency behaviour and validated in-pipeline.
%
%   out.coeffs (signpow powers 1..5), out.depth, out.cost, out.fit_table

    cfg=config(); fs=cfg.audio.fs; m=jsondecode(fileread(cfg.paths.dry_manifest));
    tb=m.files(1); segs=tb.segments; guard=round(tb.steady_analysis_guard_sec*fs)+round(0.05*fs);
    dry=audioread(fullfile(cfg.paths.dry,tb.name)); dry=dry(:,1);
    ref=audioread(fullfile(cfg.paths.reference,'subtle_tube',tb.name)); ref=ref(:,1);
    ref=subsampleAlign(ref,dry,m.calibration_click.sample_index_1based,fs);

    % --- measure reference targets: fund gain + H2..H5 (dB rel fund) per segment
    nseg=numel(segs); Rf=zeros(nseg,1); Rh=nan(nseg,4); A=zeros(nseg,1); F=zeros(nseg,1);
    for s=1:nseg
        a=segs(s).start_sample_1based+guard; b=segs(s).end_sample_1based-guard;
        F(s)=segs(s).freq_hz; A(s)=10^(segs(s).level_dbfs/20);
        [Rf(s),Rh(s,:)]=harmset(ref(a:b),F(s),fs);
    end

    % --- optimise [c1 c2 c3 c4 c5 depth gamma] to match harmonics (H2..H5).
    % gamma<1 is the compressive bias-vs-envelope mapping (Iter-3) that lifts
    % low-level even harmonics so H2 falls slower than A, as the reference does.
    p0=[0.9586 -0.7593 -0.3636 1.2168 -0.6519 0.0615 0.65];
    cost=@(p) tubeCost(p, A, F, Rf, Rh, fs);
    opt=optimset('Display','off','MaxFunEvals',6000,'MaxIter',6000,'TolFun',1e-4,'TolX',1e-4);
    [p,fval]=fminsearch(cost, p0, opt);

    out=struct('basis','signpow','powers',[1 2 3 4 5],'coeffs',p(1:5),'depth',p(6),'gamma',p(7),'cost',fval);
    fprintf('[fitTube] cost=%.3f  depth=%.4f gamma=%.3f\n  coeffs=',fval,p(6),p(7)); fprintf(' %+.4f',p(1:5)); fprintf('\n');
    fprintf('  check @1kHz (model H2/H3 vs ref):\n');
    for L=[-24 -13.5 -7 0]
        s=find(F==1000 & abs(20*log10(A)-L)<0.3,1);
        [~,mh]=modelHarm(p,A(s),1000,fs);
        fprintf('    %+5.1f dBFS: H2 %6.1f/%6.1f  H3 %6.1f/%6.1f\n',L,mh(1),Rh(s,1),mh(2),Rh(s,2));
    end
end

function J=tubeCost(p, A, F, Rf, Rh, fs)
    wH=[3 3 0.5 0.3];   % weight H2,H3 (dominant tube tone) above H4,H5
    J=0;
    for s=1:numel(A)
        [~,mh]=modelHarm(p,A(s),F(s),fs);
        for h=1:4
            if ~isnan(Rh(s,h)) && max(mh(h),Rh(s,h))>-80
                J = J + wH(h)*(mh(h)-Rh(s,h))^2;
            end
        end
    end
end

function [fundAmp,hdb]=modelHarm(p,A,f0,fs)
    c=p(1:5); depth=p(6); gamma=p(7); os=4; fso=fs*os;
    ncyc=40; N=round(ncyc*fso/f0); t=(0:N-1)'/fso;
    x=A*sin(2*pi*f0*t);
    b=depth*(2*A/pi)^gamma;                 % steady compressive envelope-driven bias
    u=x+b; y=sign(u).*0; for i=1:5; y=y+c(i)*sign(u).*abs(u).^i; end
    y=y-mean(y);
    % measure fund + H2..H5 at base-rate observable range
    Y=abs(fft(y.*hann(N))); Y=Y(1:floor(N/2)); fr=(0:numel(Y)-1)*fso/N; bw=f0*0.05+10;
    fundAmp=max(Y(fr>=f0-bw&fr<=f0+bw))/ (A* N/2/2); %#ok<NASGU>  % rough scale (unused abs)
    fund=max(Y(fr>=f0-bw&fr<=f0+bw));
    hdb=nan(1,4);
    for h=2:5
        fh=h*f0; if fh>=fs/2; break; end
        hdb(h-1)=20*log10(max(Y(fr>=fh-bw&fr<=fh+bw))/max(fund,eps));
    end
    fundAmp=fund/(N/2);                     % fundamental amplitude estimate
end

function [fundAmp,hdb]=harmset(x,f0,fs)
    x=x(:)-mean(x); N=numel(x); X=abs(fft(x.*hann(N))); X=X(1:floor(N/2));
    fr=(0:numel(X)-1)*fs/N; bw=f0*0.05+10; fund=max(X(fr>=f0-bw&fr<=f0+bw));
    fundAmp=fund/(N/2); hdb=nan(1,4);
    for h=2:5; fh=h*f0; if fh>=fs/2; break; end; hdb(h-1)=20*log10(max(X(fr>=fh-bw&fr<=fh+bw))/max(fund,eps)); end
end
