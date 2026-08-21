function d = loudVoice(d, driveMul)
%LOUDVOICE  Turn a signed-off voice into a LOUDNESS voicing of itself.
%   Loudness at a fixed ceiling is peak compression, so this undoes the three
%   levers that were added to protect peaks:
%     hf_clean.beta -> 1.0   (all HF enters the curve and gets compressed)
%     transient     -> off   (attacks are no longer protected)
%     post-EQ air   -> none  (HF shelf spends peak headroom cheaply)
%   and optionally raises drive. Measured on Disco (subtle_saturation): +3.3 dB
%   louder at equal peak versus the signed-off voice, at a cost of ~5 dB more
%   8-20 kHz nonlinear residual - the "fizz". Intended for the LOW/MID bands of the
%   multiband tool, where the loudness lives and the fizz does not matter, leaving
%   the top band on the transparent voice.
    if nargin<2||isempty(driveMul); driveMul=1.3; end
    if isfield(d,'hf_clean');  d.hf_clean.beta = 1.0;      end
    if isfield(d,'transient'); d.transient.enabled = false; end
    d.postEQ.stages = struct('type',{},'freq_hz',{},'gain_db',{},'q',{});
    d.shaper.drive_k = d.shaper.drive_k * driveMul;
end
