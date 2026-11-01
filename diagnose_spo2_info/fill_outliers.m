function [input, outlierNum] = fill_outliers(input, thresholdFactor)

coder.inline('never')

sampleCount = length(input);
outlierNum = double(0);

if sampleCount == 0
    return
end

% Lightweight clipping based on mean absolute deviation.
sumValue = single(0);
for idx = 1:sampleCount
    sumValue = sumValue + input(idx);
end
meanValue = sumValue / single(sampleCount);

sumAbsDeviation = single(0);
for idx = 1:sampleCount
    deviation = input(idx) - meanValue;
    if deviation < 0
        deviation = -deviation;
    end
    sumAbsDeviation = sumAbsDeviation + deviation;
end
meanAbsDeviation = sumAbsDeviation / single(sampleCount);

% Scale the mean absolute deviation so the clipping width stays close to the
% legacy IQR-based behavior. This keeps the new implementation lightweight
% without collapsing the green-light confidence in the old PR pipeline.
deviationLimit = single(3.0) * thresholdFactor * meanAbsDeviation;

lowerBound = single(meanValue - deviationLimit);
upperBound = single(meanValue + deviationLimit);

for idx = 1:sampleCount
    inputValue = input(idx);

    if inputValue < lowerBound
        input(idx) = lowerBound;
        outlierNum = outlierNum + 1;
    elseif inputValue > upperBound
        input(idx) = upperBound;
        outlierNum = outlierNum + 1;
    end
end
end
