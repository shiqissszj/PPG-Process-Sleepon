function [outputR,outputPR,outputConfidenceR] = r_pr_fix(inputR, inputPR, confidenceR, confidenceG, outputCounter)

coder.inline('never')

% smooth the confidence
% fix the output if the confidence is low

% parameters
fixBufferSize = 25;
confidenceBufferSize = 30;
defaultR = single(0.35);
defaultPR = single(60);
confidenceThreshold = 0.75;
defaultConfidence = single(0.5);

% initialize the static local buffer
persistent fixBufferR;
persistent fixBufferPR;
persistent confidenceBuffer;
persistent reliableCounterR;
persistent reliableCounterG;

if outputCounter == 1
    fixBufferR = zeros(fixBufferSize,1,'single');
    fixBufferPR = zeros(fixBufferSize,1,'single');
    confidenceBuffer = zeros(confidenceBufferSize,1,'single');
    reliableCounterR = uint32(0);
    reliableCounterG = uint32(0);
end
if isempty(fixBufferR)
    fixBufferR = zeros(fixBufferSize,1,'single');
end
if isempty(fixBufferPR)
    fixBufferPR = zeros(fixBufferSize,1,'single');
end
if isempty(confidenceBuffer)
    confidenceBuffer = zeros(confidenceBufferSize,1,'single');
end
if isempty(reliableCounterR)
    reliableCounterR = uint32(0);
end
if isempty(reliableCounterG)
    reliableCounterG = uint32(0);
end

% smooth the confidence
confidenceBufferIndex = mod(outputCounter-1, confidenceBufferSize) + 1;
confidenceBuffer(confidenceBufferIndex) = confidenceR;
% if confidenceR>0.6
%     confidenceBuffer(confidenceBufferIndex) = confidenceR;
% else
%     confidenceBuffer(confidenceBufferIndex) = 0;
% end
if confidenceR > 0
    if outputCounter > confidenceBufferSize
        outputConfidenceR = mean(confidenceBuffer);
        % outputConfidenceR = min(mean(confidenceBuffer),confidenceR);
    elseif outputCounter >= 1
        outputConfidenceR = mean(confidenceBuffer(1:outputCounter));
        % outputConfidenceR = min(mean(confidenceBuffer(1:outputCounter-1)),confidenceR);
    else
        outputConfidenceR = defaultConfidence;
    end
else
    outputConfidenceR = single(0);
end

if outputConfidenceR > confidenceThreshold
    reliableCounterR = reliableCounterR + 1;
end

if confidenceG > confidenceThreshold
    reliableCounterG = reliableCounterG + 1;
end
    

fixBufferIndexR = mod(reliableCounterR-1, fixBufferSize) + 1; % Circular buffer index
fixBufferIndexG = mod(reliableCounterG-1, fixBufferSize) + 1; % Circular buffer index

if outputConfidenceR < confidenceThreshold || confidenceR < confidenceThreshold % fix the R and PR value
    if reliableCounterR >= fixBufferSize
        fixedR = mean(fixBufferR);
        fixedR = fixedR*(1-confidenceR) + inputR * confidenceR;
    elseif reliableCounterR > 1
        fixedR = mean(fixBufferR(1:reliableCounterR-1));
        fixedR = fixedR*(1-confidenceR) + inputR * confidenceR;
    else
        fixedR = defaultR;
    end
else % keep the original value
    fixedR = inputR;
end

if confidenceG < confidenceThreshold % fix the R and PR value
    if reliableCounterG > fixBufferSize
        fixedPR = mean(fixBufferPR);
    elseif reliableCounterG > 1
        fixedPR = mean(fixBufferPR(1:reliableCounterG-1));
    else
        fixedPR = defaultPR;
    end
else % keep the original value
    fixedPR = inputPR;
end

% update the buffer for fix
if outputConfidenceR >= confidenceThreshold %|| outputCounter <= fixBufferSize 
    fixBufferR(fixBufferIndexR) = fixedR;
    % fixBufferR = [fixBufferR(2:fixBufferSize);fixedR];
end
if confidenceG >= confidenceThreshold %|| outputCounter <= fixBufferSize 
    fixBufferPR(fixBufferIndexG) = fixedPR;
    % fixBufferPR = [fixBufferPR(2:fixBufferSize);fixedPR];
end
outputR = fixedR;
outputPR = fixedPR;

end

