function [summaryTable, perDataMetricsTable, metricsTables] = SpO2_PR_main_beat30(dataIDList, outputDir, config)
% Independent beat30_r SpO2 validation and calibration export path.
%
% This follows the offline evaluation style of SpO2_PR_main.m, but treats
% beat30_r as its own feature:
%   1. Extract beat30_r from per-beat red/IR AC/DC.
%   2. Build beat30 confidence from beat count, valid ratio, PI and motion.
%   3. Apply a beat30-specific fix and smoothing path.
%   4. Estimate beat30's own SpO2 time offset from -beat30_r vs reference.
%   5. Export R-SpO2 pairs for beat30-specific calibration.
%
% Example:
%   ids = [1001:1014,1016:1028];
%   [summaryTable, perDataMetricsTable] = SpO2_PR_main_beat30(ids);
%
% After this, run:
%   R_SpO2_scatter_beat30_calibration

if nargin < 1 || isempty(dataIDList)
    % 1015 maps to No13 in get_filename.m, so skip it to avoid duplicate
    % calibration samples unless explicitly requested.
    dataIDList = [1001:1014, 1016:1028];
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(fileparts(mfilename('fullpath')), 'diagnostics_beat30');
end
if nargin < 3
    config = struct();
end
config = fill_beat30_config(config);

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

samplingRate = 50;
windowLength = 3;
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate;

opts = build_import_options_beat30();

R_SpO2_values_beat30 = cell(length(dataIDList), 1);
R_SpO2_details_beat30 = cell(length(dataIDList), 1);
offsetSummary = zeros(length(dataIDList), 5);
perDataMetricsTable = table();
metricsTables = cell(length(dataIDList), 1);
globalPairs = [];
globalDetails = [];

for k = 1:length(dataIDList)
    dataID = dataIDList(k);
    fprintf('\n================ Data %d ================\n', dataID);

    try
        clear ppg_process r_pr_calculation r_pr_fix r_smoothing pr_smoothing
        [dataMetrics, dataDetails, dataPairs, offsetRow, windowTable] = run_single_beat30_data( ...
            dataID, opts, samplingRate, windowSize, stepSize, outputDir, config);

        perDataMetricsTable = [perDataMetricsTable; dataMetrics]; %#ok<AGROW>
        metricsTables{k} = windowTable;
        R_SpO2_values_beat30{k} = dataPairs;
        R_SpO2_details_beat30{k} = dataDetails;
        offsetSummary(k, :) = offsetRow;
        globalPairs = [globalPairs; dataPairs]; %#ok<AGROW>
        globalDetails = [globalDetails; dataDetails]; %#ok<AGROW>
    catch ME
        warning('Data %d failed: %s', dataID, ME.message);
        failedRow = table(dataID, "ERROR", nan, nan, nan, nan, nan, nan, nan, ...
            nan, nan, nan, nan, nan, nan, nan, 0, ...
            'VariableNames', metric_variable_names_beat30());
        perDataMetricsTable = [perDataMetricsTable; failedRow]; %#ok<AGROW>
    end
end

summaryTable = summarize_feature_metrics_beat30(perDataMetricsTable);

perDataCsv = fullfile(outputDir, 'beat30_metrics_per_data.csv');
summaryCsv = fullfile(outputDir, 'beat30_metrics_summary.csv');
writetable(perDataMetricsTable, perDataCsv);
writetable(summaryTable, summaryCsv);

save(fullfile(outputDir, 'R_SpO2_values_beat30.mat'), ...
    'R_SpO2_values_beat30', 'R_SpO2_details_beat30', 'globalPairs', 'globalDetails', ...
    'offsetSummary', 'dataIDList', 'config', 'samplingRate', 'windowLength', 'stepSize');

fprintf('\n================ Beat30 Summary ================\n');
disp(summaryTable);
fprintf('Per-data metrics CSV: %s\n', perDataCsv);
fprintf('Summary metrics CSV: %s\n', summaryCsv);
fprintf('Calibration MAT: %s\n', fullfile(outputDir, 'R_SpO2_values_beat30.mat'));
fprintf('Global calibration pairs: %d\n', size(globalPairs, 1));
end

function [dataMetrics, details, pairs, offsetRow, windowTable] = run_single_beat30_data( ...
    dataID, opts, samplingRate, windowSize, stepSize, outputDir, config)

[filename, time_offset, drop_num_start, drop_num_end] = get_filename(dataID);
baseTimeOffset = time_offset;
data = readmatrix(filename, opts);

rowCount = size(data, 1);
sensorStart = drop_num_start - time_offset + 1;
sensorEnd = rowCount - drop_num_end - time_offset;
refStart = drop_num_start + 1;
refEnd = rowCount - drop_num_end;

if sensorStart < 1 || refStart < 1 || sensorEnd > rowCount || refEnd > rowCount || sensorStart > sensorEnd || refStart > refEnd
    error('Invalid trimmed ranges. sensor=[%d,%d], ref=[%d,%d], rows=%d', sensorStart, sensorEnd, refStart, refEnd, rowCount);
end

sensor_data = str2double(data(sensorStart:sensorEnd, [3,4,5]));
bodyMove = str2double(data(sensorStart:sensorEnd, 10));
checkme_PR = str2double(data(refStart:refEnd, 7));
checkme_SPO2 = str2double(data(refStart:refEnd, 6));

sampleCount = min([size(sensor_data, 1), numel(bodyMove), numel(checkme_PR), numel(checkme_SPO2)]);
sensor_data = sensor_data(1:sampleCount, :);
bodyMove = bodyMove(1:sampleCount);
checkme_PR = checkme_PR(1:sampleCount);
checkme_SPO2 = checkme_SPO2(1:sampleCount);

ppg_r = sensor_data(:, 1);
ppg_ir = sensor_data(:, 2);
ppg_g = sensor_data(:, 3);

numWindows = floor((length(ppg_r) - windowSize) / stepSize) + 1;
if numWindows <= 0
    error('Too few samples for one 3-second window.');
end

currentSpO2 = nan(numWindows, 1);
currentPR = nan(numWindows, 1);
currentConfidence = nan(numWindows, 1);
currentR = nan(numWindows, 1);
trueSPO2 = nan(numWindows, 1);
truePR = nan(numWindows, 1);
windowEndSample = nan(numWindows, 1);
windowMove = nan(numWindows, 1);

windowCounter = 0;
for sampleIdx = 1:size(ppg_r, 1)
    [outputFlag, outputPR, outputSpO2, ~, confidenceR, outputR] = ...
        ppg_process(single(ppg_r(sampleIdx)), single(ppg_ir(sampleIdx)), ...
        single(ppg_g(sampleIdx)), uint32(sampleIdx), single(bodyMove(sampleIdx)));

    if outputFlag
        windowCounter = windowCounter + 1;
        currentSpO2(windowCounter) = outputSpO2;
        currentPR(windowCounter) = outputPR;
        currentConfidence(windowCounter) = confidenceR;
        currentR(windowCounter) = outputR;
        windowEndSample(windowCounter) = sampleIdx;
        windowMove(windowCounter) = mean(bodyMove(sampleIdx - stepSize + 1:sampleIdx), 'omitnan');

        tmpSPO2 = checkme_SPO2(sampleIdx - stepSize + 1:sampleIdx);
        tmpPR = checkme_PR(sampleIdx - stepSize + 1:sampleIdx);
        trueSPO2(windowCounter) = mode_or_previous_beat30(tmpSPO2, trueSPO2, windowCounter);
        truePR(windowCounter) = min(mode_or_previous_beat30(tmpPR, truePR, windowCounter), config.maxReferencePR);
    end
end

currentSpO2 = currentSpO2(1:windowCounter);
currentPR = currentPR(1:windowCounter);
currentConfidence = currentConfidence(1:windowCounter);
currentR = currentR(1:windowCounter);
trueSPO2 = trueSPO2(1:windowCounter);
truePR = truePR(1:windowCounter);
windowEndSample = windowEndSample(1:windowCounter);
windowMove = windowMove(1:windowCounter);

beat30 = calculate_beat_level_r_series_beat30(ppg_r, ppg_ir, ppg_g, samplingRate, windowEndSample, 30, config.calibrationModel);
beat30Confidence = calculate_beat30_confidence(beat30, windowMove, config);
[beat30FixedR, beat30SmoothedR] = postprocess_beat30_r(beat30.r, beat30Confidence, config);

beat30RawSpO2 = calculate_spo2_beat30(beat30.r, config.calibrationModel);
beat30FixedSpO2 = calculate_spo2_beat30(beat30FixedR, config.calibrationModel);
beat30SmoothedSpO2 = calculate_spo2_beat30(beat30SmoothedR, config.calibrationModel);

prTimeOffset = 0;
currentSpO2TimeOffset = 0;
beat30SpO2TimeOffset = 0;

if config.autoTimeOffset
    try
        prTimeOffset = estimate_time_offset(currentPR(:), truePR(:), 120, stepSize);
    catch
        prTimeOffset = 0;
    end
    try
        currentSpO2TimeOffset = estimate_time_offset(currentSpO2(:), trueSPO2(:), 120, stepSize);
    catch
        currentSpO2TimeOffset = 0;
    end
    try
        beat30SpO2TimeOffset = estimate_negative_r_spo2_offset_beat30(beat30SmoothedR(:), trueSPO2(:), 120, stepSize);
    catch
        beat30SpO2TimeOffset = 0;
    end
end

[alignedCurrentSpO2, alignedCurrentTrueSpO2, alignedCurrentR, alignedCurrentConfidence] = ...
    align_series_pair_beat30(currentSpO2, trueSPO2, currentSpO2TimeOffset, samplingRate, currentR, currentConfidence);
[alignedBeat30SpO2, alignedTrueSpO2, alignedBeat30RawR, alignedBeat30FixedR, alignedBeat30SmoothedR, ...
    alignedBeat30Confidence, alignedBeatCount, alignedBeatValidRatio, alignedBeatRedPI, alignedBeatIRPI, ...
    alignedWindowMove, alignedWindowEndSample, alignedCurrentSpO2ForBeat] = ...
    align_series_pair_beat30(beat30SmoothedSpO2, trueSPO2, beat30SpO2TimeOffset, samplingRate, ...
    beat30.r, beat30FixedR, beat30SmoothedR, beat30Confidence, beat30.beatCount, beat30.validBeatRatio, ...
    beat30.redPI, beat30.irPI, windowMove, windowEndSample, currentSpO2);
[alignedPR, alignedTruePR] = align_series_pair_beat30(currentPR, truePR, prTimeOffset, samplingRate);

alignedBeat30RawSpO2 = calculate_spo2_beat30(alignedBeat30RawR, config.calibrationModel);
alignedBeat30FixedSpO2 = calculate_spo2_beat30(alignedBeat30FixedR, config.calibrationModel);
alignedBeat30SmoothedSpO2 = alignedBeat30SpO2;

beat30ReliableMask = alignedBeat30Confidence >= config.confidenceThreshold & ...
    isfinite(alignedBeat30SmoothedR) & alignedBeat30SmoothedR > 0 & alignedBeat30SmoothedR < config.maxR & ...
    isfinite(alignedTrueSpO2) & alignedTrueSpO2 >= 65 & alignedTrueSpO2 <= 100;

currentReliableMask = alignedCurrentConfidence >= config.currentConfidenceThreshold & ...
    isfinite(alignedCurrentR) & alignedCurrentR > 0 & ...
    isfinite(alignedCurrentTrueSpO2) & alignedCurrentTrueSpO2 >= 65 & alignedCurrentTrueSpO2 <= 100;

windowTable = table( ...
    repmat(dataID, numel(alignedTrueSpO2), 1), ...
    alignedWindowEndSample(:), alignedTrueSpO2(:), ...
    alignedBeat30RawR(:), alignedBeat30FixedR(:), alignedBeat30SmoothedR(:), ...
    alignedBeat30RawSpO2(:), alignedBeat30FixedSpO2(:), alignedBeat30SmoothedSpO2(:), ...
    alignedBeat30Confidence(:), alignedBeatCount(:), alignedBeatValidRatio(:), ...
    alignedBeatRedPI(:), alignedBeatIRPI(:), alignedWindowMove(:), alignedCurrentSpO2ForBeat(:), ...
    'VariableNames', {'dataID', 'windowEndSample', 'trueSpO2', ...
    'beat30RawR', 'beat30FixedR', 'beat30SmoothedR', ...
    'beat30RawSpO2', 'beat30FixedSpO2', 'beat30SmoothedSpO2', ...
    'beat30Confidence', 'beatCount', 'beatValidRatio', 'beatRedPI', 'beatIRPI', ...
    'movement', 'currentSpO2'});

if config.saveWindowCsv
    writetable(windowTable, fullfile(outputDir, sprintf('Data_%d_beat30_windows.csv', dataID)));
end

pairs = [alignedBeat30SmoothedR(beat30ReliableMask), alignedTrueSpO2(beat30ReliableMask)];
details = [ ...
    repmat(dataID, sum(beat30ReliableMask), 1), ...
    alignedWindowEndSample(beat30ReliableMask), ...
    alignedBeat30RawR(beat30ReliableMask), alignedBeat30FixedR(beat30ReliableMask), alignedBeat30SmoothedR(beat30ReliableMask), ...
    alignedBeat30RawSpO2(beat30ReliableMask), alignedBeat30FixedSpO2(beat30ReliableMask), alignedBeat30SmoothedSpO2(beat30ReliableMask), ...
    alignedTrueSpO2(beat30ReliableMask), alignedBeat30Confidence(beat30ReliableMask), ...
    alignedBeatCount(beat30ReliableMask), alignedBeatValidRatio(beat30ReliableMask), ...
    alignedBeatRedPI(beat30ReliableMask), alignedBeatIRPI(beat30ReliableMask), alignedWindowMove(beat30ReliableMask), ...
    repmat(baseTimeOffset, sum(beat30ReliableMask), 1), repmat(beat30SpO2TimeOffset, sum(beat30ReliableMask), 1), ...
    repmat(prTimeOffset, sum(beat30ReliableMask), 1)];

currentMetrics = build_metric_row_beat30(dataID, "currentSpO2", alignedCurrentSpO2, alignedCurrentR, ...
    alignedCurrentTrueSpO2, currentReliableMask, nan(size(alignedCurrentSpO2)), nan(size(alignedCurrentSpO2)), ...
    baseTimeOffset, currentSpO2TimeOffset, prTimeOffset, windowCounter);
beatRawMetrics = build_metric_row_beat30(dataID, "beat30Raw", alignedBeat30RawSpO2, alignedBeat30RawR, ...
    alignedTrueSpO2, isfinite(alignedBeat30RawR) & alignedBeat30RawR > 0, alignedBeatCount, alignedBeatValidRatio, ...
    baseTimeOffset, beat30SpO2TimeOffset, prTimeOffset, windowCounter);
beatFixedMetrics = build_metric_row_beat30(dataID, "beat30Fixed", alignedBeat30FixedSpO2, alignedBeat30FixedR, ...
    alignedTrueSpO2, alignedBeat30Confidence >= config.confidenceThreshold, alignedBeatCount, alignedBeatValidRatio, ...
    baseTimeOffset, beat30SpO2TimeOffset, prTimeOffset, windowCounter);
beatSmoothedMetrics = build_metric_row_beat30(dataID, "beat30Smoothed", alignedBeat30SmoothedSpO2, alignedBeat30SmoothedR, ...
    alignedTrueSpO2, beat30ReliableMask, alignedBeatCount, alignedBeatValidRatio, ...
    baseTimeOffset, beat30SpO2TimeOffset, prTimeOffset, windowCounter);

dataMetrics = [currentMetrics; beatRawMetrics; beatFixedMetrics; beatSmoothedMetrics];
offsetRow = [dataID, baseTimeOffset, currentSpO2TimeOffset, beat30SpO2TimeOffset, prTimeOffset];

validPRMask = isfinite(alignedPR) & isfinite(alignedTruePR) & alignedPR > 0 & alignedTruePR > 0;
fprintf('current SpO2 RMSE %.2f corr %.3f\n', currentMetrics.spo2Rmse, currentMetrics.spo2Corr);
fprintf('beat30 smoothed RMSE %.2f corr %.3f Rtrack %.3f R_SNR %.2f dB reliable %.2f\n', ...
    beatSmoothedMetrics.spo2Rmse, beatSmoothedMetrics.spo2Corr, ...
    beatSmoothedMetrics.rTrackingCorr, beatSmoothedMetrics.rSnrDb, beatSmoothedMetrics.reliableRatio);
fprintf('PR RMSE %.2f | offsets current %d beat30 %d PR %d samples\n', ...
    series_rmse_beat30(alignedPR(validPRMask), alignedTruePR(validPRMask)), ...
    currentSpO2TimeOffset, beat30SpO2TimeOffset, prTimeOffset);
fprintf('Beat30 calibration pairs: %d / %d windows\n', size(pairs, 1), numel(alignedTrueSpO2));

if config.enablePlots
    plot_beat30_data(dataID, outputDir, alignedTrueSpO2, alignedCurrentSpO2ForBeat, ...
        alignedBeat30SmoothedSpO2, alignedBeat30SmoothedR, alignedBeat30Confidence, beat30ReliableMask);
end
end

function config = fill_beat30_config(config)

defaults = struct();
defaults.autoTimeOffset = true;
defaults.calibrationModel = 'bootstrapLinear';
defaults.enablePlots = false;
defaults.saveWindowCsv = false;
defaults.maxReferencePR = 100;
defaults.confidenceThreshold = 0.55;
defaults.currentConfidenceThreshold = 0.75;
defaults.minBeatCount = 15;
defaults.minValidBeatRatio = 0.70;
defaults.redPIReference = 0.006;
defaults.irPIReference = 0.010;
defaults.minRedPI = 0.001;
defaults.minIRPI = 0.001;
defaults.maxMotion = 30;
defaults.confidenceBufferSize = 25;
defaults.fixBufferSize = 30;
defaults.smoothWindowSize = 15;
defaults.defaultR = 0.50;
defaults.maxR = 3.0;

names = fieldnames(defaults);
for idx = 1:numel(names)
    if ~isfield(config, names{idx}) || isempty(config.(names{idx}))
        config.(names{idx}) = defaults.(names{idx});
    end
end
end

function opts = build_import_options_beat30()

opts = delimitedTextImportOptions("NumVariables", 13);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["time", "dev_time", "ppg_r", "ppg_ir", "ppg_g", ...
    "acc_x", "acc_y", "acc_z", "slp_SPO2", "slp_HR", "masimo_SPO2", "masimo_HR", "date_time"];
opts.VariableTypes = ["string", "string", "string", "string", "string", ...
    "string", "string", "string", "string", "string", "string", "string", "string"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, opts.VariableNames, "WhitespaceRule", "preserve");
opts = setvaropts(opts, opts.VariableNames, "EmptyFieldRule", "auto");
end

function confidence = calculate_beat30_confidence(beat30, movement, config)

r = beat30.r(:);
beatCount = double(beat30.beatCount(:));
validRatio = double(beat30.validBeatRatio(:));
redPI = double(beat30.redPI(:));
irPI = double(beat30.irPI(:));
movement = double(movement(:));

countScore = clamp01_beat30(beatCount / config.minBeatCount);
validScore = clamp01_beat30((validRatio - 0.45) / max(config.minValidBeatRatio - 0.45, eps));
redScore = clamp01_beat30(redPI / config.redPIReference);
irScore = clamp01_beat30(irPI / config.irPIReference);
piScore = min(redScore, irScore);
motionScore = ones(size(r));
motionScore(movement > config.maxMotion) = max(0.20, 1 - (movement(movement > config.maxMotion) - config.maxMotion) / max(config.maxMotion, 1));

confidence = countScore .* validScore .* piScore .* motionScore;
badMask = ~isfinite(r) | r <= 0 | r >= config.maxR | ...
    ~isfinite(redPI) | ~isfinite(irPI) | ...
    redPI < config.minRedPI | irPI < config.minIRPI | ...
    ~isfinite(validRatio) | validRatio < 0.30;
confidence(badMask) = 0;
confidence = clamp01_beat30(confidence);
end

function [fixedR, smoothedR] = postprocess_beat30_r(rawR, confidence, config)

rawR = double(rawR(:));
confidence = double(confidence(:));
fixedR = nan(size(rawR));
smoothedR = nan(size(rawR));

fixBuffer = nan(config.fixBufferSize, 1);
reliableCounter = 0;

for idx = 1:numel(rawR)
    inputR = rawR(idx);
    inputConfidence = confidence(idx);
    isReliable = isfinite(inputR) && inputR > 0 && inputR < config.maxR && inputConfidence >= config.confidenceThreshold;

    if isReliable
        currentFixedR = inputR;
        reliableCounter = reliableCounter + 1;
        fixBuffer(mod(reliableCounter - 1, config.fixBufferSize) + 1) = currentFixedR;
    else
        fallbackR = finite_median_beat30_local(fixBuffer);
        if ~isfinite(fallbackR)
            fallbackR = config.defaultR;
        end
        if isfinite(inputR) && inputR > 0 && inputR < config.maxR && isfinite(inputConfidence)
            blend = clamp01_beat30(inputConfidence / max(config.confidenceThreshold, eps));
            currentFixedR = fallbackR * (1 - blend) + inputR * blend;
        else
            currentFixedR = fallbackR;
        end
    end

    fixedR(idx) = currentFixedR;
    left = max(1, idx - config.smoothWindowSize + 1);
    smoothedR(idx) = finite_median_beat30_local(fixedR(left:idx));
end
end

function output = mode_or_previous_beat30(inputValues, previousValues, currentIndex)

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

function timeOffset = estimate_negative_r_spo2_offset_beat30(featureR, trueSpO2, maxLagWin, stepSize)

featureR = double(featureR(:));
trueSpO2 = double(trueSpO2(:));
n = min(numel(featureR), numel(trueSpO2));
if n < 5
    timeOffset = 0;
    return
end

featureR = featureR(1:n);
trueSpO2 = trueSpO2(1:n);
lagLimit = min(maxLagWin, floor(n / 2));
bestCorr = -Inf;
bestLag = 0;

for lag = -lagLimit:lagLimit
    if lag >= 0
        x = -featureR(1 + lag:n);
        y = trueSpO2(1:n - lag);
    else
        x = -featureR(1:n + lag);
        y = trueSpO2(1 - lag:n);
    end

    mask = isfinite(x) & isfinite(y) & y > 0;
    if sum(mask) < 5
        continue
    end
    x = x(mask) - mean(x(mask));
    y = y(mask) - mean(y(mask));
    denom = sqrt(sum(x .^ 2)) * sqrt(sum(y .^ 2));
    if denom <= 1e-12
        continue
    end
    corrValue = (x.' * y) / denom;
    if corrValue > bestCorr
        bestCorr = corrValue;
        bestLag = lag;
    end
end

timeOffset = bestLag * stepSize;
end

function [alignedEst, alignedTrue, varargout] = align_series_pair_beat30(estimatedSeries, trueSeries, timeOffset, samplingRate, varargin)

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
for idx = 1:numel(varargin)
    current = varargin{idx};
    current = current(:);
    current = current(1:seriesLength);
    varargout{idx} = current(idxEst);
end
end

function metricRow = build_metric_row_beat30(dataID, featureName, estimatedSpO2, featureR, trueSpO2, ...
    reliableMask, beatCount, validBeatRatio, baseTimeOffset, spo2TimeOffset, prTimeOffset, windowCount)

estimatedSpO2 = double(estimatedSpO2(:));
featureR = double(featureR(:));
trueSpO2 = double(trueSpO2(:));
reliableMask = logical(reliableMask(:));
beatCount = double(beatCount(:));
validBeatRatio = double(validBeatRatio(:));

[rSnr, rSnrDb] = feature_r_snr_beat30(featureR, trueSpO2);

metricRow = table(dataID, string(featureName), ...
    series_rmse_beat30(estimatedSpO2, trueSpO2), ...
    safe_corr_beat30(estimatedSpO2, trueSpO2), ...
    std_ratio_beat30(estimatedSpO2, trueSpO2), ...
    low_spo2_recall_beat30(estimatedSpO2, trueSpO2, 92, 94), ...
    safe_corr_beat30(featureR, trueSpO2), ...
    safe_corr_beat30(-featureR, trueSpO2), ...
    rSnr, rSnrDb, ...
    mean(reliableMask, 'omitnan'), ...
    mean(beatCount, 'omitnan'), ...
    mean(validBeatRatio, 'omitnan'), ...
    baseTimeOffset, spo2TimeOffset, prTimeOffset, baseTimeOffset + spo2TimeOffset, ...
    windowCount, ...
    'VariableNames', metric_variable_names_beat30());
end

function names = metric_variable_names_beat30()

names = {'dataID', 'featureName', 'spo2Rmse', 'spo2Corr', 'spo2StdRatio', ...
    'lowRecall', 'rSpO2Corr', 'rTrackingCorr', 'rSnr', 'rSnrDb', ...
    'reliableRatio', 'meanBeatCount', 'meanBeatValidRatio', ...
    'baseTimeOffset', 'spo2TimeOffset', 'prTimeOffset', 'totalSpo2Offset', 'windowCount'};
end

function summaryTable = summarize_feature_metrics_beat30(perDataMetricsTable)

featureNames = unique(perDataMetricsTable.featureName, 'stable');
summaryTable = table();

for idx = 1:numel(featureNames)
    featureName = featureNames(idx);
    rows = perDataMetricsTable(perDataMetricsTable.featureName == featureName, :);
    currentSummary = table(featureName, height(rows), ...
        mean(rows.spo2Rmse, 'omitnan'), mean(rows.spo2Corr, 'omitnan'), ...
        mean(rows.lowRecall, 'omitnan'), mean(rows.rTrackingCorr, 'omitnan'), ...
        mean(rows.rSnr, 'omitnan'), mean(rows.rSnrDb, 'omitnan'), ...
        mean(rows.reliableRatio, 'omitnan'), mean(rows.meanBeatCount, 'omitnan'), ...
        mean(rows.meanBeatValidRatio, 'omitnan'), ...
        'VariableNames', {'featureName', 'dataCount', 'avgSpO2Rmse', 'avgSpO2Corr', ...
        'avgLowRecall', 'avgRTrackingCorr', 'avgRSnr', 'avgRSnrDb', ...
        'avgReliableRatio', 'avgBeatCount', 'avgBeatValidRatio'});
    summaryTable = [summaryTable; currentSummary]; %#ok<AGROW>
end
end

function [snrRatio, snrDb] = feature_r_snr_beat30(featureSeries, trueSpO2)

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

function output = series_rmse_beat30(estimatedSeries, trueSeries)

estimatedSeries = double(estimatedSeries(:));
trueSeries = double(trueSeries(:));
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
if ~any(validMask)
    output = NaN;
else
    errorValues = estimatedSeries(validMask) - trueSeries(validMask);
    output = sqrt(mean(errorValues .^ 2));
end
end

function output = safe_corr_beat30(inputA, inputB)

inputA = double(inputA(:));
inputB = double(inputB(:));
validMask = isfinite(inputA) & isfinite(inputB) & inputA > -Inf & inputB > 0;
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

function output = std_ratio_beat30(estimatedSeries, trueSeries)

estimatedSeries = double(estimatedSeries(:));
trueSeries = double(trueSeries(:));
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
if sum(validMask) < 5 || std(trueSeries(validMask)) <= 1e-12
    output = NaN;
else
    output = std(estimatedSeries(validMask)) / std(trueSeries(validMask));
end
end

function output = low_spo2_recall_beat30(estimatedSeries, trueSeries, trueThreshold, estimatedThreshold)

estimatedSeries = double(estimatedSeries(:));
trueSeries = double(trueSeries(:));
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
eventMask = validMask & trueSeries <= trueThreshold;

if ~any(eventMask)
    output = NaN;
else
    output = sum(estimatedSeries(eventMask) <= estimatedThreshold) / sum(eventMask);
end
end

function output = finite_median_beat30_local(inputValues)

inputValues = inputValues(isfinite(inputValues));
if isempty(inputValues)
    output = NaN;
else
    output = median(inputValues);
end
end

function output = clamp01_beat30(inputValues)

output = min(max(inputValues, 0), 1);
end

function plot_beat30_data(dataID, outputDir, trueSpO2, currentSpO2, beat30SpO2, beat30R, confidence, reliableMask)

figure(301);
clf;
subplot(3, 1, 1);
plot(trueSpO2, 'k', 'LineWidth', 1.0); hold on;
plot(currentSpO2, 'Color', [0.20, 0.45, 0.90], 'LineWidth', 0.8);
plot(beat30SpO2, 'Color', [0.85, 0.20, 0.20], 'LineWidth', 0.8);
scatter(find(~reliableMask), beat30SpO2(~reliableMask), 6, 'filled', 'MarkerFaceColor', [0.75, 0.75, 0.75]);
ylim([65, 100]);
legend('True SpO2', 'Current SpO2', 'Beat30 SpO2', 'Beat30 low confidence', 'Location', 'best');
title(sprintf('Data %d Beat30 SpO2', dataID));
grid on;

subplot(3, 1, 2);
plot(-beat30R, 'Color', [0.85, 0.20, 0.20], 'LineWidth', 0.8);
ylabel('-beat30 R');
grid on;

subplot(3, 1, 3);
plot(confidence, 'Color', [0.10, 0.55, 0.25], 'LineWidth', 0.8);
ylim([0, 1.05]);
ylabel('confidence');
xlabel('window index');
grid on;

print(gcf, '-dpng', fullfile(outputDir, sprintf('Data_%d_beat30_overview.png', dataID)), '-r200');
end
