function [outputFlag, outputPR, outputSpO2, outputPI, confidenceR, rawR, fixedRDebug, smoothedRDebug, classicRDebug, redAcDcDebug, irAcDcDebug, qualityDebug] = ppg_process_val(inputSampleR,inputSampleIR,inputSampleG,inputCounter,bodyMove)

coder.inline('never')

% paremeters
samplingRate = uint32(50); % Sampling rate in Hz
windowLength = 3; % Window length in seconds
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate; % 1 second step

% claim the static local buffer and variables
persistent windowR;
persistent windowIR;
persistent windowG;
% persistent inputCounter;
persistent outputCounter;
persistent beginCalculation;

persistent bufferR;
persistent bufferIR;
persistent bufferG;

if isempty(bufferR) || isempty(bufferIR) || isempty(bufferG)
    bufferR = zeros(stepSize, 1, 'single');
    bufferIR = zeros(stepSize, 1, 'single');
    bufferG = zeros(stepSize, 1, 'single');
end

% initialize the static local buffer
if isempty(windowR)
    windowR = zeros(windowSize,1,'single');
end
if isempty(windowIR)
    windowIR = zeros(windowSize,1,'single');
end
if isempty(windowG)
    windowG = zeros(windowSize,1,'single');
end
% if isempty(inputCounter)
%     inputCounter = 0;
% end
if isempty(outputCounter)
    outputCounter = uint32(0);
end
if isempty(beginCalculation)
    beginCalculation = false;
end

if inputCounter == 1
    % initialize
    windowR = single(zeros(windowSize,1));
    windowIR = single(zeros(windowSize,1));
    windowG = single(zeros(windowSize,1));
    outputCounter = uint32(0);
    beginCalculation = false;
end

% save the input sample in the buffer
bufferIdx = mod(inputCounter-1, stepSize) + 1;
bufferR(bufferIdx) = inputSampleR;
bufferIR(bufferIdx) = inputSampleIR;
bufferG(bufferIdx) = inputSampleG;

% the calculation begins only if the buffer is full
if inputCounter >= windowSize
    beginCalculation = true;
elseif mod(inputCounter,stepSize) == 0
    windowR = [windowR(stepSize+1:end); bufferR];
    windowIR = [windowIR(stepSize+1:end); bufferIR];
    windowG = [windowG(stepSize+1:end); bufferG];
end

% calculation the output every stepSize samples
if beginCalculation && mod(inputCounter,stepSize) == 0
    outputFlag = true;
else
    outputFlag = false;
end

if outputFlag
    outputCounter =  outputCounter + 1;

    % update the process window
    windowR = [windowR(stepSize+1:end); bufferR];
    windowIR = [windowIR(stepSize+1:end); bufferIR];
    windowG = [windowG(stepSize+1:end); bufferG];

    % calculate the raw R and PR value as well as the confidence
    [rawR, PR, PI, confidenceR, confidenceG, classicRDebug, redAcDcDebug, irAcDcDebug, qualityDebug] = r_pr_calculation_val(windowR, windowIR, windowG, samplingRate, outputCounter, bodyMove);

    % fix the R and PR value based on the confidence
    [fixedR, fixedPR, confidenceR] = r_pr_fix(rawR,PR,confidenceR,confidenceG,outputCounter);

    % smooth the R and PR value
    smoothedR = r_smoothing(fixedR,outputCounter);
    smoothedPR = pr_smoothing(fixedPR,outputCounter);
    fixedRDebug = fixedR;
    smoothedRDebug = smoothedR;

    outputPR = round(smoothedPR);
    outputSpO2 = calculate_spo2(smoothedR);
    outputPI = PI;
else
    outputPR = single(0);
    outputSpO2 = single(0);
    % linearSpO2 = single(NaN);
    outputPI = single(0);
    confidenceR = single(0);
    rawR = single(0);
    fixedRDebug = single(0);
    smoothedRDebug = single(0);
    classicRDebug = single(0);
    redAcDcDebug = single(0);
    irAcDcDebug = single(0);
    qualityDebug = single(zeros(1, 21));
end
end
