clear;
clc;

% Verify whether the low Checkme SpO2 periods are visible in the PPG R
% features. This script is intentionally independent from SpO2_PR_main.m so
% that it can be reused while testing offset, R extraction, and filtering
% changes.

dataID = 1031;
samplingRate = 50;
windowLength = 3;
windowSize = windowLength * samplingRate;
stepSize = samplingRate;

% For the merged No31 file, keep sensor/reference rows on the same timestamp
% by default. Set this to false to use the get_filename offset rule.
useManualTimeOffset = true;
manualTimeOffset = 0;

lowSpo2Threshold = 90;
severeSpo2Threshold = 85;
minLowSegmentSeconds = 30;
mergeLowSegmentGapSeconds = 60;
zoomPaddingSeconds = 180;
maxLowSegmentPlots = 6;

% Experimental dual-track R settings:
% - stable/display track: existing ppg_process output, smoothedR -> estSpO2.
% - fast/event track: classic red/IR AC/DC R, short causal smoothing -> eventSpO2.
fastRMin = 0.15;
fastRMax = 1.80;
fastRSmoothingSeconds = 5;
fastRBaselineSeconds = 120;
eventSpO2Threshold = 90;
eventRDeltaThreshold = 0.12;
eventRRatioThreshold = 1.25;
eventConfirmSeconds = 5;
eventMergeGapSeconds = 10;
eventConfidenceThreshold = 0.55;
eventMaxMovement = 20;
eventRAgreementThreshold = 0.60;
eventQualityThreshold = 0.55;
eventSmoothedRDeltaThreshold = 0.02;
eventSmoothedRRatioThreshold = 1.04;
eventRedPIMin = 0.001;
eventIrPIMin = 0.001;
eventRedPIMax = 0.15;
eventIrPIMax = 0.30;

repoDir = fileparts(mfilename('fullpath'));
if ~isempty(repoDir)
    cd(repoDir);
end

[filename, defaultTimeOffset, drop_num_start, drop_num_end] = get_filename(dataID);
if useManualTimeOffset
    time_offset = manualTimeOffset;
else
    time_offset = defaultTimeOffset;
end

outputDir = fullfile(repoDir, "debug_outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end

opts = delimitedTextImportOptions("NumVariables", 11);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["timestamp", "dev_time", "ppg_r", "ppg_ir", "ppg_g", ...
    "checkme_SPO2", "checkme_HR", "go2sleep_SPO2", "go2sleep_HR", ...
    "movement", "localtime"];
opts.VariableTypes = repmat("string", 1, 11);
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, opts.VariableNames, "WhitespaceRule", "preserve");
opts = setvaropts(opts, opts.VariableNames, "EmptyFieldRule", "auto");

fprintf("Reading %s\n", filename);
data = readmatrix(filename, opts);
rowCount = size(data, 1);

sensorStart = drop_num_start - time_offset + 1;
sensorEnd = rowCount - drop_num_end - time_offset;
refStart = drop_num_start + 1;
refEnd = rowCount - drop_num_end;

if sensorStart < 1 || refStart < 1 || sensorEnd > rowCount || refEnd > rowCount || ...
        sensorStart > sensorEnd || refStart > refEnd
    error("Invalid row range. sensor=[%d,%d], ref=[%d,%d], rows=%d", ...
        sensorStart, sensorEnd, refStart, refEnd, rowCount);
end

sensor_data = str2double(data(sensorStart:sensorEnd, [3, 4, 5]));
bodyMove = str2double(data(sensorStart:sensorEnd, 10));
time_data = parse_local_time(data(sensorStart:sensorEnd, 11));

checkme_SPO2 = str2double(data(refStart:refEnd, 6));
checkme_PR = str2double(data(refStart:refEnd, 7));
go2sleep_SPO2 = str2double(data(refStart:refEnd, 8));
go2sleep_HR = str2double(data(refStart:refEnd, 9));

sampleCount = min([size(sensor_data, 1), numel(bodyMove), numel(time_data), ...
    numel(checkme_SPO2), numel(checkme_PR), numel(go2sleep_SPO2), numel(go2sleep_HR)]);
sensor_data = sensor_data(1:sampleCount, :);
bodyMove = bodyMove(1:sampleCount);
time_data = time_data(1:sampleCount);
checkme_SPO2 = checkme_SPO2(1:sampleCount);
checkme_PR = checkme_PR(1:sampleCount);
go2sleep_SPO2 = go2sleep_SPO2(1:sampleCount);
go2sleep_HR = go2sleep_HR(1:sampleCount);

ppg_r = sensor_data(:, 1);
ppg_ir = sensor_data(:, 2);
ppg_g = sensor_data(:, 3);

num_windows = floor((sampleCount - windowSize) / stepSize) + 1;
if num_windows <= 0
    error("Not enough samples for a %d-sample window.", windowSize);
end

windowIndex = zeros(num_windows, 1);
windowEndSample = zeros(num_windows, 1);
windowTime = NaT(num_windows, 1);

estSpO2 = zeros(num_windows, 1);
estPR = zeros(num_windows, 1);
rawR = zeros(num_windows, 1);
fixedR = zeros(num_windows, 1);
smoothedR = zeros(num_windows, 1);
confidenceR = zeros(num_windows, 1);

trueSpO2 = zeros(num_windows, 1);
truePR = zeros(num_windows, 1);
go2sleepSpO2Win = zeros(num_windows, 1);
go2sleepHRWin = zeros(num_windows, 1);
bodyMoveMean = zeros(num_windows, 1);
bodyMoveMax = zeros(num_windows, 1);

classicRPeakToPeak = zeros(num_windows, 1);
classicRRobust = zeros(num_windows, 1);
redPI = zeros(num_windows, 1);
irPI = zeros(num_windows, 1);
redIRDcRatio = zeros(num_windows, 1);

windowCounter = 0;
fprintf("Processing %d samples at %d Hz ...\n", sampleCount, samplingRate);
for i = 1:sampleCount
    [outputFlag, outputPR, outputSpO2, ~, confidence, rawRValue, fixedRValue, smoothedRValue] = ...
        process_sample_for_debug(single(ppg_r(i)), single(ppg_ir(i)), single(ppg_g(i)), ...
        uint32(i), single(bodyMove(i)));

    if outputFlag
        windowCounter = windowCounter + 1;
        winStart = i - windowSize + 1;
        oneSecondStart = i - stepSize + 1;

        rWindow = ppg_r(winStart:i);
        irWindow = ppg_ir(winStart:i);

        windowIndex(windowCounter) = windowCounter;
        windowEndSample(windowCounter) = i;
        windowTime(windowCounter) = time_data(i);

        estSpO2(windowCounter) = outputSpO2;
        estPR(windowCounter) = outputPR;
        rawR(windowCounter) = rawRValue;
        fixedR(windowCounter) = fixedRValue;
        smoothedR(windowCounter) = smoothedRValue;
        confidenceR(windowCounter) = confidence;

        trueSpO2(windowCounter) = positive_mode(checkme_SPO2(oneSecondStart:i));
        truePR(windowCounter) = positive_mode(checkme_PR(oneSecondStart:i));
        go2sleepSpO2Win(windowCounter) = positive_median(go2sleep_SPO2(oneSecondStart:i));
        go2sleepHRWin(windowCounter) = positive_median(go2sleep_HR(oneSecondStart:i));
        bodyMoveMean(windowCounter) = mean(bodyMove(oneSecondStart:i), "omitnan");
        bodyMoveMax(windowCounter) = max(bodyMove(oneSecondStart:i), [], "omitnan");

        [classicRPeakToPeak(windowCounter), classicRRobust(windowCounter), ...
            redPI(windowCounter), irPI(windowCounter), redIRDcRatio(windowCounter)] = ...
            raw_red_ir_features(rWindow, irWindow);
    end
end

windowIndex = windowIndex(1:windowCounter);
windowEndSample = windowEndSample(1:windowCounter);
windowTime = windowTime(1:windowCounter);
estSpO2 = estSpO2(1:windowCounter);
estPR = estPR(1:windowCounter);
rawR = rawR(1:windowCounter);
fixedR = fixedR(1:windowCounter);
smoothedR = smoothedR(1:windowCounter);
confidenceR = confidenceR(1:windowCounter);
trueSpO2 = trueSpO2(1:windowCounter);
truePR = truePR(1:windowCounter);
go2sleepSpO2Win = go2sleepSpO2Win(1:windowCounter);
go2sleepHRWin = go2sleepHRWin(1:windowCounter);
bodyMoveMean = bodyMoveMean(1:windowCounter);
bodyMoveMax = bodyMoveMax(1:windowCounter);
classicRPeakToPeak = classicRPeakToPeak(1:windowCounter);
classicRRobust = classicRRobust(1:windowCounter);
redPI = redPI(1:windowCounter);
irPI = irPI(1:windowCounter);
redIRDcRatio = redIRDcRatio(1:windowCounter);

% Dual-track experimental low-O2 detector. This keeps the existing display
% SpO2 untouched and adds a faster event channel based on red/IR only.
fastRawR = classicRRobust;
fastRForEvent = fastRawR;
fastRValidMask = isfinite(fastRForEvent) & fastRForEvent >= fastRMin & fastRForEvent <= fastRMax & ...
    bodyMoveMax <= eventMaxMovement;
fastRForEvent(~fastRValidMask) = NaN;
fastEventR = trailing_median(fastRForEvent, fastRSmoothingSeconds);
fastEventSpO2 = calculate_spo2(fastEventR);
fastRBaseline = trailing_median(fastEventR, fastRBaselineSeconds);
fastRDelta = fastEventR - fastRBaseline;
fastRRatio = fastEventR ./ fastRBaseline;
fastRRatio(~isfinite(fastRRatio) | fastRBaseline <= 0) = NaN;
lowO2FormulaCandidate = isfinite(fastEventSpO2) & fastEventSpO2 < eventSpO2Threshold & ...
    confidenceR >= eventConfidenceThreshold & bodyMoveMax <= eventMaxMovement;
lowO2FormulaEvent = confirmed_event_runs(lowO2FormulaCandidate, eventConfirmSeconds, eventMergeGapSeconds);
lowO2Candidate = isfinite(fastRRatio) & isfinite(fastRDelta) & ...
    fastRDelta >= eventRDeltaThreshold & fastRRatio >= eventRRatioThreshold & ...
    confidenceR >= eventConfidenceThreshold & bodyMoveMax <= eventMaxMovement;
lowO2Event = confirmed_event_runs(lowO2Candidate, eventConfirmSeconds, eventMergeGapSeconds);
fastRAgreement = safe_ratio(min(classicRPeakToPeak, classicRRobust), ...
    max(classicRPeakToPeak, classicRRobust));
fastRDeltaScore = clamp01_vector(fastRDelta / eventRDeltaThreshold);
fastRRatioScore = clamp01_vector((fastRRatio - 1) / (eventRRatioThreshold - 1));
fastRAgreementScore = clamp01_vector(fastRAgreement / eventRAgreementThreshold);
fastRPIScore = min(clamp01_vector(redPI / eventRedPIMin), clamp01_vector(irPI / eventIrPIMin));
fastRPIScore(redPI > eventRedPIMax | irPI > eventIrPIMax) = 0;
fastRConfidenceScore = clamp01_vector(confidenceR);
fastRMovementScore = clamp01_vector(1 - bodyMoveMax / eventMaxMovement);
lowO2QualityScore = 0.35 * fastRDeltaScore + 0.25 * fastRRatioScore + ...
    0.15 * fastRAgreementScore + 0.10 * fastRPIScore + ...
    0.10 * fastRConfidenceScore + 0.05 * fastRMovementScore;
lowO2BaseQualityCandidate = lowO2Candidate & fastRAgreement >= eventRAgreementThreshold & ...
    redPI >= eventRedPIMin & irPI >= eventIrPIMin & ...
    redPI <= eventRedPIMax & irPI <= eventIrPIMax & ...
    lowO2QualityScore >= eventQualityThreshold;
lowO2BaseQualityEvent = confirmed_event_runs(lowO2BaseQualityCandidate, eventConfirmSeconds, eventMergeGapSeconds);
smoothedRSupportBaseline = previous_trailing_median(smoothedR, fastRBaselineSeconds);
smoothedRSupportDelta = smoothedR - smoothedRSupportBaseline;
smoothedRSupportRatio = smoothedR ./ smoothedRSupportBaseline;
smoothedRSupportRatio(~isfinite(smoothedRSupportRatio) | smoothedRSupportBaseline <= 0) = NaN;
smoothedRSupportDeltaScore = clamp01_vector(smoothedRSupportDelta / eventSmoothedRDeltaThreshold);
smoothedRSupportRatioScore = clamp01_vector((smoothedRSupportRatio - 1) / (eventSmoothedRRatioThreshold - 1));
smoothedRSupportScore = 0.50 * smoothedRSupportDeltaScore + 0.50 * smoothedRSupportRatioScore;
smoothedRSupportCandidate = isfinite(smoothedRSupportDelta) & isfinite(smoothedRSupportRatio) & ...
    smoothedRSupportDelta >= eventSmoothedRDeltaThreshold & ...
    smoothedRSupportRatio >= eventSmoothedRRatioThreshold;
lowO2QualityCandidate = lowO2BaseQualityCandidate & smoothedRSupportCandidate;
lowO2QualityEvent = confirmed_event_runs(lowO2QualityCandidate, eventConfirmSeconds, eventMergeGapSeconds);
rRiseSQI = 0.75 * lowO2QualityScore + 0.25 * smoothedRSupportScore;
rRiseSQICandidate = lowO2QualityCandidate;
rRiseSQIEvent = lowO2QualityEvent;

formulaEventStats = score_event_detection(trueSpO2 <= lowSpo2Threshold, lowO2FormulaCandidate, ...
    minLowSegmentSeconds, mergeLowSegmentGapSeconds, eventConfirmSeconds, eventMergeGapSeconds, "formula");
rRiseEventStats = score_event_detection(trueSpO2 <= lowSpo2Threshold, lowO2Candidate, ...
    minLowSegmentSeconds, mergeLowSegmentGapSeconds, eventConfirmSeconds, eventMergeGapSeconds, "r_rise");
baseQualityEventStats = score_event_detection(trueSpO2 <= lowSpo2Threshold, lowO2BaseQualityCandidate, ...
    minLowSegmentSeconds, mergeLowSegmentGapSeconds, eventConfirmSeconds, eventMergeGapSeconds, "r_rise_base_sqi");
rRiseSQIEventStats = score_event_detection(trueSpO2 <= lowSpo2Threshold, rRiseSQICandidate, ...
    minLowSegmentSeconds, mergeLowSegmentGapSeconds, eventConfirmSeconds, eventMergeGapSeconds, "r_rise_sqi_smoothedR");

[spo2AutoOffset, spo2AutoCorr] = estimate_time_offset_with_corr(estSpO2, trueSpO2, 120, stepSize);
[prAutoOffset, prAutoCorr] = estimate_time_offset_with_corr(estPR, truePR, 120, stepSize);

[autoAlignedSpO2Est, autoAlignedSpO2True] = align_series_pair_debug(estSpO2, trueSpO2, spo2AutoOffset, samplingRate);
[autoAlignedPREst, autoAlignedPRTrue] = align_series_pair_debug(estPR, truePR, prAutoOffset, samplingRate);

fprintf("\n================ No31 SpO2/R Verification ================\n");
fprintf("Data ID: %d\n", dataID);
fprintf("Default get_filename time_offset: %d samples\n", defaultTimeOffset);
fprintf("Used time_offset: %d samples\n", time_offset);
fprintf("Drop start/end: %d / %d samples\n", drop_num_start, drop_num_end);
fprintf("Output windows: %d\n", windowCounter);
fprintf("No-offset SpO2 RMSE: %.3f, corr: %.3f\n", ...
    rmse_debug(estSpO2, trueSpO2), corr_debug(estSpO2, trueSpO2));
fprintf("Auto SpO2 offset: %d samples, best corr: %.3f, auto RMSE: %.3f\n", ...
    spo2AutoOffset, spo2AutoCorr, rmse_debug(autoAlignedSpO2Est, autoAlignedSpO2True));
fprintf("No-offset PR RMSE: %.3f, corr: %.3f\n", ...
    rmse_debug(estPR, truePR), corr_debug(estPR, truePR));
fprintf("Auto PR offset: %d samples, best corr: %.3f, auto RMSE: %.3f\n\n", ...
    prAutoOffset, prAutoCorr, rmse_debug(autoAlignedPREst, autoAlignedPRTrue));
fprintf("Fast event track: red/IR robust R, %d-s trailing median, event threshold %.1f\n", ...
    fastRSmoothingSeconds, eventSpO2Threshold);
fprintf("R-rise event rule: fastRDelta >= %.3f and fastRRatio >= %.3f for %d s\n", ...
    eventRDeltaThreshold, eventRRatioThreshold, eventConfirmSeconds);
fprintf("Quality event rule: score >= %.2f, agreement >= %.2f, merged gaps <= %d s\n", ...
    eventQualityThreshold, eventRAgreementThreshold, eventMergeGapSeconds);
fprintf("Smoothed-R support rule: delta >= %.3f and ratio >= %.3f\n", ...
    eventSmoothedRDeltaThreshold, eventSmoothedRRatioThreshold);
fprintf("No-offset fast event SpO2 RMSE: %.3f, corr: %.3f\n", ...
    rmse_debug(fastEventSpO2, trueSpO2), corr_debug(fastEventSpO2, trueSpO2));
fprintf("Formula candidate/event windows: %d / %d\n", ...
    sum(lowO2FormulaCandidate), sum(lowO2FormulaEvent));
fprintf("R-rise candidate/event windows: %d / %d\n", sum(lowO2Candidate), sum(lowO2Event));
fprintf("Base SQI candidate/event windows: %d / %d\n", ...
    sum(lowO2BaseQualityCandidate), sum(lowO2BaseQualityEvent));
fprintf("Smoothed-R support candidate windows: %d\n", sum(smoothedRSupportCandidate));
fprintf("Cross-track SQI candidate/event windows: %d / %d\n\n", ...
    sum(lowO2QualityCandidate), sum(lowO2QualityEvent));
print_event_score(formulaEventStats);
print_event_score(rRiseEventStats);
print_event_score(baseQualityEventStats);
print_event_score(rRiseSQIEventStats);
fprintf("\n");

print_group_stats("all", true(size(trueSpO2)), trueSpO2, estSpO2, truePR, estPR, ...
    smoothedR, rawR, classicRPeakToPeak, classicRRobust, fastEventR, fastRDelta, ...
    fastRRatio, fastEventSpO2, lowO2FormulaCandidate, lowO2FormulaEvent, ...
    lowO2Candidate, lowO2Event, lowO2QualityCandidate, lowO2QualityEvent, ...
    lowO2QualityScore, confidenceR);
print_group_stats("true SpO2 <= 90", trueSpO2 <= lowSpo2Threshold, trueSpO2, estSpO2, truePR, estPR, ...
    smoothedR, rawR, classicRPeakToPeak, classicRRobust, fastEventR, fastRDelta, ...
    fastRRatio, fastEventSpO2, lowO2FormulaCandidate, lowO2FormulaEvent, ...
    lowO2Candidate, lowO2Event, lowO2QualityCandidate, lowO2QualityEvent, ...
    lowO2QualityScore, confidenceR);
print_group_stats("true SpO2 <= 85", trueSpO2 <= severeSpo2Threshold, trueSpO2, estSpO2, truePR, estPR, ...
    smoothedR, rawR, classicRPeakToPeak, classicRRobust, fastEventR, fastRDelta, ...
    fastRRatio, fastEventSpO2, lowO2FormulaCandidate, lowO2FormulaEvent, ...
    lowO2Candidate, lowO2Event, lowO2QualityCandidate, lowO2QualityEvent, ...
    lowO2QualityScore, confidenceR);
print_group_stats("true SpO2 > 92", trueSpO2 > 92, trueSpO2, estSpO2, truePR, estPR, ...
    smoothedR, rawR, classicRPeakToPeak, classicRRobust, fastEventR, fastRDelta, ...
    fastRRatio, fastEventSpO2, lowO2FormulaCandidate, lowO2FormulaEvent, ...
    lowO2Candidate, lowO2Event, lowO2QualityCandidate, lowO2QualityEvent, ...
    lowO2QualityScore, confidenceR);

T = table(windowIndex, windowEndSample, windowTime, trueSpO2, estSpO2, ...
    truePR, estPR, go2sleepSpO2Win, go2sleepHRWin, rawR, fixedR, smoothedR, ...
    classicRPeakToPeak, classicRRobust, fastRawR, fastEventR, fastRBaseline, ...
    fastRDelta, fastRRatio, fastEventSpO2, lowO2FormulaCandidate, lowO2FormulaEvent, ...
    lowO2Candidate, lowO2Event, fastRAgreement, lowO2QualityScore, ...
    lowO2BaseQualityCandidate, lowO2BaseQualityEvent, smoothedRSupportBaseline, ...
    smoothedRSupportDelta, smoothedRSupportRatio, smoothedRSupportScore, ...
    smoothedRSupportCandidate, lowO2QualityCandidate, lowO2QualityEvent, ...
    rRiseSQI, rRiseSQICandidate, rRiseSQIEvent, ...
    redPI, irPI, redIRDcRatio, ...
    confidenceR, bodyMoveMean, bodyMoveMax);

csvPath = fullfile(outputDir, "no31_spo2_r_verification_windows.csv");
writetable(T, csvPath);
fprintf("Wrote window CSV: %s\n", csvPath);

eventScoreTable = struct2table([formulaEventStats; rRiseEventStats; baseQualityEventStats; rRiseSQIEventStats]);
eventScoreCsvPath = fullfile(outputDir, "no31_spo2_r_event_scores.csv");
writetable(eventScoreTable, eventScoreCsvPath);
fprintf("Wrote event score CSV: %s\n", eventScoreCsvPath);

plot_overview(outputDir, windowTime, trueSpO2, estSpO2, go2sleepSpO2Win, ...
    truePR, estPR, go2sleepHRWin, smoothedR, rawR, classicRRobust, ...
    fastEventR, fastEventSpO2, lowO2FormulaEvent, lowO2Event, lowO2QualityEvent, ...
    confidenceR, bodyMoveMax);
plot_scatter(outputDir, trueSpO2, estSpO2, smoothedR, rawR, ...
    classicRPeakToPeak, classicRRobust, fastEventR, fastEventSpO2, confidenceR);

segments = find_low_segments(trueSpO2 <= lowSpo2Threshold, ...
    minLowSegmentSeconds, mergeLowSegmentGapSeconds);
if isempty(segments)
    fprintf("No low-SpO2 segments found at threshold %.1f.\n", lowSpo2Threshold);
else
    segmentMinSpo2 = zeros(size(segments, 1), 1);
    for idx = 1:size(segments, 1)
        segmentMinSpo2(idx) = min(trueSpO2(segments(idx, 1):segments(idx, 2)), [], "omitnan");
    end
    [~, order] = sort(segmentMinSpo2, "ascend");
    plotCount = min(maxLowSegmentPlots, numel(order));

    fprintf("\nLow-SpO2 segments selected for zoom plots:\n");
    for plotIdx = 1:plotCount
        segIdx = order(plotIdx);
        segStart = segments(segIdx, 1);
        segEnd = segments(segIdx, 2);
        fprintf("  Segment %d: windows [%d, %d], time %s to %s, min SpO2 %.1f\n", ...
            plotIdx, segStart, segEnd, string(windowTime(segStart)), ...
            string(windowTime(segEnd)), segmentMinSpo2(segIdx));
        plot_low_segment(outputDir, plotIdx, segStart, segEnd, zoomPaddingSeconds, ...
            windowTime, trueSpO2, estSpO2, go2sleepSpO2Win, truePR, estPR, ...
            go2sleepHRWin, smoothedR, rawR, classicRPeakToPeak, classicRRobust, ...
            fastEventR, fastEventSpO2, lowO2FormulaEvent, lowO2Candidate, ...
            lowO2Event, lowO2QualityEvent, lowO2QualityScore, confidenceR, bodyMoveMax);
    end
end

fprintf("Figures written to: %s\n", outputDir);

function [outputFlag, outputPR, outputSpO2, outputPI, confidenceR, rawR, fixedR, smoothedR] = ...
    process_sample_for_debug(inputSampleR, inputSampleIR, inputSampleG, inputCounter, bodyMove)

samplingRate = uint32(50);
windowLength = 3;
windowSize = windowLength * samplingRate;
stepSize = samplingRate;

persistent windowR;
persistent windowIR;
persistent windowG;
persistent outputCounter;
persistent beginCalculation;
persistent bufferR;
persistent bufferIR;
persistent bufferG;

if isempty(bufferR) || isempty(bufferIR) || isempty(bufferG)
    bufferR = zeros(stepSize, 1, "single");
    bufferIR = zeros(stepSize, 1, "single");
    bufferG = zeros(stepSize, 1, "single");
end
if isempty(windowR)
    windowR = zeros(windowSize, 1, "single");
end
if isempty(windowIR)
    windowIR = zeros(windowSize, 1, "single");
end
if isempty(windowG)
    windowG = zeros(windowSize, 1, "single");
end
if isempty(outputCounter)
    outputCounter = uint32(0);
end
if isempty(beginCalculation)
    beginCalculation = false;
end

if inputCounter == 1
    windowR = single(zeros(windowSize, 1));
    windowIR = single(zeros(windowSize, 1));
    windowG = single(zeros(windowSize, 1));
    outputCounter = uint32(0);
    beginCalculation = false;
end

bufferIdx = mod(inputCounter - 1, stepSize) + 1;
bufferR(bufferIdx) = inputSampleR;
bufferIR(bufferIdx) = inputSampleIR;
bufferG(bufferIdx) = inputSampleG;

if inputCounter >= windowSize
    beginCalculation = true;
elseif mod(inputCounter, stepSize) == 0
    windowR = [windowR(stepSize + 1:end); bufferR];
    windowIR = [windowIR(stepSize + 1:end); bufferIR];
    windowG = [windowG(stepSize + 1:end); bufferG];
end

outputFlag = beginCalculation && mod(inputCounter, stepSize) == 0;

if outputFlag
    outputCounter = outputCounter + 1;

    windowR = [windowR(stepSize + 1:end); bufferR];
    windowIR = [windowIR(stepSize + 1:end); bufferIR];
    windowG = [windowG(stepSize + 1:end); bufferG];

    [rawR, PR, outputPI, confidenceR, confidenceG] = ...
        r_pr_calculation(windowR, windowIR, windowG, samplingRate, outputCounter, bodyMove);
    [fixedR, fixedPR, confidenceR] = r_pr_fix(rawR, PR, confidenceR, confidenceG, outputCounter);
    smoothedR = r_smoothing(fixedR, outputCounter);
    smoothedPR = pr_smoothing(fixedPR, outputCounter);

    outputPR = round(smoothedPR);
    outputSpO2 = calculate_spo2(smoothedR);
else
    outputPR = single(0);
    outputSpO2 = single(0);
    outputPI = single(0);
    confidenceR = single(0);
    rawR = single(0);
    fixedR = single(0);
    smoothedR = single(0);
end
end

function timeValues = parse_local_time(timeText)
try
    timeValues = datetime(timeText, "InputFormat", "yyyy-MM-dd HH:mm:ss");
catch
    timeValues = datetime(timeText);
end
end

function value = positive_mode(inputValues)
validValues = inputValues(isfinite(inputValues) & inputValues > 0);
if isempty(validValues)
    value = NaN;
else
    value = mode(validValues);
end
end

function value = positive_median(inputValues)
validValues = inputValues(isfinite(inputValues) & inputValues > 0);
if isempty(validValues)
    value = NaN;
else
    value = median(validValues);
end
end

function [classicRPeakToPeak, classicRRobust, redPI, irPI, redIRDcRatio] = raw_red_ir_features(redWindow, irWindow)
redWindow = double(redWindow(:));
irWindow = double(irWindow(:));

redDc = median(redWindow, "omitnan");
irDc = median(irWindow, "omitnan");
redP2P = max(redWindow, [], "omitnan") - min(redWindow, [], "omitnan");
irP2P = max(irWindow, [], "omitnan") - min(irWindow, [], "omitnan");

redRobustAmp = local_percentile(redWindow, 95) - local_percentile(redWindow, 5);
irRobustAmp = local_percentile(irWindow, 95) - local_percentile(irWindow, 5);

redPI = safe_divide(redP2P, redDc);
irPI = safe_divide(irP2P, irDc);
classicRPeakToPeak = safe_divide(safe_divide(redP2P, redDc), safe_divide(irP2P, irDc));
classicRRobust = safe_divide(safe_divide(redRobustAmp, redDc), safe_divide(irRobustAmp, irDc));
redIRDcRatio = safe_divide(redDc, irDc);
end

function value = local_percentile(inputValues, pct)
validValues = sort(inputValues(isfinite(inputValues)));
if isempty(validValues)
    value = NaN;
    return
end
if numel(validValues) == 1
    value = validValues(1);
    return
end
pos = 1 + (numel(validValues) - 1) * pct / 100;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    value = validValues(lo);
else
    value = validValues(lo) + (validValues(hi) - validValues(lo)) * (pos - lo);
end
end

function value = safe_divide(numerator, denominator)
if ~isfinite(numerator) || ~isfinite(denominator) || abs(denominator) < 1e-12
    value = NaN;
else
    value = numerator / denominator;
end
end

function value = safe_ratio(numerator, denominator)
value = numerator ./ denominator;
invalidMask = ~isfinite(numerator) | ~isfinite(denominator) | abs(denominator) < 1e-12;
value(invalidMask) = NaN;
end

function [time_offset, bestCorr] = estimate_time_offset_with_corr(estimatedSeries, trueSeries, maxLagWin, stepSize)
if nargin < 3 || isempty(maxLagWin)
    maxLagWin = 120;
end
if nargin < 4 || isempty(stepSize)
    stepSize = 50;
end

estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);

N = min(length(estimatedSeries), length(trueSeries));
if N < 5
    time_offset = 0;
    bestCorr = NaN;
    return
end

L = min(maxLagWin, floor(N / 2));
bestCorr = -Inf;
bestLag = 0;

for lag = -L:L
    if lag >= 0
        x = estimatedSeries(1 + lag:N);
        y = trueSeries(1:N - lag);
    else
        x = estimatedSeries(1:N + lag);
        y = trueSeries(1 - lag:N);
    end

    corrVal = corr_debug(x, y);
    if isfinite(corrVal) && corrVal > bestCorr
        bestCorr = corrVal;
        bestLag = lag;
    end
end

time_offset = bestLag * stepSize;
end

function [alignedEst, alignedTrue, varargout] = align_series_pair_debug(estimatedSeries, trueSeries, time_offset, samplingRate, varargin)
seriesLength = min(numel(estimatedSeries), numel(trueSeries));
for idx = 1:numel(varargin)
    seriesLength = min(seriesLength, numel(varargin{idx}));
end

estimatedSeries = estimatedSeries(1:seriesLength);
trueSeries = trueSeries(1:seriesLength);
for idx = 1:numel(varargin)
    varargin{idx} = varargin{idx}(1:seriesLength);
end

offsetWindows = round(time_offset / samplingRate);
if seriesLength == 0 || abs(offsetWindows) >= seriesLength
    alignedEst = [];
    alignedTrue = [];
    for idx = 1:numel(varargin)
        varargout{idx} = [];
    end
    return
end

if offsetWindows >= 0
    alignedEst = estimatedSeries(offsetWindows + 1:end);
    alignedTrue = trueSeries(1:end - offsetWindows);
    for idx = 1:numel(varargin)
        varargout{idx} = varargin{idx}(offsetWindows + 1:end);
    end
else
    alignedEst = estimatedSeries(1:end + offsetWindows);
    alignedTrue = trueSeries(-offsetWindows + 1:end);
    for idx = 1:numel(varargin)
        varargout{idx} = varargin{idx}(1:end + offsetWindows);
    end
end
end

function value = corr_debug(x, y)
x = x(:);
y = y(:);
n = min(numel(x), numel(y));
x = x(1:n);
y = y(1:n);
mask = isfinite(x) & isfinite(y) & x > 0 & y > 0;
if sum(mask) < 5
    value = NaN;
    return
end
x = x(mask);
y = y(mask);
x = x - mean(x);
y = y - mean(y);
denom = sqrt(sum(x .^ 2)) * sqrt(sum(y .^ 2));
if denom == 0
    value = NaN;
else
    value = (x.' * y) / denom;
end
end

function value = rmse_debug(x, y)
x = x(:);
y = y(:);
n = min(numel(x), numel(y));
x = x(1:n);
y = y(1:n);
mask = isfinite(x) & isfinite(y) & x > 0 & y > 0;
if ~any(mask)
    value = NaN;
else
    diffValue = x(mask) - y(mask);
    value = sqrt(mean(diffValue .^ 2));
end
end

function print_group_stats(label, mask, trueSpO2, estSpO2, truePR, estPR, ...
    smoothedR, rawR, classicRPeakToPeak, classicRRobust, fastEventR, fastRDelta, ...
    fastRRatio, fastEventSpO2, lowO2FormulaCandidate, lowO2FormulaEvent, ...
    lowO2Candidate, lowO2Event, lowO2QualityCandidate, lowO2QualityEvent, ...
    lowO2QualityScore, confidenceR)

mask = mask(:) & isfinite(trueSpO2(:)) & isfinite(estSpO2(:));
fprintf("---------------- %s ----------------\n", label);
fprintf("count: %d\n", sum(mask));
if ~any(mask)
    return
end
fprintf("SpO2 true mean/min/max: %.2f / %.1f / %.1f\n", ...
    mean(trueSpO2(mask), "omitnan"), min(trueSpO2(mask), [], "omitnan"), max(trueSpO2(mask), [], "omitnan"));
fprintf("SpO2 est  mean/min/max: %.2f / %.1f / %.1f\n", ...
    mean(estSpO2(mask), "omitnan"), min(estSpO2(mask), [], "omitnan"), max(estSpO2(mask), [], "omitnan"));
fprintf("SpO2 RMSE/bias/corr: %.3f / %.3f / %.3f\n", ...
    rmse_debug(estSpO2(mask), trueSpO2(mask)), ...
    mean(estSpO2(mask) - trueSpO2(mask), "omitnan"), ...
    corr_debug(estSpO2(mask), trueSpO2(mask)));
fprintf("PR true/est mean: %.2f / %.2f, PR RMSE: %.3f\n", ...
    mean(truePR(mask), "omitnan"), mean(estPR(mask), "omitnan"), ...
    rmse_debug(estPR(mask), truePR(mask)));
fprintf("smoothedR mean/std/corr-with-trueSpO2: %.4f / %.4f / %.3f\n", ...
    mean(smoothedR(mask), "omitnan"), std(smoothedR(mask), 0, "omitnan"), ...
    corr_debug(smoothedR(mask), trueSpO2(mask)));
fprintf("rawR mean/std/corr-with-trueSpO2: %.4f / %.4f / %.3f\n", ...
    mean(rawR(mask), "omitnan"), std(rawR(mask), 0, "omitnan"), ...
    corr_debug(rawR(mask), trueSpO2(mask)));
fprintf("classic p2p R mean/std/corr-with-trueSpO2: %.4f / %.4f / %.3f\n", ...
    mean(classicRPeakToPeak(mask), "omitnan"), std(classicRPeakToPeak(mask), 0, "omitnan"), ...
    corr_debug(classicRPeakToPeak(mask), trueSpO2(mask)));
fprintf("classic robust R mean/std/corr-with-trueSpO2: %.4f / %.4f / %.3f\n", ...
    mean(classicRRobust(mask), "omitnan"), std(classicRRobust(mask), 0, "omitnan"), ...
    corr_debug(classicRRobust(mask), trueSpO2(mask)));
fprintf("fast event R mean/std/corr-with-trueSpO2: %.4f / %.4f / %.3f\n", ...
    mean(fastEventR(mask), "omitnan"), std(fastEventR(mask), 0, "omitnan"), ...
    corr_debug(fastEventR(mask), trueSpO2(mask)));
fprintf("fast R delta/ratio mean: %.4f / %.4f\n", ...
    mean(fastRDelta(mask), "omitnan"), mean(fastRRatio(mask), "omitnan"));
fprintf("fast event SpO2 mean/RMSE/corr: %.2f / %.3f / %.3f\n", ...
    mean(fastEventSpO2(mask), "omitnan"), ...
    rmse_debug(fastEventSpO2(mask), trueSpO2(mask)), ...
    corr_debug(fastEventSpO2(mask), trueSpO2(mask)));
fprintf("formula candidate/event ratio: %.3f / %.3f\n", ...
    sum(lowO2FormulaCandidate(mask)) / sum(mask), sum(lowO2FormulaEvent(mask)) / sum(mask));
fprintf("R-rise candidate/event ratio: %.3f / %.3f\n", ...
    sum(lowO2Candidate(mask)) / sum(mask), sum(lowO2Event(mask)) / sum(mask));
fprintf("R-rise SQI candidate/event ratio: %.3f / %.3f, score mean: %.3f\n", ...
    sum(lowO2QualityCandidate(mask)) / sum(mask), sum(lowO2QualityEvent(mask)) / sum(mask), ...
    mean(lowO2QualityScore(mask), "omitnan"));
fprintf("confidence mean/min/max: %.3f / %.3f / %.3f\n\n", ...
    mean(confidenceR(mask), "omitnan"), min(confidenceR(mask), [], "omitnan"), ...
    max(confidenceR(mask), [], "omitnan"));
end

function segments = find_low_segments(lowMask, minLength, mergeGap)
lowMask = lowMask(:);
lowIdx = find(lowMask);
if isempty(lowIdx)
    segments = zeros(0, 2);
    return
end

runStarts = lowIdx([true; diff(lowIdx) > 1]);
runEnds = lowIdx([diff(lowIdx) > 1; true]);
segments = [runStarts, runEnds];

merged = zeros(size(segments));
mergedCount = 0;
for idx = 1:size(segments, 1)
    if mergedCount == 0 || segments(idx, 1) - merged(mergedCount, 2) > mergeGap
        mergedCount = mergedCount + 1;
        merged(mergedCount, :) = segments(idx, :);
    else
        merged(mergedCount, 2) = segments(idx, 2);
    end
end
segments = merged(1:mergedCount, :);
lengths = segments(:, 2) - segments(:, 1) + 1;
segments = segments(lengths >= minLength, :);
end

function plot_overview(outputDir, windowTime, trueSpO2, estSpO2, go2sleepSpO2, ...
    truePR, estPR, go2sleepHR, smoothedR, rawR, classicRRobust, fastEventR, ...
    fastEventSpO2, lowO2FormulaEvent, lowO2Event, lowO2QualityEvent, confidenceR, bodyMoveMax)

fig = figure("Color", "w", "Position", [100, 100, 1300, 900], "Visible", "off");
subplot(4, 1, 1);
plot(windowTime, trueSpO2, "LineWidth", 1.1);
hold on;
plot(windowTime, estSpO2, "LineWidth", 1.0);
plot(windowTime, fastEventSpO2, "--", "LineWidth", 0.9);
plot(windowTime, go2sleepSpO2, "LineWidth", 0.8);
eventIdx = find(lowO2Event);
if ~isempty(eventIdx)
    scatter(windowTime(eventIdx), fastEventSpO2(eventIdx), 10, "filled");
end
formulaEventIdx = find(lowO2FormulaEvent);
if ~isempty(formulaEventIdx)
    scatter(windowTime(formulaEventIdx), fastEventSpO2(formulaEventIdx), 8, "x");
end
qualityEventIdx = find(lowO2QualityEvent);
if ~isempty(qualityEventIdx)
    scatter(windowTime(qualityEventIdx), fastEventSpO2(qualityEventIdx), 12, "square", "filled");
end
hold off;
grid on;
ylim([65, 101]);
ylabel("SpO2");
legend("Checkme SpO2", "Display SpO2", "Fast event SpO2", "Go2sleep SpO2", ...
    "R-rise event", "Formula event", "R-rise SQI event", "Location", "best");
title("No31 SpO2/R Verification Overview");

subplot(4, 1, 2);
plot(windowTime, truePR, "LineWidth", 1.1);
hold on;
plot(windowTime, estPR, "LineWidth", 1.0);
plot(windowTime, go2sleepHR, "LineWidth", 0.8);
hold off;
grid on;
ylim([35, 105]);
ylabel("HR / PR");
legend("Checkme HR", "Estimated PR", "Go2sleep HR", "Location", "best");

subplot(4, 1, 3);
plot(windowTime, smoothedR, "LineWidth", 1.0);
hold on;
plot(windowTime, rawR, "LineWidth", 0.7);
plot(windowTime, classicRRobust, "LineWidth", 0.8);
plot(windowTime, fastEventR, "--", "LineWidth", 1.0);
hold off;
grid on;
ylabel("R features");
legend("Smoothed R used by SpO2", "Raw R", "Classic robust red/IR R", ...
    "Fast event R", "Location", "best");

subplot(4, 1, 4);
yyaxis left;
plot(windowTime, confidenceR, "LineWidth", 1.0);
ylim([0, 1]);
ylabel("Confidence");
yyaxis right;
plot(windowTime, bodyMoveMax, "LineWidth", 0.8);
ylabel("Movement");
grid on;
xlabel("Time");

save_figure(fig, fullfile(outputDir, "no31_spo2_r_overview.png"));
end

function plot_scatter(outputDir, trueSpO2, estSpO2, smoothedR, rawR, ...
    classicRPeakToPeak, classicRRobust, fastEventR, fastEventSpO2, confidenceR)

fig = figure("Color", "w", "Position", [100, 100, 1200, 800], "Visible", "off");

subplot(2, 2, 1);
scatter(smoothedR, trueSpO2, 8, confidenceR, "filled");
grid on;
xlabel("Smoothed R used by SpO2");
ylabel("Checkme SpO2");
title("Smoothed R vs reference SpO2");
colorbar;

subplot(2, 2, 2);
scatter(rawR, trueSpO2, 8, confidenceR, "filled");
grid on;
xlabel("Raw R");
ylabel("Checkme SpO2");
title("Raw R vs reference SpO2");
colorbar;

subplot(2, 2, 3);
scatter(classicRPeakToPeak, trueSpO2, 8, confidenceR, "filled");
grid on;
xlabel("Classic p2p red/IR R");
ylabel("Checkme SpO2");
title("Classic p2p R vs reference SpO2");
colorbar;

subplot(2, 2, 4);
scatter(classicRRobust, trueSpO2, 8, confidenceR, "filled");
grid on;
xlabel("Classic robust red/IR R");
ylabel("Checkme SpO2");
title("Classic robust R vs reference SpO2");
colorbar;

save_figure(fig, fullfile(outputDir, "no31_r_vs_spo2_scatter.png"));

fig = figure("Color", "w", "Position", [100, 100, 1200, 520], "Visible", "off");
subplot(1, 2, 1);
scatter(fastEventR, trueSpO2, 8, confidenceR, "filled");
grid on;
xlabel("Fast event R");
ylabel("Checkme SpO2");
title("Fast event R vs reference SpO2");
colorbar;

subplot(1, 2, 2);
scatter(trueSpO2, fastEventSpO2, 8, confidenceR, "filled");
grid on;
xlabel("Checkme SpO2");
ylabel("Fast event SpO2");
title("Fast event SpO2 vs Checkme SpO2");
xlim([65, 101]);
ylim([65, 101]);
hold on;
plot([65, 101], [65, 101], "k--", "LineWidth", 1);
hold off;
colorbar;
save_figure(fig, fullfile(outputDir, "no31_fast_event_channel_scatter.png"));

fig = figure("Color", "w", "Position", [100, 100, 700, 700], "Visible", "off");
scatter(trueSpO2, estSpO2, 8, confidenceR, "filled");
grid on;
xlabel("Checkme SpO2");
ylabel("Estimated SpO2");
title("Estimated SpO2 vs Checkme SpO2");
xlim([65, 101]);
ylim([65, 101]);
hold on;
plot([65, 101], [65, 101], "k--", "LineWidth", 1);
hold off;
colorbar;
save_figure(fig, fullfile(outputDir, "no31_estimated_vs_checkme_spo2.png"));
end

function plot_low_segment(outputDir, plotIdx, segStart, segEnd, paddingSeconds, ...
    windowTime, trueSpO2, estSpO2, go2sleepSpO2, truePR, estPR, go2sleepHR, ...
    smoothedR, rawR, classicRPeakToPeak, classicRRobust, fastEventR, fastEventSpO2, ...
    lowO2FormulaEvent, lowO2Candidate, lowO2Event, lowO2QualityEvent, ...
    lowO2QualityScore, confidenceR, bodyMoveMax)

idxStart = max(1, segStart - paddingSeconds);
idxEnd = min(numel(trueSpO2), segEnd + paddingSeconds);
idx = idxStart:idxEnd;

fig = figure("Color", "w", "Position", [80, 80, 1300, 950], "Visible", "off");
subplot(4, 1, 1);
plot(windowTime(idx), trueSpO2(idx), "LineWidth", 1.2);
hold on;
plot(windowTime(idx), estSpO2(idx), "LineWidth", 1.0);
plot(windowTime(idx), fastEventSpO2(idx), "--", "LineWidth", 0.9);
plot(windowTime(idx), go2sleepSpO2(idx), "LineWidth", 0.8);
eventIdx = idx(lowO2Event(idx));
if ~isempty(eventIdx)
    scatter(windowTime(eventIdx), fastEventSpO2(eventIdx), 12, "filled");
end
formulaEventIdx = idx(lowO2FormulaEvent(idx));
if ~isempty(formulaEventIdx)
    scatter(windowTime(formulaEventIdx), fastEventSpO2(formulaEventIdx), 9, "x");
end
qualityEventIdx = idx(lowO2QualityEvent(idx));
if ~isempty(qualityEventIdx)
    scatter(windowTime(qualityEventIdx), fastEventSpO2(qualityEventIdx), 13, "square", "filled");
end
hold off;
grid on;
ylim([65, 101]);
ylabel("SpO2");
legend("Checkme SpO2", "Display SpO2", "Fast event SpO2", "Go2sleep SpO2", ...
    "R-rise event", "Formula event", "R-rise SQI event", "Location", "best");
title(sprintf("No31 low-SpO2 segment %d", plotIdx));

subplot(4, 1, 2);
plot(windowTime(idx), truePR(idx), "LineWidth", 1.2);
hold on;
plot(windowTime(idx), estPR(idx), "LineWidth", 1.0);
plot(windowTime(idx), go2sleepHR(idx), "LineWidth", 0.8);
hold off;
grid on;
ylim([35, 105]);
ylabel("HR / PR");
legend("Checkme HR", "Estimated PR", "Go2sleep HR", "Location", "best");

subplot(4, 1, 3);
plot(windowTime(idx), smoothedR(idx), "LineWidth", 1.0);
hold on;
plot(windowTime(idx), rawR(idx), "LineWidth", 0.7);
plot(windowTime(idx), classicRPeakToPeak(idx), "LineWidth", 0.8);
plot(windowTime(idx), classicRRobust(idx), "LineWidth", 0.8);
plot(windowTime(idx), fastEventR(idx), "--", "LineWidth", 1.0);
hold off;
grid on;
ylabel("R features");
legend("Smoothed R", "Raw R", "Classic p2p R", "Classic robust R", ...
    "Fast event R", "Location", "best");

subplot(4, 1, 4);
yyaxis left;
plot(windowTime(idx), confidenceR(idx), "LineWidth", 1.0);
hold on;
plot(windowTime(idx), lowO2Candidate(idx), "LineWidth", 0.8);
plot(windowTime(idx), lowO2Event(idx), "LineWidth", 1.0);
plot(windowTime(idx), lowO2FormulaEvent(idx), "LineWidth", 0.8);
plot(windowTime(idx), lowO2QualityEvent(idx), "LineWidth", 1.0);
plot(windowTime(idx), lowO2QualityScore(idx), "LineWidth", 0.8);
hold off;
ylim([0, 1]);
ylabel("Confidence / event");
yyaxis right;
plot(windowTime(idx), bodyMoveMax(idx), "LineWidth", 0.8);
ylabel("Movement");
grid on;
xlabel("Time");

save_figure(fig, fullfile(outputDir, sprintf("no31_low_spo2_segment_%02d.png", plotIdx)));
end

function outputValues = trailing_median(inputValues, windowLength)
inputValues = inputValues(:);
outputValues = NaN(size(inputValues));
windowLength = max(1, round(windowLength));

for idx = 1:numel(inputValues)
    startIdx = max(1, idx - windowLength + 1);
    windowValues = inputValues(startIdx:idx);
    windowValues = windowValues(isfinite(windowValues));
    if ~isempty(windowValues)
        outputValues(idx) = median(windowValues);
    end
end
end

function outputValues = previous_trailing_median(inputValues, windowLength)
inputValues = inputValues(:);
outputValues = NaN(size(inputValues));
windowLength = max(1, round(windowLength));

for idx = 1:numel(inputValues)
    startIdx = max(1, idx - windowLength);
    endIdx = idx - 1;
    if endIdx < startIdx
        continue
    end
    windowValues = inputValues(startIdx:endIdx);
    windowValues = windowValues(isfinite(windowValues));
    if ~isempty(windowValues)
        outputValues(idx) = median(windowValues);
    end
end
end

function outputMask = consecutive_true(inputMask, minCount)
inputMask = logical(inputMask(:));
outputMask = false(size(inputMask));
minCount = max(1, round(minCount));
runCount = 0;

for idx = 1:numel(inputMask)
    if inputMask(idx)
        runCount = runCount + 1;
    else
        runCount = 0;
    end

    if runCount >= minCount
        outputMask(idx) = true;
    end
end
end

function outputValues = clamp01_vector(inputValues)
outputValues = inputValues;
outputValues(~isfinite(outputValues)) = 0;
outputValues = min(max(outputValues, 0), 1);
end

function outputMask = confirmed_event_runs(inputMask, minCount, mergeGap)
segments = find_low_segments(inputMask, minCount, mergeGap);
outputMask = false(size(inputMask(:)));
for idx = 1:size(segments, 1)
    outputMask(segments(idx, 1):segments(idx, 2)) = true;
end
end

function stats = score_event_detection(referenceMask, predictedMask, ...
    trueMinLength, trueMergeGap, predMinLength, predMergeGap, detectorName)

trueSegments = find_low_segments(referenceMask, trueMinLength, trueMergeGap);
predSegments = find_low_segments(predictedMask, predMinLength, predMergeGap);

trueEventCount = size(trueSegments, 1);
predEventCount = size(predSegments, 1);
matchedTrue = false(trueEventCount, 1);
truePositivePredCount = 0;
overlapScores = NaN(predEventCount, 1);

for predIdx = 1:predEventCount
    predStart = predSegments(predIdx, 1);
    predEnd = predSegments(predIdx, 2);
    predLength = predEnd - predStart + 1;

    bestTrueIdx = 0;
    bestOverlapScore = 0;
    for trueIdx = 1:trueEventCount
        trueStart = trueSegments(trueIdx, 1);
        trueEnd = trueSegments(trueIdx, 2);
        trueLength = trueEnd - trueStart + 1;
        overlapLength = max(0, min(predEnd, trueEnd) - max(predStart, trueStart) + 1);
        if overlapLength <= 0
            continue
        end

        predOverlapRatio = overlapLength / max(predLength, 1);
        trueOverlapRatio = overlapLength / max(trueLength, 1);
        overlapScore = 0.5 * predOverlapRatio + 0.5 * trueOverlapRatio;
        if overlapScore > bestOverlapScore
            bestOverlapScore = overlapScore;
            bestTrueIdx = trueIdx;
        end
    end

    if bestTrueIdx > 0
        truePositivePredCount = truePositivePredCount + 1;
        matchedTrue(bestTrueIdx) = true;
        overlapScores(predIdx) = bestOverlapScore;
    end
end

detectedTrueEventCount = sum(matchedTrue);
falsePositiveEventCount = predEventCount - truePositivePredCount;
precision = safe_divide(truePositivePredCount, predEventCount);
recall = safe_divide(detectedTrueEventCount, trueEventCount);
f1Score = safe_divide(2 * precision * recall, precision + recall);

validOverlapScores = overlapScores(isfinite(overlapScores));
if isempty(validOverlapScores)
    meanOverlapScore = NaN;
else
    meanOverlapScore = mean(validOverlapScores);
end

stats = struct( ...
    "detector", detectorName, ...
    "true_event_count", trueEventCount, ...
    "pred_event_count", predEventCount, ...
    "true_positive_pred_count", truePositivePredCount, ...
    "false_positive_event_count", falsePositiveEventCount, ...
    "detected_true_event_count", detectedTrueEventCount, ...
    "precision", precision, ...
    "recall", recall, ...
    "f1_score", f1Score, ...
    "mean_overlap_score", meanOverlapScore);
end

function print_event_score(stats)
fprintf("%s event score: true=%d, pred=%d, TPpred=%d, FP=%d, detectedTrue=%d, precision=%.3f, recall=%.3f, F1=%.3f, overlap=%.3f\n", ...
    char(stats.detector), stats.true_event_count, stats.pred_event_count, ...
    stats.true_positive_pred_count, stats.false_positive_event_count, ...
    stats.detected_true_event_count, stats.precision, stats.recall, ...
    stats.f1_score, stats.mean_overlap_score);
end

function save_figure(fig, pathName)
try
    exportgraphics(fig, pathName, "Resolution", 160);
catch
    saveas(fig, pathName);
end
close(fig);
end
