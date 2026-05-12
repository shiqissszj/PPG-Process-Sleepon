function [outputR, outputPR, outputSQI, outputConfidenceR, outputConfidenceG] = r_pr_calculation(windowR, windowIR, windowG, samplingRate, outputCounter, bodyMove)

coder.inline('never')

% Parameters for period identification
pr1 = single(0.2);
pr2 = single(0.8);
confidence = single(1);

windowSize = single(length(windowR));
windowSampleCount = length(windowR);
stepSize = double(samplingRate);
maxExpandedCount = windowSampleCount * 2;

persistent previousConfidenceG;
persistent previousPRG;
persistent previousPRGValidCount;
persistent expandedGreenInputBuffer;
persistent trackedPR;
persistent trackedConfidence;

if outputCounter == 1
    % initialize
    previousConfidenceG = single(0.6);
    previousPRG = zeros(windowSampleCount, 1, 'single');
    previousPRGValidCount = uint32(0);
    expandedGreenInputBuffer = zeros(maxExpandedCount, 1, 'single');
    trackedPR = single(-1);
    trackedConfidence = single(0);
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
if isempty(expandedGreenInputBuffer)
    expandedGreenInputBuffer = zeros(maxExpandedCount, 1, 'single');
end
if isempty(trackedPR)
    trackedPR = single(-1);
end
if isempty(trackedConfidence)
    trackedConfidence = single(0);
end

[dcR, dcIR, ~, acGRaw, acR, acIR, acG, ppgFilteredR, ppgFilteredIR, ppgFilteredG, ~, outlierNumG, delay1, delay2] = ...
    preprocess_ppg_window_shared(windowR, windowIR, windowG, samplingRate);

% Preserve the legacy PR behavior: peak detection uses an expanded green
% signal built from a rolling history plus the current aligned AC green.
validHistoryCount = double(previousPRGValidCount);
expandedCount = validHistoryCount + windowSampleCount;

if validHistoryCount > 0
    historyStartIdx = windowSampleCount - validHistoryCount + 1;
    for idx = 1:validHistoryCount
        expandedGreenInputBuffer(idx) = previousPRG(historyStartIdx + idx - 1);
    end
end
for idx = 1:windowSampleCount
    expandedGreenInputBuffer(validHistoryCount + idx) = acGRaw(idx);
end
[ppgExpandedG, ~] = ac_filter(expandedGreenInputBuffer(1:expandedCount));
ppgNormalizedG = ac_normalize(ppgExpandedG);
for idx = 1:(windowSampleCount - stepSize)
    previousPRG(idx) = previousPRG(idx + stepSize);
end
for idx = 1:stepSize
    previousPRG(windowSampleCount - stepSize + idx) = acGRaw(idx);
end
previousPRGValidCount = min(previousPRGValidCount + uint32(stepSize), uint32(windowSampleCount));

% PR calculation
[~, peakLocG0] = find_peaks(ppgNormalizedG, single(samplingRate)*pr1, single(-inf), single(0.025));
if length(peakLocG0) < 2
    confidence = single(0);
    PR = single(-1);
else
    deltaPR = mean_peak_interval(peakLocG0);
    [~, peakLocG1] = find_peaks(ppgNormalizedG,single(deltaPR*pr2),single(0.1), single(0));
    if length(peakLocG1) < 2
        confidence = single(0);
        PR = single(-1);
    else
        PR = estimate_tail_tracked_pr(peakLocG1, ppgExpandedG, single(samplingRate), validHistoryCount, trackedPR);
        PR = refine_pr_local_autocorr(ppgExpandedG, single(samplingRate), PR, trackedPR);
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
else
    outputConfidenceG = single(0);
end

outputConfidenceR = confidence;
% outputConfidenceR = 1;

if outputConfidenceG > 0.6
    outputConfidenceG = outputConfidenceG * 0.5 + previousConfidenceG * 0.5;
else
    outputConfidenceG = min(outputConfidenceG, previousConfidenceG);
end
previousConfidenceG = outputConfidenceG;
[trackedPR, trackedConfidence] = update_tracked_pr_state(trackedPR, trackedConfidence, PR, outputConfidenceG, bodyMove);

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

inputCount = numel(inputValues);

if inputCount <= 2
    outputValues = inputValues;
    return
end

sortedValues = sort_values_for_median(inputValues);
centerValue = median_of_sorted_values(sortedValues, inputCount);

absDeviation = zeros(size(inputValues), 'single');
for idx = 1:inputCount
    deviation = inputValues(idx) - centerValue;
    if deviation < 0
        deviation = -deviation;
    end
    absDeviation(idx) = deviation;
end

sortedDeviation = sort_values_for_median(absDeviation);
madValue = median_of_sorted_values(sortedDeviation, inputCount);

if madValue <= single(1e-6)
    outputValues = inputValues;
    return
end

thresholdValue = single(3.0) * madValue;
keepCount = 0;
outputValues = zeros(size(inputValues), 'single');
for idx = 1:inputCount
    if absDeviation(idx) <= thresholdValue
        keepCount = keepCount + 1;
        outputValues(keepCount) = inputValues(idx);
    end
end

if keepCount > 0
    outputValues = outputValues(1:keepCount);
else
    outputValues = inputValues;
end
end

function outputValue = mean_peak_interval(peakLocs)

intervalCount = length(peakLocs) - 1;
intervalSum = single(0);
for idx = 1:intervalCount
    intervalSum = intervalSum + (peakLocs(idx + 1) - peakLocs(idx));
end
outputValue = intervalSum / single(intervalCount);
end

function outputPR = estimate_tail_tracked_pr(peakLocs, inputSignal, samplingRate, validHistoryCount, trackedPR)

intervalCount = length(peakLocs) - 1;
intervalBuffer = zeros(49, 1, 'single');
tailIntervalCount = 0;
currentWindowStart = single(validHistoryCount) + single(1);

for idx = 1:intervalCount
    if peakLocs(idx + 1) >= currentWindowStart
        tailIntervalCount = tailIntervalCount + 1;
        intervalBuffer(tailIntervalCount) = peakLocs(idx + 1) - peakLocs(idx);
    end
end

if tailIntervalCount == 0
    for idx = 1:intervalCount
        intervalBuffer(idx) = peakLocs(idx + 1) - peakLocs(idx);
    end
    tailIntervalCount = intervalCount;
end

if tailIntervalCount > 4
    for idx = 1:4
        intervalBuffer(idx) = intervalBuffer(tailIntervalCount - 4 + idx);
    end
    tailIntervalCount = 4;
end

sortedIntervals = sort_values_for_median(intervalBuffer(1:tailIntervalCount));
centerInterval = median_of_sorted_values(sortedIntervals, tailIntervalCount);

robustBuffer = zeros(49, 1, 'single');
robustCount = 0;
for idx = 1:tailIntervalCount
    if intervalBuffer(idx) >= centerInterval * single(0.75) && ...
            intervalBuffer(idx) <= centerInterval * single(1.25)
        robustCount = robustCount + 1;
        robustBuffer(robustCount) = intervalBuffer(idx);
    end
end

if robustCount == 0
    for idx = 1:tailIntervalCount
        robustBuffer(idx) = intervalBuffer(idx);
    end
    robustCount = tailIntervalCount;
end

if trackedPR > 0
    expectedInterval = single(60) * samplingRate / trackedPR;
    trackedBuffer = zeros(49, 1, 'single');
    trackedCount = 0;
    for idx = 1:robustCount
        if robustBuffer(idx) >= expectedInterval * single(0.8) && ...
                robustBuffer(idx) <= expectedInterval * single(1.2)
            trackedCount = trackedCount + 1;
            trackedBuffer(trackedCount) = robustBuffer(idx);
        end
    end
    if trackedCount > 0
        for idx = 1:trackedCount
            robustBuffer(idx) = trackedBuffer(idx);
        end
        robustCount = trackedCount;
    end
end

sortedRobustIntervals = sort_values_for_median(robustBuffer(1:robustCount));
medianInterval = median_of_sorted_values(sortedRobustIntervals, robustCount);
if ~isfinite(medianInterval) || medianInterval <= 0
    outputPR = single(-1);
    return
end

coarsePR = single(60) * samplingRate / medianInterval;
outputPR = coarsePR;
end

function sortedValues = sort_values_for_median(inputValues)

inputCount = numel(inputValues);
sortedValues = inputValues;

for idx = 2:inputCount
    currentValue = sortedValues(idx);
    insertIdx = idx - 1;

    while insertIdx >= 1 && sortedValues(insertIdx) > currentValue
        sortedValues(insertIdx + 1) = sortedValues(insertIdx);
        insertIdx = insertIdx - 1;
    end

    sortedValues(insertIdx + 1) = currentValue;
end
end

function outputValue = median_of_sorted_values(sortedValues, inputCount)

middleIdx = floor(double(inputCount + 1) / 2);
if mod(inputCount, 2) == 1
    outputValue = sortedValues(middleIdx);
else
    outputValue = (sortedValues(middleIdx) + sortedValues(middleIdx + 1)) * single(0.5);
end
end

function outputValue = peak_to_peak(inputSignal)

outputValue = max(inputSignal) - min(inputSignal);
end

function refinedPR = refine_pr_local_autocorr(inputSignal, samplingRate, coarsePR, trackedPR)

if coarsePR <= 0
    refinedPR = single(-1);
    return
end

candidateLag = single(60) * samplingRate / coarsePR;
lagMarginRatio = single(0.08);
if trackedPR > 0
    lagMarginRatio = single(0.06);
end

minLag = max(2, round(candidateLag * (single(1) - lagMarginRatio)));
maxLag = max(minLag + 1, round(candidateLag * (single(1) + lagMarginRatio)));
[maxCorrValue, corrValues] = a_corr(inputSignal, minLag, maxLag);

if isempty(corrValues) || maxCorrValue < single(0.35)
    refinedPR = coarsePR;
    return
end

bestIndex = 1;
bestValue = corrValues(1);
for idx = 2:length(corrValues)
    if corrValues(idx) > bestValue
        bestValue = corrValues(idx);
        bestIndex = idx;
    end
end

refinedLag = single(minLag + bestIndex - 1);
candidateRefinedPR = single(60) * samplingRate / refinedLag;

if trackedPR > 0 && abs(candidateRefinedPR - trackedPR) > abs(coarsePR - trackedPR) + single(4) && ...
        maxCorrValue < single(0.55)
    refinedPR = coarsePR;
    return
end

refineBlend = single(0.25) + single(0.35) * clamp01((maxCorrValue - single(0.35)) / single(0.25));
refinedPR = coarsePR * (single(1) - refineBlend) + candidateRefinedPR * refineBlend;
end

function [trackedPR, trackedConfidence] = update_tracked_pr_state(trackedPR, trackedConfidence, measuredPR, confidenceG, bodyMove)

updateThreshold = single(0.45);
if measuredPR > 0 && measuredPR < 50
    updateThreshold = single(0.60);
end

if measuredPR > 0 && confidenceG > updateThreshold
    if trackedPR < 0
        trackedPR = measuredPR;
    else
        jumpLimit = single(10);
        if bodyMove > 10
            jumpLimit = single(16);
        end

        distanceToTrack = abs(measuredPR - trackedPR);
        distancePenalty = clamp01(distanceToTrack / jumpLimit);
        trackBlend = single(0.30) - single(0.18) * distancePenalty;
        if bodyMove > 10
            trackBlend = trackBlend * single(0.8);
        end
        if distanceToTrack > jumpLimit * single(1.5) && confidenceG < single(0.75)
            trackBlend = trackBlend * single(0.5);
        end
        trackBlend = min(max(trackBlend, single(0.08)), single(0.30));
        trackedPR = trackedPR * (single(1) - trackBlend) + measuredPR * trackBlend;
    end
    trackedConfidence = trackedConfidence * single(0.55) + confidenceG * single(0.45);
elseif confidenceG < single(0.20)
    trackedConfidence = trackedConfidence * single(0.7);
    if trackedConfidence < single(0.15)
        trackedPR = single(-1);
    end
else
    trackedConfidence = trackedConfidence * single(0.8) + confidenceG * single(0.2);
end
end

function outputValue = clamp01(inputValue)

outputValue = min(max(inputValue, single(0)), single(1));
end
