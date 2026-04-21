clear;
clc;

% 20260202 regression
% remove 195,199,202,229
% dataIDList = [182,183,184,187,188,193,194,196,197,198,200, ...
%     201,203,204,206,207,208,209,210,211,212,213,214,215,216,...
%     217,218,219,220,221,222,223,224,225,226,227,228,230,231];

dataIDList = 225;
R_SpO2_values = cell(length(dataIDList), 1);

samplingRate = 50; % Sampling rate in Hz
windowLength = 2; % Window length in seconds
windowSize = windowLength * samplingRate;
stepSize = 1 * samplingRate; % 1 second step

smoothWindowSizeR = 60; % Size of the moving window for median calculation
smoothWindowSizePR = 15; % Size of the moving window for median calculation
qualityWindowSize = 10;

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
    RValues = zeros(num_windows, 1); % for evaluation
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

        [outputFlag, outputPR, outputSpO2, outputPI, confidence, smoothedR] = ppg_process(single(ppg_r(i)),single(ppg_ir(i)),single(ppg_g(i)), uint32(i), single(bodyMove(i)));
        if outputFlag
            windowCounter = windowCounter+1;
            piecewiseSpO2Values(windowCounter) = outputSpO2;
            % linearSpO2Values(windowCounter) = linearSpO2;
            PRValues(windowCounter) = outputPR;
            SQIValues(windowCounter,:) = outputPI;
            confidenceValues(windowCounter) = confidence;
            RValues(windowCounter) = smoothedR;

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

    overallRMSE = rmse(piecewiseSpO2Values(1:end), trueSPO2(1:end), "omitnan");
    reliableRMSE = rmse(piecewiseSpO2Values(confidenceValues>confidenceTheshold), trueSPO2(confidenceValues>confidenceTheshold), "omitnan");
    reliableRatio = sum(confidenceValues>confidenceTheshold)/num_windows;
    figure(1); clf;
    plot(piecewiseSpO2Values(1:end)), hold on; plot(trueSPO2(1:end)); 
    scatter(find(confidenceValues<confidenceTheshold), piecewiseSpO2Values(confidenceValues<confidenceTheshold),6,'filled','MarkerFaceColor',"#FF0000")
    % plot(find(confidenceValues>0.6),calculate_spo2(smoothdata(RValues(confidenceValues>0.6),'movmedian',30)));
    hold off;
    legend('Estimated SpO2', 'True SpO2', 'Location','northoutside','NumColumns', 3)
    ylim([70, 100])
    text(0, 75, append('RMSE: ', string(overallRMSE)));
    text(0, 73, append('RMSE for confidence > 0.6: ', string(reliableRMSE)));
    text(0, 71, append('Ratio for confidence > 0.6: ', string(reliableRatio)));
    title(append('Estimated SpO2 ', string(dataID)));
    print(gcf, '-dpng', append('Estimated SpO2 ', string(dataID), '.png'), '-r600');

    figure(2); clf;
    if time_offset >= 0
        plot(PRValues(time_offset/50+1:end)); hold on; plot(truePR(1:end-time_offset/50)); hold off;
        prRMSE = rmse(PRValues(time_offset/50+1:end), truePR(1:end-time_offset/50), "omitnan");
        text(0, 45, append('RMSE: ', string(rmse(PRValues(time_offset/50+1:end), truePR(1:end-time_offset/50), "omitnan")))); 
    else
        plot(PRValues(1:end+time_offset/50)); hold on; plot(truePR(-time_offset/50+1:end)); hold off;
        prRMSE = rmse(PRValues(1:end+time_offset/50), truePR(-time_offset/50+1:end), "omitnan");
        text(0, 45, append('RMSE: ', string(rmse(PRValues(1:end+time_offset/50), truePR(-time_offset/50+1:end), "omitnan"))));
    end
    legend('Calculated PR', 'True PR', 'Location','northoutside','NumColumns', 2)
    ylim([40, 100])
    title(append('Estimated PR ', string(dataID)));
    print(gcf, '-dpng', append('Estimated PR ', string(dataID), '.png'), '-r600');

    % figure(3);
    % plot(sensor_data(:,[1,2,3]));
    % 
    % figure(4);
    % plot(smoothdata(confidenceValues,'movmean',30));

    R_SpO2_values{k} = [RValues(confidenceValues>confidenceTheshold), trueSPO2(confidenceValues>confidenceTheshold)];
    fprintf('Data No. %d\n', dataID)
    fprintf('Overall SpO2 RMSE %.2f\n', overallRMSE)
    fprintf('Reliable SpO2 RMSE %.2f\n', reliableRMSE)
    fprintf('PR RMSE %.2f\n', prRMSE)
    fprintf('Reliable ratio: %.2f\n', reliableRatio)
    fprintf('Window number: %d\n', num_windows)

end
save('R_SpO2_values.mat', 'R_SpO2_values')