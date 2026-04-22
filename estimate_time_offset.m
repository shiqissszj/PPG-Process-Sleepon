function time_offset = estimate_time_offset(PR_est, PR_true, maxLagWin, stepSize)
% Estimate sample-level time offset between estimated and reference
% sequences using normalized cross-correlation over window indices.
%
% Positive offset means the estimated series lags the reference series, so
% the estimated series should be shifted left by offset/stepSize windows.

if nargin < 3 || isempty(maxLagWin)
    maxLagWin = 120;
end
if nargin < 4 || isempty(stepSize)
    stepSize = 50;
end

PR_est = PR_est(:);
PR_true = PR_true(:);

N = min(length(PR_est), length(PR_true));
if N < 5
    time_offset = 0;
    return
end

L = min(maxLagWin, floor(N / 2));

bestCorr = -Inf;
bestLag = 0;

for lag = -L:L
    if lag >= 0
        x = PR_est(1 + lag:N);
        y = PR_true(1:N - lag);
    else
        x = PR_est(1:N + lag);
        y = PR_true(1 - lag:N);
    end

    mask = isfinite(x) & isfinite(y) & (x > 0) & (y > 0);
    if ~any(mask)
        continue
    end

    x = x(mask);
    y = y(mask);
    if numel(x) < 5
        continue
    end

    x = x - mean(x);
    y = y - mean(y);
    denom = sqrt(sum(x .^ 2)) * sqrt(sum(y .^ 2));
    if denom == 0
        continue
    end

    corrVal = (x.' * y) / denom;
    if corrVal > bestCorr
        bestCorr = corrVal;
        bestLag = lag;
    end
end

time_offset = bestLag * stepSize;
end
