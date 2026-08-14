function d = withEQ(d, where, type, fc, gainDb, q)
%WITHEQ  Append one EQ stage to the pre- or post-filter of a coloration config.
%   where  'pre'  - stage sits BEFORE the waveshaper, so it changes how hard that
%                   region drives the curve (more level AND more harmonics there)
%          'post' - stage sits AFTER, pure tonal level, no change to distortion
%   type   'peaking' | 'lowshelf' | 'highshelf'
%
%   Phase B voice lever: Phase A proved the Saturn match needs no EQ at all
%   (H1 = H2 = identity), so anything added here is a deliberate deviation under
%   R-ReferenceFreeze, not part of the model.
    st = struct('type',type,'freq_hz',fc,'gain_db',gainDb,'q',q);
    if strcmpi(where,'pre')
        d.preEQ.stages(end+1) = st;
    else
        d.postEQ.stages(end+1) = st;
    end
end
