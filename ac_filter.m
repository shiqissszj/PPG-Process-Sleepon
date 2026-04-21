function [inputAC,outlierNum] = ac_filter(inputAC) %#codegen

coder.inline('never')

% threshold for outlier filter
thresholdFactor = single(0.6);

% use customized filloutliers function
[inputAC, outlierNum] = fill_outliers(inputAC, thresholdFactor);

% use zero-phase digital filter
% a, b are parameters for butter bandpass filter
% [b, a] = butter(3, [0.5/(0.5*50), 4/(0.5*50)], 'bandpass');
a = single([1,-5.04456767,10.69467700,-12.21737356,7.94145633,-2.78601016,0.41183913]);
b = single([0.00716766,0,-0.02150300,0,0.02150300,0,-0.00716766]);
inputAC = filt_filt(b, a, inputAC);

end