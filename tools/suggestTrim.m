function t = suggestTrim(cfg, files, ceilingDb)
%SUGGESTTRIM  What output_gain_db to set so the current multiband setting never
%   clips on your material.
%
%   Band summation raises peaks rather than lowering them, so a setting that sounds
%   right can still write over full scale. This measures the true peak across a set
%   of files with the CURRENT cfg.multiband settings and returns the trim that puts
%   the worst case at the requested ceiling (default -1 dBFS).
%
%   Reports per file so an outlier is visible rather than averaged away.

    if nargin<1||isempty(cfg); cfg=config(); end
    if nargin<2||isempty(files)
        d=dir(fullfile(cfg.paths.program,'*.wav'));
        files=setdiff({d.name},{'01_tone_battery.wav'});
    end
    if nargin<3||isempty(ceilingDb); ceilingDb=-1; end

    c=cfg; c.multiband.output_gain_db=0;      % measure ungained
    worst=0;
    fprintf('Peak with the current multiband setting (trim at 0 dB):\n');
    for i=1:numel(files)
        [x,fs]=audioread(fullfile(cfg.paths.program,files{i}));
        pk=0;
        for ch=1:size(x,2)
            y=multibandProcess(x(:,ch),c,fs);
            pk=max(pk,max(abs(y)));
        end
        fprintf('  %-24s %7.3f  (%+6.2f dBFS)%s\n', files{i}, pk, 20*log10(max(pk,eps)), ...
            repmat(' <-- would clip', 1, pk>1));
        worst=max(worst,pk);
    end
    t = ceilingDb - 20*log10(max(worst,eps));
    fprintf('\n  worst peak %.3f (%+.2f dBFS)\n', worst, 20*log10(max(worst,eps)));
    fprintf('  suggested cfg.multiband.output_gain_db = %+.2f   (ceiling %+.0f dBFS)\n', t, ceilingDb);
end
