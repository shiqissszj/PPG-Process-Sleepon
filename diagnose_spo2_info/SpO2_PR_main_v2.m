% clear;
% clc;

% V2 offline validation entry.
% Keeps the current green-template R path and adds beat-level R features.
% Green is used only for beat timing in calculate_beat_level_r_series_v2.

% 20260202 regression
% remove 195,199,202,229
% dataIDList = [182,183,184,187,188,193,194,196,197,198,200, ...
%     201,203,204,206,207,208,209,210,211,212,213,214,215,216, ...
%     217,218,219,220,221,222,223,224,225,226,227,228,230,231,1001,1002,1003, ...
%     1004,1005,1006,1007,1008,1009,1010,1011,1012,1013,1014,1015,1016,1017,1018, ...
%     1019,1020,1021,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014];

% dataIDList = [1001,1002,1003, ...
%     1004,1005,1006,1007,1008,1009,1010,1011,1012,1013,1014,1015,1016,1017,1018, ...
%     1019,1020,1022,1023];

% dataIDList = [182,183,184,187,188,193,194,196,197,198,200, ...
%     201,203,204,206,207,208,209,210,211,212,213,214,215,216, ...
%     217,218,219,220,221,222,223,224,225,226,227,228,230,231];

dataIDList = 1025;
autoTimeOffset = true;
savePlots = true;

projectDir = fileparts(mfilename('fullpath'));
if isempty(projectDir)
    projectDir = pwd;
end
outputDir = fullfile(projectDir, 'diagnostics_v2');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

R_SpO2_values_v2 = cell(length(dataIDList), 1);
metricsTables = cell(length(dataIDList), 1);
spo2RMSEList = nan(length(dataIDList), 1);
prRMSEList = nan(length(dataIDList), 1);

samplingRate = 50; % Sampling rate in Hz
windowLength = 3; % Window length in seconds
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate; % 1 second step

confidenceTheshold = 0.75;
segmentWindowSeconds = 300;
segmentStepSeconds = 300;
qualityDebugCount = 21;

opts = delimitedTextImportOptions("NumVariables", 13);

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["time", "dev_time", "ppg_r", "ppg_ir", "ppg_g", "acc_x", "acc_y", "acc_z", "slp_SPO2", "slp_HR", "masimo_SPO2", "masimo_HR", "date_time"];
opts.VariableTypes = ["string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["time", "dev_time", "ppg_r", "ppg_ir", "ppg_g", "acc_x", "acc_y", "acc_z", "slp_SPO2", "slp_HR", "masimo_SPO2", "masimo_HR", "date_time"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["time", "dev_time", "ppg_r", "ppg_ir", "ppg_g", "acc_x", "acc_y", "acc_z", "slp_SPO2", "slp_HR", "masimo_SPO2", "masimo_HR", "date_time"], "EmptyFieldRule", "auto");

for k = 1:length(dataIDList)

    clear ppg_process_v2 r_pr_calculation_v2 r_pr_fix_v2 r_smoothing_v2 pr_smoothing_v2

    % read data from file
    dataID = dataIDList(k);

    [filename,time_offset,drop_num_start,drop_num_end] = get_filename_v2(dataID);
    baseTimeOffset = time_offset;

    % Read the matrix from the file
    data = readmatrix(filename, opts);

    sensorStart = drop_num_start - time_offset + 1;
    sensorEnd = size(data,1) - drop_num_end - time_offset;
    refStart = drop_num_start + 1;
    refEnd = size(data,1) - drop_num_end;

    sensor_data = str2double(data(sensorStart:sensorEnd, [3,4,5]));
    time_data = datetime(data(sensorStart:sensorEnd, 11));
    bodyMove = str2double(data(sensorStart:sensorEnd, 10));
    checkme_PR = str2double(data(refStart:refEnd, 7));
    checkme_SPO2 = str2double(data(refStart:refEnd, 6));

    ppg_r = sensor_data(:, 1);
    ppg_ir = sensor_data(:, 2);
    ppg_g = sensor_data(:, 3);

    % for validation
    num_windows = floor((length(ppg_r) - windowSize) / stepSize) + 1;
    currentSpO2Values = nan(num_windows, 1);
    rawRValues = nan(num_windows, 1);
    fixedRValues = nan(num_windows, 1);
    currentRValues = nan(num_windows, 1);
    classicRValues = nan(num_windows, 1);
    redAcDcValues = nan(num_windows, 1);
    irAcDcValues = nan(num_windows, 1);
    PRValues = nan(num_windows, 1);
    SQIValues = nan(num_windows, 6);
    trueSPO2 = nan(num_windows, 1);
    truePR = nan(num_windows, 1);
    confidenceValues = nan(num_windows, 1);
    windowEndSample = nan(num_windows, 1);
    windowTime = NaT(num_windows, 1);
    qualityDebugValues = nan(num_windows, qualityDebugCount);

    windowCounter = 0;

    for i = 1:size(ppg_r,1)

        [outputFlag, outputPR, outputSpO2, outputPI, confidence, rawR, fixedR, currentR, classicR, redAcDc, irAcDc, qualityDebug] = ...
            ppg_process_v2(single(ppg_r(i)),single(ppg_ir(i)),single(ppg_g(i)), uint32(i), single(bodyMove(i)));
        if outputFlag
            windowCounter = windowCounter+1;
            currentSpO2Values(windowCounter) = outputSpO2;
            PRValues(windowCounter) = outputPR;
            SQIValues(windowCounter,:) = outputPI;
            confidenceValues(windowCounter) = confidence;
            rawRValues(windowCounter) = rawR;
            fixedRValues(windowCounter) = fixedR;
            currentRValues(windowCounter) = currentR;
            classicRValues(windowCounter) = classicR;
            redAcDcValues(windowCounter) = redAcDc;
            irAcDcValues(windowCounter) = irAcDc;
            windowEndSample(windowCounter) = i;
            windowTime(windowCounter) = time_data(i);

            copyCount = min(numel(qualityDebug), qualityDebugCount);
            qualityDebugValues(windowCounter, 1:copyCount) = double(qualityDebug(1:copyCount));

            tmpSPO2 = checkme_SPO2(i-samplingRate+1:i);
            tmpPR = checkme_PR(i-samplingRate+1:i);
            trueSPO2(windowCounter) = mode_or_previous(tmpSPO2, trueSPO2, windowCounter);
            truePR(windowCounter) = min(mode_or_previous(tmpPR, truePR, windowCounter), 100);
        end
    end

    currentSpO2Values = currentSpO2Values(1:windowCounter);
    rawRValues = rawRValues(1:windowCounter);
    fixedRValues = fixedRValues(1:windowCounter);
    currentRValues = currentRValues(1:windowCounter);
    classicRValues = classicRValues(1:windowCounter);
    redAcDcValues = redAcDcValues(1:windowCounter);
    irAcDcValues = irAcDcValues(1:windowCounter);
    PRValues = PRValues(1:windowCounter);
    SQIValues = SQIValues(1:windowCounter, :);
    confidenceValues = confidenceValues(1:windowCounter);
    trueSPO2 = trueSPO2(1:windowCounter);
    truePR = truePR(1:windowCounter);
    windowEndSample = windowEndSample(1:windowCounter);
    windowTime = windowTime(1:windowCounter);
    qualityDebugValues = qualityDebugValues(1:windowCounter, :);

    beat15 = calculate_beat_level_r_series_v2(ppg_r, ppg_ir, ppg_g, samplingRate, windowEndSample, 15);
    beat30 = calculate_beat_level_r_series_v2(ppg_r, ppg_ir, ppg_g, samplingRate, windowEndSample, 30);
    beat60 = calculate_beat_level_r_series_v2(ppg_r, ppg_ir, ppg_g, samplingRate, windowEndSample, 60);

    pr_time_offset = 0;
    spo2_time_offset = 0;

    if autoTimeOffset
        try
            pr_est_offset = estimate_time_offset_v2(PRValues(:), truePR(:), 120, stepSize);
            if isfinite(pr_est_offset)
                pr_time_offset = pr_est_offset;
            end
        catch
        end

        try
            spo2_est_offset = estimate_time_offset_v2(currentSpO2Values(:), trueSPO2(:), 120, stepSize);
            if isfinite(spo2_est_offset)
                spo2_time_offset = spo2_est_offset;
            end
        catch
        end
    end

    [alignedCurrentSpO2, alignedSpO2True, alignedIdxEst, alignedIdxTrue] = ...
        align_series_with_indices(currentSpO2Values, trueSPO2, spo2_time_offset, samplingRate);
    [alignedPREst, alignedPRTrue] = ...
        align_series_pair(PRValues, truePR, pr_time_offset, samplingRate);

    alignedRawR = rawRValues(alignedIdxEst);
    alignedFixedR = fixedRValues(alignedIdxEst);
    alignedCurrentR = currentRValues(alignedIdxEst);
    alignedClassicR = classicRValues(alignedIdxEst);
    alignedRedAcDc = redAcDcValues(alignedIdxEst);
    alignedIRAcDc = irAcDcValues(alignedIdxEst);
    alignedConfidence = confidenceValues(alignedIdxEst);
    alignedWindowEndSample = windowEndSample(alignedIdxEst);
    alignedWindowTime = windowTime(alignedIdxEst);
    alignedTruePRForSpO2Offset = truePR(alignedIdxTrue);
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

    alignedRawSpO2 = calculate_spo2_v2(alignedRawR);
    alignedFixedSpO2 = calculate_spo2_v2(alignedFixedR);
    alignedClassicSpO2 = calculate_spo2_v2(alignedClassicR);

    validPRMask = alignedPREst > 0 & alignedPRTrue > 0 & isfinite(alignedPREst) & isfinite(alignedPRTrue);
    plotPREst = alignedPREst;
    plotPREst(~validPRMask) = nan;

    overallRMSE = series_rmse(alignedCurrentSpO2, alignedSpO2True);
    reliableMask = alignedConfidence > confidenceTheshold;
    reliableRMSE = series_rmse(alignedCurrentSpO2(reliableMask), alignedSpO2True(reliableMask));
    reliableRatio = sum(reliableMask) / max(1, numel(alignedConfidence));
    prRMSE = series_rmse(alignedPREst(validPRMask), alignedPRTrue(validPRMask));

    qualityNames = ["redPI", "irPI", "greenPI", ...
        "xcorrR_G", "xcorrIR_G", "xcorrR_IR", ...
        "acorrR", "acorrIR", "acorrG", "lowLagCorrG", ...
        "usedSampleRatio", "delayR", "delayIR", "outlierRatioG", ...
        "greenIRProjectionGuardRatio", "projectionSignMismatch", ...
        "spo2WindowConfidence", "signalConfidence", ...
        "dcRMean", "dcIRMean", "dcGMean"];

    windowTable = table((1:numel(alignedSpO2True))', alignedWindowEndSample, ...
        string(alignedWindowTime), alignedSpO2True, alignedCurrentSpO2, ...
        alignedRawSpO2, alignedFixedSpO2, alignedClassicSpO2, ...
        alignedBeat15SpO2, alignedBeat30SpO2, alignedBeat60SpO2, ...
        alignedCurrentR, alignedBeat15R, alignedBeat30R, alignedBeat60R, ...
        alignedRawR, alignedFixedR, alignedClassicR, ...
        alignedRedAcDc, alignedIRAcDc, ...
        alignedBeat15RedPI, alignedBeat30RedPI, alignedBeat60RedPI, ...
        alignedBeat15IRPI, alignedBeat30IRPI, alignedBeat60IRPI, ...
        alignedBeat15GreenPI, alignedBeat30GreenPI, alignedBeat60GreenPI, ...
        alignedBeat15Count, alignedBeat30Count, alignedBeat60Count, ...
        alignedBeat15ValidRatio, alignedBeat30ValidRatio, alignedBeat60ValidRatio, ...
        alignedConfidence, PRValues(alignedIdxEst), alignedTruePRForSpO2Offset, ...
        'VariableNames', {'windowIndex', 'endSample', 'time', 'trueSpO2', ...
        'currentSpO2', 'rawRSpO2', 'fixedRSpO2', 'classicRSpO2', ...
        'beat15SpO2', 'beat30SpO2', 'beat60SpO2', ...
        'currentR', 'beat15R', 'beat30R', 'beat60R', ...
        'rawR', 'fixedR', 'classicR', 'redAcDc', 'irAcDc', ...
        'beat15RedPI', 'beat30RedPI', 'beat60RedPI', ...
        'beat15IRPI', 'beat30IRPI', 'beat60IRPI', ...
        'beat15GreenPI', 'beat30GreenPI', 'beat60GreenPI', ...
        'beat15Count', 'beat30Count', 'beat60Count', ...
        'beat15ValidRatio', 'beat30ValidRatio', 'beat60ValidRatio', ...
        'confidenceR', 'PR', 'truePR'});

    qualityTable = array2table(alignedQualityDebug, 'VariableNames', cellstr(qualityNames));
    windowTable = [windowTable, qualityTable];

    metricsTable = build_feature_metrics_table(windowTable);
    segmentTable = build_segment_follow_table(windowTable, segmentWindowSeconds, segmentStepSeconds);

    windowCsv = fullfile(outputDir, sprintf('Data_%d_spo2_v2_windows.csv', dataID));
    metricsCsv = fullfile(outputDir, sprintf('Data_%d_spo2_v2_metrics.csv', dataID));
    segmentCsv = fullfile(outputDir, sprintf('Data_%d_spo2_v2_segments.csv', dataID));
    writetable(windowTable, windowCsv);
    writetable(metricsTable, metricsCsv);
    writetable(segmentTable, segmentCsv);

    currentMetric = metricsTable(metricsTable.featureName == "current", :);
    beat30Metric = metricsTable(metricsTable.featureName == "beat30", :);

    figure(1); clf;
    plot(alignedCurrentSpO2, 'Color', [0.0000 0.4470 0.7410], 'LineWidth', 1.1); hold on;
    plot(alignedSpO2True, 'Color', [0.15 0.15 0.15], 'LineWidth', 1.0);
    scatter(find(~reliableMask), alignedCurrentSpO2(~reliableMask), 8, 'filled', 'MarkerFaceColor', "#D95319")
    hold off;
    grid on;
    ylim([65, 100]);
    xlabel('Window index');
    ylabel('SpO2 (%)');
    legend('Current R -> SpO2', 'True SpO2', 'low confidence current', ...
        'Location','northoutside','NumColumns', 3);
    title(append('Fig1 Current R SpO2 ', string(dataID)));
    add_metric_text(currentMetric, sprintf('RMSE %.2f | corr %.2f | R_SNR %.2f dB', ...
        currentMetric.spo2Rmse, currentMetric.spo2Corr, currentMetric.rSnrDb));
    safe_save_figure(gcf, outputDir, dataID, '01_current_spo2', savePlots);

    figure(2); clf;
    plot(alignedBeat30SpO2, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.1); hold on;
    plot(alignedSpO2True, 'Color', [0.15 0.15 0.15], 'LineWidth', 1.0);
    hold off;
    grid on;
    ylim([65, 100]);
    xlabel('Window index');
    ylabel('SpO2 (%)');
    legend('Beat30 R -> SpO2', 'True SpO2', 'Location','northoutside','NumColumns', 2);
    title(append('Fig2 Beat30 R SpO2 ', string(dataID)));
    add_metric_text(beat30Metric, sprintf('RMSE %.2f | corr %.2f | R_SNR %.2f dB | beats %.1f | valid %.2f', ...
        beat30Metric.spo2Rmse, beat30Metric.spo2Corr, beat30Metric.rSnrDb, ...
        beat30Metric.meanBeatCount, beat30Metric.meanBeatValidRatio));
    safe_save_figure(gcf, outputDir, dataID, '02_beat30_spo2', savePlots);

    figure(3); clf;
    plot(alignedCurrentSpO2, 'Color', [0.0000 0.4470 0.7410], 'LineWidth', 1.0); hold on;
    plot(alignedBeat30SpO2, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.0);
    plot(alignedSpO2True, 'Color', [0.15 0.15 0.15], 'LineWidth', 1.0);
    hold off;
    grid on;
    ylim([65, 100]);
    xlabel('Window index');
    ylabel('SpO2 (%)');
    legend('Current R -> SpO2', 'Beat30 R -> SpO2', 'True SpO2', ...
        'Location','northoutside','NumColumns', 3);
    title(append('Fig3 Current vs Beat30 vs True SpO2 ', string(dataID)));
    add_metric_text(beat30Metric, sprintf('current RMSE %.2f, corr %.2f | beat30 RMSE %.2f, corr %.2f', ...
        currentMetric.spo2Rmse, currentMetric.spo2Corr, beat30Metric.spo2Rmse, beat30Metric.spo2Corr));
    safe_save_figure(gcf, outputDir, dataID, '03_current_beat30_true_spo2', savePlots);

    reliableCurrentMask = reliableMask & isfinite(alignedCurrentR) & isfinite(alignedSpO2True);
    R_SpO2_values_v2{k} = [alignedCurrentR(reliableCurrentMask), ...
        alignedBeat30R(reliableCurrentMask), alignedSpO2True(reliableCurrentMask)];
    metricsTables{k} = metricsTable;

    fprintf('Data No. %d V2\n', dataID)
    fprintf('Overall current SpO2 RMSE %.2f\n', overallRMSE)
    fprintf('Reliable current SpO2 RMSE %.2f\n', reliableRMSE)
    fprintf('PR RMSE %.2f\n', prRMSE)
    fprintf('Reliable ratio: %.2f\n', reliableRatio)
    fprintf('Base time offset from get_filename (samples): %d\n', baseTimeOffset)
    fprintf('Auto SpO2 offset (samples): %d\n', spo2_time_offset)
    fprintf('Auto PR offset (samples): %d\n', pr_time_offset)
    fprintf('Total SpO2 offset (samples): %d\n', baseTimeOffset + spo2_time_offset)
    fprintf('Total PR offset (samples): %d\n', baseTimeOffset + pr_time_offset)
    fprintf('Window number: %d\n', num_windows)
    fprintf('Window CSV: %s\n', windowCsv)
    fprintf('Metrics CSV: %s\n', metricsCsv)
    fprintf('Segment CSV: %s\n', segmentCsv)
    fprintf('Current R metrics: RMSE %.2f, corr %.3f, R_SNR %.2f dB, valid ratio %.3f, red/IR PI %.6f / %.6f\n', ...
        currentMetric.spo2Rmse, currentMetric.spo2Corr, currentMetric.rSnrDb, ...
        currentMetric.validRatio, currentMetric.meanRedPI, currentMetric.meanIRPI)
    fprintf('Beat30 R metrics: RMSE %.2f, corr %.3f, R_SNR %.2f dB, effective beats %.1f, valid ratio %.3f, red/IR PI %.6f / %.6f\n', ...
        beat30Metric.spo2Rmse, beat30Metric.spo2Corr, beat30Metric.rSnrDb, ...
        beat30Metric.meanBeatCount, beat30Metric.meanBeatValidRatio, ...
        beat30Metric.meanRedPI, beat30Metric.meanIRPI)
    disp(metricsTable(ismember(metricsTable.featureName, ["current", "beat30"]), :))

    spo2RMSEList(k) = overallRMSE;
    prRMSEList(k) = prRMSE;

end

avgSpO2RMSE = mean(spo2RMSEList, 'omitnan');
avgPRRMSE = mean(prRMSEList, 'omitnan');

fprintf('\nAverage current SpO2 RMSE %.2f\n', avgSpO2RMSE)
fprintf('Average PR RMSE %.2f\n', avgPRRMSE)
save(fullfile(outputDir, 'R_SpO2_values_v2.mat'), 'R_SpO2_values_v2', 'metricsTables')

function add_metric_text(~, textString)

xLimits = xlim;
yLimits = ylim;
xPosition = xLimits(1) + 0.01 * (xLimits(2) - xLimits(1));
yPosition = yLimits(1) + 0.08 * (yLimits(2) - yLimits(1));
text(xPosition, yPosition, textString, 'FontSize', 10, ...
    'BackgroundColor', [1 1 1], 'Margin', 4);
end

function output = mode_or_previous(inputValues, previousValues, currentIndex)

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

function metricsTable = build_feature_metrics_table(windowTable)

featureName = ["current"; "beat15"; "beat30"; "beat60"; "raw"; "fixed"; "classic"; "redPI"; "irPI"];
featureColumn = ["currentR"; "beat15R"; "beat30R"; "beat60R"; "rawR"; "fixedR"; "classicR"; "redAcDc"; "irAcDc"];
spo2Column = ["currentSpO2"; "beat15SpO2"; "beat30SpO2"; "beat60SpO2"; "rawRSpO2"; "fixedRSpO2"; "classicRSpO2"; ""; ""];

featureCount = numel(featureName);
spo2Rmse = nan(featureCount, 1);
spo2Corr = nan(featureCount, 1);
spo2StdRatio = nan(featureCount, 1);
lowRecall = nan(featureCount, 1);
featureCorr = nan(featureCount, 1);
featureAbsCorr = nan(featureCount, 1);
rSnr = nan(featureCount, 1);
rSnrDb = nan(featureCount, 1);
validRatio = nan(featureCount, 1);
meanBeatCount = nan(featureCount, 1);
meanBeatValidRatio = nan(featureCount, 1);
meanRedPI = nan(featureCount, 1);
meanIRPI = nan(featureCount, 1);

for idx = 1:featureCount
    currentFeature = windowTable.(char(featureColumn(idx)));
    trueSpO2 = windowTable.trueSpO2;
    validRatio(idx) = mean(isfinite(currentFeature) & currentFeature > 0);
    featureCorr(idx) = safe_corr_signed(currentFeature, trueSpO2);
    featureAbsCorr(idx) = abs(featureCorr(idx));
    [rSnr(idx), rSnrDb(idx)] = feature_r_snr(currentFeature, trueSpO2);

    if strlength(spo2Column(idx)) > 0
        currentSpO2 = windowTable.(char(spo2Column(idx)));
        spo2Rmse(idx) = series_rmse(currentSpO2, trueSpO2);
        spo2Corr(idx) = safe_corr_signed(currentSpO2, trueSpO2);
        spo2StdRatio(idx) = std_ratio(currentSpO2, trueSpO2);
        lowRecall(idx) = low_spo2_recall(currentSpO2, trueSpO2, 92, 94);
    end
end

meanBeatCount(featureName == "beat15") = mean(windowTable.beat15Count, 'omitnan');
meanBeatCount(featureName == "beat30") = mean(windowTable.beat30Count, 'omitnan');
meanBeatCount(featureName == "beat60") = mean(windowTable.beat60Count, 'omitnan');
meanBeatValidRatio(featureName == "beat15") = mean(windowTable.beat15ValidRatio, 'omitnan');
meanBeatValidRatio(featureName == "beat30") = mean(windowTable.beat30ValidRatio, 'omitnan');
meanBeatValidRatio(featureName == "beat60") = mean(windowTable.beat60ValidRatio, 'omitnan');
meanRedPI(featureName == "beat15") = mean(windowTable.beat15RedPI, 'omitnan');
meanRedPI(featureName == "beat30") = mean(windowTable.beat30RedPI, 'omitnan');
meanRedPI(featureName == "beat60") = mean(windowTable.beat60RedPI, 'omitnan');
meanIRPI(featureName == "beat15") = mean(windowTable.beat15IRPI, 'omitnan');
meanIRPI(featureName == "beat30") = mean(windowTable.beat30IRPI, 'omitnan');
meanIRPI(featureName == "beat60") = mean(windowTable.beat60IRPI, 'omitnan');
meanRedPI(featureName == "current") = mean(windowTable.redAcDc, 'omitnan');
meanIRPI(featureName == "current") = mean(windowTable.irAcDc, 'omitnan');

metricsTable = table(featureName, spo2Rmse, spo2Corr, spo2StdRatio, lowRecall, ...
    featureCorr, featureAbsCorr, rSnr, rSnrDb, validRatio, ...
    meanBeatCount, meanBeatValidRatio, meanRedPI, meanIRPI);
end

function segmentTable = build_segment_follow_table(windowTable, windowSeconds, stepSeconds)

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
centerMinutes = nan(segmentCount, 1);

currentRmse = nan(segmentCount, 1);
beat15Rmse = nan(segmentCount, 1);
beat30Rmse = nan(segmentCount, 1);
beat60Rmse = nan(segmentCount, 1);
currentCorr = nan(segmentCount, 1);
beat15Corr = nan(segmentCount, 1);
beat30Corr = nan(segmentCount, 1);
beat60Corr = nan(segmentCount, 1);
currentRSnrDb = nan(segmentCount, 1);
beat15RSnrDb = nan(segmentCount, 1);
beat30RSnrDb = nan(segmentCount, 1);
beat60RSnrDb = nan(segmentCount, 1);
currentLowRecall = nan(segmentCount, 1);
beat15LowRecall = nan(segmentCount, 1);
beat30LowRecall = nan(segmentCount, 1);
beat60LowRecall = nan(segmentCount, 1);
meanBeat15Count = nan(segmentCount, 1);
meanBeat30Count = nan(segmentCount, 1);
meanBeat60Count = nan(segmentCount, 1);
meanBeat15ValidRatio = nan(segmentCount, 1);
meanBeat30ValidRatio = nan(segmentCount, 1);
meanBeat60ValidRatio = nan(segmentCount, 1);
beat30ClassValue = zeros(segmentCount, 1);
beat30Quality = strings(segmentCount, 1);
spo2Min = nan(segmentCount, 1);
spo2Max = nan(segmentCount, 1);

for idx = 1:segmentCount
    startIdx = segmentStarts(idx);
    endIdx = min(startIdx + segmentLength - 1, seriesLength);
    part = windowTable(startIdx:endIdx, :);

    startWindow(idx) = part.windowIndex(1);
    endWindow(idx) = part.windowIndex(end);
    centerMinutes(idx) = (startWindow(idx) + endWindow(idx) - 2) / 2 / 60;

    currentRmse(idx) = series_rmse(part.currentSpO2, part.trueSpO2);
    beat15Rmse(idx) = series_rmse(part.beat15SpO2, part.trueSpO2);
    beat30Rmse(idx) = series_rmse(part.beat30SpO2, part.trueSpO2);
    beat60Rmse(idx) = series_rmse(part.beat60SpO2, part.trueSpO2);
    currentCorr(idx) = safe_corr_signed(part.currentSpO2, part.trueSpO2);
    beat15Corr(idx) = safe_corr_signed(part.beat15SpO2, part.trueSpO2);
    beat30Corr(idx) = safe_corr_signed(part.beat30SpO2, part.trueSpO2);
    beat60Corr(idx) = safe_corr_signed(part.beat60SpO2, part.trueSpO2);
    [~, currentRSnrDb(idx)] = feature_r_snr(part.currentR, part.trueSpO2);
    [~, beat15RSnrDb(idx)] = feature_r_snr(part.beat15R, part.trueSpO2);
    [~, beat30RSnrDb(idx)] = feature_r_snr(part.beat30R, part.trueSpO2);
    [~, beat60RSnrDb(idx)] = feature_r_snr(part.beat60R, part.trueSpO2);
    currentLowRecall(idx) = low_spo2_recall(part.currentSpO2, part.trueSpO2, 92, 94);
    beat15LowRecall(idx) = low_spo2_recall(part.beat15SpO2, part.trueSpO2, 92, 94);
    beat30LowRecall(idx) = low_spo2_recall(part.beat30SpO2, part.trueSpO2, 92, 94);
    beat60LowRecall(idx) = low_spo2_recall(part.beat60SpO2, part.trueSpO2, 92, 94);
    meanBeat15Count(idx) = mean(part.beat15Count, 'omitnan');
    meanBeat30Count(idx) = mean(part.beat30Count, 'omitnan');
    meanBeat60Count(idx) = mean(part.beat60Count, 'omitnan');
    meanBeat15ValidRatio(idx) = mean(part.beat15ValidRatio, 'omitnan');
    meanBeat30ValidRatio(idx) = mean(part.beat30ValidRatio, 'omitnan');
    meanBeat60ValidRatio(idx) = mean(part.beat60ValidRatio, 'omitnan');
    spo2Min(idx) = min(part.trueSpO2, [], 'omitnan');
    spo2Max(idx) = max(part.trueSpO2, [], 'omitnan');
    beat30ClassValue(idx) = classify_spo2_segment(beat30Rmse(idx), beat30Corr(idx), ...
        std_ratio(part.beat30SpO2, part.trueSpO2), beat30LowRecall(idx), part.trueSpO2);
    beat30Quality(idx) = class_value_to_text(beat30ClassValue(idx));
end

segmentTable = table(segmentIndex, startWindow, endWindow, centerMinutes, ...
    currentRmse, beat15Rmse, beat30Rmse, beat60Rmse, ...
    currentCorr, beat15Corr, beat30Corr, beat60Corr, ...
    currentRSnrDb, beat15RSnrDb, beat30RSnrDb, beat60RSnrDb, ...
    currentLowRecall, beat15LowRecall, beat30LowRecall, beat60LowRecall, ...
    meanBeat15Count, meanBeat30Count, meanBeat60Count, ...
    meanBeat15ValidRatio, meanBeat30ValidRatio, meanBeat60ValidRatio, ...
    beat30ClassValue, beat30Quality, spo2Min, spo2Max);
end

function classValue = classify_spo2_segment(rmseValue, corrValue, stdRatioValue, lowRecallValue, trueSpO2)

classValue = 0;
if ~isfinite(rmseValue) || ~isfinite(corrValue) || ~isfinite(stdRatioValue)
    return
end

validTrue = trueSpO2(isfinite(trueSpO2) & trueSpO2 > 0);
if isempty(validTrue)
    lowEventRatio = NaN;
else
    lowEventRatio = sum(validTrue <= 92) / numel(validTrue);
end
hasMeaningfulLowEvent = isfinite(lowEventRatio) && lowEventRatio >= 0.02;
lowRecallFailed = hasMeaningfulLowEvent && isfinite(lowRecallValue) && lowRecallValue < 0.5;
lowRecallGood = ~hasMeaningfulLowEvent || (isfinite(lowRecallValue) && lowRecallValue >= 0.7);

if rmseValue > 2.5 || corrValue < 0.35 || lowRecallFailed
    classValue = 1;
elseif rmseValue <= 2.0 && corrValue >= 0.6 && stdRatioValue >= 0.75 && lowRecallGood
    classValue = 3;
else
    classValue = 2;
end
end

function output = class_value_to_text(classValue)

if classValue == 3
    output = "Good";
elseif classValue == 2
    output = "Borderline";
elseif classValue == 1
    output = "Failed";
else
    output = "Unknown";
end
end

function [snrRatio, snrDb] = feature_r_snr(featureSeries, trueSpO2)

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

function output = series_rmse(estimatedSeries, trueSeries)

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

function output = safe_corr_signed(inputA, inputB)

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

function output = std_ratio(estimatedSeries, trueSeries)

estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
if sum(validMask) < 5 || std(trueSeries(validMask)) <= 1e-12
    output = NaN;
else
    output = std(estimatedSeries(validMask)) / std(trueSeries(validMask));
end
end

function output = low_spo2_recall(estimatedSeries, trueSeries, trueThreshold, estimatedThreshold)

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

function [lowerLimit, upperLimit] = robust_axis_limits(varargin)

allValues = [];
for idx = 1:numel(varargin)
    currentValues = varargin{idx};
    currentValues = currentValues(:);
    currentValues = currentValues(isfinite(currentValues));
    allValues = [allValues; currentValues]; %#ok<AGROW>
end

if isempty(allValues)
    lowerLimit = 0;
    upperLimit = 1;
    return
end

allValues = sort(allValues);
valueCount = numel(allValues);
lowerIndex = max(1, round((valueCount - 1) * 0.01) + 1);
upperIndex = min(valueCount, round((valueCount - 1) * 0.99) + 1);

lowerLimit = allValues(lowerIndex);
upperLimit = allValues(upperIndex);
valueRange = upperLimit - lowerLimit;
valueScale = max(abs([lowerLimit, upperLimit]));
padding = max(valueRange * 0.1, valueScale * 0.01);

if padding == 0
    padding = 1;
end

lowerLimit = lowerLimit - padding;
upperLimit = upperLimit + padding;
end

function outputLimits = robust_spo2_limits(inputSeries)

[lowerLimit, upperLimit] = robust_axis_limits(inputSeries);
plotLowerLimit = max(65, floor(lowerLimit));
plotUpperLimit = min(100, ceil(upperLimit));
if plotUpperLimit <= plotLowerLimit
    plotUpperLimit = plotLowerLimit + 1;
end
outputLimits = [plotLowerLimit, plotUpperLimit];
end

function safe_save_figure(figureHandle, outputDir, dataID, figureName, savePlots)

if ~savePlots
    return
end

try
    axesHandles = findall(figureHandle, 'Type', 'axes');
    for axisIdx = 1:numel(axesHandles)
        try
            axtoolbar(axesHandles(axisIdx), {});
        catch
        end
    end
    outputPath = fullfile(outputDir, sprintf('Data_%d_%s.png', dataID, figureName));
    exportgraphics(figureHandle, outputPath, 'Resolution', 200);
catch
    try
        saveas(figureHandle, outputPath);
    catch
    end
end
end

function [alignedEst, alignedTrue, idxEst, idxTrue] = align_series_with_indices(estimatedSeries, trueSeries, time_offset, samplingRate)

estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);
seriesLength = min(numel(estimatedSeries), numel(trueSeries));
estimatedSeries = estimatedSeries(1:seriesLength);
trueSeries = trueSeries(1:seriesLength);
offsetWindows = round(time_offset / samplingRate);

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

function [alignedEst, alignedTrue, varargout] = align_series_pair(estimatedSeries, trueSeries, time_offset, samplingRate, varargin)

offsetWindows = round(time_offset / samplingRate);

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
