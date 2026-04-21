function [input, outlierNum] = fill_outliers(input, thresholdFactor)

coder.inline('never')

% custom filloutliers
Q1 = quantile(input, single(0.25));
Q3 = quantile(input, single(0.75));
IQR = Q3 - Q1;

lowerBound = single(Q1 - thresholdFactor * IQR);
upperBound = single(Q3 + thresholdFactor * IQR);

% outlierIndexes = input < lowerBound | input > upperBound;
outlierNum = sum(input < lowerBound | input > upperBound);

input(input < lowerBound) = lowerBound;
input(input > upperBound) = upperBound;
end