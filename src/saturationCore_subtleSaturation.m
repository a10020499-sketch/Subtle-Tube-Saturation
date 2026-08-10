function y = saturationCore_subtleSaturation(x, dof, fs)
%SATURATIONCORE_SUBTLESATURATION  Subtle Saturation coloration core.
%   Thin wrapper over processSignal for track 'subtle_saturation' so callers
%   have a mode-named entry point (used by the multiband layer, 3.1/3.5).
    y = processSignal(x, dof, fs, 'subtle_saturation');
end
