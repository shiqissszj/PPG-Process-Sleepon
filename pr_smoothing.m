function [outputPR] = pr_smoothing(inputPR,outputCounter)

coder.inline('never')

% parameters
smoothBufferSizePR = 10;

% initialize the static local buffer
persistent PRSmoothBuffer;
if isempty(PRSmoothBuffer)
    PRSmoothBuffer = single(zeros(smoothBufferSizePR,1));
end
if outputCounter == 1
    PRSmoothBuffer = single(zeros(smoothBufferSizePR,1));
end

% Circular buffer index
bufferIndex = mod(outputCounter-1, smoothBufferSizePR) + 1; 
% Insert the new value
PRSmoothBuffer(bufferIndex) = inputPR; 
% compute the first level of smoothed values
if outputCounter >= smoothBufferSizePR
    firstSmoothedPR = median(PRSmoothBuffer); % Compute the median of the buffer
else
    firstSmoothedPR = median(PRSmoothBuffer(1:outputCounter)); % For initial values when buffer is not full
end

outputPR = firstSmoothedPR;
end

