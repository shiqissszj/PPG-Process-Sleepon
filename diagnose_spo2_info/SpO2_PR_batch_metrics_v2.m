function [summaryTable, perDataMetricsTable] = SpO2_PR_batch_metrics_v2(dataIDList, outputDir)
% Batch metrics for current R and beat30 R without plotting.
%
% Example:
%   ids = [1025, 1026, 1027, 1028];
% dataIDList = [1001,1002,1003, ...
%     1004,1005,1006,1007,1008,1009,1010,1011,1012,1013,1014,1015,1016,1017,1018, ...
%     1019,1020,1022,1023];
%   [summaryTable, perDataMetricsTable] = SpO2_PR_batch_metrics_v2(ids);

if nargin < 1 || isempty(dataIDList)
    dataIDList = 1025;
end
if nargin < 2 || isempty(outputDir)
    projectDir = fileparts(mfilename('fullpath'));
    if isempty(projectDir)
        projectDir = pwd;
    end
    outputDir = fullfile(projectDir, 'diagnostics_v2');
end
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

samplingRate = 50;
windowLength = 3;
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate;
autoTimeOffset = true;

opts = delimitedTextImportOptions("NumVariables", 13);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["time", "dev_time", "ppg_r", "ppg_ir", "ppg_g", ...
    "acc_x", "acc_y", "acc_z", "slp_SPO2", "slp_HR", "masimo_SPO2", ...
    "masimo_HR", "date_time"];
opts.VariableTypes = ["string", "string", "string", "string", "string", ...
    "string", "string", "string", "string", "string", "string", "string", "string"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, opts.VariableNames, "WhitespaceRule", "preserve");
opts = setvaropts(opts, opts.VariableNames, "EmptyFieldRule", "auto");

perDataMetricsTable = table();

for dataIdx = 1:numel(dataIDList)
    dataID = dataIDList(dataIdx);
    currentTable = run_single_data_metrics_v2(dataID, opts, samplingRate, ...
        windowSize, stepSize, autoTimeOffset);
    perDataMetricsTable = [perDataMetricsTable; currentTable]; %#ok<AGROW>
end

summaryTable = summarize_batch_metrics(perDataMetricsTable);

perDataCsv = fullfile(outputDir, 'batch_metrics_v2_per_data.csv');
summaryCsv = fullfile(outputDir, 'batch_metrics_v2_summary.csv');
writetable(perDataMetricsTable, perDataCsv);
writetable(summaryTable, summaryCsv);

fprintf('Per-data metrics CSV: %s\n', perDataCsv);
fprintf('Summary metrics CSV: %s\n', summaryCsv);
disp(summaryTable)
end

function metricsTable = run_single_data_metrics_v2(dataID, opts, samplingRate, windowSize, stepSize, autoTimeOffset)

clear ppg_process_v2 r_pr_calculation_v2 r_pr_fix_v2 r_smoothing_v2 pr_smoothing_v2

[filename,time_offset,drop_num_start,drop_num_end] = get_filename_v2(dataID);
baseTimeOffset = time_offset;
data = readmatrix(filename, opts);

sensorStart = drop_num_start - time_offset + 1;
sensorEnd = size(data, 1) - drop_num_end - time_offset;
refStart = drop_num_start + 1;
refEnd = size(data, 1) - drop_num_end;

sensor_data = str2double(data(sensorStart:sensorEnd, [3,4,5]));
bodyMove = str2double(data(sensorStart:sensorEnd, 10));
checkme_PR = str2double(data(refStart:refEnd, 7));
checkme_SPO2 = str2double(data(refStart:refEnd, 6));

ppg_r = sensor_data(:, 1);
ppg_ir = sensor_data(:, 2);
ppg_g = sensor_data(:, 3);

num_windows = floor((length(ppg_r) - windowSize) / stepSize) + 1;
currentSpO2Values = nan(num_windows, 1);
currentRValues = nan(num_windows, 1);
redAcDcValues = nan(num_windows, 1);
irAcDcValues = nan(num_windows, 1);
PRValues = nan(num_windows, 1);
trueSPO2 = nan(num_windows, 1);
truePR = nan(num_windows, 1);
windowEndSample = nan(num_windows, 1);

windowCounter = 0;
for sampleIdx = 1:size(ppg_r, 1)
    [outputFlag, outputPR, outputSpO2, ~, ~, ~, ~, currentR, ~, redAcDc, irAcDc] = ...
        ppg_process_v2(single(ppg_r(sampleIdx)), single(ppg_ir(sampleIdx)), ...
        single(ppg_g(sampleIdx)), uint32(sampleIdx), single(bodyMove(sampleIdx)));

    if outputFlag
        windowCounter = windowCounter + 1;
        currentSpO2Values(windowCounter) = outputSpO2;
        currentRValues(windowCounter) = currentR;
        redAcDcValues(windowCounter) = redAcDc;
        irAcDcValues(windowCounter) = irAcDc;
        PRValues(windowCounter) = outputPR;
        windowEndSample(windowCounter) = sampleIdx;

        tmpSPO2 = checkme_SPO2(sampleIdx - samplingRate + 1:sampleIdx);
        tmpPR = checkme_PR(sampleIdx - samplingRate + 1:sampleIdx);
        trueSPO2(windowCounter) = mode_or_previous_v2(tmpSPO2, trueSPO2, windowCounter);
        truePR(windowCounter) = min(mode_or_previous_v2(tmpPR, truePR, windowCounter), 100);
    end
end

currentSpO2Values = currentSpO2Values(1:windowCounter);
currentRValues = currentRValues(1:windowCounter);
redAcDcValues = redAcDcValues(1:windowCounter);
irAcDcValues = irAcDcValues(1:windowCounter);
PRValues = PRValues(1:windowCounter);
trueSPO2 = trueSPO2(1:windowCounter);
truePR = truePR(1:windowCounter);
windowEndSample = windowEndSample(1:windowCounter);

beat30 = calculate_beat_level_r_series_v2(ppg_r, ppg_ir, ppg_g, samplingRate, windowEndSample, 30);

spo2_time_offset = 0;
pr_time_offset = 0;
if autoTimeOffset
    try
        spo2_est_offset = estimate_time_offset_v2(currentSpO2Values(:), trueSPO2(:), 120, stepSize);
        if isfinite(spo2_est_offset)
            spo2_time_offset = spo2_est_offset;
        end
    catch
    end

    try
        pr_est_offset = estimate_time_offset_v2(PRValues(:), truePR(:), 120, stepSize);
        if isfinite(pr_est_offset)
            pr_time_offset = pr_est_offset;
        end
    catch
    end
end

[alignedCurrentSpO2, alignedTrueSpO2, alignedIdxEst] = ...
    align_series_with_indices_v2(currentSpO2Values, trueSPO2, spo2_time_offset, samplingRate);

alignedCurrentR = currentRValues(alignedIdxEst);
alignedRedAcDc = redAcDcValues(alignedIdxEst);
alignedIRAcDc = irAcDcValues(alignedIdxEst);
alignedBeat30R = beat30.r(alignedIdxEst);
alignedBeat30SpO2 = beat30.spo2(alignedIdxEst);
alignedBeat30Count = beat30.beatCount(alignedIdxEst);
alignedBeat30ValidRatio = beat30.validBeatRatio(alignedIdxEst);
alignedBeat30RedPI = beat30.redPI(alignedIdxEst);
alignedBeat30IRPI = beat30.irPI(alignedIdxEst);

currentMetric = build_metric_row(dataID, "current", alignedCurrentSpO2, ...
    alignedCurrentR, alignedTrueSpO2, NaN, NaN, alignedRedAcDc, alignedIRAcDc, ...
    baseTimeOffset, spo2_time_offset, pr_time_offset, windowCounter);
beat30Metric = build_metric_row(dataID, "beat30", alignedBeat30SpO2, ...
    alignedBeat30R, alignedTrueSpO2, mean(alignedBeat30Count, 'omitnan'), ...
    mean(alignedBeat30ValidRatio, 'omitnan'), alignedBeat30RedPI, alignedBeat30IRPI, ...
    baseTimeOffset, spo2_time_offset, pr_time_offset, windowCounter);

metricsTable = [currentMetric; beat30Metric];

fprintf('Data %d: current RMSE %.2f corr %.3f R_SNR %.2f dB | beat30 RMSE %.2f corr %.3f R_SNR %.2f dB\n', ...
    dataID, currentMetric.spo2Rmse, currentMetric.spo2Corr, currentMetric.rSnrDb, ...
    beat30Metric.spo2Rmse, beat30Metric.spo2Corr, beat30Metric.rSnrDb);
end

function outputTable = build_metric_row(dataID, featureName, estimatedSpO2, featureR, trueSpO2, ...
    meanBeatCount, meanBeatValidRatio, redPI, irPI, baseTimeOffset, spo2TimeOffset, prTimeOffset, windowCount)

[rSnr, rSnrDb] = feature_r_snr_v2(featureR, trueSpO2);

outputTable = table(dataID, featureName, ...
    series_rmse_v2(estimatedSpO2, trueSpO2), ...
    safe_corr_signed_v2(estimatedSpO2, trueSpO2), ...
    std_ratio_v2(estimatedSpO2, trueSpO2), ...
    low_spo2_recall_v2(estimatedSpO2, trueSpO2, 92, 94), ...
    safe_corr_signed_v2(featureR, trueSpO2), ...
    rSnr, rSnrDb, ...
    mean(isfinite(featureR) & featureR > 0), ...
    meanBeatCount, meanBeatValidRatio, ...
    mean(redPI, 'omitnan'), mean(irPI, 'omitnan'), ...
    baseTimeOffset, spo2TimeOffset, prTimeOffset, baseTimeOffset + spo2TimeOffset, ...
    baseTimeOffset + prTimeOffset, windowCount, ...
    'VariableNames', {'dataID', 'featureName', 'spo2Rmse', 'spo2Corr', ...
    'spo2StdRatio', 'lowRecall', 'featureCorr', 'rSnr', 'rSnrDb', ...
    'featureValidRatio', 'meanBeatCount', 'meanBeatValidRatio', ...
    'meanRedPI', 'meanIRPI', 'baseTimeOffset', 'spo2TimeOffset', ...
    'prTimeOffset', 'totalSpo2Offset', 'totalPROffset', 'windowCount'});
end

function summaryTable = summarize_batch_metrics(perDataMetricsTable)

featureNames = unique(perDataMetricsTable.featureName, 'stable');
summaryTable = table();

for featureIdx = 1:numel(featureNames)
    featureName = featureNames(featureIdx);
    featureRows = perDataMetricsTable(perDataMetricsTable.featureName == featureName, :);
    currentSummary = table(featureName, height(featureRows), ...
        mean(featureRows.spo2Rmse, 'omitnan'), ...
        mean(featureRows.spo2Corr, 'omitnan'), ...
        mean(featureRows.spo2StdRatio, 'omitnan'), ...
        mean(featureRows.lowRecall, 'omitnan'), ...
        mean(featureRows.featureCorr, 'omitnan'), ...
        mean(featureRows.rSnr, 'omitnan'), ...
        mean(featureRows.rSnrDb, 'omitnan'), ...
        mean(featureRows.featureValidRatio, 'omitnan'), ...
        mean(featureRows.meanBeatCount, 'omitnan'), ...
        mean(featureRows.meanBeatValidRatio, 'omitnan'), ...
        mean(featureRows.meanRedPI, 'omitnan'), ...
        mean(featureRows.meanIRPI, 'omitnan'), ...
        'VariableNames', {'featureName', 'dataCount', 'avgSpO2Rmse', ...
        'avgSpO2Corr', 'avgSpO2StdRatio', 'avgLowRecall', ...
        'avgFeatureCorr', 'avgRSnr', 'avgRSnrDb', 'avgFeatureValidRatio', ...
        'avgBeatCount', 'avgBeatValidRatio', 'avgRedPI', 'avgIRPI'});
    summaryTable = [summaryTable; currentSummary]; %#ok<AGROW>
end
end

function output = mode_or_previous_v2(inputValues, previousValues, currentIndex)

validValues = inputValues(inputValues > 0 & isfinite(inputValues));
if isempty(validValues)
    if currentIndex > 1
        output = previousValues(currentIndex - 1);
    else
        output = NaN;
    end
else
    output = mode(validValues);
end
end

function [alignedEst, alignedTrue, idxEst, idxTrue] = align_series_with_indices_v2(estimatedSeries, trueSeries, timeOffset, samplingRate)

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

function [snrRatio, snrDb] = feature_r_snr_v2(featureSeries, trueSpO2)

featureSeries = double(featureSeries(:));
trueSpO2 = double(trueSpO2(:));
validMask = isfinite(featureSeries) & isfinite(trueSpO2) & featureSeries > 0 & trueSpO2 > 0;

if sum(validMask) < 5 || std(trueSpO2(validMask)) <= 1e-12
    snrRatio = NaN;
    snrDb = NaN;
    return
end

featureValues = featureSeries(validMask);
trueValues = trueSpO2(validMask);
fitCoeffs = polyfit(trueValues, featureValues, 1);
fitValues = polyval(fitCoeffs, trueValues);
signalValues = fitValues - mean(fitValues);
noiseValues = featureValues - fitValues;
signalRms = sqrt(mean(signalValues .^ 2));
noiseRms = sqrt(mean(noiseValues .^ 2));

if noiseRms <= 1e-12
    snrRatio = Inf;
    snrDb = Inf;
else
    snrRatio = signalRms / noiseRms;
    snrDb = 20 * log10(snrRatio);
end
end

function output = series_rmse_v2(estimatedSeries, trueSeries)

estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
if ~any(validMask)
    output = NaN;
else
    errorValues = estimatedSeries(validMask) - trueSeries(validMask);
    output = sqrt(mean(errorValues .^ 2));
end
end

function output = safe_corr_signed_v2(inputA, inputB)

inputA = double(inputA(:));
inputB = double(inputB(:));
validMask = isfinite(inputA) & isfinite(inputB) & inputA > 0 & inputB > 0;
if sum(validMask) < 5
    output = NaN;
    return
end

inputA = inputA(validMask);
inputB = inputB(validMask);
inputA = inputA - mean(inputA);
inputB = inputB - mean(inputB);
denom = sqrt(sum(inputA .^ 2)) * sqrt(sum(inputB .^ 2));
if denom <= 1e-12
    output = NaN;
else
    output = sum(inputA .* inputB) / denom;
end
end

function output = std_ratio_v2(estimatedSeries, trueSeries)

estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
if sum(validMask) < 5 || std(trueSeries(validMask)) <= 1e-12
    output = NaN;
else
    output = std(estimatedSeries(validMask)) / std(trueSeries(validMask));
end
end

function output = low_spo2_recall_v2(estimatedSeries, trueSeries, trueThreshold, estimatedThreshold)

estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
eventMask = validMask & trueSeries <= trueThreshold;

if ~any(eventMask)
    output = NaN;
else
    output = sum(estimatedSeries(eventMask) <= estimatedThreshold) / sum(eventMask);
end
end
