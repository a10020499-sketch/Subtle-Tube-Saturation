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
            % very light envelope-following compression, ratio ~1.02..1.15:1.
            atk = exp(-1/(fs*dec.attack_ms/1000));
            rel = exp(-1/(fs*dec.release_ms/1000));
            env = 0; g = ones(numel(x),1);
            ax = abs(x);
            for n = 1:numel(x)
                if ax(n) > env; env = atk*env + (1-atk)*ax(n);
                else;           env = rel*env + (1-rel)*ax(n); end
                if env > 1e-6
                    envDb  = 20*log10(env);
                    overDb = max(envDb, -60);
                    gDb    = overDb*(1/dec.ratio - 1);   % downward, no threshold (glue)
                    g(n)   = 10^(gDb/20);
                end
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
