function [outputR, outputPR, outputSQI, outputConfidenceR, outputConfidenceG] = r_pr_calculation(windowR, windowIR, windowG, samplingRate, outputCounter, bodyMove)

coder.inline('never')

% Parameters for period identification
pr1 = single(0.2);
pr2 = single(0.8);
confidence = single(1);

windowSize = single(length(windowR));
windowSampleCount = length(windowR);
stepSize = double(samplingRate);

persistent previousConfidenceG;
persistent previousPRG;
persistent previousPRGValidCount;

if outputCounter == 1
    % initialize
    previousConfidenceG = single(0.6);
    previousPRG = zeros(windowSampleCount, 1, 'single');
    previousPRGValidCount = uint32(0);
end
if isempty(previousConfidenceG)
    previousConfidenceG = single(0.6);
end
if isempty(previousPRG)
    previousPRG = zeros(windowSampleCount, 1, 'single');
end
if isempty(previousPRGValidCount)
    previousPRGValidCount = uint32(0);
end

[dcR, dcIR, ~, acGRaw, acR, acIR, acG, ppgFilteredR, ppgFilteredIR, ppgFilteredG, ~, outlierNumG, delay1, delay2] = ...
    preprocess_ppg_window_shared(windowR, windowIR, windowG, samplingRate);

% Preserve the legacy PR behavior: peak detection uses an expanded green
% signal built from a rolling history plus the current aligned AC green.
validHistoryCount = double(previousPRGValidCount);
if validHistoryCount > 0
    ppgHistoryG = previousPRG(end-validHistoryCount+1:end);
    ppgExpandedInputG = [ppgHistoryG; acGRaw];
else
    ppgExpandedInputG = acGRaw;
end
[ppgExpandedG, ~] = ac_filter(ppgExpandedInputG);
ppgNormalizedG = ac_normalize(ppgExpandedG);
previousPRG = [previousPRG(stepSize + 1:end); acGRaw(1:stepSize)];
previousPRGValidCount = min(previousPRGValidCount + uint32(stepSize), uint32(windowSampleCount));

% PR calculation
[~, peakLocG0] = find_peaks(ppgNormalizedG, single(samplingRate)*pr1, single(-inf), single(0.025));
if length(peakLocG0) < 2
    confidence = single(0);
    PR = single(-1);
else
    deltaPR = mean(diff(peakLocG0));
    [~, peakLocG1] = find_peaks(ppgNormalizedG,single(deltaPR*pr2),single(0.1), single(0));
    if length(peakLocG1) < 2
        confidence = single(0);
        PR = single(-1);
    else
        greenPeakDiff1 = diff(peakLocG1);
        deltaPR2 = remove_outliers_for_codegen(greenPeakDiff1);
        PR = single(60/(mean(deltaPR2)/single(samplingRate)));  %BPM
    end
    if length(peakLocG1) < 2 || PR < 35
        confidence = single(0);
        PR = single(-1);
    end
end

% PI calculaton
PI = peak_to_peak(ppgFilteredR)/mean(dcR);

[outputR, isValidR] = calculate_r_protected(ppgFilteredG, ppgFilteredR, ppgFilteredIR, dcR, dcIR);

outputPR = single(PR);
outputPI = PI;

% Confidence calculation
% Comment the following code to disable the signal calculation

% Obtain SQI for confidence calculation
xcorrR_G = sum(ppgFilteredG .* ppgFilteredR)/(sqrt(sum(ppgFilteredR .^2))*sqrt(sum(ppgFilteredG .^2)));
xcorrIR_G = sum(ppgFilteredG .* ppgFilteredIR)/(sqrt(sum(ppgFilteredIR .^2))*sqrt(sum(ppgFilteredG .^2)));
xcorrR_IR = sum(ppgFilteredIR .* ppgFilteredR)/(sqrt(sum(ppgFilteredIR .^2))*sqrt(sum(ppgFilteredR .^2)));

outputSQI = [xcorrR_G,xcorrIR_G,xcorrR_IR,0,0,0];

usedSampleRatio = (windowSize - outlierNumG - single(max(abs(delay1), abs(delay2)))) / windowSize;
usedSampleRatio = clamp01(usedSampleRatio);

% Confidence of Green light for the legacy PR path
outputConfidenceG = usedSampleRatio^2;

% Confidence of Red light / SpO2 path
validR = is_signal_valid(ppgFilteredR);
validIR = is_signal_valid(ppgFilteredIR);
validG = is_signal_valid(ppgFilteredG);
validChannelRatio = single(validG + validR + validIR) / single(3);
signalConfidence = (max(xcorrR_G,0) + max(xcorrIR_G,0) + max(xcorrR_IR,0)) / single(3);
spo2WindowConfidence = clamp01(single(0.25) + single(0.75) * signalConfidence * usedSampleRatio * validChannelRatio);

if ~isValidR || outputR <= 0
    confidence = single(0);
end

if confidence > 0
    confidence = clamp01(signalConfidence * (single(0.45) + single(0.55) * spo2WindowConfidence));
end

if xcorrR_G < 0.25 || xcorrIR_G < 0.25
    confidence = single(0);
elseif bodyMove > 20 && spo2WindowConfidence < 0.5
    confidence = confidence * single(0.4);
end

if PR > 0
    meanDeltaPeak = single(60) * single(samplingRate) / PR;
    [maxCorrValueR, corrValuesR]=a_corr(acR, round(meanDeltaPeak*0.9), round(meanDeltaPeak*1.1));
    [maxCorrValueIR, corrValuesIR]=a_corr(acIR, round(meanDeltaPeak*0.9), round(meanDeltaPeak*1.1));
    [maxCorrValueG, corrValuesG]=a_corr(acG, round(meanDeltaPeak*0.9), round(meanDeltaPeak*1.1));
    outputSQI([4,5,6]) = [maxCorrValueR,maxCorrValueIR,maxCorrValueG];

    lowLagIndex = min(max(round(meanDeltaPeak*0.1), 1), length(corrValuesG));
    lowLagCorrValueG = corrValuesG(lowLagIndex);

    greenCorrPenalty = single(1);
    if maxCorrValueG < 0.75
        greenCorrPenalty = greenCorrPenalty * max(maxCorrValueG / single(0.75), single(0.2));
    end
    if lowLagCorrValueG < 0.5
        greenCorrPenalty = greenCorrPenalty * max(lowLagCorrValueG / single(0.5), single(0.2));
    end

    % Startup windows are noisier after moving to 3 s. Use a soft penalty
    % instead of hard-zeroing the PR confidence so raw PR can still seed the
    % fix and smoothing stages.
    if outputCounter <= 8
        outputConfidenceG = outputConfidenceG * max(greenCorrPenalty, single(0.45));
    else
        outputConfidenceG = outputConfidenceG * greenCorrPenalty;
    end

    if maxCorrValueR < 0.25 || maxCorrValueIR < 0.25 || bodyMove > 15
        outputConfidenceG = outputConfidenceG * single(0.4);
    end
end

outputConfidenceR = confidence;
% outputConfidenceR = 1;

if outputConfidenceG > 0.6
    outputConfidenceG = outputConfidenceG * 0.5 + previousConfidenceG * 0.5;
else
    outputConfidenceG = min(outputConfidenceG, previousConfidenceG);
end
previousConfidenceG = outputConfidenceG;

end

function isValid = is_signal_valid(inputAC)

maxValue = max(inputAC);
minValue = min(inputAC);
rangeValue = maxValue - minValue;

isValid = rangeValue > single(1e-6);
end

function [outputR, isValid] = calculate_r_protected(ppgFilteredG, ppgFilteredR, ppgFilteredIR, dcR, dcIR)

N1 = sum(ppgFilteredG .* ppgFilteredR);
D1 = sum(ppgFilteredG .* ppgFilteredIR);
N2 = mean(dcIR);
D2 = mean(dcR);

guardD1 = single(1e-6) + single(1e-3) * mean(abs(ppgFilteredG .* ppgFilteredIR));
guardD2 = single(1e-6) + single(1e-3) * abs(D2);

isValid = isfinite(N1) && isfinite(D1) && isfinite(N2) && isfinite(D2) && ...
    abs(D1) > guardD1 && abs(D2) > guardD2;

if ~isValid
    outputR = single(NaN);
    return
end

outputR = (N1 * N2) / (D1 * D2);
isValid = isfinite(outputR);
if ~isValid
    outputR = single(NaN);
end
end

function outputValues = remove_outliers_for_codegen(inputValues)

if numel(inputValues) <= 2
    outputValues = inputValues;
    return
end

centerValue = median(inputValues);
absDeviation = abs(inputValues - centerValue);
madValue = median(absDeviation);

if madValue <= single(1e-6)
    outputValues = inputValues;
    return
end

keepMask = absDeviation <= single(3.0) * madValue;
if any(keepMask)
    outputValues = inputValues(keepMask);
else
    outputValues = inputValues;
end
end

function outputValue = peak_to_peak(inputSignal)

outputValue = max(inputSignal) - min(inputSignal);
end

function outputValue = clamp01(inputValue)

outputValue = min(max(inputValue, single(0)), single(1));
end
