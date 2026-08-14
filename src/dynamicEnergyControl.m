function y = dynamicEnergyControl(x, dof, fs)
%DYNAMICENERGYCONTROL  H9 umbrella (SPECIFICATION 3.2-B). Phase A: always bypass.
%   Candidate implementations (validation order): soft_compression (default
%   starting point), env_mod, micro_sag, level_gain. Only soft_compression is
%   implemented here; the others are Phase B research stubs that fall back to
%   bypass with a warning so the loop never silently mis-processes.

    dec = dof.dec;
    switch lower(dec.mode)
        case 'bypass'
            y = x;

        case 'soft_compression'
            % Light envelope-following compression above a threshold.
            %
            % The earlier form had no threshold and computed the gain from the
            % absolute envelope level, so the QUIETER a passage was the more it was
            % boosted, and because the envelope lags a transient by the attack time
            % the loudest peaks were boosted too - it expanded transients instead of
            % compressing them (measured: crest 10.0 -> 18.3 dB at ratio 1.5). This
            % form only acts on the amount by which the envelope EXCEEDS threshold,
            % which is what "ratio" is defined against.
            thr = -18; if isfield(dec,'threshold_db') && ~isempty(dec.threshold_db); thr = dec.threshold_db; end
            knee = 6;  if isfield(dec,'knee_db')      && ~isempty(dec.knee_db);      knee = dec.knee_db;     end
            mkup = 0;  if isfield(dec,'makeup_db')    && ~isempty(dec.makeup_db);    mkup = dec.makeup_db;   end
            atk = exp(-1/(fs*dec.attack_ms/1000));
            rel = exp(-1/(fs*dec.release_ms/1000));
            env = 0; g = ones(numel(x),1);
            ax = abs(x);
            for n = 1:numel(x)
                if ax(n) > env; env = atk*env + (1-atk)*ax(n);
                else;           env = rel*env + (1-rel)*ax(n); end
                envDb = 20*log10(max(env, 1e-9));
                over  = envDb - thr;
                if over <= -knee/2
                    gDb = 0;                                    % below the knee
                elseif over < knee/2
                    gDb = (1/dec.ratio - 1) * (over + knee/2)^2 / (2*knee);   % soft knee
                else
                    gDb = (1/dec.ratio - 1) * over;             % above: ratio applies
                end
                g(n) = 10^((gDb + mkup)/20);
            end
            y = x .* g;

        case 'upward'
            % Upward compression: lift material BELOW threshold, leaving loud
            % material alone. This is the tool for "make the reverb tail more
            % audible" - it raises low-level detail without squashing transients.
            thr = -30;   if isfield(dec,'threshold_db') && ~isempty(dec.threshold_db); thr = dec.threshold_db; end
            rng = 24;    if isfield(dec,'range_db')     && ~isempty(dec.range_db);     rng = dec.range_db;     end
            atk = exp(-1/(fs*dec.attack_ms/1000));
            rel = exp(-1/(fs*dec.release_ms/1000));
            env = 0; g = ones(numel(x),1); ax = abs(x);
            for n = 1:numel(x)
                if ax(n) > env; env = atk*env + (1-atk)*ax(n);
                else;           env = rel*env + (1-rel)*ax(n); end
                envDb = 20*log10(max(env, 1e-9));
                under = min(max(thr - envDb, 0), rng);          % how far below thr
                gDb   = under * (1 - 1/dec.ratio);              % lift, bounded by range
                g(n)  = 10^(gDb/20);
            end
            y = x .* g;

        case {'env_mod','micro_sag','level_gain'}
            warning('dynamicEnergyControl:stub', ...
                'DEC mode "%s" is a Phase B research stub; bypassing.', dec.mode);
            y = x;

        otherwise
            error('dynamicEnergyControl:mode', 'unknown dec.mode "%s"', dec.mode);
    end
end
