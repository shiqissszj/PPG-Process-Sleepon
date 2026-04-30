% clear;
% clc;

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
R_SpO2_values = cell(length(dataIDList), 1);
spo2RMSEList = nan(length(dataIDList), 1);
prRMSEList = nan(length(dataIDList), 1);
autoTimeOffset = true;

samplingRate = 50; % Sampling rate in Hz
windowLength = 3; % Window length in seconds
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate; % 1 second step

smoothWindowSizeR = 60; % Size of the moving window for median calculation
smoothWindowSizePR = 15; % Size of the moving window for median calculation
qualityWindowSize = 10;
spo2QualityWindowSeconds = 300;
spo2QualityStepSeconds = 300;
spo2QualityMinValidSeconds = 120;

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

    % read data from file
    dataID = dataIDList(k);

    [filename,time_offset,drop_num_start,drop_num_end] = get_filename(dataID);
    baseTimeOffset = time_offset;
    % filename = append('../', filename);
    % time_offset = 0;
    % drop_num_start = 0;
    % drop_num_end = 0;

    % Read the matrix from the file
    data = readmatrix(filename, opts);

    sensor_data = str2double(data(drop_num_start-time_offset+1:size(data,1)-drop_num_end-time_offset, [3,4,5]));
    time_data = datetime(data(drop_num_start-time_offset+1:size(data,1)-drop_num_end-time_offset, 11));
    bodyMove = str2double(data(drop_num_start-time_offset+1:size(data,1)-drop_num_end-time_offset, 10));
    checkme_PR = str2double(data(drop_num_start+1:size(data,1)-drop_num_end, 7));
    checkme_SPO2 = str2double(data(drop_num_start+1:size(data,1)-drop_num_end, 6));

    ppg_r = sensor_data(:, 1);
    ppg_ir = sensor_data(:, 2);
    ppg_g = sensor_data(:, 3);

    % for validation
    num_windows = floor((length(ppg_r) - windowSize) / stepSize) + 1;
    piecewiseSpO2Values = zeros(num_windows, 1);% for evaluation
    % linearSpO2Values = zeros(num_windows, 1);% for evaluation
    rawRValues = zeros(num_windows, 1);
    fixedRValues = zeros(num_windows, 1);
    smoothedRValues = zeros(num_windows, 1);
    classicRValues = zeros(num_windows, 1);
    redAcDcValues = zeros(num_windows, 1);
    irAcDcValues = zeros(num_windows, 1);
    PRValues = zeros(num_windows, 1);
    SQIValues = zeros(num_windows, 6);
    trueSPO2 = zeros(num_windows, 1);
    truePR = zeros(num_windows, 1);
    confidenceValues = zeros(num_windows, 1);
    confidenceTheshold = 0.75;
    % loop counter
    sampleCounter = 0;
    windowCounter = 0;
    

    for i = 1:size(ppg_r,1)

        [outputFlag, outputPR, outputSpO2, outputPI, confidence, rawR, fixedR, smoothedR, classicR, redAcDc, irAcDc] = ...
            ppg_process_val(single(ppg_r(i)),single(ppg_ir(i)),single(ppg_g(i)), uint32(i), single(bodyMove(i)));
        if outputFlag
            windowCounter = windowCounter+1;
            piecewiseSpO2Values(windowCounter) = outputSpO2;
            % linearSpO2Values(windowCounter) = linearSpO2;
            PRValues(windowCounter) = outputPR;
            SQIValues(windowCounter,:) = outputPI;
            confidenceValues(windowCounter) = confidence;
            rawRValues(windowCounter) = rawR;
            fixedRValues(windowCounter) = fixedR;
            smoothedRValues(windowCounter) = smoothedR;
            classicRValues(windowCounter) = classicR;
            redAcDcValues(windowCounter) = redAcDc;
            irAcDcValues(windowCounter) = irAcDc;

            tmpSPO2 = checkme_SPO2(i-50+1:i);
            tmpPR = checkme_PR(i-50+1:i);
            trueSPO2(windowCounter) = mode(tmpSPO2(tmpSPO2>0));
            if isnan(trueSPO2(windowCounter)) && windowCounter > 1
                trueSPO2(windowCounter) = trueSPO2(windowCounter-1);
            end
            truePR(windowCounter) = mode(tmpPR(tmpPR>0));
            if isnan(truePR(windowCounter)) && windowCounter > 1
                truePR(windowCounter) = truePR(windowCounter-1);
            end
            truePR(windowCounter) = min(truePR(windowCounter), 100);
        end
    end

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
            spo2_est_offset = estimate_time_offset(piecewiseSpO2Values(:), trueSPO2(:), 120, stepSize);
            if isfinite(spo2_est_offset)
                spo2_time_offset = spo2_est_offset;
            end
        catch
        end
    end

    [alignedSpO2Est, alignedSpO2True, alignedConfidence, alignedRawRValues, alignedFixedRValues, alignedSmoothedRValues, alignedClassicRValues, alignedRedAcDcValues, alignedIRAcDcValues] = ...
        align_series_pair(piecewiseSpO2Values, trueSPO2, spo2_time_offset, samplingRate, ...
        confidenceValues, rawRValues, fixedRValues, smoothedRValues, classicRValues, redAcDcValues, irAcDcValues);
    [alignedPREst, alignedPRTrue] = ...
        align_series_pair(PRValues, truePR, pr_time_offset, samplingRate);

    validPRMask = alignedPREst > 0 & alignedPRTrue > 0 & isfinite(alignedPREst) & isfinite(alignedPRTrue);
    plotPREst = alignedPREst;
    plotPREst(~validPRMask) = nan;

    overallRMSE = rmse(alignedSpO2Est, alignedSpO2True, "omitnan");
    reliableMask = alignedConfidence > confidenceTheshold;
    reliableRMSE = rmse(alignedSpO2Est(reliableMask), alignedSpO2True(reliableMask), "omitnan");
    reliableRatio = sum(reliableMask) / numel(alignedConfidence);
    prRMSE = rmse(alignedPREst(validPRMask), alignedPRTrue(validPRMask), "omitnan");
    rawRSpO2Values = calculate_spo2(alignedRawRValues);
    fixedRSpO2Values = calculate_spo2(alignedFixedRValues);
    smoothedRSpO2Values = calculate_spo2(alignedSmoothedRValues);
    classicRSpO2Values = calculate_spo2(alignedClassicRValues);
    [rawStageRMSE, rawStageCorr, rawStageStdRatio] = series_pair_metrics(rawRSpO2Values, alignedSpO2True);
    [fixedStageRMSE, fixedStageCorr, fixedStageStdRatio] = series_pair_metrics(fixedRSpO2Values, alignedSpO2True);
    [smoothedStageRMSE, smoothedStageCorr, smoothedStageStdRatio] = series_pair_metrics(smoothedRSpO2Values, alignedSpO2True);
    [classicStageRMSE, classicStageCorr, classicStageStdRatio] = series_pair_metrics(classicRSpO2Values, alignedSpO2True);
    [redAcDcCorr, redAcDcStdRatio] = feature_pair_metrics(alignedRedAcDcValues, alignedSpO2True);
    [irAcDcCorr, irAcDcStdRatio] = feature_pair_metrics(alignedIRAcDcValues, alignedSpO2True);
    rawLowSpO2Recall = low_spo2_recall(rawRSpO2Values, alignedSpO2True, 92, 94);
    fixedLowSpO2Recall = low_spo2_recall(fixedRSpO2Values, alignedSpO2True, 92, 94);
    smoothedLowSpO2Recall = low_spo2_recall(smoothedRSpO2Values, alignedSpO2True, 92, 94);
    classicLowSpO2Recall = low_spo2_recall(classicRSpO2Values, alignedSpO2True, 92, 94);
    qualitySegments = calculate_spo2_quality_segments(smoothedRSpO2Values, alignedSpO2True, ...
        alignedConfidence, spo2QualityWindowSeconds, spo2QualityStepSeconds, spo2QualityMinValidSeconds);

    figure(1); clf;
    plot(alignedSpO2Est(1:end)), hold on; plot(alignedSpO2True(1:end)); 
    scatter(find(~reliableMask), alignedSpO2Est(~reliableMask),6,'filled','MarkerFaceColor',"#FF0000")
    % plot(find(confidenceValues>0.6),calculate_spo2(smoothdata(smoothedRValues(confidenceValues>0.6),'movmedian',30)));
    hold off;
    legend('Estimated SpO2', 'True SpO2', 'Location','northoutside','NumColumns', 3)
    ylim([70, 100])
    text(0, 75, append('RMSE: ', string(overallRMSE)));
    text(0, 73, append('RMSE for confidence > ', string(confidenceTheshold), ': ', string(reliableRMSE)));
    text(0, 71, append('Ratio for confidence > ', string(confidenceTheshold), ': ', string(reliableRatio)));
    text(0, 69, append('SpO2 auto offset (samples): ', string(spo2_time_offset)));
    text(0, 67, append('SpO2 total offset (samples): ', string(baseTimeOffset + spo2_time_offset)));
    title(append('Estimated SpO2 ', string(dataID)));
    % print(gcf, '-dpng', append('Estimated SpO2 ', string(dataID), '.png'), '-r600');

    figure(2); clf;
    plot(plotPREst); hold on; plot(alignedPRTrue); hold off;
    text(0, 45, append('RMSE: ', string(prRMSE))); 
    text(0, 42, append('PR auto offset (samples): ', string(pr_time_offset)));
    text(0, 39, append('PR total offset (samples): ', string(baseTimeOffset + pr_time_offset)));
    legend('Calculated PR', 'True PR', 'Location','northoutside','NumColumns', 2)
    ylim([40, 100])
    title(append('Estimated PR ', string(dataID)));

    % print(gcf, '-dpng', append('Estimated PR ', string(dataID), '.png'), '-r600');

    figure(3); clf;
    yyaxis left;
    hRawR = plot(alignedRawRValues, 'Color', [0.0000 0.4470 0.7410]); hold on;
    hFixedR = plot(alignedFixedRValues, 'Color', [0.9290 0.6940 0.1250]);
    hSmoothedR = plot(alignedSmoothedRValues, 'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.2);
    ylabel('R value');
    [rLowerLimit, rUpperLimit] = robust_axis_limits(alignedRawRValues, alignedFixedRValues, alignedSmoothedRValues);
    ylim([rLowerLimit, rUpperLimit]);

    yyaxis right;
    hTrueSpO2 = plot(alignedSpO2True, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.0);
    ylabel('True SpO2 (%)');
    [spo2LowerLimit, spo2UpperLimit] = robust_axis_limits(alignedSpO2True);
    spo2PlotLowerLimit = max(65, floor(spo2LowerLimit));
    spo2PlotUpperLimit = min(100, ceil(spo2UpperLimit));
    if spo2PlotUpperLimit <= spo2PlotLowerLimit
        spo2PlotUpperLimit = spo2PlotLowerLimit + 1;
    end
    ylim([spo2PlotLowerLimit, spo2PlotUpperLimit]);
    hold off;
    grid on;
    legend([hRawR, hFixedR, hSmoothedR, hTrueSpO2], ...
        {'raw R', 'fixed R', 'smoothed R', 'True SpO2'}, ...
        'Location','northoutside','NumColumns', 4);
    title(append('R Stage Diagnostic ', string(dataID)));

    figure(4); clf;
    plot(rawRSpO2Values, 'Color', [0.0000 0.4470 0.7410]); hold on;
    plot(fixedRSpO2Values, 'Color', [0.9290 0.6940 0.1250]);
    plot(smoothedRSpO2Values, 'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.2);
    plot(classicRSpO2Values, 'Color', [0.4940 0.1840 0.5560]);
    plot(alignedSpO2True, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.0);
    scatter(find(~reliableMask), smoothedRSpO2Values(~reliableMask), 6, 'filled', 'MarkerFaceColor', "#FF0000")
    hold off;
    grid on;
    legend('raw R -> SpO2', 'fixed R -> SpO2', 'smoothed R -> SpO2', 'classic R -> SpO2', 'True SpO2', ...
        'Location','northoutside','NumColumns', 5);
    ylim([65, 100]);
    text(0, 72, append('raw RMSE/corr/std: ', string(rawStageRMSE), ' / ', string(rawStageCorr), ' / ', string(rawStageStdRatio)));
    text(0, 70, append('fixed RMSE/corr/std: ', string(fixedStageRMSE), ' / ', string(fixedStageCorr), ' / ', string(fixedStageStdRatio)));
    text(0, 68, append('smoothed RMSE/corr/std: ', string(smoothedStageRMSE), ' / ', string(smoothedStageCorr), ' / ', string(smoothedStageStdRatio)));
    text(0, 66, append('classic RMSE/corr/std: ', string(classicStageRMSE), ' / ', string(classicStageCorr), ' / ', string(classicStageStdRatio)));
    title(append('R-to-SpO2 Stage Diagnostic ', string(dataID)));

    figure(5); clf;
    yyaxis left;
    hCurrentRawR = plot(alignedRawRValues, 'Color', [0.0000 0.4470 0.7410]); hold on;
    hClassicR = plot(alignedClassicRValues, 'Color', [0.4940 0.1840 0.5560]);
    ylabel('R value');
    [diagnosticRLowerLimit, diagnosticRUpperLimit] = robust_axis_limits(alignedRawRValues, alignedClassicRValues);
    ylim([diagnosticRLowerLimit, diagnosticRUpperLimit]);

    yyaxis right;
    hDiagnosticTrueSpO2 = plot(alignedSpO2True, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.0);
    ylabel('True SpO2 (%)');
    [diagnosticSpO2LowerLimit, diagnosticSpO2UpperLimit] = robust_axis_limits(alignedSpO2True);
    diagnosticSpO2PlotLowerLimit = max(65, floor(diagnosticSpO2LowerLimit));
    diagnosticSpO2PlotUpperLimit = min(100, ceil(diagnosticSpO2UpperLimit));
    if diagnosticSpO2PlotUpperLimit <= diagnosticSpO2PlotLowerLimit
        diagnosticSpO2PlotUpperLimit = diagnosticSpO2PlotLowerLimit + 1;
    end
    ylim([diagnosticSpO2PlotLowerLimit, diagnosticSpO2PlotUpperLimit]);
    hold off;
    grid on;
    legend([hCurrentRawR, hClassicR, hDiagnosticTrueSpO2], ...
        {'current raw R', 'classic R', 'True SpO2'}, ...
        'Location','northoutside','NumColumns', 3);
    title(append('Current-vs-Classic R Diagnostic ', string(dataID)));

    figure(6); clf;
    subplot(2,1,1);
    yyaxis left;
    hRedAcDc = plot(alignedRedAcDcValues, 'Color', [0.6350 0.0780 0.1840]); hold on;
    hIRAcDc = plot(alignedIRAcDcValues, 'Color', [0.3010 0.7450 0.9330]);
    ylabel('AC/DC');
    [acDcLowerLimit, acDcUpperLimit] = robust_axis_limits(alignedRedAcDcValues, alignedIRAcDcValues);
    ylim([acDcLowerLimit, acDcUpperLimit]);

    yyaxis right;
    hAcDcTrueSpO2 = plot(alignedSpO2True, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.0);
    ylabel('True SpO2 (%)');
    [acDcSpO2LowerLimit, acDcSpO2UpperLimit] = robust_axis_limits(alignedSpO2True);
    ylim([max(65, floor(acDcSpO2LowerLimit)), min(100, ceil(acDcSpO2UpperLimit))]);
    hold off;
    grid on;
    legend([hRedAcDc, hIRAcDc, hAcDcTrueSpO2], ...
        {'AC_R/DC_R', 'AC_IR/DC_IR', 'True SpO2'}, ...
        'Location','northoutside','NumColumns', 3);
    title(append('AC/DC Diagnostic Auto Offset ', string(dataID)));

    subplot(2,1,2);
    plot(normalize_series(alignedRedAcDcValues), 'Color', [0.6350 0.0780 0.1840]); hold on;
    plot(normalize_series(alignedIRAcDcValues), 'Color', [0.3010 0.7450 0.9330]);
    plot(normalize_series(alignedClassicRValues), 'Color', [0.4940 0.1840 0.5560]);
    plot(normalize_series(alignedSpO2True), 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.0);
    hold off;
    grid on;
    legend('norm AC_R/DC_R', 'norm AC_IR/DC_IR', 'norm classic R', 'norm True SpO2', ...
        'Location','northoutside','NumColumns', 4);
    title(append('Normalized AC/DC Shape Diagnostic ', string(dataID)));

    figure(7); clf;
    fixedTotalOffsets = [baseTimeOffset + spo2_time_offset, 0, -20 * samplingRate, -60 * samplingRate];
    for offsetIdx = 1:numel(fixedTotalOffsets)
        fixedTotalOffset = fixedTotalOffsets(offsetIdx);
        extraOffset = fixedTotalOffset - baseTimeOffset;
        [offsetClassicR, offsetTrueSpO2, offsetRedAcDc, offsetIRAcDc] = ...
            align_series_pair(classicRValues, trueSPO2, extraOffset, samplingRate, redAcDcValues, irAcDcValues);
        [offsetClassicCorr, ~] = feature_pair_metrics(offsetClassicR, offsetTrueSpO2);

        subplot(2,2,offsetIdx);
        yyaxis left;
        plot(normalize_series(offsetRedAcDc), 'Color', [0.6350 0.0780 0.1840]); hold on;
        plot(normalize_series(offsetIRAcDc), 'Color', [0.3010 0.7450 0.9330]);
        plot(normalize_series(offsetClassicR), 'Color', [0.4940 0.1840 0.5560]);
        ylabel('Normalized feature');

        yyaxis right;
        plot(offsetTrueSpO2, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.0);
        ylabel('True SpO2 (%)');
        hold off;
        grid on;
        title(append('Total offset ', string(fixedTotalOffset / samplingRate), 's, classic corr ', string(offsetClassicCorr)));
        if offsetIdx == 1
            legend('AC_R/DC_R', 'AC_IR/DC_IR', 'classic R', 'True SpO2', ...
                'Location','northoutside','NumColumns', 4);
        end
    end

    figure(8); clf;
    subplot(4,1,1);
    plot(qualitySegments.centerMinutes, qualitySegments.rmseValues, '-o', 'Color', [0.0000 0.4470 0.7410]); hold on;
    yline(2.0, '--', 'Color', [0.4660 0.6740 0.1880]);
    yline(2.5, '--', 'Color', [0.8500 0.3250 0.0980]);
    hold off;
    grid on;
    ylabel('RMSE');
    title(append('Segment SpO2 Tracking Quality ', string(dataID)));

    subplot(4,1,2);
    plot(qualitySegments.centerMinutes, qualitySegments.corrValues, '-o', 'Color', [0.4940 0.1840 0.5560]); hold on;
    yline(0.6, '--', 'Color', [0.4660 0.6740 0.1880]);
    yline(0.35, '--', 'Color', [0.8500 0.3250 0.0980]);
    hold off;
    grid on;
    ylabel('corr');

    subplot(4,1,3);
    plot(qualitySegments.centerMinutes, qualitySegments.stdRatioValues, '-o', 'Color', [0.9290 0.6940 0.1250]); hold on;
    yline(0.75, '--', 'Color', [0.4660 0.6740 0.1880]);
    yline(0.6, '--', 'Color', [0.8500 0.3250 0.0980]);
    hold off;
    grid on;
    ylabel('std ratio');

    subplot(4,1,4);
    stairs(qualitySegments.centerMinutes, qualitySegments.classValues, 'LineWidth', 1.4); hold on;
    plot(qualitySegments.centerMinutes, qualitySegments.lowRecallValues, '-o', 'Color', [0.3010 0.7450 0.9330]);
    hold off;
    grid on;
    ylim([0, 3.2]);
    yticks([1, 2, 3]);
    yticklabels({'Failed', 'Borderline', 'Good'});
    ylabel('quality');
    xlabel('Time (min)');
    legend('class', 'low recall', 'Location','northoutside','NumColumns', 2);

    R_SpO2_values{k} = [alignedSmoothedRValues(reliableMask), alignedSpO2True(reliableMask)];
    fprintf('Data No. %d\n', dataID)
    fprintf('Overall SpO2 RMSE %.2f\n', overallRMSE)
    fprintf('Reliable SpO2 RMSE %.2f\n', reliableRMSE)
    fprintf('Raw R->SpO2 RMSE %.2f, corr %.2f, std ratio %.2f, low recall %.2f\n', ...
        rawStageRMSE, rawStageCorr, rawStageStdRatio, rawLowSpO2Recall)
    fprintf('Fixed R->SpO2 RMSE %.2f, corr %.2f, std ratio %.2f, low recall %.2f\n', ...
        fixedStageRMSE, fixedStageCorr, fixedStageStdRatio, fixedLowSpO2Recall)
    fprintf('Smoothed R->SpO2 RMSE %.2f, corr %.2f, std ratio %.2f, low recall %.2f\n', ...
        smoothedStageRMSE, smoothedStageCorr, smoothedStageStdRatio, smoothedLowSpO2Recall)
    fprintf('Classic R->SpO2 RMSE %.2f, corr %.2f, std ratio %.2f, low recall %.2f\n', ...
        classicStageRMSE, classicStageCorr, classicStageStdRatio, classicLowSpO2Recall)
    fprintf('Red AC/DC corr %.2f, std ratio %.2f\n', redAcDcCorr, redAcDcStdRatio)
    fprintf('IR AC/DC corr %.2f, std ratio %.2f\n', irAcDcCorr, irAcDcStdRatio)
    fprintf('Segment quality (%ds windows): Good %.1f%%, Borderline %.1f%%, Failed %.1f%%, Unknown %.1f%%\n', ...
        spo2QualityWindowSeconds, qualitySegments.goodRatio * 100, qualitySegments.borderlineRatio * 100, ...
        qualitySegments.failedRatio * 100, qualitySegments.unknownRatio * 100)
    fprintf('Segment counts: Good %d, Borderline %d, Failed %d, Unknown %d, Total %d\n', ...
        qualitySegments.goodCount, qualitySegments.borderlineCount, qualitySegments.failedCount, ...
        qualitySegments.unknownCount, qualitySegments.segmentCount)
    fprintf('PR RMSE %.2f\n', prRMSE)
    fprintf('Reliable ratio: %.2f\n', reliableRatio)
    fprintf('Base time offset from get_filename (samples): %d\n', baseTimeOffset)
    fprintf('Auto SpO2 offset (samples): %d\n', spo2_time_offset)
    fprintf('Auto PR offset (samples): %d\n', pr_time_offset)
    fprintf('Total SpO2 offset (samples): %d\n', baseTimeOffset + spo2_time_offset)
    fprintf('Total PR offset (samples): %d\n', baseTimeOffset + pr_time_offset)
    fprintf('Window number: %d\n', num_windows)

    spo2RMSEList(k) = overallRMSE;
    prRMSEList(k) = prRMSE;

end

avgSpO2RMSE = mean(spo2RMSEList, 'omitnan');
avgPRRMSE = mean(prRMSEList, 'omitnan');

fprintf('\nAverage SpO2 RMSE %.2f\n', avgSpO2RMSE)
fprintf('Average PR RMSE %.2f\n', avgPRRMSE)
% save('R_SpO2_values.mat', 'R_SpO2_values')

function qualitySegments = calculate_spo2_quality_segments(estimatedSpO2, trueSpO2, confidenceValues, windowSeconds, stepSeconds, minValidSeconds)

estimatedSpO2 = estimatedSpO2(:);
trueSpO2 = trueSpO2(:);
confidenceValues = confidenceValues(:);

seriesLength = min([numel(estimatedSpO2), numel(trueSpO2), numel(confidenceValues)]);
estimatedSpO2 = estimatedSpO2(1:seriesLength);
trueSpO2 = trueSpO2(1:seriesLength);
confidenceValues = confidenceValues(1:seriesLength);

if seriesLength < minValidSeconds
    qualitySegments = empty_quality_segments();
    return
end

windowLength = max(1, round(windowSeconds));
stepLength = max(1, round(stepSeconds));
segmentCount = floor((seriesLength - windowLength) / stepLength) + 1;
if segmentCount < 1
    segmentCount = 1;
    windowLength = seriesLength;
end

centerMinutes = nan(segmentCount, 1);
rmseValues = nan(segmentCount, 1);
corrValues = nan(segmentCount, 1);
stdRatioValues = nan(segmentCount, 1);
lowRecallValues = nan(segmentCount, 1);
lowEventRatioValues = nan(segmentCount, 1);
meanConfidenceValues = nan(segmentCount, 1);
classValues = zeros(segmentCount, 1);

for segmentIndex = 1:segmentCount
    startIndex = (segmentIndex - 1) * stepLength + 1;
    endIndex = min(startIndex + windowLength - 1, seriesLength);
    segmentEstimated = estimatedSpO2(startIndex:endIndex);
    segmentTrue = trueSpO2(startIndex:endIndex);
    segmentConfidence = confidenceValues(startIndex:endIndex);
    validMask = isfinite(segmentEstimated) & isfinite(segmentTrue) & segmentEstimated > 0 & segmentTrue > 0;
    validCount = sum(validMask);

    centerMinutes(segmentIndex) = (startIndex + endIndex - 2) / 2 / 60;
    if validCount < minValidSeconds
        classValues(segmentIndex) = 0;
        continue
    end

    [rmseValues(segmentIndex), corrValues(segmentIndex), stdRatioValues(segmentIndex)] = ...
        series_pair_metrics(segmentEstimated, segmentTrue);
    lowRecallValues(segmentIndex) = low_spo2_recall(segmentEstimated, segmentTrue, 92, 94);
    lowEventRatioValues(segmentIndex) = sum(segmentTrue(validMask) <= 92) / validCount;
    meanConfidenceValues(segmentIndex) = mean(segmentConfidence(isfinite(segmentConfidence)), 'omitnan');
    classValues(segmentIndex) = classify_spo2_segment(rmseValues(segmentIndex), corrValues(segmentIndex), ...
        stdRatioValues(segmentIndex), lowRecallValues(segmentIndex), lowEventRatioValues(segmentIndex));
end

qualitySegments.centerMinutes = centerMinutes;
qualitySegments.rmseValues = rmseValues;
qualitySegments.corrValues = corrValues;
qualitySegments.stdRatioValues = stdRatioValues;
qualitySegments.lowRecallValues = lowRecallValues;
qualitySegments.lowEventRatioValues = lowEventRatioValues;
qualitySegments.meanConfidenceValues = meanConfidenceValues;
qualitySegments.classValues = classValues;
qualitySegments.segmentCount = segmentCount;
qualitySegments.goodCount = sum(classValues == 3);
qualitySegments.borderlineCount = sum(classValues == 2);
qualitySegments.failedCount = sum(classValues == 1);
qualitySegments.unknownCount = sum(classValues == 0);
knownCount = max(1, segmentCount - qualitySegments.unknownCount);
qualitySegments.goodRatio = qualitySegments.goodCount / knownCount;
qualitySegments.borderlineRatio = qualitySegments.borderlineCount / knownCount;
qualitySegments.failedRatio = qualitySegments.failedCount / knownCount;
qualitySegments.unknownRatio = qualitySegments.unknownCount / segmentCount;
end

function classValue = classify_spo2_segment(rmseValue, corrValue, stdRatio, lowRecallValue, lowEventRatio)

classValue = 0;
if ~isfinite(rmseValue) || ~isfinite(corrValue) || ~isfinite(stdRatio)
    return
end

hasMeaningfulLowEvent = isfinite(lowEventRatio) && lowEventRatio >= 0.02;
lowRecallFailed = hasMeaningfulLowEvent && isfinite(lowRecallValue) && lowRecallValue < 0.5;
lowRecallGood = ~hasMeaningfulLowEvent || (isfinite(lowRecallValue) && lowRecallValue >= 0.7);

if rmseValue > 2.5 || corrValue < 0.35 || lowRecallFailed
    classValue = 1;
elseif rmseValue <= 2.0 && corrValue >= 0.6 && stdRatio >= 0.75 && lowRecallGood
    classValue = 3;
else
    classValue = 2;
end
end

function qualitySegments = empty_quality_segments()

qualitySegments.centerMinutes = [];
qualitySegments.rmseValues = [];
qualitySegments.corrValues = [];
qualitySegments.stdRatioValues = [];
qualitySegments.lowRecallValues = [];
qualitySegments.lowEventRatioValues = [];
qualitySegments.meanConfidenceValues = [];
qualitySegments.classValues = [];
qualitySegments.segmentCount = 0;
qualitySegments.goodCount = 0;
qualitySegments.borderlineCount = 0;
qualitySegments.failedCount = 0;
qualitySegments.unknownCount = 0;
qualitySegments.goodRatio = 0;
qualitySegments.borderlineRatio = 0;
qualitySegments.failedRatio = 0;
qualitySegments.unknownRatio = 1;
end

function normalizedSeries = normalize_series(inputSeries)

normalizedSeries = inputSeries(:);
validMask = isfinite(normalizedSeries);

if ~any(validMask)
    return
end

validValues = double(normalizedSeries(validMask));
valueMean = mean(validValues);
valueStd = sqrt(mean((validValues - valueMean) .^ 2));

if valueStd == 0
    normalizedSeries(validMask) = single(0);
else
    normalizedSeries(validMask) = single((validValues - valueMean) / valueStd);
end
end

function [corrValue, stdRatio] = feature_pair_metrics(featureSeries, trueSeries)

featureSeries = featureSeries(:);
trueSeries = trueSeries(:);
validMask = isfinite(featureSeries) & isfinite(trueSeries) & trueSeries > 0;

if ~any(validMask)
    corrValue = nan;
    stdRatio = nan;
    return
end

featureValues = double(featureSeries(validMask));
trueValues = double(trueSeries(validMask));
featureCentered = featureValues - mean(featureValues);
trueCentered = trueValues - mean(trueValues);
featureStd = sqrt(mean(featureCentered .^ 2));
trueStd = sqrt(mean(trueCentered .^ 2));

if featureStd == 0 || trueStd == 0
    corrValue = nan;
else
    corrValue = mean(featureCentered .* trueCentered) / (featureStd * trueStd);
end

if trueStd == 0
    stdRatio = nan;
else
    stdRatio = featureStd / trueStd;
end
end

function [rmseValue, corrValue, stdRatio] = series_pair_metrics(estimatedSeries, trueSeries)

estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;

if ~any(validMask)
    rmseValue = nan;
    corrValue = nan;
    stdRatio = nan;
    return
end

estimatedValues = double(estimatedSeries(validMask));
trueValues = double(trueSeries(validMask));
errorValues = estimatedValues - trueValues;
rmseValue = sqrt(mean(errorValues .^ 2));

estimatedCentered = estimatedValues - mean(estimatedValues);
trueCentered = trueValues - mean(trueValues);
estimatedStd = sqrt(mean(estimatedCentered .^ 2));
trueStd = sqrt(mean(trueCentered .^ 2));

if estimatedStd == 0 || trueStd == 0
    corrValue = nan;
else
    corrValue = mean(estimatedCentered .* trueCentered) / (estimatedStd * trueStd);
end

if trueStd == 0
    stdRatio = nan;
else
    stdRatio = estimatedStd / trueStd;
end
end

function recallValue = low_spo2_recall(estimatedSeries, trueSeries, trueThreshold, estimatedThreshold)

estimatedSeries = estimatedSeries(:);
trueSeries = trueSeries(:);
validMask = isfinite(estimatedSeries) & isfinite(trueSeries) & estimatedSeries > 0 & trueSeries > 0;
eventMask = validMask & trueSeries <= trueThreshold;

if ~any(eventMask)
    recallValue = nan;
    return
end

recallValue = sum(estimatedSeries(eventMask) <= estimatedThreshold) / sum(eventMask);
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
