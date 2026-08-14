function tunePunchAir(which)
%TUNEPUNCHAIR  Phase B iter 03 sweeps for the two live requests.
%   which = 'punch' (subtle_tube, kick punch) | 'air' (subtle_saturation, HF
%   excitement + reverb-tail audibility). Prints the voiceMetrics table for each
%   candidate, loudness-matched, so a candidate cannot win by being louder.

    if nargin<1||isempty(which); which='punch'; end
    cfg=config(); fs=48000;

    switch lower(which)
    case 'punch'
        track='subtle_tube'; dof0=cfg.tracks.(track).dof;
        file='Epic_Drum_Test.wav';
        base=@(d) hfVariant(d,8000,0.75,1.0);          % the listener's pick, E3
        C={};
        C{end+1}=struct('name','E3 (current)',     'p',@(d) base(d));
        C{end+1}=struct('name','post +2 @90 Q.8',  'p',@(d) peak(base(d),'post',90,2.0,0.8));
        C{end+1}=struct('name','pre  +3 @90 Q.8',  'p',@(d) peak(base(d),'pre', 90,3.0,0.8));
        C{end+1}=struct('name','pre+3 post+1 @90', 'p',@(d) peak(peak(base(d),'pre',90,3.0,0.8),'post',90,1.0,0.8));
        C{end+1}=struct('name','LF60 clean',       'p',@(d) lfVariant(base(d),60,0,0));
        C{end+1}=struct('name','LF60 + post+2',    'p',@(d) peak(lfVariant(base(d),60,0,0),'post',90,2.0,0.8));
        run(track,file,dof0,C,fs,{'punch','lowcrest','lowE','crest','nlLOW'});

    case 'air'
        track='subtle_saturation'; dof0=cfg.tracks.(track).dof;
        % the decay-tail probe isolates exactly what "reverb tails more audible"
        % means; in a dense mix the dynamics metric is swamped by the music
        file='../probes/P8_decay_tail.wav';
        base=@(d) hfVariant(d,8000,0.50,1.0);          % the listener's pick, E2
        C={};
        C{end+1}=struct('name','E2 (current)',    'p',@(d) base(d));
        C{end+1}=struct('name','air 8k +2',       'p',@(d) shelf(base(d),8000,2.0));
        C{end+1}=struct('name','air 8k +3',       'p',@(d) shelf(base(d),8000,3.0));
        C{end+1}=struct('name','up 1.5 thr-30',   'p',@(d) upw(base(d),1.5,-30,18));
        C{end+1}=struct('name','up 2.0 thr-30',   'p',@(d) upw(base(d),2.0,-30,18));
        C{end+1}=struct('name','up 2.0 thr-24',   'p',@(d) upw(base(d),2.0,-24,18));
        C{end+1}=struct('name','up2.0-30 + air+2','p',@(d) shelf(upw(base(d),2.0,-30,18),8000,2.0));
        run(track,file,dof0,C,fs,{'air','tail','crest','nlHF'});
    end
end

function run(track,file,dof0,C,fs,cols)
    cfg=config();
    [x,fsp]=audioread(fullfile(cfg.paths.program,file)); x=x(:,1); assert(fsp==fs);
    fprintf('[%s] %s  (loudness-matched)\n', track, file);
    fprintf('  %-20s', 'variant'); fprintf('%9s', cols{:}); fprintf('\n');
    for c=1:numel(C)
        d=C{c}.p(dof0);
        y=processSignal(x,d,fs,track);
        y=y*10^((loud(x,fs)-loud(y,fs))/20);
        m=voiceMetrics(y,x,fs);
        fprintf('  %-20s', C{c}.name);
        for k=1:numel(cols); fprintf('%9.2f', m.(cols{k})); end
        fprintf('\n');
    end
    mdry=voiceMetrics(x,x,fs);
    fprintf('  %-20s', '(dry reference)');
    for k=1:numel(cols)
        switch cols{k}
            case 'punch'; fprintf('%9.2f', mdry.punch);
            case 'tail';  fprintf('%9.2f', mdry.tail);
            case 'crest'; fprintf('%9.2f', mdry.crest);
            otherwise;    fprintf('%9s', '-');
        end
    end
    fprintf('\n');
end

function d=fatk(d,ms);  d.hf_clean.follow_attack_ms=ms; end
function d=drv(d,k);    d.shaper.drive_k=d.shaper.drive_k*k; end
function d=bias(d,a,r); d.dynamic_bias.attack_ms=a; d.dynamic_bias.release_ms=r; end
function d=peak(d,where,fc,g,q)
%PEAK  add a peaking stage to pre- or post-EQ. 'pre' drives the curve harder in
%   that region (more weight AND more harmonics there); 'post' is pure level.
    st=struct('type','peaking','freq_hz',fc,'gain_db',g,'q',q);
    if strcmpi(where,'pre'); d.preEQ.stages(end+1)=st; else; d.postEQ.stages(end+1)=st; end
end
function d=shelf(d,fc,g)
    d.postEQ.stages(end+1)=struct('type','highshelf','freq_hz',fc,'gain_db',g,'q',0.7);
end
function d=upw(d,ratio,thr,rng)
%UPW  upward compression: lift material BELOW threshold so reverb tails and low
%   level detail come forward, without squashing transients.
    % Attack must be FAST: the boost has to be withdrawn the instant the signal
    % rises, otherwise a lagging envelope still thinks the transient is "quiet"
    % and amplifies it (measured: crest 10.0 -> 16.3 dB with a 20 ms attack).
    d.dec.mode='upward'; d.dec.position='post';
    d.dec.ratio=ratio; d.dec.threshold_db=thr; d.dec.range_db=rng;
    d.dec.attack_ms=2; d.dec.release_ms=300;
end
function d=comp(d,ratio,atk,rel)
    d.dec.mode='soft_compression'; d.dec.position='post';
    d.dec.ratio=ratio; d.dec.attack_ms=atk; d.dec.release_ms=rel;
end
function L=loud(x,fs)
    if exist('integratedLoudness','file'); L=integratedLoudness(x,fs);
    else; L=20*log10(sqrt(mean(x(:).^2))+eps)-0.691; end
end
