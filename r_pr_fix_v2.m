function [outputR,outputPR,outputConfidenceR] = r_pr_fix_v2(inputR, inputPR, confidenceR, confidenceG, outputCounter)

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

if outputConfidenceR > confidenceThresholdR
    reliableCounterR = reliableCounterR + 1;
end

if confidenceG > confidenceThresholdPR
    reliableCounterG = reliableCounterG + 1;
end

if ~prSeeded && inputPR > 0 && confidenceG > confidenceFloorPR
    fixBufferPR(:) = inputPR;
    reliableCounterG = max(reliableCounterG, uint32(1));
    prSeeded = true;
end

fixBufferIndexR = mod(reliableCounterR-1, fixBufferSize) + 1; % Circular buffer index
fixBufferIndexG = mod(reliableCounterG-1, fixBufferSize) + 1; % Circular buffer index

if outputConfidenceR < confidenceThresholdR || confidenceR < confidenceThresholdR % fix the R and PR value
    if reliableCounterR >= fixBufferSize
        fixedR = mean(fixBufferR);
        if isfinite(inputR) && inputR > 0
            fixedR = fixedR*(1-confidenceR) + inputR * confidenceR;
        end
    elseif reliableCounterR > 1
        fixedR = mean(fixBufferR(1:reliableCounterR-1));
        if isfinite(inputR) && inputR > 0
            fixedR = fixedR*(1-confidenceR) + inputR * confidenceR;
        end
    else
        if isfinite(inputR) && inputR > 0
            fixedR = defaultR * (1-confidenceR) + inputR * confidenceR;
        else
            fixedR = defaultR;
        end
    end
else % keep the original value
    fixedR = inputR;
end

if confidenceG < confidenceThresholdPR % fix the R and PR value
    if reliableCounterG > fixBufferSize
        fallbackPR = mean(fixBufferPR);
    elseif reliableCounterG > 1
        fallbackPR = mean(fixBufferPR(1:reliableCounterG-1));
    else
        fallbackPR = defaultPR;
    end

    if inputPR > 0 && confidenceG > confidenceFloorPR
        prBlend = (confidenceG - confidenceFloorPR) / (confidenceThresholdPR - confidenceFloorPR);
        prBlend = min(max(prBlend, single(0)), single(1));
        fixedPR = fallbackPR * (single(1) - prBlend) + inputPR * prBlend;
    elseif inputPR > 0 && reliableCounterG == 0
        fixedPR = inputPR;
    else
        fixedPR = fallbackPR;
    end
else % keep the original value
    fixedPR = inputPR;
end

% update the buffer for fix
if outputConfidenceR >= confidenceThresholdR %|| outputCounter <= fixBufferSize 
    fixBufferR(fixBufferIndexR) = fixedR;
    % fixBufferR = [fixBufferR(2:fixBufferSize);fixedR];
end
if confidenceG >= confidenceThresholdPR %|| outputCounter <= fixBufferSize 
    fixBufferPR(fixBufferIndexG) = fixedPR;
    % fixBufferPR = [fixBufferPR(2:fixBufferSize);fixedPR];
end
outputR = fixedR;
outputPR = fixedPR;

end
