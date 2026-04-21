function [outputR] = r_smoothing(inputR,outputCounter)

coder.inline('never')

% parameters
smoothBufferSizeR = 30;

% smooth method 1: use moving median
% initialize the static local buffer
persistent RSmoothBuffer1;
persistent RSmoothBuffer2;
if isempty(RSmoothBuffer1) || isempty(RSmoothBuffer2)
    RSmoothBuffer1 = single(zeros(smoothBufferSizeR,1));
    RSmoothBuffer2 = single(zeros(smoothBufferSizeR,1));
end
if outputCounter == 1
    RSmoothBuffer1 = single(zeros(smoothBufferSizeR,1));
    RSmoothBuffer2 = single(zeros(smoothBufferSizeR,1));
end

% Update the first buffer and compute the first level of smoothed values
% Circular buffer index
bufferIndex = mod(outputCounter-1, smoothBufferSizeR) + 1; 
% Insert the new value
RSmoothBuffer1(bufferIndex) = inputR; 
% compute the first level of smoothed values
if outputCounter >= smoothBufferSizeR
    firstSmoothedR = median(RSmoothBuffer1); % Compute the median of the buffer
else
    firstSmoothedR = median(RSmoothBuffer1(1:outputCounter)); % For initial values when buffer is not full
end

% Update the second buffer with the first level smoothed value and compute the second level
% Insert the new value
RSmoothBuffer2(bufferIndex) = firstSmoothedR;
% compute the second level of smoothed values
if outputCounter >= smoothBufferSizeR
    secondSmoothedR = median(RSmoothBuffer2); % Compute the median of the buffer
else
    secondSmoothedR = median(RSmoothBuffer2(1:outputCounter)); % For initial values when buffer is not full
end

outputR = secondSmoothedR;
end

