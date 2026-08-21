function gainAudit()
%GAINAUDIT  Where does this chain change level, and is each one deliberate?
%   The goal being audited: "adding colour should make it as loud as the harmonics
%   actually make it - no automatic matching, no normalising."
    addpath('src'); addpath('.'); addpath('tools');
    cfg=config(); fs=48000;
    t=(0:round(0.5*fs)-1)'/fs;

    fprintf('=== 1. LINEAR-REGION gain of each voice (is the quiet path unity?) ===\n');
    fprintf('    A tone at -60 dBFS barely touches the curve, so this is pure linear gain.\n');
    for tr={'subtle_tube','subtle_saturation'}
        tk=tr{1};
        for vn={'final','loud'}
            d=cfg.voice.(tk).(vn{1});
            q=10^(-60/20)*sin(2*pi*1000*t);
            y=processSignal(q,d,fs,tk);
            fprintf('    %-18s %-6s  linear gain %+6.2f dB   (drive_k=%.3f, c1=%.4f)\n', ...
                tk, vn{1}, 20*log10(sqrt(mean(y.^2))/sqrt(mean(q.^2))), ...
                d.shaper.drive_k, d.shaper.coeffs(1));
        end
    end

    fprintf('\n=== 2. DRY/WET crossfade law: does 50%% wet add phantom level? ===\n');
    fprintf('    dry and wet are highly correlated here, so an equal-power law sums them\n');
    fprintf('    ABOVE unity in the middle. Level at each mix, relative to mix=0:\n');
    [x,fsp]=audioread(fullfile(cfg.paths.program,'Disco_Test.wav')); x=x(1:2*fsp,1);
    for law={'equal_power','linear'}
        c=cfg; c.multiband.crossfade=law{1};
        c.multiband.num_bands=1; c.multiband.crossover_hz=[];
        fprintf('    %-12s', law{1});
        for w=[0 0.25 0.5 0.75 1.0]
            c.multiband.bands=struct('mode','subtle_saturation','drive',1.0,'dry_wet',w,'voice',[]);
            y=multibandProcess(x,c,fsp);
            if w==0; ref=sqrt(mean(y.^2)); end
            fprintf('  w%.2f %+5.2f dB', w, 20*log10(sqrt(mean(y.^2))/ref));
        end
        fprintf('\n');
    end

    fprintf('\n=== 3. Auto/normalising steps that exist in the SIGNAL path ===\n');
    for tr={'subtle_tube','subtle_saturation'}
        tk=tr{1}; d=cfg.voice.(tk).final;
        fprintf('    %-18s output.mode=%-14s hf_clean.gain_match=%d\n', tk, d.output.mode, ...
            d.hf_clean.gain_match);
    end
    fprintf('    multiband auto_gain = %s   output_gain_db = %+.2f\n', ...
        cfg.multiband.auto_gain, cfg.multiband.output_gain_db);
    fprintf('    per-band output gain: NOT IMPLEMENTED\n');
end
