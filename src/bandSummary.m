function y = bandSummary(bands)
%BANDSUMMARY  Sum per-band outputs back to a single signal (SPECIFICATION 3.1).
    n = max(cellfun(@numel, bands));
    y = zeros(n, 1);
    for k = 1:numel(bands)
        bk = bands{k}(:);
        y(1:numel(bk)) = y(1:numel(bk)) + bk;
    end
end
