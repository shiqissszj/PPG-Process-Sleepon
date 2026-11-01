%% Replay raw TXT PPG through the existing MATLAB algorithm and compare to EDF.
% Run prepare_pulse_comparison_inputs.py first. It creates one MAT input per
% subject containing raw PPG packet rows, the historical XLSX Movement join,
% EDF SpO2/Pulse, and ECG-derived heart rate.
%
% This script calls the existing ppg_process/r_pr_calculation/r_pr_fix,
% smoothing, and calculate_spo2 functions from this directory. It does not
% modify those functions or any source EDF/TXT/XLSX files.
%
% Route 1: MATLAB SpO2 vs EDF SpO2; MATLAB PR vs EDF Pulse.
% Route 2: MATLAB SpO2 vs EDF SpO2; MATLAB PR vs ECG-derived heart rate.
%
% Positive offset means the MATLAB estimate occurs later than the reference:
% compare device[t + offset] with reference[t]. Offsets are estimated in an
% valid common timeline, as in SpO2_PR_main.m and the Python EDF/XLSX
% comparator. If the search correlation is weak or there are too few pairs,
% zero offset is retained and the reason is recorded.

clearvars;
clc;

%% User configuration
SCRIPT_DIR = fileparts(mfilename('fullpath'));
DATA_ROOT = '/Volumes/NewSSS/邵逸夫医院睡眠监测数据/PPG-PSG';
PREPARED_ROOT = fullfile(DATA_ROOT, 'Pulse_from_ECG_derived', 'python_inputs');
if ~isempty(getenv('SLEEPON_COMPARE_PREPARED_ROOT'))
    PREPARED_ROOT = getenv('SLEEPON_COMPARE_PREPARED_ROOT');
end
OUTPUT_ROOT = fullfile(DATA_ROOT, 'Pulse_from_ECG_derived', 'matlab_results');
if ~isempty(getenv('SLEEPON_COMPARE_OUTPUT_ROOT'))
    OUTPUT_ROOT = getenv('SLEEPON_COMPARE_OUTPUT_ROOT');
end

SUBJECT_SELECTION = "11";  % e.g. "9" to run one subject.
if ~isempty(getenv('SLEEPON_COMPARE_SUBJECT'))
    SUBJECT_SELECTION = string(getenv('SLEEPON_COMPARE_SUBJECT'));
end
SHOW_INTERACTIVE_PLOTS = true; % keep both main route figures open for zoom/pan
if strcmp(getenv('SLEEPON_COMPARE_NO_PLOTS'), '1')
    SHOW_INTERACTIVE_PLOTS = false;
end
% For workbook entry: replay all selected subjects and print one RMSE row per
% subject, without opening figures or writing comparison files.
METRICS_ONLY = strcmp(getenv('SLEEPON_COMPARE_METRICS_ONLY'), '1');
if METRICS_ONLY
    SHOW_INTERACTIVE_PLOTS = false;
end
AUTO_OFFSET = true;
MAX_OFFSET_SECONDS = 300;
MIN_OFFSET_PAIRS = 300;
MIN_OFFSET_CORRELATION = 0.20;
MAX_PAIR_DISTANCE_SECONDS = 0.35;
IGNORE_FIRST_OUTPUTS_PER_RUN = 30; % algorithm's stateful filters need warm-up
SPO2_VALID_RANGE = [50, 100];
HR_VALID_RANGE = [30, 220];
SPO2_CONFIDENCE_THRESHOLD = 0.75;
LOCAL_TIME_ZONE = 'Asia/Shanghai';

addpath(SCRIPT_DIR);
if ~isfolder(PREPARED_ROOT)
    error('Prepared input folder does not exist: %s. Run the Python preparation script first.', PREPARED_ROOT);
end
manifestPath = fullfile(PREPARED_ROOT, 'manifest.json');
if ~isfile(manifestPath)
    error('Preparation manifest not found: %s. Run the Python preparation script first.', manifestPath);
end
inputManifest = jsondecode(fileread(manifestPath));
manifestStatus = string(inputManifest.status);
if ~ismember(manifestStatus, ["complete", "completed_with_failures"])
    error('Python preparation is not complete (status: %s). Check %s.', ...
        char(manifestStatus), manifestPath);
end
preparedSubjectIds = string(inputManifest.prepared_subjects(:));
if isempty(preparedSubjectIds)
    error('The Python manifest contains no successfully prepared subjects: %s', manifestPath);
end

if SUBJECT_SELECTION ~= "all"
    selectedSubject = SUBJECT_SELECTION;
    if ~any(preparedSubjectIds == selectedSubject)
        error('Subject %s was not prepared in the current manifest: %s.', ...
            char(selectedSubject), manifestPath);
    end
    preparedSubjectIds = selectedSubject;
end
inputFiles = strings(numel(preparedSubjectIds), 1);
for subjectIndex = 1:numel(preparedSubjectIds)
    subjectFolder = fullfile(PREPARED_ROOT, char("subject_" + preparedSubjectIds(subjectIndex)));
    inputFiles(subjectIndex) = fullfile(subjectFolder, ...
        char("subject_" + preparedSubjectIds(subjectIndex) + "_inputs.mat"));
    if ~isfile(inputFiles(subjectIndex))
        error('Prepared MAT file is missing: %s', char(inputFiles(subjectIndex)));
    end
end

if ~METRICS_ONLY && ~isfolder(OUTPUT_ROOT)
    mkdir(OUTPUT_ROOT);
end
fprintf('Prepared inputs: %s\n', PREPARED_ROOT);
if METRICS_ONLY
    fprintf('Metrics-only mode: Subject, ECG-PR, EDF Pulse-PR, EDF SpO2-SpO2 RMSE\n');
else
    fprintf('MATLAB outputs:  %s\n', OUTPUT_ROOT);
end

summaryRows = table('Size', [0, 12], ...
    'VariableTypes', {'string','string','string','string', ...
    'double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'Subject','Route','Signal','Variant', ...
    'OffsetSeconds','OffsetSearchCorrelation','PairCount','EvaluationCoverage', ...
    'RMSE','MAE','BiasEstimateMinusReference','Correlation'});

for fileIndex = 1:numel(inputFiles)
    inputPath = char(inputFiles(fileIndex));
    input = load(inputPath);
    subjectId = preparedSubjectIds(fileIndex);
    fprintf('\n[%d/%d] Replaying subject %s (%s)\n', ...
        fileIndex, numel(inputFiles), char(subjectId), inputPath);

    requiredVariables = {'ppg_red_raw','ppg_ir_raw','ppg_green_raw', ...
        'ppg_movement','ppg_sample_time_unix_s','ppg_segment_id', ...
        'edf_start_unix_s','edf_bin_end_unix_s','edf_spo2_1hz', ...
        'edf_spo2_valid','edf_spo2_xml_artifact','edf_pulse_1hz', ...
        'edf_pulse_valid','ecg_r_peak_unix_s','ecg_hr_1hz','ecg_hr_coverage_s'};
    for keyIndex = 1:numel(requiredVariables)
        if ~isfield(input, requiredVariables{keyIndex})
            error('Input %s is missing required field %s.', inputPath, requiredVariables{keyIndex});
        end
    end

    red = single(input.ppg_red_raw(:));
    infrared = single(input.ppg_ir_raw(:));
    green = single(input.ppg_green_raw(:));
    movement = single(input.ppg_movement(:));
    ppgTime = double(input.ppg_sample_time_unix_s(:));
    segmentId = double(input.ppg_segment_id(:));
    ppgLength = numel(red);
    if any([numel(infrared), numel(green), numel(movement), ...
            numel(ppgTime), numel(segmentId)] ~= ppgLength)
        error('Subject %s PPG arrays have different lengths.', subjectId);
    end

    % A missing Movement value or packet-counter break ends a run. Replaying
    % across it would make ppg_process treat nonconsecutive samples as 50 Hz.
    sampleValid = isfinite(red) & isfinite(infrared) & isfinite(green) & ...
        isfinite(movement) & isfinite(ppgTime);
    runStart = sampleValid;
    runEnd = sampleValid;
    if ppgLength > 1
        sameRunAsPrevious = segmentId(2:end) == segmentId(1:end-1) & ...
            sampleValid(1:end-1);
        runStart(2:end) = sampleValid(2:end) & ~sameRunAsPrevious;
        sameRunAsNext = segmentId(1:end-1) == segmentId(2:end) & sampleValid(2:end);
        runEnd(1:end-1) = sampleValid(1:end-1) & ~sameRunAsNext;
    end
    runStarts = find(runStart);
    runEnds = find(runEnd);
    if numel(runStarts) ~= numel(runEnds)
        error('Internal run-boundary mismatch for subject %s.', subjectId);
    end

    maxOutputs = ceil(ppgLength / 50) + numel(runStarts);
    outputTime = nan(maxOutputs, 1);
    outputSpO2 = nan(maxOutputs, 1);
    outputPR = nan(maxOutputs, 1);
    outputConfidence = nan(maxOutputs, 1);
    outputSQI = nan(maxOutputs, 6);
    outputSmoothedR = nan(maxOutputs, 1);
    outputCounter = nan(maxOutputs, 1);
    outputSegment = nan(maxOutputs, 1);
    outputIndex = 0;
    replayedRunCount = 0;
    skippedShortRunCount = 0;

    for runIndex = 1:numel(runStarts)
        first = runStarts(runIndex);
        last = runEnds(runIndex);
        if last < first || (last - first + 1) < 150
            skippedShortRunCount = skippedShortRunCount + 1;
            continue;
        end
        replayedRunCount = replayedRunCount + 1;

        % Clear persistent streaming state between truly discontinuous runs.
        clear ppg_process r_pr_calculation r_pr_fix r_smoothing pr_smoothing ...
            ac_filter dc_ac_spliter find_peaks

        runOutputCounter = 0;
        for sampleIndex = first:last
            [outputFlag, currentPR, currentSpO2, currentSQI, currentConfidence, currentR] = ...
                ppg_process(red(sampleIndex), infrared(sampleIndex), green(sampleIndex), ...
                uint32(sampleIndex - first + 1), movement(sampleIndex));
            if outputFlag
                runOutputCounter = runOutputCounter + 1;
                outputIndex = outputIndex + 1;
                outputTime(outputIndex) = ppgTime(sampleIndex);
                outputSpO2(outputIndex) = double(currentSpO2);
                outputPR(outputIndex) = double(currentPR);
                outputConfidence(outputIndex) = double(currentConfidence);
                outputSQI(outputIndex, :) = double(currentSQI(:)).';
                outputSmoothedR(outputIndex) = double(currentR);
                outputCounter(outputIndex) = runOutputCounter;
                outputSegment(outputIndex) = segmentId(sampleIndex);
            end
        end
        if ~METRICS_ONLY
            fprintf('  PPG run %d/%d: %d samples, %d outputs\n', ...
                runIndex, numel(runStarts), last - first + 1, runOutputCounter);
        end
    end

    outputTime = outputTime(1:outputIndex);
    outputSpO2 = outputSpO2(1:outputIndex);
    outputPR = outputPR(1:outputIndex);
    outputConfidence = outputConfidence(1:outputIndex);
    outputSQI = outputSQI(1:outputIndex, :);
    outputSmoothedR = outputSmoothedR(1:outputIndex);
    outputCounter = outputCounter(1:outputIndex);
    outputSegment = outputSegment(1:outputIndex);
    warmupValid = outputCounter > IGNORE_FIRST_OUTPUTS_PER_RUN;
    outputSpO2(~warmupValid) = NaN;
    outputPR(~warmupValid) = NaN;

    % Sort by absolute time for lookup. If separate device runs share an
    % identical time, keep the first recorded estimate at that timestamp.
    [outputTime, order] = sort(outputTime);
    outputSpO2 = outputSpO2(order);
    outputPR = outputPR(order);
    outputConfidence = outputConfidence(order);
    outputSQI = outputSQI(order, :);
    outputSmoothedR = outputSmoothedR(order);
    outputCounter = outputCounter(order);
    outputSegment = outputSegment(order);
    [outputTime, uniqueIndex] = unique(outputTime, 'stable');
    outputSpO2 = outputSpO2(uniqueIndex);
    outputPR = outputPR(uniqueIndex);
    outputConfidence = outputConfidence(uniqueIndex);
    outputSQI = outputSQI(uniqueIndex, :);
    outputSmoothedR = outputSmoothedR(uniqueIndex);
    outputCounter = outputCounter(uniqueIndex);
    outputSegment = outputSegment(uniqueIndex);

    edfStart = double(input.edf_start_unix_s(1));
    edfTime = double(input.edf_bin_end_unix_s(:));
    edfSpO2 = double(input.edf_spo2_1hz(:));
    edfSpO2Valid = logical(input.edf_spo2_valid(:));
    edfPulse = double(input.edf_pulse_1hz(:));
    edfPulseValid = logical(input.edf_pulse_valid(:));
    ecgHR = double(input.ecg_hr_1hz(:));
    ecgCoverage = double(input.ecg_hr_coverage_s(:));
    if any([numel(edfSpO2), numel(edfSpO2Valid), numel(edfPulse), ...
            numel(edfPulseValid), numel(ecgHR), numel(ecgCoverage)] ~= numel(edfTime))
        error('Subject %s reference arrays have different lengths.', subjectId);
    end

    % Route 1: compare the PPG algorithm with both EDF channels.
    spo2Comparison = compareSignal(outputTime, outputSpO2, outputConfidence, ...
        edfTime, edfSpO2, edfSpO2Valid, ...
        AUTO_OFFSET, MAX_OFFSET_SECONDS, MIN_OFFSET_PAIRS, MIN_OFFSET_CORRELATION, ...
        MAX_PAIR_DISTANCE_SECONDS, SPO2_VALID_RANGE);
    pulseComparison = compareSignal(outputTime, outputPR, outputConfidence, ...
        edfTime, edfPulse, edfPulseValid, ...
        AUTO_OFFSET, MAX_OFFSET_SECONDS, MIN_OFFSET_PAIRS, MIN_OFFSET_CORRELATION, ...
        MAX_PAIR_DISTANCE_SECONDS, HR_VALID_RANGE);

    summaryRows = appendMetricRows(summaryRows, subjectId, "Route1_EDF", "SpO2", spo2Comparison);
    summaryRows = appendConfidenceMetricRows(summaryRows, subjectId, "Route1_EDF", ...
        spo2Comparison, SPO2_CONFIDENCE_THRESHOLD);
    summaryRows = appendMetricRows(summaryRows, subjectId, "Route1_EDF", "Pulse", pulseComparison);

    % Route 2 reuses the same PPG replay and SpO2 comparison, replacing only
    % the heart-rate reference with the 1 Hz ECG-derived series.
    ecgValid = isfinite(ecgHR) & ecgCoverage >= 0.5;
    ecgComparison = compareSignal(outputTime, outputPR, outputConfidence, ...
        edfTime, ecgHR, ecgValid, ...
        AUTO_OFFSET, MAX_OFFSET_SECONDS, MIN_OFFSET_PAIRS, MIN_OFFSET_CORRELATION, ...
        MAX_PAIR_DISTANCE_SECONDS, HR_VALID_RANGE);
    summaryRows = appendMetricRows(summaryRows, subjectId, "Route2_ECG", "SpO2", spo2Comparison);
    summaryRows = appendConfidenceMetricRows(summaryRows, subjectId, "Route2_ECG", ...
        spo2Comparison, SPO2_CONFIDENCE_THRESHOLD);
    summaryRows = appendMetricRows(summaryRows, subjectId, "Route2_ECG", "ECG_HR", ecgComparison);

    if METRICS_ONLY
        ecgMetric = calculateMetrics(ecgComparison.aligned.deviceValues, ...
            ecgComparison.aligned.referenceValues);
        pulseMetric = calculateMetrics(pulseComparison.aligned.deviceValues, ...
            pulseComparison.aligned.referenceValues);
        spo2Metric = calculateMetrics(spo2Comparison.aligned.deviceValues, ...
            spo2Comparison.aligned.referenceValues);
        fprintf('RMSE_ROW,%s,%.8f,%.8f,%.8f,%d,%d,%d,%g,%g,%g\n', ...
            char(subjectId), ecgMetric.RMSE, pulseMetric.RMSE, spo2Metric.RMSE, ...
            ecgMetric.PairCount, pulseMetric.PairCount, spo2Metric.PairCount, ...
            ecgComparison.appliedOffsetSeconds, pulseComparison.appliedOffsetSeconds, ...
            spo2Comparison.appliedOffsetSeconds);
        continue;
    end

    subjectOutDir = fullfile(OUTPUT_ROOT, char("subject_" + subjectId));
    if ~isfolder(subjectOutDir)
        mkdir(subjectOutDir);
    end

    writePairs(subjectOutDir, subjectId, "route1_spo2", spo2Comparison, LOCAL_TIME_ZONE);
    writePairs(subjectOutDir, subjectId, "route1_edf_pulse", pulseComparison, LOCAL_TIME_ZONE);
    writePairs(subjectOutDir, subjectId, "route2_spo2", spo2Comparison, LOCAL_TIME_ZONE);
    writePairs(subjectOutDir, subjectId, "route2_ecg_hr", ecgComparison, LOCAL_TIME_ZONE);
    plotRoute(subjectOutDir, subjectId, "Route 1: EDF SpO2 and Pulse", ...
        "route1_edf_pulse", "EDF Pulse (bpm)", outputTime, outputSpO2, outputPR, outputConfidence, ...
        edfTime, edfSpO2, edfPulse, spo2Comparison, pulseComparison, ...
        SPO2_CONFIDENCE_THRESHOLD, LOCAL_TIME_ZONE, SHOW_INTERACTIVE_PLOTS);
    plotRoute(subjectOutDir, subjectId, "Route 2: EDF SpO2 and ECG-derived HR", ...
        "route2_ecg_hr", "ECG-derived HR (bpm)", outputTime, outputSpO2, outputPR, outputConfidence, ...
        edfTime, edfSpO2, ecgHR, spo2Comparison, ecgComparison, ...
        SPO2_CONFIDENCE_THRESHOLD, LOCAL_TIME_ZONE, SHOW_INTERACTIVE_PLOTS);

    subjectSummary = summaryRows(summaryRows.Subject == subjectId, :);
    writetable(subjectSummary, fullfile(subjectOutDir, "metrics.csv"));
    save(fullfile(subjectOutDir, "matlab_replay.mat"), ...
        'subjectId','inputPath','outputTime','outputSpO2','outputPR', ...
        'outputConfidence','outputSQI','outputSmoothedR','outputCounter', ...
        'outputSegment','edfTime','edfSpO2','edfPulse','ecgHR','ecgCoverage', ...
        'spo2Comparison','pulseComparison','ecgComparison','replayedRunCount', ...
        'skippedShortRunCount','IGNORE_FIRST_OUTPUTS_PER_RUN','MAX_OFFSET_SECONDS', ...
        'MIN_OFFSET_PAIRS','MIN_OFFSET_CORRELATION');
    fprintf('  Saved comparisons to %s\n', subjectOutDir);
end

if METRICS_ONLY
    fprintf('\nCompleted %d subject(s) in metrics-only mode.\n', numel(inputFiles));
else
    summaryPath = fullfile(OUTPUT_ROOT, 'all_subjects_metrics.csv');
    writetable(summaryRows, summaryPath);
    fprintf('\nCompleted %d subject(s). Summary: %s\n', ...
        numel(inputFiles), summaryPath);
end


%% Local helpers
function comparison = compareSignal(deviceTime, deviceValues, deviceConfidence, ...
    referenceTime, referenceValues, referenceValid, ...
    autoOffset, maxOffsetSeconds, minPairs, minCorrelation, maxPairDistance, validRange)

deviceTime = double(deviceTime(:));
deviceValues = double(deviceValues(:));
deviceConfidence = double(deviceConfidence(:));
referenceTime = double(referenceTime(:));
referenceValues = double(referenceValues(:));
referenceValid = logical(referenceValid(:));
if numel(deviceTime) ~= numel(deviceValues) || numel(referenceTime) ~= numel(referenceValues)
    error('Time and value vector lengths do not match.');
end
deviceValid = isfinite(deviceTime) & isfinite(deviceValues) & ...
    deviceValues >= validRange(1) & deviceValues <= validRange(2);
referenceValid = referenceValid & isfinite(referenceTime) & isfinite(referenceValues) & ...
    referenceValues >= validRange(1) & referenceValues <= validRange(2);
deviceTime = deviceTime(deviceValid);
deviceValues = deviceValues(deviceValid);
deviceConfidence = deviceConfidence(deviceValid);
referenceTime = referenceTime(referenceValid);
referenceValues = referenceValues(referenceValid);

% EDF vitals represent [second, second+1) and are timestamped at the right
% edge. Place each MATLAB PPG output into the same 1 Hz bin before pairing,
% matching the absolute-time Python comparator's second-grid semantics.
% Repeated outputs in one second are reduced by their median.
if ~isempty(deviceTime)
    deviceTime = floor(deviceTime) + 1;
    [deviceTime, ~, deviceSecondGroup] = unique(deviceTime, 'sorted');
    deviceValues = accumarray(deviceSecondGroup, deviceValues, [], @median);
    deviceConfidence = accumarray(deviceSecondGroup, deviceConfidence, [], ...
        @(values) median(values, 'omitnan'));
end

comparison = struct;
comparison.status = "no_common_valid_data";
comparison.appliedOffsetSeconds = 0;
comparison.estimatedOffsetSeconds = NaN;
comparison.offsetSearchCorrelation = NaN;
comparison.offsetSearchPairCount = 0;
comparison.offsetAccepted = false;
comparison.raw = emptyPairStruct();
comparison.aligned = emptyPairStruct();
comparison.evaluationSecondCount = 0;
if isempty(deviceTime) || isempty(referenceTime)
    return;
end

commonStart = max(min(deviceTime), min(referenceTime));
commonStop = min(max(deviceTime), max(referenceTime));
if commonStop <= commonStart
    return;
end
commonReference = referenceTime >= commonStart & referenceTime <= commonStop;
comparison.evaluationSecondCount = sum(commonReference);

if autoOffset
    bestCorrelation = -Inf;
    bestLag = 0;
    bestCount = 0;
    for lag = -maxOffsetSeconds:maxOffsetSeconds
        pairs = makePairs(referenceTime(commonReference), ...
            referenceValues(commonReference), deviceTime, deviceValues, deviceConfidence, ...
            commonStart, commonStop, lag, maxPairDistance);
        pairCount = numel(pairs.referenceValues);
        if pairCount < minPairs || std(pairs.referenceValues) == 0 || std(pairs.deviceValues) == 0
            continue;
        end
        c = corrcoef(pairs.deviceValues, pairs.referenceValues);
        candidateCorrelation = c(1,2);
        if isfinite(candidateCorrelation) && (candidateCorrelation > bestCorrelation || ...
                (candidateCorrelation == bestCorrelation && ...
                (abs(lag) < abs(bestLag) || ...
                (abs(lag) == abs(bestLag) && lag < bestLag))))
            bestCorrelation = candidateCorrelation;
            bestLag = lag;
            bestCount = pairCount;
        end
    end
    comparison.offsetSearchPairCount = bestCount;
    if bestCorrelation >= minCorrelation
        comparison.estimatedOffsetSeconds = bestLag;
        comparison.appliedOffsetSeconds = bestLag;
        comparison.offsetSearchCorrelation = bestCorrelation;
        comparison.offsetAccepted = true;
        comparison.status = "offset_estimated";
    else
        comparison.status = "offset_rejected_low_correlation_or_pair_count";
        if isfinite(bestCorrelation)
            comparison.offsetSearchCorrelation = bestCorrelation;
            comparison.offsetSearchPairCount = bestCount;
            comparison.estimatedOffsetSeconds = bestLag;
        end
    end
else
    comparison.status = "offset_search_disabled";
end

comparison.raw = makePairs(referenceTime(commonReference), referenceValues(commonReference), ...
    deviceTime, deviceValues, deviceConfidence, commonStart, commonStop, 0, maxPairDistance);
comparison.aligned = makePairs(referenceTime(commonReference), referenceValues(commonReference), ...
    deviceTime, deviceValues, deviceConfidence, commonStart, commonStop, ...
    comparison.appliedOffsetSeconds, maxPairDistance);

% Confidence-qualified SpO2 agreement is additional context. The primary
% estimate metrics above retain every finite, range-valid algorithm output.
comparison.raw.confidence = comparison.raw.deviceConfidence;
comparison.aligned.confidence = comparison.aligned.deviceConfidence;
end


function pairs = makePairs(referenceTime, referenceValues, deviceTime, deviceValues, ...
    deviceConfidence, windowStart, windowStop, lagSeconds, maxDistance)

pairs = emptyPairStruct();
if numel(deviceTime) < 2 || isempty(referenceTime)
    return;
end
targetDeviceTime = referenceTime(:) + lagSeconds;
deviceIndices = interp1(deviceTime, (1:numel(deviceTime)).', ...
    targetDeviceTime, 'nearest', NaN);
validIndex = isfinite(deviceIndices);
deviceIndices = round(deviceIndices(validIndex));
referenceIndices = find(validIndex);
if isempty(deviceIndices)
    return;
end
distance = abs(deviceTime(deviceIndices) - targetDeviceTime(validIndex));
insideReferenceWindow = referenceTime(referenceIndices) >= windowStart & ...
    referenceTime(referenceIndices) < windowStop;
keep = distance <= maxDistance & insideReferenceWindow;
deviceIndices = deviceIndices(keep);
referenceIndices = referenceIndices(keep);
if isempty(deviceIndices)
    return;
end
pairs.referenceTime = referenceTime(referenceIndices);
pairs.deviceTime = deviceTime(deviceIndices);
pairs.referenceValues = referenceValues(referenceIndices);
pairs.deviceValues = deviceValues(deviceIndices);
pairs.deviceConfidence = deviceConfidence(deviceIndices);
pairs.referenceIndex = referenceIndices;
pairs.deviceIndex = deviceIndices;
pairs.lagSeconds = lagSeconds;
end


function pairs = emptyPairStruct()
pairs = struct('referenceTime',[],'deviceTime',[],'referenceValues',[], ...
    'deviceValues',[],'deviceConfidence',[],'confidence',[], ...
    'referenceIndex',[],'deviceIndex',[],'lagSeconds',0);
end


function rows = appendMetricRows(rows, subjectId, routeName, signalName, comparison)
rows = appendOneMetric(rows, subjectId, routeName, signalName, "raw", ...
    0, comparison, comparison.raw);
variant = "fixed_offset";
if ~comparison.offsetAccepted && comparison.appliedOffsetSeconds == 0
    variant = "zero_offset_offset_not_accepted";
end
rows = appendOneMetric(rows, subjectId, routeName, signalName, variant, ...
    comparison.appliedOffsetSeconds, comparison, comparison.aligned);
end


function rows = appendConfidenceMetricRows(rows, subjectId, routeName, comparison, threshold)
rawMask = isfinite(comparison.raw.deviceConfidence) & ...
    comparison.raw.deviceConfidence > threshold;
alignedMask = isfinite(comparison.aligned.deviceConfidence) & ...
    comparison.aligned.deviceConfidence > threshold;
rawReliable = subsetPairs(comparison.raw, rawMask);
alignedReliable = subsetPairs(comparison.aligned, alignedMask);
rows = appendOneMetric(rows, subjectId, routeName, ...
    "SpO2_confidence_gt_" + string(threshold), "reliable_zero_offset", ...
    0, comparison, rawReliable);
variant = "reliable_fixed_offset";
if ~comparison.offsetAccepted && comparison.appliedOffsetSeconds == 0
    variant = "reliable_zero_offset_offset_not_accepted";
end
rows = appendOneMetric(rows, subjectId, routeName, ...
    "SpO2_confidence_gt_" + string(threshold), variant, ...
    comparison.appliedOffsetSeconds, comparison, alignedReliable);
end


function selected = subsetPairs(pairs, keep)
selected = pairs;
fields = {'referenceTime','deviceTime','referenceValues','deviceValues', ...
    'deviceConfidence','confidence','referenceIndex','deviceIndex'};
for index = 1:numel(fields)
    field = fields{index};
    if numel(pairs.(field)) == numel(keep)
        values = pairs.(field);
        selected.(field) = values(keep);
    end
end
end


function rows = appendOneMetric(rows, subjectId, routeName, signalName, variant, offset, comparison, pairs)
metric = calculateMetrics(pairs.deviceValues, pairs.referenceValues);
coverage = NaN;
if comparison.evaluationSecondCount > 0
    coverage = metric.PairCount / comparison.evaluationSecondCount;
end
newRow = table(string(subjectId), string(routeName), string(signalName), string(variant), ...
    double(offset), double(comparison.offsetSearchCorrelation), double(metric.PairCount), ...
    double(coverage), double(metric.RMSE), double(metric.MAE), double(metric.Bias), ...
    double(metric.Correlation), 'VariableNames', rows.Properties.VariableNames);
rows = [rows; newRow];
end


function metric = calculateMetrics(estimate, reference)
estimate = double(estimate(:));
reference = double(reference(:));
valid = isfinite(estimate) & isfinite(reference);
estimate = estimate(valid);
reference = reference(valid);
metric = struct('PairCount',numel(estimate),'RMSE',NaN,'MAE',NaN, ...
    'Bias',NaN,'Correlation',NaN);
if isempty(estimate)
    return;
end
errorValue = estimate - reference;
metric.RMSE = sqrt(mean(errorValue.^2));
metric.MAE = mean(abs(errorValue));
metric.Bias = mean(errorValue);
if numel(estimate) > 1 && std(estimate) > 0 && std(reference) > 0
    c = corrcoef(estimate, reference);
    metric.Correlation = c(1,2);
end
end


function writePairs(outputDir, subjectId, signalTag, comparison, timeZone)
variants = {"raw", comparison.raw; "offset", comparison.aligned};
for index = 1:size(variants,1)
    label = variants{index,1};
    pairs = variants{index,2};
    if isempty(pairs.referenceValues)
        outputTable = table('Size',[0, 5], ...
            'VariableTypes',{'datetime','datetime','double','double','double'}, ...
            'VariableNames',{'ReferenceTimeLocal','MATLABOutputTimeLocal', ...
            'ReferenceValue','MATLABEstimate','EstimateMinusReference'});
    else
        refTime = datetime(pairs.referenceTime, 'ConvertFrom','posixtime', 'TimeZone',timeZone);
        deviceTime = datetime(pairs.deviceTime, 'ConvertFrom','posixtime', 'TimeZone',timeZone);
        outputTable = table(refTime(:), deviceTime(:), pairs.referenceValues(:), ...
            pairs.deviceValues(:), pairs.deviceValues(:)-pairs.referenceValues(:), ...
            'VariableNames', {'ReferenceTimeLocal','MATLABOutputTimeLocal', ...
            'ReferenceValue','MATLABEstimate','EstimateMinusReference'});
    end
    fileName = sprintf('subject_%s_%s_%s_pairs.csv', ...
        char(subjectId), char(signalTag), char(label));
    writetable(outputTable, fullfile(outputDir, fileName));
end
end


function plotRoute(outputDir, subjectId, routeTitle, routeFileTag, heartRateLabel, ...
    deviceTime, deviceSpO2, deviceHR, confidence, edfTime, edfSpO2, edfHR, ...
    spo2Comparison, hrComparison, confidenceThreshold, timeZone, showInteractive)

visibility = 'off';
if showInteractive
    visibility = 'on';
end
fig = figure('Visible',visibility,'Color','w','Position',[80 80 1500 900], ...
    'Name',sprintf('Subject %s: %s',char(subjectId),char(routeTitle)), ...
    'NumberTitle','off');
layout = tiledlayout(fig, 2, 2, 'TileSpacing','compact','Padding','compact');
title(layout, sprintf('Subject %s: %s', char(subjectId), char(routeTitle)), 'Interpreter','none');
deviceDate = datetime(deviceTime, 'ConvertFrom','posixtime', 'TimeZone',timeZone);
edfDate = datetime(edfTime, 'ConvertFrom','posixtime', 'TimeZone',timeZone);

axSpO2 = nexttile(layout);
ax = axSpO2;
plot(ax, edfDate, edfSpO2, 'DisplayName','EDF SpO2', 'LineWidth',0.8); hold(ax,'on');
plot(ax, deviceDate, deviceSpO2, 'DisplayName','MATLAB SpO2 (all valid)', ...
    'LineWidth',0.65, 'Color',[0.45 0.45 0.45]);
reliableSpO2 = isfinite(deviceSpO2) & isfinite(confidence) & confidence > confidenceThreshold;
if any(reliableSpO2)
    plot(ax, deviceDate(reliableSpO2), deviceSpO2(reliableSpO2), ...
        'DisplayName',sprintf('MATLAB SpO2, confidence > %.2f',confidenceThreshold), ...
        'LineWidth',0.8, 'Color',[0.00 0.35 0.80]);
end
lowConfidenceSpO2 = isfinite(deviceSpO2) & isfinite(confidence) & confidence <= confidenceThreshold;
if any(lowConfidenceSpO2)
    scatter(ax, deviceDate(lowConfidenceSpO2), deviceSpO2(lowConfidenceSpO2), ...
        8, 'r', 'filled', 'DisplayName','MATLAB SpO2, low confidence');
end
grid(ax,'on'); ylabel(ax,'SpO2 (%)'); title(ax,'Original timelines'); legend(ax,'Location','best');

axHR = nexttile(layout);
ax = axHR;
plot(ax, edfDate, edfHR, 'DisplayName',heartRateLabel, 'LineWidth',0.8); hold(ax,'on');
plot(ax, deviceDate, deviceHR, 'DisplayName','MATLAB PR', 'LineWidth',0.8);
grid(ax,'on'); ylabel(ax,'bpm'); title(ax,heartRateLabel,'Interpreter','none'); legend(ax,'Location','best');

axSpO2Aligned = nexttile(layout);
ax = axSpO2Aligned;
plotAligned(ax, spo2Comparison, 'SpO2 (%)', timeZone);
title(ax, sprintf('SpO2 paired values; offset %g s (%s)', ...
    spo2Comparison.appliedOffsetSeconds, spo2Comparison.status), 'Interpreter','none');
addMetricInset(ax, spo2Comparison, confidenceThreshold);

axHRAligned = nexttile(layout);
ax = axHRAligned;
plotAligned(ax, hrComparison, 'bpm', timeZone);
title(ax, sprintf('Heart-rate paired values; offset %g s (%s)', ...
    hrComparison.appliedOffsetSeconds, hrComparison.status), 'Interpreter','none');
addMetricInset(ax, hrComparison, NaN);
xlabel(ax,'Local time');

if showInteractive
    linkedAxes = [axSpO2 axHR];
    if ~isempty(spo2Comparison.raw.referenceValues) || ...
            ~isempty(spo2Comparison.aligned.referenceValues)
        linkedAxes(end+1) = axSpO2Aligned;
    end
    if ~isempty(hrComparison.raw.referenceValues) || ...
            ~isempty(hrComparison.aligned.referenceValues)
        linkedAxes(end+1) = axHRAligned;
    end
    linkaxes(linkedAxes, 'x');
    fullTimeRange = [min([edfDate(:); deviceDate(:)]), ...
        max([edfDate(:); deviceDate(:)])];
    xlim(axSpO2, fullTimeRange);
    uimenu(fig, 'Label','显示全段', ...
        'MenuSelectedFcn',@(~,~) xlim(axSpO2, fullTimeRange));
    zoom(fig,'on');
end

exportgraphics(fig, fullfile(outputDir, sprintf('subject_%s_%s.png', ...
    char(subjectId), char(routeFileTag))), 'Resolution',160);
if ~showInteractive
    close(fig);
end

% Save a separate SpO2 confidence view so algorithm confidence never changes
% which samples appear in the primary numeric comparison.
figConfidence = figure('Visible','off','Color','w','Position',[100 100 1400 450]);
if ~isempty(spo2Comparison.raw.referenceValues)
    scatter(spo2Comparison.raw.referenceTime, spo2Comparison.raw.deviceConfidence, ...
        7, spo2Comparison.raw.deviceValues, 'filled');
    colorbar; ylim([0 1]); grid on;
    xlabel('EDF reference Unix time (s)'); ylabel('MATLAB SpO2 confidence');
    title(sprintf('Subject %s SpO2 confidence (color = estimated SpO2)', char(subjectId)));
else
    axis off;
    text(0.1,0.5,'No valid SpO2 pairs for confidence plot');
end
exportgraphics(figConfidence, fullfile(outputDir, ...
    sprintf('subject_%s_%s_spo2_confidence.png', ...
    char(subjectId), char(routeFileTag))), 'Resolution',160);
close(figConfidence);
if showInteractive
    figure(fig);
end
end


function plotAligned(ax, comparison, yLabelText, timeZone)
if isempty(comparison.raw.referenceValues) && isempty(comparison.aligned.referenceValues)
    text(ax,0.1,0.5,'No valid evaluation pairs'); axis(ax,'off'); return;
end
hold(ax,'on');
if ~isempty(comparison.raw.referenceValues)
    refDate = datetime(comparison.raw.referenceTime, 'ConvertFrom','posixtime', 'TimeZone',timeZone);
    plot(ax, refDate, comparison.raw.referenceValues, ...
        'DisplayName','Reference', 'LineWidth',0.8);
    plot(ax, refDate, comparison.raw.deviceValues, ...
        'DisplayName','MATLAB, zero offset', 'LineWidth',0.7);
end
if ~isempty(comparison.aligned.referenceValues) && comparison.offsetAccepted
    refDate = datetime(comparison.aligned.referenceTime, 'ConvertFrom','posixtime', 'TimeZone',timeZone);
    plot(ax, refDate, comparison.aligned.deviceValues, ...
        'DisplayName','MATLAB, auto offset', 'LineWidth',0.8);
end
grid(ax,'on'); ylabel(ax,yLabelText); xlabel(ax,'Reference local time');
legend(ax,'Location','northeast');
end


function addMetricInset(ax, comparison, confidenceThreshold)
% Compare zero-offset and corrected estimates on exactly the same EDF seconds.
% The CSV also contains whole-evaluation metrics, whose pair counts may differ.
[~, rawIndex, alignedIndex] = intersect( ...
    comparison.raw.referenceTime(:), ...
    comparison.aligned.referenceTime(:), 'stable');
rawEstimate = double(comparison.raw.deviceValues(rawIndex));
alignedEstimate = double(comparison.aligned.deviceValues(alignedIndex));
reference = double(comparison.raw.referenceValues(rawIndex));
valid = isfinite(rawEstimate) & isfinite(alignedEstimate) & isfinite(reference);
rawMetric = calculateMetrics(rawEstimate(valid), reference(valid));
alignedMetric = calculateMetrics(alignedEstimate(valid), reference(valid));

annotationText = sprintf([ ...
    'Auto offset: %+g s (%s)\n' ...
    'RMSE, same EDF seconds (n=%d): %.2f -> %.2f\n' ...
    'Offset search r=%.2f, pairs=%d'], ...
    comparison.appliedOffsetSeconds, char(comparison.status), ...
    rawMetric.PairCount, rawMetric.RMSE, alignedMetric.RMSE, ...
    comparison.offsetSearchCorrelation, comparison.offsetSearchPairCount);
if isfinite(confidenceThreshold)
    rawConfidence = double(comparison.raw.deviceConfidence(rawIndex));
    alignedConfidence = double(comparison.aligned.deviceConfidence(alignedIndex));
    reliable = valid & isfinite(rawConfidence) & isfinite(alignedConfidence) & ...
        rawConfidence > confidenceThreshold & alignedConfidence > confidenceThreshold;
    rawReliable = calculateMetrics(rawEstimate(reliable), reference(reliable));
    alignedReliable = calculateMetrics(alignedEstimate(reliable), reference(reliable));
    annotationText = sprintf( ...
        '%s\nConfidence > %.2f (n=%d): %.2f -> %.2f', ...
        annotationText, confidenceThreshold, rawReliable.PairCount, ...
        rawReliable.RMSE, alignedReliable.RMSE);
end
text(ax, 0.02, 0.03, annotationText, 'Units','normalized', ...
    'VerticalAlignment','bottom', 'HorizontalAlignment','left', ...
    'FontSize',9, 'Interpreter','none', 'BackgroundColor','w', ...
    'EdgeColor',[0.65 0.65 0.65], 'Margin',5, 'HandleVisibility','off');
end
