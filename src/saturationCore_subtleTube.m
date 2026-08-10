function y = saturationCore_subtleTube(x, dof, fs)
%SATURATIONCORE_SUBTLETUBE  Subtle Tube coloration core.
%   Thin wrapper over processSignal for track 'subtle_tube'. Enables the
%   tube-specific dynamic-bias lever (H8) when dof.dynamic_bias.enabled.
    y = processSignal(x, dof, fs, 'subtle_tube');
end
