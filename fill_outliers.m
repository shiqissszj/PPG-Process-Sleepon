function [input, outlierNum] = fill_outliers(input, thresholdFactor)

coder.inline('never')

% Lightweight clipping based on mean absolute deviation.
meanValue = mean(input);
meanAbsDeviation = mean(abs(input - meanValue));

% Scale the mean absolute deviation so the clipping width stays close to the
% legacy IQR-based behavior. This keeps the new implementation lightweight
% without collapsing the green-light confidence in the old PR pipeline.
deviationLimit = single(3.0) * thresholdFactor * meanAbsDeviation;

lowerBound = single(meanValue - deviationLimit);
upperBound = single(meanValue + deviationLimit);

% outlierIndexes = input < lowerBound | input > upperBound;
outlierNum = sum(input < lowerBound | input > upperBound);

input(input < lowerBound) = lowerBound;
input(input > upperBound) = upperBound;
end
