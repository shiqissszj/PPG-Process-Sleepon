function diagnosis = diagnose_spo2_information_chain_val(dataID, outputDir)
% Diagnose whether the collected PPG carries usable SpO2 information.
%
% This script does not change the production algorithm. It runs the _val
% path, exports per-window features, and compares raw/direct AC/DC,
% preprocessed classic R, green-template raw R, fixed R, and smoothed R
% against the aligned reference SpO2.

if nargin < 1 || isempty(dataID)
    dataID = 1025;
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(fileparts(mfilename('fullpath')), 'diagnostics');
end
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

projectDir = fileparts(mfilename('fullpath'));
oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(projectDir);

clear ppg_process_val r_pr_calculation_val r_pr_fix r_smoothing pr_smoothing

samplingRate = 50;
windowLength = 3;
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate;
qualityDebugCount = 21;

opts = delimitedTextImportOptions("NumVariables", 13);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["time", "dev_time", "ppg_r", "ppg_ir", "ppg_g", ...
    "acc_x", "acc_y", "acc_z", "slp_SPO2", "slp_HR", "masimo_SPO2", ...
    "masimo_HR", "date_time"];
opts.VariableTypes = repmat("string", 1, 13);
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, opts.VariableNames, "WhitespaceRule", "preserve");
opts = setvaropts(opts, opts.VariableNames, "EmptyFieldRule", "auto");

[filename, baseTimeOffset, drop_num_start, drop_num_end] = get_filename(dataID);
data = readmatrix(filename, opts);

sensorStart = drop_num_start - baseTimeOffset + 1;
sensorEnd = size(data, 1) - drop_num_end - baseTimeOffset;
refStart = drop_num_start + 1;
refEnd = size(data, 1) - drop_num_end;

sensor_data = str2double(data(sensorStart:sensorEnd, [3, 4, 5]));
time_data = datetime(data(sensorStart:sensorEnd, 11));
bodyMove = str2double(data(sensorStart:sensorEnd, 10));
checkme_PR = str2double(data(refStart:refEnd, 7));
checkme_SPO2 = str2double(data(refStart:refEnd, 6));

ppg_r = sensor_data(:, 1);
ppg_ir = sensor_data(:, 2);
ppg_g = sensor_data(:, 3);

num_windows = floor((length(ppg_r) - windowSize) / stepSize) + 1;
outputSpO2Values = nan(num_windows, 1);
rawRValues = nan(num_windows, 1);
fixedRValues = nan(num_windows, 1);
smoothedRValues = nan(num_windows, 1);
classicRValues = nan(num_windows, 1);
redAcDcValues = nan(num_windows, 1);
irAcDcValues = nan(num_windows, 1);
rawWindowRedAcDcValues = nan(num_windows, 1);
rawWindowIRAcDcValues = nan(num_windows, 1);
rawWindowClassicRValues = nan(num_windows, 1);
PRValues = nan(num_windows, 1);
confidenceValues = nan(num_windows, 1);
trueSPO2 = nan(num_windows, 1);
truePR = nan(num_windows, 1);
windowEndSample = nan(num_windows, 1);
windowTime = NaT(num_windows, 1);
qualityDebugValues = nan(num_windows, qualityDebugCount);

windowCounter = 0;
inputCounter = uint32(0);

for i = 1:size(ppg_r, 1)
    inputCounter = inputCounter + uint32(1);
    [outputFlag, outputPR, outputSpO2, ~, confidence, rawR, fixedR, ...
        smoothedR, classicR, redAcDc, irAcDc, qualityDebug] = ...
        ppg_process_val(single(ppg_r(i)), single(ppg_ir(i)), single(ppg_g(i)), ...
        inputCounter, single(bodyMove(i)));

    if outputFlag
        windowCounter = windowCounter + 1;
        outputSpO2Values(windowCounter) = outputSpO2;
        PRValues(windowCounter) = outputPR;
        confidenceValues(windowCounter) = confidence;
        rawRValues(windowCounter) = rawR;
        fixedRValues(windowCounter) = fixedR;
        smoothedRValues(windowCounter) = smoothedR;
        classicRValues(windowCounter) = classicR;
        redAcDcValues(windowCounter) = redAcDc;
        irAcDcValues(windowCounter) = irAcDc;
        windowEndSample(windowCounter) = i;
        windowTime(windowCounter) = time_data(i);

        currentR = single(ppg_r(i - windowSize + 1:i));
        currentIR = single(ppg_ir(i - windowSize + 1:i));
        rawWindowRedAcDcValues(windowCounter) = rms_acdc(currentR);
        rawWindowIRAcDcValues(windowCounter) = rms_acdc(currentIR);
        rawWindowClassicRValues(windowCounter) = ...
            rawWindowRedAcDcValues(windowCounter) / rawWindowIRAcDcValues(windowCounter);

        copyCount = min(numel(qualityDebug), qualityDebugCount);
        qualityDebugValues(windowCounter, 1:copyCount) = double(qualityDebug(1:copyCount));

        tmpSPO2 = checkme_SPO2(i - samplingRate + 1:i);
        tmpPR = checkme_PR(i - samplingRate + 1:i);
        trueSPO2(windowCounter) = mode_or_previous(tmpSPO2, trueSPO2, windowCounter);
        truePR(windowCounter) = min(mode_or_previous(tmpPR, truePR, windowCounter), 100);
    end
end

outputSpO2Values = outputSpO2Values(1:windowCounter);
rawRValues = rawRValues(1:windowCounter);
fixedRValues = fixedRValues(1:windowCounter);
smoothedRValues = smoothedRValues(1:windowCounter);
classicRValues = classicRValues(1:windowCounter);
redAcDcValues = redAcDcValues(1:windowCounter);
irAcDcValues = irAcDcValues(1:windowCounter);
rawWindowRedAcDcValues = rawWindowRedAcDcValues(1:windowCounter);
rawWindowIRAcDcValues = rawWindowIRAcDcValues(1:windowCounter);
rawWindowClassicRValues = rawWindowClassicRValues(1:windowCounter);
PRValues = PRValues(1:windowCounter);
confidenceValues = confidenceValues(1:windowCounter);
trueSPO2 = trueSPO2(1:windowCounter);
truePR = truePR(1:windowCounter);
windowEndSample = windowEndSample(1:windowCounter);
windowTime = windowTime(1:windowCounter);
qualityDebugValues = qualityDebugValues(1:windowCounter, :);

beat15 = calculate_beat_level_r_series_val(ppg_r, ppg_ir, ppg_g, samplingRate, windowEndSample, 15);
beat30 = calculate_beat_level_r_series_val(ppg_r, ppg_ir, ppg_g, samplingRate, windowEndSample, 30);
beat60 = calculate_beat_level_r_series_val(ppg_r, ppg_ir, ppg_g, samplingRate, windowEndSample, 60);

spo2_time_offset = estimate_time_offset(outputSpO2Values(:), trueSPO2(:), 120, stepSize);
[alignedOutputSpO2, alignedTrueSpO2, alignedIdxEst, alignedIdxTrue] = ...
    align_series_with_indices(outputSpO2Values, trueSPO2, spo2_time_offset, samplingRate);

alignedRawR = rawRValues(alignedIdxEst);
alignedFixedR = fixedRValues(alignedIdxEst);
alignedSmoothedR = smoothedRValues(alignedIdxEst);
alignedClassicR = classicRValues(alignedIdxEst);
alignedRawWindowClassicR = rawWindowClassicRValues(alignedIdxEst);
alignedRedAcDc = redAcDcValues(alignedIdxEst);
alignedIRAcDc = irAcDcValues(alignedIdxEst);
alignedRawWindowRedAcDc = rawWindowRedAcDcValues(alignedIdxEst);
alignedRawWindowIRAcDc = rawWindowIRAcDcValues(alignedIdxEst);
alignedPR = PRValues(alignedIdxEst);
alignedConfidence = confidenceValues(alignedIdxEst);
alignedWindowEndSample = windowEndSample(alignedIdxEst);
alignedWindowTime = windowTime(alignedIdxEst);
alignedTruePR = truePR(alignedIdxTrue);
alignedQualityDebug = qualityDebugValues(alignedIdxEst, :);
alignedBeat15R = beat15.r(alignedIdxEst);
alignedBeat30R = beat30.r(alignedIdxEst);
alignedBeat60R = beat60.r(alignedIdxEst);
alignedBeat15SpO2 = beat15.spo2(alignedIdxEst);
alignedBeat30SpO2 = beat30.spo2(alignedIdxEst);
alignedBeat60SpO2 = beat60.spo2(alignedIdxEst);
alignedBeat15RedPI = beat15.redPI(alignedIdxEst);
alignedBeat30RedPI = beat30.redPI(alignedIdxEst);
alignedBeat60RedPI = beat60.redPI(alignedIdxEst);
alignedBeat15IRPI = beat15.irPI(alignedIdxEst);
alignedBeat30IRPI = beat30.irPI(alignedIdxEst);
alignedBeat60IRPI = beat60.irPI(alignedIdxEst);
alignedBeat15GreenPI = beat15.greenPI(alignedIdxEst);
alignedBeat30GreenPI = beat30.greenPI(alignedIdxEst);
alignedBeat60GreenPI = beat60.greenPI(alignedIdxEst);
alignedBeat15Count = beat15.beatCount(alignedIdxEst);
alignedBeat30Count = beat30.beatCount(alignedIdxEst);
alignedBeat60Count = beat60.beatCount(alignedIdxEst);
alignedBeat15ValidRatio = beat15.validBeatRatio(alignedIdxEst);
alignedBeat30ValidRatio = beat30.validBeatRatio(alignedIdxEst);
alignedBeat60ValidRatio = beat60.validBeatRatio(alignedIdxEst);

alignedRawSpO2 = calculate_spo2(alignedRawR);
alignedFixedSpO2 = calculate_spo2(alignedFixedR);
alignedSmoothedSpO2 = calculate_spo2(alignedSmoothedR);
alignedClassicSpO2 = calculate_spo2(alignedClassicR);
alignedRawWindowClassicSpO2 = calculate_spo2(alignedRawWindowClassicR);

qualityNames = ["redPI", "irPI", "greenPI", ...
    "xcorrR_G", "xcorrIR_G", "xcorrR_IR", ...
    "acorrR", "acorrIR", "acorrG", "lowLagCorrG", ...
    "usedSampleRatio", "delayR", "delayIR", "outlierRatioG", ...
    "greenIRProjectionGuardRatio", "projectionSignMismatch", ...
    "spo2WindowConfidence", "signalConfidence", ...
    "dcRMean", "dcIRMean", "dcGMean"];

windowTable = table((1:numel(alignedTrueSpO2))', alignedWindowEndSample, ...
    string(alignedWindowTime), alignedTrueSpO2, alignedOutputSpO2, ...
    alignedRawSpO2, alignedFixedSpO2, alignedSmoothedSpO2, ...
    alignedClassicSpO2, alignedRawWindowClassicSpO2, ...
    alignedBeat15SpO2, alignedBeat30SpO2, alignedBeat60SpO2, alignedRawR, ...
    alignedFixedR, alignedSmoothedR, alignedClassicR, alignedRawWindowClassicR, ...
    alignedBeat15R, alignedBeat30R, alignedBeat60R, ...
    alignedRedAcDc, alignedIRAcDc, alignedRawWindowRedAcDc, ...
    alignedRawWindowIRAcDc, alignedBeat15RedPI, alignedBeat30RedPI, ...
    alignedBeat60RedPI, alignedBeat15IRPI, alignedBeat30IRPI, alignedBeat60IRPI, ...
    alignedBeat15GreenPI, alignedBeat30GreenPI, alignedBeat60GreenPI, ...
    alignedBeat15Count, alignedBeat30Count, alignedBeat60Count, ...
    alignedBeat15ValidRatio, alignedBeat30ValidRatio, alignedBeat60ValidRatio, ...
    alignedConfidence, alignedPR, alignedTruePR, ...
    'VariableNames', {'windowIndex', 'endSample', 'time', 'trueSpO2', ...
    'outputSpO2', 'rawRSpO2', 'fixedRSpO2', 'smoothedRSpO2', ...
    'classicRSpO2', 'rawWindowClassicSpO2', ...
    'beat15SpO2', 'beat30SpO2', 'beat60SpO2', 'rawR', 'fixedR', ...
    'smoothedR', 'classicR', 'rawWindowClassicR', ...
    'beat15R', 'beat30R', 'beat60R', 'redAcDc', 'irAcDc', ...
    'rawWindowRedAcDc', 'rawWindowIRAcDc', ...
    'beat15RedPI', 'beat30RedPI', 'beat60RedPI', ...
    'beat15IRPI', 'beat30IRPI', 'beat60IRPI', ...
    'beat15GreenPI', 'beat30GreenPI', 'beat60GreenPI', ...
    'beat15Count', 'beat30Count', 'beat60Count', ...
    'beat15ValidRatio', 'beat30ValidRatio', 'beat60ValidRatio', ...
    'confidenceR', 'PR', 'truePR'});

qualityTable = array2table(alignedQualityDebug, 'VariableNames', cellstr(qualityNames));
windowTable = [windowTable, qualityTable];

segmentTable = build_segment_table(windowTable, 300, 300);

windowCsv = fullfile(outputDir, sprintf('Data_%d_spo2_information_windows.csv', dataID));
segmentCsv = fullfile(outputDir, sprintf('Data_%d_spo2_information_segments.csv', dataID));
writetable(windowTable, windowCsv);
writetable(segmentTable, segmentCsv);

diagnosis = struct();
diagnosis.dataID = dataID;
diagnosis.filename = filename;
diagnosis.baseTimeOffset = baseTimeOffset;
diagnosis.autoSpO2Offset = spo2_time_offset;
diagnosis.windowCsv = windowCsv;
diagnosis.segmentCsv = segmentCsv;
diagnosis.windowCount = height(windowTable);
diagnosis.metrics = table( ...
    ["raw"; "fixed"; "smoothed"; "classic"; "rawWindowClassic"; ...
     "beat15"; "beat30"; "beat60"; "redAcDc"; "irAcDc"], ...
    [series_rmse(alignedRawSpO2, alignedTrueSpO2); ...
     series_rmse(alignedFixedSpO2, alignedTrueSpO2); ...
     series_rmse(alignedSmoothedSpO2, alignedTrueSpO2); ...
     series_rmse(alignedClassicSpO2, alignedTrueSpO2); ...
     series_rmse(alignedRawWindowClassicSpO2, alignedTrueSpO2); ...
     series_rmse(alignedBeat15SpO2, alignedTrueSpO2); ...
     series_rmse(alignedBeat30SpO2, alignedTrueSpO2); ...
     series_rmse(alignedBeat60SpO2, alignedTrueSpO2); ...
     NaN; NaN], ...
    [safe_corr(alignedRawSpO2, alignedTrueSpO2); ...
     safe_corr(alignedFixedSpO2, alignedTrueSpO2); ...
     safe_corr(alignedSmoothedSpO2, alignedTrueSpO2); ...
     safe_corr(alignedClassicSpO2, alignedTrueSpO2); ...
     safe_corr(alignedRawWindowClassicSpO2, alignedTrueSpO2); ...
     safe_corr(alignedBeat15SpO2, alignedTrueSpO2); ...
     safe_corr(alignedBeat30SpO2, alignedTrueSpO2); ...
     safe_corr(alignedBeat60SpO2, alignedTrueSpO2); ...
     safe_corr(alignedRedAcDc, alignedTrueSpO2); ...
     safe_corr(alignedIRAcDc, alignedTrueSpO2)], ...
    [std_ratio(alignedRawSpO2, alignedTrueSpO2); ...
     std_ratio(alignedFixedSpO2, alignedTrueSpO2); ...
     std_ratio(alignedSmoothedSpO2, alignedTrueSpO2); ...
     std_ratio(alignedClassicSpO2, alignedTrueSpO2); ...
     std_ratio(alignedRawWindowClassicSpO2, alignedTrueSpO2); ...
     std_ratio(alignedBeat15SpO2, alignedTrueSpO2); ...
     std_ratio(alignedBeat30SpO2, alignedTrueSpO2); ...
     std_ratio(alignedBeat60SpO2, alignedTrueSpO2); ...
     std_ratio(alignedRedAcDc, alignedTrueSpO2); ...
     std_ratio(alignedIRAcDc, alignedTrueSpO2)], ...
    [low_spo2_recall(alignedRawSpO2, alignedTrueSpO2, 92, 94); ...
     low_spo2_recall(alignedFixedSpO2, alignedTrueSpO2, 92, 94); ...
     low_spo2_recall(alignedSmoothedSpO2, alignedTrueSpO2, 92, 94); ...
     low_spo2_recall(alignedClassicSpO2, alignedTrueSpO2, 92, 94); ...
     low_spo2_recall(alignedRawWindowClassicSpO2, alignedTrueSpO2, 92, 94); ...
     low_spo2_recall(alignedBeat15SpO2, alignedTrueSpO2, 92, 94); ...
     low_spo2_recall(alignedBeat30SpO2, alignedTrueSpO2, 92, 94); ...
     low_spo2_recall(alignedBeat60SpO2, alignedTrueSpO2, 92, 94); ...
     NaN; NaN], ...
    'VariableNames', {'stage', 'rmse', 'corr', 'stdRatio', 'lowRecall'});

disp(diagnosis.metrics);
fprintf('Data No. %d information-chain diagnosis\n', dataID);
fprintf('Base offset %d samples, auto SpO2 offset %d samples\n', baseTimeOffset, spo2_time_offset);
fprintf('Window CSV: %s\n', windowCsv);
fprintf('Segment CSV: %s\n', segmentCsv);
fprintf('Segment quality: Good %d, Borderline %d, Failed %d, Unknown %d, Total %d\n', ...
    sum(segmentTable.quality == "Good"), sum(segmentTable.quality == "Borderline"), ...
    sum(segmentTable.quality == "Failed"), sum(segmentTable.quality == "Unknown"), ...
    height(segmentTable));
diagnosis.interpretation = interpret_spo2_information_chain(diagnosis.metrics);
fprintf('Interpretation: %s\n', char(diagnosis.interpretation));

end

function output = mode_or_previous(inputValues, previousValues, currentIndex)
valid = inputValues(inputValues > 0 & isfinite(inputValues));
if isempty(valid)
    if currentIndex > 1
        output = previousValues(currentIndex - 1);
    else
        output = NaN;
    end
else
    output = mode(valid);
end
end

function output = rms_acdc(inputSignal)
dcValue = mean(inputSignal, 'omitnan');
acValue = inputSignal - dcValue;
output = sqrt(mean(acValue .^ 2, 'omitnan')) / max(abs(dcValue), single(1e-6));
end

function [alignedEst, alignedTrue, idxEst, idxTrue] = align_series_with_indices(estimatedSeries, trueSeries, timeOffset, samplingRate)
estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);
seriesLength = min(numel(estimatedSeries), numel(trueSeries));
estimatedSeries = estimatedSeries(1:seriesLength);
trueSeries = trueSeries(1:seriesLength);
offsetWindows = round(timeOffset / samplingRate);

if offsetWindows >= 0
    idxEst = (offsetWindows + 1:seriesLength)';
    idxTrue = (1:seriesLength - offsetWindows)';
else
    idxEst = (1:seriesLength + offsetWindows)';
    idxTrue = (-offsetWindows + 1:seriesLength)';
end

alignedEst = estimatedSeries(idxEst);
alignedTrue = trueSeries(idxTrue);
end

function outputTable = build_segment_table(windowTable, windowSeconds, stepSeconds)
segmentLength = max(1, round(windowSeconds));
stepLength = max(1, round(stepSeconds));
seriesLength = height(windowTable);
if seriesLength < segmentLength
    segmentStarts = 1;
else
    segmentStarts = (1:stepLength:(seriesLength - segmentLength + 1))';
end

segmentCount = numel(segmentStarts);
segmentIndex = (1:segmentCount)';
startWindow = nan(segmentCount, 1);
endWindow = nan(segmentCount, 1);
quality = strings(segmentCount, 1);
smoothedRmse = nan(segmentCount, 1);
smoothedCorr = nan(segmentCount, 1);
smoothedStdRatio = nan(segmentCount, 1);
smoothedLowRecall = nan(segmentCount, 1);
lowEventRatio = nan(segmentCount, 1);
rawCorr = nan(segmentCount, 1);
classicCorr = nan(segmentCount, 1);
rawWindowClassicCorr = nan(segmentCount, 1);
beat15Rmse = nan(segmentCount, 1);
beat30Rmse = nan(segmentCount, 1);
beat60Rmse = nan(segmentCount, 1);
beat15Corr = nan(segmentCount, 1);
beat30Corr = nan(segmentCount, 1);
beat60Corr = nan(segmentCount, 1);
beat15StdRatio = nan(segmentCount, 1);
beat30StdRatio = nan(segmentCount, 1);
beat60StdRatio = nan(segmentCount, 1);
beat15LowRecall = nan(segmentCount, 1);
beat30LowRecall = nan(segmentCount, 1);
beat60LowRecall = nan(segmentCount, 1);
meanBeat15Count = nan(segmentCount, 1);
meanBeat30Count = nan(segmentCount, 1);
meanBeat60Count = nan(segmentCount, 1);
meanBeat15ValidRatio = nan(segmentCount, 1);
meanBeat30ValidRatio = nan(segmentCount, 1);
meanBeat60ValidRatio = nan(segmentCount, 1);
meanBeat15RedPI = nan(segmentCount, 1);
meanBeat30RedPI = nan(segmentCount, 1);
meanBeat60RedPI = nan(segmentCount, 1);
meanBeat15IRPI = nan(segmentCount, 1);
meanBeat30IRPI = nan(segmentCount, 1);
meanBeat60IRPI = nan(segmentCount, 1);
meanBeat15GreenPI = nan(segmentCount, 1);
meanBeat30GreenPI = nan(segmentCount, 1);
meanBeat60GreenPI = nan(segmentCount, 1);
meanRedPI = nan(segmentCount, 1);
meanIRPI = nan(segmentCount, 1);
meanProjectionGuardRatio = nan(segmentCount, 1);
meanConfidence = nan(segmentCount, 1);
spo2Min = nan(segmentCount, 1);
spo2Max = nan(segmentCount, 1);

for idx = 1:segmentCount
    startIdx = segmentStarts(idx);
    endIdx = min(startIdx + segmentLength - 1, seriesLength);
    part = windowTable(startIdx:endIdx, :);
    startWindow(idx) = part.windowIndex(1);
    endWindow(idx) = part.windowIndex(end);
    smoothedRmse(idx) = series_rmse(part.smoothedRSpO2, part.trueSpO2);
    smoothedCorr(idx) = safe_corr(part.smoothedRSpO2, part.trueSpO2);
    smoothedStdRatio(idx) = std_ratio(part.smoothedRSpO2, part.trueSpO2);
    smoothedLowRecall(idx) = low_spo2_recall(part.smoothedRSpO2, part.trueSpO2, 92, 94);
    validMask = isfinite(part.smoothedRSpO2) & isfinite(part.trueSpO2) & ...
        part.smoothedRSpO2 > 0 & part.trueSpO2 > 0;
    lowEventRatio(idx) = sum(part.trueSpO2(validMask) <= 92) / max(1, sum(validMask));
    rawCorr(idx) = safe_corr(part.rawRSpO2, part.trueSpO2);
    classicCorr(idx) = safe_corr(part.classicRSpO2, part.trueSpO2);
    rawWindowClassicCorr(idx) = safe_corr(part.rawWindowClassicSpO2, part.trueSpO2);
    beat15Rmse(idx) = series_rmse(part.beat15SpO2, part.trueSpO2);
    beat30Rmse(idx) = series_rmse(part.beat30SpO2, part.trueSpO2);
    beat60Rmse(idx) = series_rmse(part.beat60SpO2, part.trueSpO2);
    beat15Corr(idx) = safe_corr(part.beat15SpO2, part.trueSpO2);
    beat30Corr(idx) = safe_corr(part.beat30SpO2, part.trueSpO2);
    beat60Corr(idx) = safe_corr(part.beat60SpO2, part.trueSpO2);
    beat15StdRatio(idx) = std_ratio(part.beat15SpO2, part.trueSpO2);
    beat30StdRatio(idx) = std_ratio(part.beat30SpO2, part.trueSpO2);
    beat60StdRatio(idx) = std_ratio(part.beat60SpO2, part.trueSpO2);
    beat15LowRecall(idx) = low_spo2_recall(part.beat15SpO2, part.trueSpO2, 92, 94);
    beat30LowRecall(idx) = low_spo2_recall(part.beat30SpO2, part.trueSpO2, 92, 94);
    beat60LowRecall(idx) = low_spo2_recall(part.beat60SpO2, part.trueSpO2, 92, 94);
    meanBeat15Count(idx) = mean(part.beat15Count, 'omitnan');
    meanBeat30Count(idx) = mean(part.beat30Count, 'omitnan');
    meanBeat60Count(idx) = mean(part.beat60Count, 'omitnan');
    meanBeat15ValidRatio(idx) = mean(part.beat15ValidRatio, 'omitnan');
    meanBeat30ValidRatio(idx) = mean(part.beat30ValidRatio, 'omitnan');
    meanBeat60ValidRatio(idx) = mean(part.beat60ValidRatio, 'omitnan');
    meanBeat15RedPI(idx) = mean(part.beat15RedPI, 'omitnan');
    meanBeat30RedPI(idx) = mean(part.beat30RedPI, 'omitnan');
    meanBeat60RedPI(idx) = mean(part.beat60RedPI, 'omitnan');
    meanBeat15IRPI(idx) = mean(part.beat15IRPI, 'omitnan');
    meanBeat30IRPI(idx) = mean(part.beat30IRPI, 'omitnan');
    meanBeat60IRPI(idx) = mean(part.beat60IRPI, 'omitnan');
    meanBeat15GreenPI(idx) = mean(part.beat15GreenPI, 'omitnan');
    meanBeat30GreenPI(idx) = mean(part.beat30GreenPI, 'omitnan');
    meanBeat60GreenPI(idx) = mean(part.beat60GreenPI, 'omitnan');
    meanRedPI(idx) = mean(part.redPI, 'omitnan');
    meanIRPI(idx) = mean(part.irPI, 'omitnan');
    meanProjectionGuardRatio(idx) = mean(part.greenIRProjectionGuardRatio, 'omitnan');
    meanConfidence(idx) = mean(part.confidenceR, 'omitnan');
    spo2Min(idx) = min(part.trueSpO2, [], 'omitnan');
    spo2Max(idx) = max(part.trueSpO2, [], 'omitnan');
    quality(idx) = classify_segment(smoothedRmse(idx), smoothedCorr(idx), ...
        smoothedStdRatio(idx), smoothedLowRecall(idx), lowEventRatio(idx));
end

outputTable = table(segmentIndex, startWindow, endWindow, quality, ...
    smoothedRmse, smoothedCorr, smoothedStdRatio, smoothedLowRecall, lowEventRatio, ...
    rawCorr, classicCorr, rawWindowClassicCorr, ...
    beat15Rmse, beat30Rmse, beat60Rmse, ...
    beat15Corr, beat30Corr, beat60Corr, ...
    beat15StdRatio, beat30StdRatio, beat60StdRatio, ...
    beat15LowRecall, beat30LowRecall, beat60LowRecall, ...
    meanBeat15Count, meanBeat30Count, meanBeat60Count, ...
    meanBeat15ValidRatio, meanBeat30ValidRatio, meanBeat60ValidRatio, ...
    meanBeat15RedPI, meanBeat30RedPI, meanBeat60RedPI, ...
    meanBeat15IRPI, meanBeat30IRPI, meanBeat60IRPI, ...
    meanBeat15GreenPI, meanBeat30GreenPI, meanBeat60GreenPI, ...
    meanRedPI, meanIRPI, ...
    meanProjectionGuardRatio, meanConfidence, spo2Min, spo2Max);
end

function output = interpret_spo2_information_chain(metricsTable)

stageNames = string(metricsTable.stage);
smoothedCorr = metric_value(metricsTable, stageNames, "smoothed", "corr");
smoothedLowRecall = metric_value(metricsTable, stageNames, "smoothed", "lowRecall");
classicCorr = metric_value(metricsTable, stageNames, "classic", "corr");
rawWindowCorr = metric_value(metricsTable, stageNames, "rawWindowClassic", "corr");

beatMask = ismember(stageNames, ["beat15", "beat30", "beat60"]);
beatCorrValues = metricsTable.corr(beatMask);
beatLowRecallValues = metricsTable.lowRecall(beatMask);
bestBeatCorr = max(beatCorrValues, [], 'omitnan');
bestBeatLowRecall = max(beatLowRecallValues, [], 'omitnan');

if ~isfinite(bestBeatCorr)
    bestBeatCorr = NaN;
end
if ~isfinite(bestBeatLowRecall)
    bestBeatLowRecall = NaN;
end

if isfinite(bestBeatCorr) && isfinite(smoothedCorr) && ...
        (bestBeatCorr >= smoothedCorr + 0.15 || bestBeatLowRecall >= smoothedLowRecall + 0.2)
    output = "Beat-level R is clearly better. Current 3 s projection/window extraction is likely losing SpO2 information.";
elseif max([smoothedCorr, classicCorr, rawWindowCorr, bestBeatCorr], [], 'omitnan') < 0.25 && ...
        max([smoothedLowRecall, bestBeatLowRecall], [], 'omitnan') < 0.45
    output = "All R extraction paths are weak. This recording likely lacks stable red/IR ratio information for SpO2 tracking.";
elseif isfinite(classicCorr) && isfinite(smoothedCorr) && classicCorr >= smoothedCorr + 0.15
    output = "Classic red/IR AC/DC is better than the green-template R. The current R formula or green reference alignment is the main suspect.";
else
    output = "No single cause is isolated. Compare the beat columns and segment CSV to separate acquisition instability from R extraction instability.";
end
end

function output = metric_value(metricsTable, stageNames, stageName, columnName)

idx = find(stageNames == stageName, 1);
if isempty(idx)
    output = NaN;
else
    output = metricsTable.(char(columnName))(idx);
end
end

function output = classify_segment(rmseValue, corrValue, stdRatioValue, lowRecallValue, lowEventRatio)
if ~isfinite(rmseValue) || ~isfinite(corrValue) || ~isfinite(stdRatioValue)
    output = "Unknown";
    return
end

hasMeaningfulLowEvent = isfinite(lowEventRatio) && lowEventRatio >= 0.02;
lowRecallFailed = hasMeaningfulLowEvent && isfinite(lowRecallValue) && lowRecallValue < 0.5;
lowRecallGood = ~hasMeaningfulLowEvent || (isfinite(lowRecallValue) && lowRecallValue >= 0.7);

if rmseValue > 2.5 || corrValue < 0.35 || lowRecallFailed
    output = "Failed";
elseif rmseValue <= 2.0 && corrValue >= 0.6 && stdRatioValue >= 0.75 && lowRecallGood
    output = "Good";
else
    output = "Borderline";
end
end

function output = series_rmse(estimatedSeries, trueSeries)
mask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
if ~any(mask)
    output = NaN;
else
    delta = estimatedSeries(mask) - trueSeries(mask);
    output = sqrt(mean(delta .^ 2));
end
end

function output = safe_corr(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y) & x > 0 & y > 0;
if sum(mask) < 5
    output = NaN;
    return
end
x = x(mask);
y = y(mask);
if std(x) <= 1e-12 || std(y) <= 1e-12
    output = NaN;
else
    output = corr(x, y);
end
end

function output = std_ratio(estimatedSeries, trueSeries)
mask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
if sum(mask) < 5 || std(trueSeries(mask)) <= 1e-12
    output = NaN;
else
    output = std(estimatedSeries(mask)) / std(trueSeries(mask));
end
end

function output = low_spo2_recall(estimatedSeries, trueSeries, trueThreshold, estimatedThreshold)
mask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
eventMask = mask & trueSeries <= trueThreshold;
if ~any(eventMask)
    output = NaN;
else
    output = sum(estimatedSeries(eventMask) <= estimatedThreshold) / sum(eventMask);
end
end
