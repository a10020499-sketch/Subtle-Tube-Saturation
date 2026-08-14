function checkDriveHeadroom(track, fs)
%CHECKDRIVEHEADROOM  Does the signal reaching the waveshaper stay on the
%   monotonic part of the fitted curve?
%
%   The signpow curves are polynomials fitted over the measured range only. Above
%   some |u| the derivative can cross zero, after which MORE input gives LESS
%   output with inverted slope - wave folding, which sounds far worse than
%   clipping and destroys exactly the transient impact we are trying to protect.
%   Any Phase B lever that raises drive (drive_k, a pre-EQ boost, per-band drive
%   in the multiband layer) can walk the signal into that region, so this has to
%   be checked whenever one is added.

    if nargin<1||isempty(track); track='subtle_tube'; end
    if nargin<2||isempty(fs);    fs=48000; end
    cfg=config(); dof0=cfg.tracks.(track).dof;

    % --- where does the curve turn over? ---
    p=dof0.shaper.powers(:); c=dof0.shaper.coeffs(:);
    uu=linspace(0,3,300001)'; f=zeros(size(uu));
    for i=1:numel(p); f=f+c(i)*uu.^p(i); end
    df=diff(f); turn=find(df<=0,1);
    if isempty(turn)
        uturn=Inf; fprintf('[%s] curve is monotonic to u=3\n', track);
    else
        uturn=uu(turn);
        fprintf('[%s] curve turns over at u=%.4f (f=%.4f) -> folds above this\n', track, uturn, f(turn));
    end

    % --- how hard do the candidates actually drive it? ---
    files={'Epic_Drum_Test.wav','EDM_Test.wav','Disco_Test.wav'};
    base=@(d) hfVariant(d,8000,0.75,1.0);
    C={ struct('name','T0 E3',        'p',@(d) base(d)), ...
        struct('name','T1 post +2',   'p',@(d) withEQ(base(d),'post','peaking',90,2.0,0.8)), ...
        struct('name','T2 pre +3',    'p',@(d) withEQ(base(d),'pre','peaking',90,3.0,0.8)), ...
        struct('name','T3 pre+3post+1','p',@(d) withEQ(withEQ(base(d),'pre','peaking',90,3.0,0.8),'post','peaking',90,1.0,0.8))};

    fprintf('  %-16s', 'variant'); for i=1:numel(files); fprintf('%22s', erase(files{i},'_Test.wav')); end
    fprintf('\n  %-16s', ''); for i=1:numel(files); fprintf('%12s%10s','max|u|','%folded'); end; fprintf('\n');
    for k=1:numel(C)
        fprintf('  %-16s', C{k}.name);
        for i=1:numel(files)
            [x,fsp]=audioread(fullfile(cfg.paths.program,files{i})); x=x(:,1); assert(fsp==fs);
            u = driveSignal(x, C{k}.p(dof0), fs);
            fprintf('%12.3f%9.3f%%', max(abs(u)), 100*mean(abs(u)>uturn));
        end
        fprintf('\n');
    end
end

function u = driveSignal(x, dof, fs)
%DRIVESIGNAL  reproduce exactly what reaches the waveshaper input.
    if isfield(dof,'hf_clean') && dof.hf_clean.enabled && dof.hf_clean.freq_hz>0
        b=crossoverBank(x, dof.hf_clean.freq_hz, fs); lo=b{1}; hi=b{2};
        beta=0; if isfield(dof.hf_clean,'beta'); beta=dof.hf_clean.beta; end
        x = lo + beta*hi;
    end
    v = preEQ(x, dof, fs);
    L = dof.oversample.factor;
    if L>1; v = resample(v, L, 1); end
    u = dof.shaper.drive_k * v;
end
