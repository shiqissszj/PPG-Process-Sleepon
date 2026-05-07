clear;
clc;

% Export calibration-ready (smoothedR, trueSpO2) pairs from the current
% SpO2_PR_main.m pipeline.
%
% This script follows the current ppg_process.m logic, but exposes rawR,
% fixedR and smoothedR so SpO2 fitting can use the same R value that is
% passed into calculate_spo2(smoothedR).

dataIDList = [182,183,184,187,188,193,194,196,197,198,200, ...
    201,203,204,206,207,208,209,210,211,212,213,214,215,216, ...
    217,218,219,220,221,222,223,224,225,226,227,228,230,231, ...
    1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012, ...
    1013,1016,1017,1018,1019,1020,1021,1022,1023,1024,1025,1026,1027,1028,1029];

autoTimeOffset = true;
maxReferencePR = 100;

samplingRate = 50;
windowLength = 3;
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate;
confidenceThreshold = 0.75;

opts = delimitedTextImportOptions("NumVariables", 13);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["time", "dev_time", "ppg_r", "ppg_ir", "ppg_g", "acc_x", "acc_y", "acc_z", "slp_SPO2", "slp_HR", "masimo_SPO2", "masimo_HR", "date_time"];
opts.VariableTypes = ["string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, opts.VariableNames, "WhitespaceRule", "preserve");
opts = setvaropts(opts, opts.VariableNames, "EmptyFieldRule", "auto");

R_SpO2_values_current = cell(length(dataIDList), 1);
R_SpO2_details_current = cell(length(dataIDList), 1);
offsetSummary = zeros(length(dataIDList), 4);

globalPairs = [];
globalDetails = [];

for k = 1:length(dataIDList)
    dataID = dataIDList(k);

    [filename, time_offset, drop_num_start, drop_num_end] = get_filename(dataID);
    baseTimeOffset = time_offset;
    data = readmatrix(filename, opts);

    rowCount = size(data, 1);
    sensorStart = drop_num_start - time_offset + 1;
    sensorEnd = rowCount - drop_num_end - time_offset;
    refStart = drop_num_start + 1;
    refEnd = rowCount - drop_num_end;

    if sensorStart < 1 || refStart < 1 || sensorEnd > rowCount || refEnd > rowCount || sensorStart > sensorEnd || refStart > refEnd
        warning('Skipping dataID %d because the trimmed ranges are invalid.', dataID);
        continue
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

    num_windows = floor((length(ppg_r) - windowSize) / stepSize) + 1;
    if num_windows <= 0
        warning('Skipping dataID %d because it has too few samples.', dataID);
        continue
    end

    estimatedSpO2Values = zeros(num_windows, 1);
    rawRValues = zeros(num_windows, 1);
    fixedRValues = zeros(num_windows, 1);
    smoothedRValues = zeros(num_windows, 1);
    PRValues = zeros(num_windows, 1);
    trueSPO2 = zeros(num_windows, 1);
    truePR = zeros(num_windows, 1);
    confidenceValues = zeros(num_windows, 1);
    windowIndices = zeros(num_windows, 1);

    windowCounter = 0;

    for i = 1:size(ppg_r, 1)
        [outputFlag, outputPR, outputSpO2, ~, confidence, rawR, fixedR, smoothedR] = ...
            process_sample_for_calibration(single(ppg_r(i)), single(ppg_ir(i)), single(ppg_g(i)), uint32(i), single(bodyMove(i)));

        if outputFlag
            windowCounter = windowCounter + 1;
            windowIndices(windowCounter) = windowCounter;
            estimatedSpO2Values(windowCounter) = outputSpO2;
            rawRValues(windowCounter) = rawR;
            fixedRValues(windowCounter) = fixedR;
            smoothedRValues(windowCounter) = smoothedR;
            PRValues(windowCounter) = outputPR;
            confidenceValues(windowCounter) = confidence;

            tmpSPO2 = checkme_SPO2(i - stepSize + 1:i);
            tmpPR = checkme_PR(i - stepSize + 1:i);

            trueSPO2(windowCounter) = mode(tmpSPO2(tmpSPO2 > 0));
            if isnan(trueSPO2(windowCounter)) && windowCounter > 1
                trueSPO2(windowCounter) = trueSPO2(windowCounter - 1);
            end

            truePR(windowCounter) = mode(tmpPR(tmpPR > 0));
            if isnan(truePR(windowCounter)) && windowCounter > 1
                truePR(windowCounter) = truePR(windowCounter - 1);
            end
            if isfinite(maxReferencePR) && maxReferencePR > 0
                truePR(windowCounter) = min(truePR(windowCounter), maxReferencePR);
            end
        end
    end

    estimatedSpO2Values = estimatedSpO2Values(1:windowCounter);
    rawRValues = rawRValues(1:windowCounter);
    fixedRValues = fixedRValues(1:windowCounter);
    smoothedRValues = smoothedRValues(1:windowCounter);
    PRValues = PRValues(1:windowCounter);
    trueSPO2 = trueSPO2(1:windowCounter);
    truePR = truePR(1:windowCounter);
    confidenceValues = confidenceValues(1:windowCounter);
    windowIndices = windowIndices(1:windowCounter);

    pr_time_offset = 0;
    spo2_time_offset = 0;

    if autoTimeOffset
        try
            pr_est_offset = estimate_time_offset(PRValues(:), truePR(:), 120, stepSize);
            if isfinite(pr_est_offset)
                pr_time_offset = pr_est_offset;
            end
        catch
        end

        try
            spo2_est_offset = estimate_time_offset(estimatedSpO2Values(:), trueSPO2(:), 120, stepSize);
            if isfinite(spo2_est_offset)
                spo2_time_offset = spo2_est_offset;
            end
        catch
        end
    end

    [alignedSpO2Est, alignedSpO2True, alignedConfidence, alignedRawR, alignedFixedR, alignedSmoothedR, alignedWindowIndex] = ...
        align_series_pair(estimatedSpO2Values, trueSPO2, spo2_time_offset, samplingRate, ...
        confidenceValues, rawRValues, fixedRValues, smoothedRValues, windowIndices);
    [alignedPREst, alignedPRTrue] = align_series_pair(PRValues, truePR, pr_time_offset, samplingRate);

    validMask = alignedConfidence > confidenceThreshold & ...
        isfinite(alignedSmoothedR) & alignedSmoothedR > 0 & ...
        isfinite(alignedSpO2True) & alignedSpO2True >= 65 & alignedSpO2True <= 100;

    R_SpO2_values_current{k} = [alignedSmoothedR(validMask), alignedSpO2True(validMask)];
    R_SpO2_details_current{k} = [ ...
        repmat(dataID, sum(validMask), 1), ...
        alignedWindowIndex(validMask), ...
        alignedSmoothedR(validMask), ...
        alignedRawR(validMask), ...
        alignedFixedR(validMask), ...
        alignedSpO2Est(validMask), ...
        alignedSpO2True(validMask), ...
        alignedConfidence(validMask), ...
        repmat(spo2_time_offset, sum(validMask), 1), ...
        repmat(pr_time_offset, sum(validMask), 1), ...
        repmat(baseTimeOffset, sum(validMask), 1)];

    offsetSummary(k, :) = [dataID, baseTimeOffset, spo2_time_offset, pr_time_offset];

    globalPairs = [globalPairs; R_SpO2_values_current{k}];
    globalDetails = [globalDetails; R_SpO2_details_current{k}];

    validPRMask = alignedPREst > 0 & alignedPRTrue > 0 & isfinite(alignedPREst) & isfinite(alignedPRTrue);
    spo2RMSE = rmse(alignedSpO2Est, alignedSpO2True, "omitnan");
    reliableRMSE = rmse(alignedSpO2Est(validMask), alignedSpO2True(validMask), "omitnan");
    prRMSE = rmse(alignedPREst(validPRMask), alignedPRTrue(validPRMask), "omitnan");

    fprintf('Data No. %d\n', dataID);
    fprintf('Valid calibration pairs: %d / %d\n', sum(validMask), windowCounter);
    fprintf('Overall SpO2 RMSE %.2f\n', spo2RMSE);
    fprintf('Reliable SpO2 RMSE %.2f\n', reliableRMSE);
    fprintf('PR RMSE %.2f\n', prRMSE);
    fprintf('Base time offset from get_filename (samples): %d\n', baseTimeOffset);
    fprintf('Auto SpO2 offset (samples): %d\n', spo2_time_offset);
    fprintf('Auto PR offset (samples): %d\n', pr_time_offset);
    if any(validMask)
        fprintf('Mean confidence: %.3f\n', mean(alignedConfidence(validMask), 'omitnan'));
        fprintf('Smoothed-R range: [%.3f, %.3f]\n', min(alignedSmoothedR(validMask)), max(alignedSmoothedR(validMask)));
        fprintf('True-SpO2 range: [%.1f, %.1f]\n', min(alignedSpO2True(validMask)), max(alignedSpO2True(validMask)));
    end
end

R_SpO2_values = R_SpO2_values_current;
R_SpO2_details = R_SpO2_details_current;

fprintf('================ Calibration Export Summary ================\n');
fprintf('Data IDs processed: %d\n', length(dataIDList));
fprintf('Confidence threshold: %.2f\n', confidenceThreshold);
fprintf('Global calibration pairs: %d\n', size(globalPairs, 1));

save('R_SpO2_values_current.mat', 'R_SpO2_values_current', 'R_SpO2_values', 'confidenceThreshold', 'offsetSummary');
save('R_SpO2_calibration_export_current.mat', ...
    'R_SpO2_values_current', 'R_SpO2_details_current', 'R_SpO2_values', 'R_SpO2_details', ...
    'globalPairs', 'globalDetails', 'offsetSummary', 'dataIDList', 'confidenceThreshold', ...
    'samplingRate', 'windowLength', 'stepSize', 'autoTimeOffset', 'maxReferencePR');

function [outputFlag, outputPR, outputSpO2, outputPI, confidenceR, rawR, fixedR, smoothedR] = ...
    process_sample_for_calibration(inputSampleR, inputSampleIR, inputSampleG, inputCounter, bodyMove)

samplingRate = uint32(50);
windowLength = 3;
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate;

persistent windowR;
persistent windowIR;
persistent windowG;
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
if isempty(windowR)
    windowR = zeros(windowSize, 1, 'single');
end
if isempty(windowIR)
    windowIR = zeros(windowSize, 1, 'single');
end
if isempty(windowG)
    windowG = zeros(windowSize, 1, 'single');
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

    [rawR, PR, PI, confidenceR, confidenceG] = r_pr_calculation(windowR, windowIR, windowG, samplingRate, outputCounter, bodyMove);
    [fixedR, fixedPR, confidenceR] = r_pr_fix(rawR, PR, confidenceR, confidenceG, outputCounter);
    smoothedR = r_smoothing(fixedR, outputCounter);
    smoothedPR = pr_smoothing(fixedPR, outputCounter);

    outputPR = round(smoothedPR);
    outputSpO2 = calculate_spo2(smoothedR);
    outputPI = PI;
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

function varargout = align_series_pair(estimatedSeries, trueSeries, time_offset, samplingRate, varargin)

seriesLength = min(numel(estimatedSeries), numel(trueSeries));
for idx = 1:length(varargin)
    seriesLength = min(seriesLength, numel(varargin{idx}));
end

estimatedSeries = estimatedSeries(1:seriesLength);
trueSeries = trueSeries(1:seriesLength);
for idx = 1:length(varargin)
    varargin{idx} = varargin{idx}(1:seriesLength);
end

offsetWindows = round(time_offset / samplingRate);
auxCount = length(varargin);
varargout = cell(2 + auxCount, 1);

if seriesLength == 0 || abs(offsetWindows) >= seriesLength
    for idx = 1:(2 + auxCount)
        varargout{idx} = [];
    end
    return
end

if offsetWindows >= 0
    keepCount = seriesLength - offsetWindows;
    varargout{1} = estimatedSeries(offsetWindows + 1:seriesLength);
    varargout{2} = trueSeries(1:keepCount);
    for idx = 1:auxCount
        varargout{2 + idx} = varargin{idx}(offsetWindows + 1:seriesLength);
    end
else
    trueShift = -offsetWindows;
    keepCount = seriesLength - trueShift;
    varargout{1} = estimatedSeries(1:keepCount);
    varargout{2} = trueSeries(trueShift + 1:seriesLength);
    for idx = 1:auxCount
        varargout{2 + idx} = varargin{idx}(1:keepCount);
    end
end
end
