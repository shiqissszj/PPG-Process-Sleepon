function [inputAC,outlierNum] = ac_filter(inputAC) %#codegen

coder.inline('never')

% threshold for outlier filter
thresholdFactor = single(0.6);
maxBufferLength = 300;

persistent forwardBuffer;
persistent reverseBuffer;

if isempty(forwardBuffer)
    forwardBuffer = zeros(maxBufferLength, 1, 'single');
end
if isempty(reverseBuffer)
    reverseBuffer = zeros(maxBufferLength, 1, 'single');
end

% use customized filloutliers function
[inputAC, outlierNum] = fill_outliers(inputAC, thresholdFactor);

% use zero-phase digital filter
% a, b are parameters for butter bandpass filter
% [b, a] = butter(3, [0.5/(0.5*50), 4/(0.5*50)], 'bandpass');
a = single([1,-5.04456767,10.69467700,-12.21737356,7.94145633,-2.78601016,0.41183913]);
b = single([0.00716766,0,-0.02150300,0,0.02150300,0,-0.00716766]);
sampleCount = length(inputAC);
filterOrder = length(a);

for sampleIdx = 1:sampleCount
    accValue = single(0);

    for coeffIdx = 1:filterOrder
        inputIdx = sampleIdx - coeffIdx + 1;
        if inputIdx >= 1
            accValue = accValue + b(coeffIdx) * inputAC(inputIdx);
        end
    end

    for coeffIdx = 2:filterOrder
        outputIdx = sampleIdx - coeffIdx + 1;
        if outputIdx >= 1
            accValue = accValue - a(coeffIdx) * forwardBuffer(outputIdx);
        end
    end

    forwardBuffer(sampleIdx) = accValue;
end

for sampleIdx = 1:sampleCount
    reverseBuffer(sampleIdx) = forwardBuffer(sampleCount - sampleIdx + 1);
end

for sampleIdx = 1:sampleCount
    accValue = single(0);

    for coeffIdx = 1:filterOrder
        inputIdx = sampleIdx - coeffIdx + 1;
        if inputIdx >= 1
            accValue = accValue + b(coeffIdx) * reverseBuffer(inputIdx);
        end
    end

    for coeffIdx = 2:filterOrder
        outputIdx = sampleIdx - coeffIdx + 1;
        if outputIdx >= 1
            accValue = accValue - a(coeffIdx) * forwardBuffer(outputIdx);
        end
    end

    forwardBuffer(sampleIdx) = accValue;
end

for sampleIdx = 1:sampleCount
    inputAC(sampleIdx) = forwardBuffer(sampleCount - sampleIdx + 1);
end

end
