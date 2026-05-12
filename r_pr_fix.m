function [outputR,outputPR,outputConfidenceR] = r_pr_fix(inputR, inputPR, confidenceR, confidenceG, outputCounter)

coder.inline('never')

% smooth the confidence
% fix the output if the confidence is low

% parameters
fixBufferSize = 25;
confidenceBufferSize = 30;
defaultR = single(0.35);
defaultPR = single(60);
confidenceThresholdR = single(0.45);
confidenceThresholdPR = single(0.55);
confidenceFloorPR = single(0.35);
defaultConfidence = single(0.5);
minUsableR = single(0.15);
maxUsableR = single(1.80);
minUsablePR = single(35);
maxUsablePR = single(220);
lowConfidenceRJumpRatio = single(0.45);
highConfidenceRJumpRatio = single(0.65);
minLowConfidenceRJump = single(0.18);
minHighConfidenceRJump = single(0.25);

% initialize the static local buffer
persistent fixBufferR;
persistent fixBufferPR;
persistent confidenceBuffer;
persistent reliableCounterR;
persistent reliableCounterG;
persistent prSeeded;

if outputCounter == 1
    fixBufferR = zeros(fixBufferSize,1,'single');
    fixBufferPR = zeros(fixBufferSize,1,'single');
    confidenceBuffer = zeros(confidenceBufferSize,1,'single');
    reliableCounterR = uint32(0);
    reliableCounterG = uint32(0);
    prSeeded = false;
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
if isempty(prSeeded)
    prSeeded = false;
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

inputPRUsable = isfinite(inputPR) && inputPR >= minUsablePR && inputPR <= maxUsablePR;

if ~prSeeded && inputPRUsable && confidenceG > confidenceFloorPR
    fixBufferPR(:) = inputPR;
    reliableCounterG = max(reliableCounterG, uint32(1));
    prSeeded = true;
end

fixBufferIndexR = mod(double(reliableCounterR), fixBufferSize) + 1; % Circular buffer index
fixBufferIndexG = mod(double(reliableCounterG), fixBufferSize) + 1; % Circular buffer index

if reliableCounterR >= fixBufferSize
    fallbackR = mean(fixBufferR);
elseif reliableCounterR > 0
    fallbackR = mean(fixBufferR(1:double(reliableCounterR)));
else
    fallbackR = defaultR;
end

if reliableCounterG >= fixBufferSize
    fallbackPR = mean(fixBufferPR);
elseif reliableCounterG > 0
    fallbackPR = mean(fixBufferPR(1:double(reliableCounterG)));
else
    fallbackPR = defaultPR;
end

inputRUsable = isfinite(inputR) && inputR > minUsableR && inputR < maxUsableR;
lowConfidenceRJumpLimit = max(minLowConfidenceRJump, lowConfidenceRJumpRatio * max(abs(fallbackR), defaultR));
highConfidenceRJumpLimit = max(minHighConfidenceRJump, highConfidenceRJumpRatio * max(abs(fallbackR), defaultR));
inputRUsableLowConfidence = inputRUsable && abs(inputR - fallbackR) <= lowConfidenceRJumpLimit;
inputRUsableHighConfidence = inputRUsable && ...
    (reliableCounterR == 0 || abs(inputR - fallbackR) <= highConfidenceRJumpLimit);
rShouldUpdateHistory = false;
prShouldUpdateHistory = false;

if outputConfidenceR < confidenceThresholdR || confidenceR < confidenceThresholdR % fix the R and PR value
    fixedR = fallbackR;
    if inputRUsableLowConfidence
        confidenceBlend = min(max(confidenceR, single(0)), single(1));
        fixedR = fallbackR * (single(1) - confidenceBlend) + inputR * confidenceBlend;
    end
else % keep the original value
    if inputRUsableHighConfidence
        fixedR = inputR;
        rShouldUpdateHistory = true;
    else
        fixedR = fallbackR;
        outputConfidenceR = min(outputConfidenceR, confidenceThresholdR);
    end
end

if confidenceG < confidenceThresholdPR % fix the R and PR value
    if inputPRUsable && confidenceG > confidenceFloorPR
        prBlend = (confidenceG - confidenceFloorPR) / (confidenceThresholdPR - confidenceFloorPR);
        prBlend = min(max(prBlend, single(0)), single(1));
        fixedPR = fallbackPR * (single(1) - prBlend) + inputPR * prBlend;
    elseif inputPRUsable && reliableCounterG == 0
        fixedPR = inputPR;
    else
        fixedPR = fallbackPR;
    end
else % keep the original value
    if inputPRUsable
        fixedPR = inputPR;
        prShouldUpdateHistory = true;
    else
        fixedPR = fallbackPR;
    end
end

% update the buffer for fix
if rShouldUpdateHistory %|| outputCounter <= fixBufferSize
    reliableCounterR = reliableCounterR + 1;
    fixBufferR(fixBufferIndexR) = fixedR;
    % fixBufferR = [fixBufferR(2:fixBufferSize);fixedR];
end
if prShouldUpdateHistory %|| outputCounter <= fixBufferSize
    reliableCounterG = reliableCounterG + 1;
    fixBufferPR(fixBufferIndexG) = fixedPR;
    % fixBufferPR = [fixBufferPR(2:fixBufferSize);fixedPR];
end
outputR = fixedR;
outputPR = fixedPR;

end
