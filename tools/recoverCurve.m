function out = recoverCurve(track, basis, order, probeFreq, weightMode)
%RECOVERCURVE  Recover the static transfer curve f(x) directly from aligned
%   dry-input / reference-output sample pairs (H2). Fits an odd static curve by
%   (weighted) least squares over the tone-battery levels at one probe frequency
%   (default 250 Hz: low enough that oversampling/EQ edge effects are minimal, so
%   the instantaneous input->output map is clean).
%
%   basis:
%     'oddpoly' (default) - odd integer powers  f = sum c_k x^(2k-1)
%     'signpow'           - f = sum c_p sign(x)|x|^p for p = 1..order. Odd powers
%                           reduce to x^p; even powers give the "odd square-law"
%                           terms x|x|^(p-1) whose 3rd harmonic ~ A^2 (THD slope 1),
%                           which pure odd polynomials cannot represent (Iter-4).
%   order       highest power (default 9 for oddpoly, 5 for signpow)
%   weightMode  'rms' (plain LS) | 'levelbalanced' (each level contributes equally
%               so low-level near-origin curvature is not drowned by high-amplitude
%               samples; fixes low-level THD under-fit, Iter-3)
%
%   If one curve fits all levels with small residual, a static waveshaper is
%   sufficient; a level-dependent residual would indicate W-H filtering (H6) or
%   dynamics (H8/H9).
%
%   out.basis, out.powers, out.coeffs (feed waveshaper 'signpow'/'poly'),
%   out.rms_residual, out.per_level_residual, out.levels_dbfs, out.linear_gain

    if nargin<2||isempty(basis);      basis='oddpoly'; end
    if nargin<3||isempty(order);      order = strcmpi(basis,'signpow')*5 + ~strcmpi(basis,'signpow')*9; end
    if nargin<4||isempty(probeFreq);  probeFreq=250; end
    if nargin<5||isempty(weightMode); weightMode='rms'; end

    cfg=config(); fs=cfg.audio.fs; m=jsondecode(fileread(cfg.paths.dry_manifest));
    tb=m.files(1); segs=tb.segments; guard=round(tb.steady_analysis_guard_sec*fs)+round(0.05*fs);
    dry=audioread(fullfile(cfg.paths.dry,tb.name)); dry=dry(:,1);
    ref=audioread(fullfile(cfg.paths.reference,track,tb.name)); ref=ref(:,1);
    ref=subsampleAlign(ref,dry,m.calibration_click.sample_index_1based,fs);

    switch lower(basis)
        case 'oddpoly'; powers = 1:2:order;
        case 'signpow'; powers = 1:order;
        otherwise; error('recoverCurve:basis','unknown basis "%s"',basis);
    end

    X=[]; Y=[]; segIdx=[];
    for s = find([segs.freq_hz]==probeFreq)
        a=segs(s).start_sample_1based+guard; b=segs(s).end_sample_1based-guard;
        X=[X;dry(a:b)]; Y=[Y;ref(a:b)]; segIdx=[segIdx; repmat(s,b-a+1,1)]; %#ok<AGROW>
    end

    A = buildBasis(X, powers, basis);

    % sample weights
    w = ones(numel(X),1);
    if strcmpi(weightMode,'levelbalanced')
        for s = unique(segIdx)'
            sel = segIdx==s;
            w(sel) = 1/max(sqrt(mean(Y(sel).^2)),eps);   % each level -> equal total weight
        end
        w = w / mean(w);
    end
    W = sqrt(w);
    c = (W.*A) \ (W.*Y);
    yhat = A*c;
    rmsRes = sqrt(mean((Y-yhat).^2)) / sqrt(mean(Y.^2));

    uSeg = unique(segIdx); pl = zeros(numel(uSeg),1); lvl = zeros(numel(uSeg),1);
    for i=1:numel(uSeg)
        sel = segIdx==uSeg(i);
        pl(i) = sqrt(mean((Y(sel)-yhat(sel)).^2))/sqrt(mean(Y(sel).^2));
        lvl(i) = segs(uSeg(i)).level_dbfs;
    end

    out=struct('track',track,'basis',basis,'powers',powers,'coeffs',c(:)', ...
               'linear_gain',c(1),'rms_residual',rmsRes, ...
               'per_level_residual',pl,'levels_dbfs',lvl,'order',order,'weight',weightMode);
    fprintf('[recoverCurve %s] basis=%s order=%d weight=%s  relRMSresid=%.4f  c1=%.4f\n', ...
        track, basis, order, weightMode, rmsRes, c(1));
    fprintf('  powers:'); fprintf(' %d',powers); fprintf('\n  coeffs:'); fprintf(' %+.4g', c); fprintf('\n');
    fprintf('  per-level relRMS:'); fprintf(' %.3f', pl); fprintf('  (levels'); fprintf(' %+.0f', lvl); fprintf(')\n');
end

function A = buildBasis(x, powers, basis)
    A = zeros(numel(x), numel(powers));
    for j=1:numel(powers)
        if strcmpi(basis,'signpow'); A(:,j) = sign(x).*abs(x).^powers(j);
        else;                        A(:,j) = x.^powers(j); end
    end
end
