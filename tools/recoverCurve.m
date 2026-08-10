function out = recoverCurve(track, oddOnly, order, probeFreq)
%RECOVERCURVE  Recover the static transfer curve f(x) directly from aligned
%   dry-input / reference-output sample pairs (H2). Fits an (odd) polynomial
%   f(x) = c1*x + c3*x^3 + ... by least squares over several tone-battery levels
%   at one probe frequency (default 250 Hz: low enough that oversampling/EQ edge
%   effects are minimal, so the instantaneous input->output map is clean).
%
%   If the same curve fits across all levels with small residual, a pure static
%   waveshaper is sufficient; a level-dependent residual would indicate W-H
%   filtering (H6) or dynamics (H8/H9).
%
%   out.coeffs (for waveshaper 'poly', powers 1..order), out.rms_residual,
%   out.tanh_k_equiv, out.per_level_residual

    if nargin<2||isempty(oddOnly);  oddOnly=true;  end
    if nargin<3||isempty(order);    order=9;       end
    if nargin<4||isempty(probeFreq);probeFreq=250; end

    cfg=config(); fs=cfg.audio.fs; m=jsondecode(fileread(cfg.paths.dry_manifest));
    tb=m.files(1); segs=tb.segments; guard=round(tb.steady_analysis_guard_sec*fs)+round(0.05*fs);
    dry=audioread(fullfile(cfg.paths.dry,tb.name)); dry=dry(:,1);
    ref=audioread(fullfile(cfg.paths.reference,track,tb.name)); ref=ref(:,1);
    ref=subsampleAlign(ref,dry,m.calibration_click.sample_index_1based,fs);

    powers = 1:order; if oddOnly; powers = powers(mod(powers,2)==1); end

    X=[]; Y=[]; segIdx=[];
    idx = find([segs.freq_hz]==probeFreq);
    for s = idx(:)'
        a=segs(s).start_sample_1based+guard; b=segs(s).end_sample_1based-guard;
        xi=dry(a:b); yi=ref(a:b);
        X=[X;xi]; Y=[Y;yi]; segIdx=[segIdx; repmat(s,numel(xi),1)]; %#ok<AGROW>
    end
    A = zeros(numel(X), numel(powers));
    for j=1:numel(powers); A(:,j)=X.^powers(j); end
    c = A\Y;                               % least-squares fit
    yhat = A*c;
    rmsRes = sqrt(mean((Y-yhat).^2)) / sqrt(mean(Y.^2));  % relative RMS residual

    % per-level residual (does one curve fit all levels?)
    uSeg = unique(segIdx); pl = zeros(numel(uSeg),1); lvl = zeros(numel(uSeg),1);
    for i=1:numel(uSeg)
        sel = segIdx==uSeg(i);
        pl(i) = sqrt(mean((Y(sel)-yhat(sel)).^2))/sqrt(mean(Y(sel).^2));
        lvl(i) = segs(uSeg(i)).level_dbfs;
    end

    % express as full poly_coeffs vector for waveshaper 'poly' (powers 1..order)
    coeffs = zeros(1, order);
    for j=1:numel(powers); coeffs(powers(j)) = c(j); end

    % equivalent tanh drive (match small-signal slope c1 and cubic): tanh(kx)~kx-(kx)^3/3
    k_lin = c(1); % linear gain
    out=struct('track',track,'powers',powers,'poly_coeffs',coeffs,'linear_gain',k_lin, ...
               'rms_residual',rmsRes,'per_level_residual',pl,'levels_dbfs',lvl,'order',order);
    fprintf('[recoverCurve %s] order=%d oddOnly=%d  relRMSresid=%.4f  linear gain c1=%.4f\n', ...
        track, order, oddOnly, rmsRes, k_lin);
    fprintf('  coeffs(1..%d):', order); fprintf(' %+.4g', coeffs); fprintf('\n');
    fprintf('  per-level relRMS:'); fprintf(' %.3f', pl); fprintf('  (levels'); fprintf(' %+.0f', lvl); fprintf(')\n');
end
