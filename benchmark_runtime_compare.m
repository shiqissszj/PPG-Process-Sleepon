function results = benchmark_runtime_compare(dataIDList, repeatCount)

% Compare the streaming runtime of the current 0421 pipeline and the 0317
% pipeline on the same records. This is a desktop-side approximation of
% relative compute cost, not a replacement for on-device profiling.

if nargin < 1 || isempty(dataIDList)
    dataIDList = [222, 225];
end
if nargin < 2 || isempty(repeatCount)
    repeatCount = 5;
end

currentRoot = fileparts(mfilename('fullpath'));
v0317Root = '/Users/shiqissszj/Desktop/Sleepon/Codes/sleepon_0317';
samplingRate = 50;

records = cell(numel(dataIDList), 1);
for idx = 1:numel(dataIDList)
    records{idx} = load_benchmark_record(dataIDList(idx));
end

fprintf('Benchmark records: %s\n', mat2str(dataIDList));
fprintf('Repeat count per implementation: %d\n', repeatCount);
fprintf('All timings exclude plotting and file saving.\n\n');

results = struct();
results.records = dataIDList;
results.repeatCount = repeatCount;
results.current0421 = run_suite(currentRoot, 'ppg_process', records, samplingRate, repeatCount, false);
results.v0317_matlab = run_suite(v0317Root, 'ppg_process_v2_compat', records, samplingRate, repeatCount, false);

if exist(fullfile(v0317Root, 'ppg_process_v2_compat_mex.mexmaca64'), 'file')
    results.v0317_mex = run_suite(v0317Root, 'ppg_process_v2_compat_mex', records, samplingRate, repeatCount, true);
else
    results.v0317_mex = [];
end

fprintf('\nSummary\n');
print_result_line('0421 current (MATLAB)', results.current0421);
print_result_line('0317 v2 (MATLAB)', results.v0317_matlab);
if ~isempty(results.v0317_mex)
    print_result_line('0317 v2 (MEX)', results.v0317_mex);
end
end

function suiteResult = run_suite(projectRoot, entryName, records, samplingRate, repeatCount, isMex)

elapsedList = zeros(numel(records), repeatCount);
sampleCountList = zeros(numel(records), 1);
outputCountList = zeros(numel(records), 1);

for recordIdx = 1:numel(records)
    record = records{recordIdx};
    sampleCountList(recordIdx) = numel(record.ppg_r);

    % Warm up once to reduce one-time overhead and JIT noise.
    run_stream_once(projectRoot, entryName, record, isMex);

    for repIdx = 1:repeatCount
        tic;
        outputCountList(recordIdx) = run_stream_once(projectRoot, entryName, record, isMex);
        elapsedList(recordIdx, repIdx) = toc;
    end
end

totalElapsedPerRepeat = sum(elapsedList, 1);
totalSamples = sum(sampleCountList);
totalOutputs = sum(outputCountList);
recordDurationSec = totalSamples / samplingRate;

suiteResult = struct();
suiteResult.entryName = entryName;
suiteResult.projectRoot = projectRoot;
suiteResult.isMex = isMex;
suiteResult.elapsedMatrix = elapsedList;
suiteResult.meanTotalSec = mean(totalElapsedPerRepeat);
suiteResult.stdTotalSec = std(totalElapsedPerRepeat);
suiteResult.usPerSample = suiteResult.meanTotalSec / totalSamples * 1e6;
suiteResult.msPerOutput = suiteResult.meanTotalSec / max(totalOutputs, 1) * 1e3;
suiteResult.realTimeRatio = suiteResult.meanTotalSec / recordDurationSec;
suiteResult.speedupVsRealtime = recordDurationSec / suiteResult.meanTotalSec;
suiteResult.totalSamples = totalSamples;
suiteResult.totalOutputs = totalOutputs;
end

function outputCount = run_stream_once(projectRoot, entryName, record, isMex)

originalFolder = pwd;
cleanupObj = onCleanup(@() cd(originalFolder));
cd(projectRoot);

reset_project_state(entryName, isMex);

outputCount = 0;
for sampleIdx = 1:numel(record.ppg_r)
    if strcmp(entryName, 'ppg_process')
        [outputFlag, ~, ~, ~, ~, ~] = ppg_process( ...
            record.ppg_r(sampleIdx), ...
            record.ppg_ir(sampleIdx), ...
            record.ppg_g(sampleIdx), ...
            uint32(sampleIdx), ...
            record.bodyMove(sampleIdx));
    elseif strcmp(entryName, 'ppg_process_v2_compat')
        [outputFlag, ~, ~, ~, ~, ~] = ppg_process_v2_compat( ...
            record.ppg_r(sampleIdx), ...
            record.ppg_ir(sampleIdx), ...
            record.ppg_g(sampleIdx), ...
            uint32(sampleIdx), ...
            record.bodyMove(sampleIdx));
    else
        [outputFlag, ~, ~, ~, ~, ~] = ppg_process_v2_compat_mex( ...
            record.ppg_r(sampleIdx), ...
            record.ppg_ir(sampleIdx), ...
            record.ppg_g(sampleIdx), ...
            uint32(sampleIdx), ...
            record.bodyMove(sampleIdx));
    end

    if outputFlag
        outputCount = outputCount + 1;
    end
end
end

function reset_project_state(entryName, isMex)

if strcmp(entryName, 'ppg_process')
    clear ppg_process r_pr_calculation r_pr_fix r_smoothing pr_smoothing
elseif strcmp(entryName, 'ppg_process_v2_compat')
    clear ppg_process_v2_compat r_pr_calculation_v2 pr_estimation_v2 r_pr_fix r_smoothing pr_smoothing preprocess_ppg_window_shared
elseif isMex
    clear ppg_process_v2_compat_mex
end
end

function record = load_benchmark_record(dataID)

[filename, time_offset, drop_num_start, drop_num_end] = get_filename(dataID);
opts = build_read_options();
data = readmatrix(filename, opts);

sensor_data = str2double(data(drop_num_start-time_offset+1:size(data,1)-drop_num_end-time_offset, [3, 4, 5]));
bodyMove = str2double(data(drop_num_start-time_offset+1:size(data,1)-drop_num_end-time_offset, 10));

record = struct();
record.dataID = dataID;
record.ppg_r = single(sensor_data(:, 1));
record.ppg_ir = single(sensor_data(:, 2));
record.ppg_g = single(sensor_data(:, 3));
record.bodyMove = single(bodyMove);
end

function opts = build_read_options()

opts = delimitedTextImportOptions("NumVariables", 13);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["time", "dev_time", "ppg_r", "ppg_ir", "ppg_g", "acc_x", "acc_y", "acc_z", "slp_SPO2", "slp_HR", "masimo_SPO2", "masimo_HR", "date_time"];
opts.VariableTypes = ["string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, opts.VariableNames, "WhitespaceRule", "preserve");
opts = setvaropts(opts, opts.VariableNames, "EmptyFieldRule", "auto");
end

function print_result_line(labelText, resultStruct)

fprintf('%s\n', labelText);
fprintf('  mean total time : %.4f s\n', resultStruct.meanTotalSec);
fprintf('  std total time  : %.4f s\n', resultStruct.stdTotalSec);
fprintf('  us per sample   : %.2f\n', resultStruct.usPerSample);
fprintf('  ms per output   : %.2f\n', resultStruct.msPerOutput);
fprintf('  realtime ratio  : %.4f x\n', resultStruct.realTimeRatio);
fprintf('  speed vs real   : %.2f x realtime\n\n', resultStruct.speedupVsRealtime);
end
