function result = calculate_beat_level_r_series_beat30(ppgR, ppgIR, ppgG, samplingRate, outputSamples, windowSeconds, calibrationModel)
% Beat-level red/IR ratio-of-ratios feature for SpO2 validation.
%
% Green is used only to locate beats. Each valid beat produces one
% R = (ACred/DCred)/(ACir/DCir). Each output window uses the median of the
% recent beat R values. The default windowSeconds is 30.

if nargin < 6 || isempty(windowSeconds)
    windowSeconds = 30;
end
if nargin < 7
    calibrationModel = [];
end

ppgR = double(ppgR(:));
ppgIR = double(ppgIR(:));
ppgG = double(ppgG(:));
outputSamples = double(outputSamples(:));
samplingRate = double(samplingRate);

[pulseR, ~] = diagnostic_pulse_filter_beat30(ppgR, samplingRate);
[pulseIR, ~] = diagnostic_pulse_filter_beat30(ppgIR, samplingRate);
[pulseG, ~] = diagnostic_pulse_filter_beat30(ppgG, samplingRate);

greenPeaks = find_green_peaks_for_beats_beat30(pulseG, samplingRate);
[beatCenter, beatR, beatRedPI, beatIRPI, beatGreenPI, beatValid] = ...
    build_beat_features_beat30(ppgR, ppgIR, ppgG, pulseR, pulseIR, pulseG, greenPeaks, samplingRate);

windowCount = numel(outputSamples);
result.r = nan(windowCount, 1);
result.spo2 = nan(windowCount, 1);
result.redPI = nan(windowCount, 1);
result.irPI = nan(windowCount, 1);
result.greenPI = nan(windowCount, 1);
result.beatCount = zeros(windowCount, 1);
result.totalBeatCount = zeros(windowCount, 1);
result.validBeatRatio = nan(windowCount, 1);

windowSamples = round(windowSeconds * samplingRate);

for idx = 1:windowCount
    endSample = outputSamples(idx);
    startSample = max(1, endSample - windowSamples + 1);
    inWindow = beatCenter >= startSample & beatCenter <= endSample;
    validInWindow = inWindow & beatValid & isfinite(beatR);

    result.beatCount(idx) = sum(validInWindow);
    result.totalBeatCount(idx) = sum(inWindow);
    if result.totalBeatCount(idx) > 0
        result.validBeatRatio(idx) = result.beatCount(idx) / result.totalBeatCount(idx);
    end

    if result.beatCount(idx) >= max(3, floor(windowSeconds / 2))
        result.r(idx) = finite_median_beat30(beatR(validInWindow));
        result.redPI(idx) = finite_median_beat30(beatRedPI(validInWindow));
        result.irPI(idx) = finite_median_beat30(beatIRPI(validInWindow));
        result.greenPI(idx) = finite_median_beat30(beatGreenPI(validInWindow));
    end
end

result.spo2 = calculate_spo2_beat30(result.r, calibrationModel);
result.beatCenter = beatCenter;
result.beatR = beatR;
result.beatRedPI = beatRedPI;
result.beatIRPI = beatIRPI;
result.beatGreenPI = beatGreenPI;
result.beatValid = beatValid;
result.greenPeaks = greenPeaks;
end

function [pulse, baseline] = diagnostic_pulse_filter_beat30(inputSignal, samplingRate)

baselineWindow = max(3, round(1.8 * samplingRate));
smoothWindow = max(1, round(0.08 * samplingRate));
if mod(smoothWindow, 2) == 0
    smoothWindow = smoothWindow + 1;
end

baseline = movmean(inputSignal, baselineWindow, 'Endpoints', 'shrink');
pulse = inputSignal - baseline;
pulse = movmean(pulse, smoothWindow, 'Endpoints', 'shrink');
end

function peaks = find_green_peaks_for_beats_beat30(pulseG, samplingRate)

scale = robust_percentile_range_beat30(pulseG, 5, 95);
if ~isfinite(scale) || scale <= 0
    scale = max(abs(pulseG));
end
if ~isfinite(scale) || scale <= 0
    peaks = zeros(0, 1);
    return
end

normalizedG = pulseG / scale;
minDistance = max(1, round(0.35 * samplingRate));
minHeight = max(0.03, 0.15 * robust_percentile_range_beat30(normalizedG, 50, 90));

positivePeaks = find_local_peaks_with_distance_beat30(normalizedG, minDistance, minHeight);
negativePeaks = find_local_peaks_with_distance_beat30(-normalizedG, minDistance, minHeight);

if peak_train_score_beat30(negativePeaks, samplingRate) > peak_train_score_beat30(positivePeaks, samplingRate)
    peaks = negativePeaks;
else
    peaks = positivePeaks;
end
end

function peaks = find_local_peaks_with_distance_beat30(inputSignal, minDistance, minHeight)

candidateCount = 0;
candidateLocs = zeros(numel(inputSignal), 1);
candidateValues = zeros(numel(inputSignal), 1);

for idx = 2:(numel(inputSignal) - 1)
    if inputSignal(idx) > inputSignal(idx - 1) && ...
            inputSignal(idx) >= inputSignal(idx + 1) && ...
            inputSignal(idx) > minHeight
        candidateCount = candidateCount + 1;
        candidateLocs(candidateCount) = idx;
        candidateValues(candidateCount) = inputSignal(idx);
    end
end

if candidateCount == 0
    peaks = zeros(0, 1);
    return
end

candidateLocs = candidateLocs(1:candidateCount);
candidateValues = candidateValues(1:candidateCount);
acceptedLocs = zeros(candidateCount, 1);
acceptedValues = zeros(candidateCount, 1);
acceptedCount = 0;

for idx = 1:candidateCount
    loc = candidateLocs(idx);
    value = candidateValues(idx);
    if acceptedCount == 0 || loc - acceptedLocs(acceptedCount) > minDistance
        acceptedCount = acceptedCount + 1;
        acceptedLocs(acceptedCount) = loc;
        acceptedValues(acceptedCount) = value;
    elseif value > acceptedValues(acceptedCount)
        acceptedLocs(acceptedCount) = loc;
        acceptedValues(acceptedCount) = value;
    end
end

peaks = acceptedLocs(1:acceptedCount);
end

function score = peak_train_score_beat30(peaks, samplingRate)

peakCount = numel(peaks);
if peakCount < 2
    score = peakCount;
    return
end

intervals = diff(peaks(:)) / samplingRate;
validIntervals = intervals(intervals >= 0.35 & intervals <= 2.0);
if isempty(validIntervals)
    score = 0;
    return
end

intervalMean = mean(validIntervals);
if intervalMean <= 0
    intervalCv = 1;
else
    intervalCv = std(validIntervals) / intervalMean;
end

score = peakCount * (numel(validIntervals) / numel(intervals)) - 2 * intervalCv;
end

function [beatCenter, beatR, beatRedPI, beatIRPI, beatGreenPI, beatValid] = ...
    build_beat_features_beat30(ppgR, ppgIR, ppgG, pulseR, pulseIR, pulseG, peaks, samplingRate)

beatCount = max(0, numel(peaks) - 2);
beatCenter = nan(beatCount, 1);
beatR = nan(beatCount, 1);
beatRedPI = nan(beatCount, 1);
beatIRPI = nan(beatCount, 1);
beatGreenPI = nan(beatCount, 1);
beatValid = false(beatCount, 1);

for idx = 2:(numel(peaks) - 1)
    outputIdx = idx - 1;
    left = max(1, round((peaks(idx - 1) + peaks(idx)) / 2));
    right = min(numel(ppgR), round((peaks(idx) + peaks(idx + 1)) / 2));
    if right <= left
        continue
    end

    periodSamples = peaks(idx + 1) - peaks(idx - 1);
    periodSeconds = periodSamples / (2 * samplingRate);
    if periodSeconds < 0.35 || periodSeconds > 2.0
        continue
    end

    beatRange = left:right;
    redDc = finite_median_beat30(ppgR(beatRange));
    irDc = finite_median_beat30(ppgIR(beatRange));
    greenDc = finite_median_beat30(ppgG(beatRange));
    redAc = robust_percentile_range_beat30(pulseR(beatRange), 5, 95);
    irAc = robust_percentile_range_beat30(pulseIR(beatRange), 5, 95);
    greenAc = robust_percentile_range_beat30(pulseG(beatRange), 5, 95);

    redPI = redAc / max(abs(redDc), eps);
    irPI = irAc / max(abs(irDc), eps);
    greenPI = greenAc / max(abs(greenDc), eps);
    currentR = redPI / max(abs(irPI), eps);

    beatCenter(outputIdx) = peaks(idx);
    beatR(outputIdx) = currentR;
    beatRedPI(outputIdx) = redPI;
    beatIRPI(outputIdx) = irPI;
    beatGreenPI(outputIdx) = greenPI;
    beatValid(outputIdx) = isfinite(currentR) && currentR > 0 && currentR < 3 && ...
        isfinite(redPI) && isfinite(irPI) && isfinite(greenPI) && ...
        redPI > 1e-4 && irPI > 1e-4 && greenPI > 1e-4;
end
end

function output = finite_median_beat30(inputValues)

inputValues = inputValues(isfinite(inputValues));
if isempty(inputValues)
    output = NaN;
else
    output = median(inputValues);
end
end

function output = robust_percentile_range_beat30(inputValues, lowPercentile, highPercentile)

inputValues = sort(inputValues(isfinite(inputValues)));
if isempty(inputValues)
    output = NaN;
    return
end

lowValue = percentile_from_sorted_beat30(inputValues, lowPercentile);
highValue = percentile_from_sorted_beat30(inputValues, highPercentile);
output = highValue - lowValue;
end

function output = percentile_from_sorted_beat30(sortedValues, percentile)

count = numel(sortedValues);
if count == 1
    output = sortedValues(1);
    return
end

position = 1 + (count - 1) * percentile / 100;
lowerIndex = floor(position);
upperIndex = ceil(position);
weight = position - lowerIndex;
lowerIndex = max(1, min(count, lowerIndex));
upperIndex = max(1, min(count, upperIndex));
output = sortedValues(lowerIndex) * (1 - weight) + sortedValues(upperIndex) * weight;
end
