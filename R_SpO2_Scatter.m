clear;
clc;

% Calibration workflow for the current SpO2_PR_main.m pipeline:
% 1. Load record-level (smoothedR, trueSpO2) pairs.
% 2. Split records into train/validation with low-SpO2 stratification.
% 3. Clean training pairs while preserving low-SpO2 samples.
% 4. Fit weighted candidate models with extra emphasis on low-SpO2.
% 5. Evaluate all models on both train and validation sets.
% 6. Print candidate formulas that can be copied into calculate_spo2.m.

rng(42);

% ---------------- Configuration ----------------
candidateMatFiles = {'R_SpO2_values_current.mat', 'R_SpO2_calibration_export_current.mat', 'R_SpO2_values.mat'};

validationRatio = 0.30;
scatterPointSize = 6;
plotRRange = 0:0.01:1.40;
spo2PlotRange = [65, 100];
rPlotLimits = [0, 1.5];

lowSpO2Threshold = 90;
veryLowSpO2Threshold = 85;
highSpO2Boundary = 95;

defaultWeight = 1.0;
lowSpO2Weight = 3.0;
veryLowSpO2Weight = 5.0;
highSpO2Weight = 0.9;

lowSpO2WinsorThreshold = 1.8;
midSpO2OutlierThreshold = 1.1;
highSpO2OutlierThreshold = 0.9;

scoreWeightOverallRmse = 0.35;
scoreWeightLowRmse = 0.45;
scoreWeightLowBias = 0.20;

% ---------------- Load Data ----------------
matFilename = '';
for idx = 1:length(candidateMatFiles)
    if exist(candidateMatFiles{idx}, 'file')
        matFilename = candidateMatFiles{idx};
        break
    end
end

if isempty(matFilename)
    error('No calibration MAT file found. Run SpO2_PR_main_for_calibration.m first.');
end

loadedData = load(matFilename);
if isfield(loadedData, 'R_SpO2_values_current')
    R_SpO2_values = loadedData.R_SpO2_values_current;
elseif isfield(loadedData, 'R_SpO2_values')
    R_SpO2_values = loadedData.R_SpO2_values;
else
    error('MAT file does not contain R_SpO2_values_current or R_SpO2_values.');
end

dataIDList = [];
if isfield(loadedData, 'dataIDList')
    dataIDList = loadedData.dataIDList;
end

[allR, allSpO2, allRecordId] = flatten_record_cells(R_SpO2_values);
baseMask = isfinite(allR) & isfinite(allSpO2) & allR > 0 & allSpO2 >= 65 & allSpO2 <= 100;
allR = allR(baseMask);
allSpO2 = allSpO2(baseMask);
allRecordId = allRecordId(baseMask);

if isempty(allR)
    error('No valid calibration pairs found in %s.', matFilename);
end

[uniqueRecords, recordHasLowSpO2] = summarize_records(allRecordId, allSpO2, lowSpO2Threshold);
[trainingRecords, validationRecords] = stratified_record_split(uniqueRecords, recordHasLowSpO2, validationRatio);

trainMaskRaw = ismember(allRecordId, trainingRecords);
validationMaskRaw = ismember(allRecordId, validationRecords);

trainRawR = allR(trainMaskRaw);
trainRawSpO2 = allSpO2(trainMaskRaw);
trainRawRecordId = allRecordId(trainMaskRaw);

validationR = allR(validationMaskRaw);
validationSpO2 = allSpO2(validationMaskRaw);
validationRecordId = allRecordId(validationMaskRaw);

[trainR, trainSpO2, trainKeepMask, trainCleaningSummary] = clean_training_pairs( ...
    trainRawR, trainRawSpO2, lowSpO2Threshold, highSpO2Boundary, ...
    lowSpO2WinsorThreshold, midSpO2OutlierThreshold, highSpO2OutlierThreshold);
trainRecordId = trainRawRecordId(trainKeepMask);
trainWeights = build_training_weights(trainSpO2, lowSpO2Threshold, veryLowSpO2Threshold, highSpO2Boundary, ...
    defaultWeight, lowSpO2Weight, veryLowSpO2Weight, highSpO2Weight);

trainLowCount = sum(trainSpO2 <= lowSpO2Threshold);
validationLowCount = sum(validationSpO2 <= lowSpO2Threshold);
trainVeryLowCount = sum(trainSpO2 <= veryLowSpO2Threshold);
validationVeryLowCount = sum(validationSpO2 <= veryLowSpO2Threshold);
trainLowRecordCount = sum(ismember(trainingRecords, uniqueRecords(recordHasLowSpO2)));
validationLowRecordCount = sum(ismember(validationRecords, uniqueRecords(recordHasLowSpO2)));

fprintf('Calibration data file: %s\n', matFilename);
fprintf('Record count: %d\n', numel(uniqueRecords));
fprintf('Low-SpO2 records (<= %.0f): %d\n', lowSpO2Threshold, sum(recordHasLowSpO2));
fprintf('Training records: %d (low-SpO2 records: %d)\n', numel(trainingRecords), trainLowRecordCount);
fprintf('Validation records: %d (low-SpO2 records: %d)\n', numel(validationRecords), validationLowRecordCount);
fprintf('Training samples before cleaning: %d\n', numel(trainRawR));
fprintf('Training samples after cleaning: %d\n', numel(trainR));
fprintf('Validation samples: %d\n', numel(validationR));
fprintf('Train low-SpO2 samples (<= %.0f): %d\n', lowSpO2Threshold, trainLowCount);
fprintf('Validation low-SpO2 samples (<= %.0f): %d\n', lowSpO2Threshold, validationLowCount);
fprintf('Train very-low-SpO2 samples (<= %.0f): %d\n', veryLowSpO2Threshold, trainVeryLowCount);
fprintf('Validation very-low-SpO2 samples (<= %.0f): %d\n', veryLowSpO2Threshold, validationVeryLowCount);
fprintf('Low-SpO2 samples preserved by winsorization: %d\n', trainCleaningSummary.lowSpO2PreservedCount);
fprintf('Mid/High-SpO2 samples removed as outliers: %d\n', trainCleaningSummary.removedOutlierCount);

% ---------------- Fit Models ----------------
models = cell(5, 1);
models{1} = fit_weighted_linear_model(trainR, trainSpO2, trainWeights);
models{2} = fit_weighted_quadratic_model(trainR, trainSpO2, trainWeights);
models{3} = fit_weighted_piecewise_linear_model(trainR, trainSpO2, trainWeights);
models{4} = fit_weighted_segmented_low_spo2_model(trainR, trainSpO2, trainWeights, lowSpO2Threshold);
models{5} = fit_residual_corrected_quadratic_model(trainR, trainSpO2, trainWeights, lowSpO2Threshold);

for idx = 1:length(models)
    models{idx}.trainMetrics = evaluate_model(models{idx}, trainR, trainSpO2, lowSpO2Threshold);
    models{idx}.validationMetrics = evaluate_model(models{idx}, validationR, validationSpO2, lowSpO2Threshold);
    models{idx}.curveY = apply_model(models{idx}, plotRRange);
    models{idx}.isMonotonic = all(diff(models{idx}.curveY) <= 1e-6);
    models{idx}.selectionScore = compute_selection_score( ...
        models{idx}.validationMetrics, scoreWeightOverallRmse, scoreWeightLowRmse, scoreWeightLowBias);
end

bestModelIndex = choose_best_model(models);
bestModel = models{bestModelIndex};

% ---------------- Report ----------------
fprintf('\n================ Calibration Model Comparison ================\n');
for idx = 1:length(models)
    report_model(models{idx});
end

fprintf('\nRecommended model: %s\n', bestModel.name);
fprintf('Reason: best low-SpO2 aware validation score');
if bestModel.isMonotonic
    fprintf(' among monotonic candidates.\n');
else
    fprintf(' (no monotonic candidate available).\n');
end
print_calculate_spo2_snippet(bestModel);

% ---------------- Plot ----------------
figure(101);
clf;
hold on;
scatter(trainRawR, trainRawSpO2, scatterPointSize, [0.80, 0.80, 0.80], 'filled');
scatter(trainR, trainSpO2, scatterPointSize, [0.10, 0.45, 0.90], 'filled');
scatter(validationR, validationSpO2, scatterPointSize, [0.95, 0.50, 0.10], 'filled');

for idx = 1:length(models)
    plot(plotRRange, models{idx}.curveY, 'LineWidth', 1.5);
end

xlim(rPlotLimits);
ylim(spo2PlotRange);
xlabel('R');
ylabel('SpO2');
title('Calibration Data And Candidate Fits');
legend( ...
    'Train raw', ...
    'Train cleaned', ...
    'Validation', ...
    models{1}.name, ...
    models{2}.name, ...
    models{3}.name, ...
    models{4}.name, ...
    models{5}.name, ...
    'Location', 'best');
grid on;
hold off;

figure(102);
clf;
bar(categorical({models{1}.name, models{2}.name, models{3}.name, models{4}.name, models{5}.name}), ...
    [models{1}.selectionScore, models{2}.selectionScore, models{3}.selectionScore, models{4}.selectionScore, models{5}.selectionScore]);
ylabel('Validation Selection Score');
title('Low-SpO2 Aware Validation Score By Model');
grid on;

figure(103);
clf;
subplot(1, 2, 1);
scatter(trainR, trainSpO2, scatterPointSize, [0.10, 0.45, 0.90], 'filled');
hold on;
plot(plotRRange, bestModel.curveY, 'r', 'LineWidth', 2);
xlim(rPlotLimits);
ylim(spo2PlotRange);
title(sprintf('Train: %s', bestModel.name));
xlabel('R');
ylabel('SpO2');
grid on;
hold off;

subplot(1, 2, 2);
scatter(validationR, validationSpO2, scatterPointSize, [0.95, 0.50, 0.10], 'filled');
hold on;
plot(plotRRange, bestModel.curveY, 'r', 'LineWidth', 2);
xlim(rPlotLimits);
ylim(spo2PlotRange);
title(sprintf('Validation: %s', bestModel.name));
xlabel('R');
ylabel('SpO2');
grid on;
hold off;

figure(104);
clf;
bar(categorical({models{1}.name, models{2}.name, models{3}.name, models{4}.name, models{5}.name}), ...
    [models{1}.validationMetrics.rmse, models{2}.validationMetrics.rmse, models{3}.validationMetrics.rmse, ...
    models{4}.validationMetrics.rmse, models{5}.validationMetrics.rmse; ...
    models{1}.validationMetrics.lowRmse, models{2}.validationMetrics.lowRmse, models{3}.validationMetrics.lowRmse, ...
    models{4}.validationMetrics.lowRmse, models{5}.validationMetrics.lowRmse]');
legend('All samples', sprintf('SpO2 <= %.0f', lowSpO2Threshold), 'Location', 'best');
ylabel('Validation RMSE');
title('Validation RMSE Comparison');
grid on;

% ---------------- Save Results ----------------
save('R_SpO2_calibration_current_results.mat', ...
    'matFilename', 'dataIDList', 'trainingRecords', 'validationRecords', ...
    'trainRawR', 'trainRawSpO2', 'trainRecordId', ...
    'validationR', 'validationSpO2', 'validationRecordId', ...
    'trainR', 'trainSpO2', 'trainWeights', 'models', 'bestModelIndex', ...
    'trainCleaningSummary', ...
    'lowSpO2Threshold', 'veryLowSpO2Threshold', 'highSpO2Boundary', ...
    'defaultWeight', 'lowSpO2Weight', 'veryLowSpO2Weight', 'highSpO2Weight', ...
    'scoreWeightOverallRmse', 'scoreWeightLowRmse', 'scoreWeightLowBias');

% ---------------- Local Functions ----------------
function [allR, allSpO2, allRecordId] = flatten_record_cells(inputCells)

allR = [];
allSpO2 = [];
allRecordId = [];

for recordIdx = 1:length(inputCells)
    currentPairs = inputCells{recordIdx};
    if isempty(currentPairs) || size(currentPairs, 2) < 2
        continue
    end

    currentR = currentPairs(:, 1);
    currentSpO2 = currentPairs(:, 2);
    sampleCount = size(currentPairs, 1);

    allR = [allR; currentR(:)];
    allSpO2 = [allSpO2; currentSpO2(:)];
    allRecordId = [allRecordId; repmat(recordIdx, sampleCount, 1)];
end
end

function [uniqueRecords, recordHasLowSpO2] = summarize_records(allRecordId, allSpO2, lowSpO2Threshold)

uniqueRecords = unique(allRecordId, 'stable');
recordHasLowSpO2 = false(size(uniqueRecords));

for idx = 1:numel(uniqueRecords)
    currentMask = allRecordId == uniqueRecords(idx);
    recordHasLowSpO2(idx) = any(allSpO2(currentMask) <= lowSpO2Threshold);
end
end

function [trainingRecords, validationRecords] = stratified_record_split(uniqueRecords, recordHasLowSpO2, validationRatio)

lowRecords = uniqueRecords(recordHasLowSpO2);
normalRecords = uniqueRecords(~recordHasLowSpO2);

validationLow = sample_validation_records(lowRecords, validationRatio);
validationNormal = sample_validation_records(normalRecords, validationRatio);
validationRecords = [validationLow(:); validationNormal(:)];
validationRecords = unique(validationRecords, 'stable');
trainingRecords = setdiff(uniqueRecords, validationRecords, 'stable');

if isempty(validationRecords) && numel(uniqueRecords) > 1
    validationRecords = uniqueRecords(randperm(numel(uniqueRecords), 1));
    trainingRecords = setdiff(uniqueRecords, validationRecords, 'stable');
end

if isempty(trainingRecords) && numel(validationRecords) > 1
    trainingRecords = validationRecords(end);
    validationRecords = validationRecords(1:end - 1);
end
end

function validationRecords = sample_validation_records(recordList, validationRatio)

recordCount = numel(recordList);
if recordCount <= 1
    validationRecords = [];
    return
end

validationCount = round(recordCount * validationRatio);
validationCount = max(validationCount, 1);
validationCount = min(validationCount, recordCount - 1);

shuffledOrder = randperm(recordCount);
validationRecords = recordList(shuffledOrder(1:validationCount));
end

function [cleanR, cleanSpO2, keepMask, cleaningSummary] = clean_training_pairs( ...
    inputR, inputSpO2, lowSpO2Threshold, highSpO2Boundary, ...
    lowSpO2WinsorThreshold, midSpO2OutlierThreshold, highSpO2OutlierThreshold)

cleanRFull = inputR;
keepMask = true(size(inputR));

cleaningSummary = struct();
cleaningSummary.lowSpO2PreservedCount = 0;
cleaningSummary.midSpO2KeptCount = 0;
cleaningSummary.highSpO2KeptCount = 0;
cleaningSummary.removedOutlierCount = 0;

roundedSpO2 = round(inputSpO2);
uniqueSpO2 = unique(roundedSpO2);

for idx = 1:length(uniqueSpO2)
    currentSpO2 = uniqueSpO2(idx);
    currentIndices = find(roundedSpO2 == currentSpO2);
    currentR = inputR(currentIndices);

    if isempty(currentR)
        continue
    end

    if currentSpO2 <= lowSpO2Threshold
        cleanRFull(currentIndices) = winsorize_by_iqr(currentR, lowSpO2WinsorThreshold);
        cleaningSummary.lowSpO2PreservedCount = cleaningSummary.lowSpO2PreservedCount + numel(currentIndices);
    elseif currentSpO2 < highSpO2Boundary
        outlierMask = isoutlier(currentR, 'mean', 'ThresholdFactor', midSpO2OutlierThreshold);
        keepMask(currentIndices) = ~outlierMask;
        cleaningSummary.midSpO2KeptCount = cleaningSummary.midSpO2KeptCount + sum(~outlierMask);
        cleaningSummary.removedOutlierCount = cleaningSummary.removedOutlierCount + sum(outlierMask);
    else
        outlierMask = isoutlier(currentR, 'mean', 'ThresholdFactor', highSpO2OutlierThreshold);
        keepMask(currentIndices) = ~outlierMask;
        cleaningSummary.highSpO2KeptCount = cleaningSummary.highSpO2KeptCount + sum(~outlierMask);
        cleaningSummary.removedOutlierCount = cleaningSummary.removedOutlierCount + sum(outlierMask);
    end
end

cleanR = cleanRFull(keepMask);
cleanSpO2 = inputSpO2(keepMask);
end

function outputValues = winsorize_by_iqr(inputValues, thresholdFactor)

outputValues = inputValues;
if numel(inputValues) < 4
    return
end

q1 = quantile(inputValues, 0.25);
q3 = quantile(inputValues, 0.75);
iqrValue = q3 - q1;

if iqrValue <= 1e-9
    return
end

lowerBound = q1 - thresholdFactor * iqrValue;
upperBound = q3 + thresholdFactor * iqrValue;
outputValues(outputValues < lowerBound) = lowerBound;
outputValues(outputValues > upperBound) = upperBound;
end

function weights = build_training_weights(trainSpO2, lowSpO2Threshold, veryLowSpO2Threshold, highSpO2Boundary, ...
    defaultWeight, lowSpO2Weight, veryLowSpO2Weight, highSpO2Weight)

weights = defaultWeight * ones(size(trainSpO2));
weights(trainSpO2 >= highSpO2Boundary) = highSpO2Weight;
weights(trainSpO2 <= lowSpO2Threshold) = lowSpO2Weight;
weights(trainSpO2 <= veryLowSpO2Threshold) = veryLowSpO2Weight;
end

function model = fit_weighted_linear_model(trainR, trainSpO2, trainWeights)

coeffs = weighted_polyfit(trainR, trainSpO2, 1, trainWeights);
model.name = 'WeightedLinear';
model.coeffs = coeffs;
model.predictFn = @(x) polyval(coeffs, x);
model.description = sprintf('SpO2 = %.6f * R + %.6f', coeffs(1), coeffs(2));
end

function model = fit_weighted_quadratic_model(trainR, trainSpO2, trainWeights)

coeffs = weighted_polyfit(trainR, trainSpO2, 2, trainWeights);
model.name = 'WeightedQuadratic';
model.coeffs = coeffs;
model.predictFn = @(x) polyval(coeffs, x);
model.description = sprintf('SpO2 = %.6f * R^2 + %.6f * R + %.6f', coeffs(1), coeffs(2), coeffs(3));
end

function model = fit_weighted_piecewise_linear_model(trainR, trainSpO2, trainWeights)

piecewiseFun = @(b, x) (x <= b(3)).*(b(1) + b(2) * x) + ...
    (x > b(3)).*(b(1) + b(2) * b(3) + b(4) * (x - b(3)));

weightedLine = weighted_polyfit(trainR, trainSpO2, 1, trainWeights);
initialGuess = [weightedLine(2), weightedLine(1), median(trainR), weightedLine(1) * 2];

lowerBreakpoint = min(trainR);
upperBreakpoint = max(trainR);
options = optimset('Display', 'off', 'MaxFunEvals', 12000, 'MaxIter', 12000);
objectiveFun = @(b) weighted_piecewise_objective( ...
    b, trainR, trainSpO2, trainWeights, piecewiseFun, lowerBreakpoint, upperBreakpoint);
coeffs = fminsearch(objectiveFun, initialGuess, options);
coeffs(3) = min(max(coeffs(3), lowerBreakpoint), upperBreakpoint);

model.name = 'WeightedPiecewiseLinear';
model.coeffs = coeffs;
model.predictFn = @(x) piecewiseFun(coeffs, x);
model.description = sprintf('SpO2 = piecewise([%.6f %.6f %.6f %.6f])', coeffs(1), coeffs(2), coeffs(3), coeffs(4));
end

function model = fit_weighted_segmented_low_spo2_model(trainR, trainSpO2, trainWeights, lowSpO2Threshold)

segmentedFun = @(b, x) ...
    (x <= b(3)).*(b(1) + b(2) * x) + ...
    (x > b(3) & x <= b(5)).*(b(1) + b(2) * b(3) + b(4) * (x - b(3))) + ...
    (x > b(5)).*(b(1) + b(2) * b(3) + b(4) * (b(5) - b(3)) + b(6) * (x - b(5)));

weightedLine = weighted_polyfit(trainR, trainSpO2, 1, trainWeights);
bp1Init = median(trainR(trainSpO2 >= lowSpO2Threshold + 2));
bp2Init = median(trainR(trainSpO2 <= lowSpO2Threshold - 3));
if ~isfinite(bp1Init)
    bp1Init = quantile(trainR, 0.35);
end
if ~isfinite(bp2Init)
    bp2Init = quantile(trainR, 0.70);
end
if bp2Init <= bp1Init
    bp1Init = quantile(trainR, 0.35);
    bp2Init = quantile(trainR, 0.70);
end

initialGuess = [prctile(trainSpO2, 75), weightedLine(1), bp1Init, weightedLine(1) * 1.8, bp2Init, weightedLine(1) * 2.8];

lowerBreakpoint = min(trainR);
upperBreakpoint = max(trainR);
options = optimset('Display', 'off', 'MaxFunEvals', 20000, 'MaxIter', 20000);
objectiveFun = @(b) weighted_segmented_objective( ...
    b, trainR, trainSpO2, trainWeights, segmentedFun, lowerBreakpoint, upperBreakpoint);
coeffs = fminsearch(objectiveFun, initialGuess, options);

coeffs(3) = min(max(coeffs(3), lowerBreakpoint), upperBreakpoint);
coeffs(5) = min(max(coeffs(5), coeffs(3) + 1e-3), upperBreakpoint);

model.name = 'WeightedLowSpO2Segmented';
model.coeffs = coeffs;
model.predictFn = @(x) segmentedFun(coeffs, x);
model.description = sprintf('SpO2 = segmented([%.6f %.6f %.6f %.6f %.6f %.6f])', ...
    coeffs(1), coeffs(2), coeffs(3), coeffs(4), coeffs(5), coeffs(6));
end

function model = fit_residual_corrected_quadratic_model(trainR, trainSpO2, trainWeights, lowSpO2Threshold)

baseCoeffs = weighted_polyfit(trainR, trainSpO2, 2, trainWeights);
basePredictFn = @(x) polyval(baseCoeffs, x);
basePredTrain = basePredictFn(trainR);

residualFeature = max(zeros(size(basePredTrain)), lowSpO2Threshold - basePredTrain);
correctionDesign = [ones(size(basePredTrain)), residualFeature];
correctionCoeffs = weighted_least_squares(correctionDesign, trainSpO2 - basePredTrain, trainWeights);

model.name = 'ResidualCorrectedQuadratic';
model.coeffs.base = baseCoeffs;
model.coeffs.residual = correctionCoeffs;
model.predictFn = @(x) residual_corrected_predict(basePredictFn, correctionCoeffs, x, lowSpO2Threshold);
model.description = sprintf('SpO2 = quadratic(R) + %.6f + %.6f * max(0, %.1f - quadratic(R))', ...
    correctionCoeffs(1), correctionCoeffs(2), lowSpO2Threshold);
end

function predictions = residual_corrected_predict(basePredictFn, correctionCoeffs, inputR, lowSpO2Threshold)

basePrediction = basePredictFn(inputR);
residualFeature = max(zeros(size(basePrediction)), lowSpO2Threshold - basePrediction);
predictions = basePrediction + correctionCoeffs(1) + correctionCoeffs(2) * residualFeature;
end

function coeffs = weighted_polyfit(inputX, inputY, degree, weights)

inputX = inputX(:);
inputY = inputY(:);
weights = weights(:);

designMatrix = zeros(numel(inputX), degree + 1);
for powerIdx = 0:degree
    designMatrix(:, powerIdx + 1) = inputX .^ (degree - powerIdx);
end

coeffs = weighted_least_squares(designMatrix, inputY, weights).';
end

function coeffs = weighted_least_squares(designMatrix, targetValue, weights)

sqrtWeights = sqrt(max(weights(:), eps));
weightedDesign = designMatrix .* sqrtWeights;
weightedTarget = targetValue(:) .* sqrtWeights;
coeffs = weightedDesign \ weightedTarget;
end

function objectiveValue = weighted_piecewise_objective(coeffs, inputR, inputSpO2, inputWeights, piecewiseFun, lowerBreakpoint, upperBreakpoint)

adjustedCoeffs = coeffs;
penaltyValue = 0;

if adjustedCoeffs(3) < lowerBreakpoint
    penaltyValue = penaltyValue + (lowerBreakpoint - adjustedCoeffs(3))^2 * 1e5;
    adjustedCoeffs(3) = lowerBreakpoint;
elseif adjustedCoeffs(3) > upperBreakpoint
    penaltyValue = penaltyValue + (adjustedCoeffs(3) - upperBreakpoint)^2 * 1e5;
    adjustedCoeffs(3) = upperBreakpoint;
end

if adjustedCoeffs(2) > 0
    penaltyValue = penaltyValue + adjustedCoeffs(2)^2 * 1e5;
end
if adjustedCoeffs(4) > 0
    penaltyValue = penaltyValue + adjustedCoeffs(4)^2 * 1e5;
end

predictions = piecewiseFun(adjustedCoeffs, inputR);
residuals = predictions - inputSpO2;
weightedMse = sum(inputWeights .* (residuals .^ 2)) / sum(inputWeights);

denseX = linspace(lowerBreakpoint, upperBreakpoint, 200);
denseY = piecewiseFun(adjustedCoeffs, denseX);
penaltyValue = penaltyValue + sum(max(diff(denseY), 0).^2) * 1e5;

objectiveValue = weightedMse + penaltyValue;
end

function objectiveValue = weighted_segmented_objective(coeffs, inputR, inputSpO2, inputWeights, segmentedFun, lowerBreakpoint, upperBreakpoint)

adjustedCoeffs = coeffs;
penaltyValue = 0;
minGap = max((upperBreakpoint - lowerBreakpoint) * 0.05, 1e-3);

if adjustedCoeffs(3) < lowerBreakpoint
    penaltyValue = penaltyValue + (lowerBreakpoint - adjustedCoeffs(3))^2 * 1e5;
    adjustedCoeffs(3) = lowerBreakpoint;
end
if adjustedCoeffs(5) > upperBreakpoint
    penaltyValue = penaltyValue + (adjustedCoeffs(5) - upperBreakpoint)^2 * 1e5;
    adjustedCoeffs(5) = upperBreakpoint;
end
if adjustedCoeffs(5) <= adjustedCoeffs(3) + minGap
    penaltyValue = penaltyValue + (adjustedCoeffs(3) + minGap - adjustedCoeffs(5))^2 * 1e6;
    adjustedCoeffs(5) = adjustedCoeffs(3) + minGap;
end

if adjustedCoeffs(2) > 0
    penaltyValue = penaltyValue + adjustedCoeffs(2)^2 * 1e5;
end
if adjustedCoeffs(4) > 0
    penaltyValue = penaltyValue + adjustedCoeffs(4)^2 * 1e5;
end
if adjustedCoeffs(6) > 0
    penaltyValue = penaltyValue + adjustedCoeffs(6)^2 * 1e5;
end

predictions = segmentedFun(adjustedCoeffs, inputR);
residuals = predictions - inputSpO2;
weightedMse = sum(inputWeights .* (residuals .^ 2)) / sum(inputWeights);

denseX = linspace(lowerBreakpoint, upperBreakpoint, 300);
denseY = segmentedFun(adjustedCoeffs, denseX);
penaltyValue = penaltyValue + sum(max(diff(denseY), 0).^2) * 1e5;

objectiveValue = weightedMse + penaltyValue;
end

function predictions = apply_model(model, inputR)

predictions = model.predictFn(inputR);
predictions = max(min(predictions, 100), 65);
end

function metrics = evaluate_model(model, inputR, inputSpO2, lowSpO2Threshold)

if isempty(inputR)
    metrics.rmse = NaN;
    metrics.bias = NaN;
    metrics.mae = NaN;
    metrics.corr = NaN;
    metrics.sampleCount = 0;
    metrics.lowSampleCount = 0;
    metrics.lowRmse = NaN;
    metrics.lowBias = NaN;
    return
end

predictions = apply_model(model, inputR);
metrics.rmse = rmse(predictions, inputSpO2, "omitnan");
metrics.bias = mean(predictions - inputSpO2, 'omitnan');
metrics.mae = mean(abs(predictions - inputSpO2), 'omitnan');
if numel(inputSpO2) > 1
    metrics.corr = corr(predictions, inputSpO2, 'rows', 'complete');
else
    metrics.corr = NaN;
end
metrics.sampleCount = numel(inputSpO2);

lowMask = inputSpO2 <= lowSpO2Threshold;
metrics.lowSampleCount = sum(lowMask);
if any(lowMask)
    metrics.lowRmse = rmse(predictions(lowMask), inputSpO2(lowMask), "omitnan");
    metrics.lowBias = mean(predictions(lowMask) - inputSpO2(lowMask), 'omitnan');
else
    metrics.lowRmse = NaN;
    metrics.lowBias = NaN;
end
end

function score = compute_selection_score(metrics, overallWeight, lowWeight, lowBiasWeight)

if metrics.lowSampleCount > 0 && isfinite(metrics.lowRmse)
    score = overallWeight * metrics.rmse + lowWeight * metrics.lowRmse + lowBiasWeight * abs(metrics.lowBias);
else
    score = metrics.rmse + lowBiasWeight * abs(metrics.bias);
end

if ~isfinite(score)
    score = inf;
end
end

function bestModelIndex = choose_best_model(models)

monotonicMask = false(length(models), 1);
selectionScore = zeros(length(models), 1);

for idx = 1:length(models)
    monotonicMask(idx) = models{idx}.isMonotonic;
    selectionScore(idx) = models{idx}.selectionScore;
end

candidateIndices = find(monotonicMask);
if isempty(candidateIndices)
    candidateIndices = 1:length(models);
end

[~, localIndex] = min(selectionScore(candidateIndices));
bestModelIndex = candidateIndices(localIndex);
end

function report_model(model)

fprintf('\nModel: %s\n', model.name);
fprintf('Formula: %s\n', model.description);
fprintf('Monotonic on plot range: %d\n', model.isMonotonic);
fprintf('Selection Score: %.4f\n', model.selectionScore);
fprintf('Train RMSE: %.4f\n', model.trainMetrics.rmse);
fprintf('Train MAE: %.4f\n', model.trainMetrics.mae);
fprintf('Train Bias: %.4f\n', model.trainMetrics.bias);
fprintf('Train Corr: %.4f\n', model.trainMetrics.corr);
fprintf('Train Low-SpO2 Samples: %d\n', model.trainMetrics.lowSampleCount);
fprintf('Train Low-SpO2 RMSE: %.4f\n', model.trainMetrics.lowRmse);
fprintf('Train Low-SpO2 Bias: %.4f\n', model.trainMetrics.lowBias);
fprintf('Validation RMSE: %.4f\n', model.validationMetrics.rmse);
fprintf('Validation MAE: %.4f\n', model.validationMetrics.mae);
fprintf('Validation Bias: %.4f\n', model.validationMetrics.bias);
fprintf('Validation Corr: %.4f\n', model.validationMetrics.corr);
fprintf('Validation Low-SpO2 Samples: %d\n', model.validationMetrics.lowSampleCount);
fprintf('Validation Low-SpO2 RMSE: %.4f\n', model.validationMetrics.lowRmse);
fprintf('Validation Low-SpO2 Bias: %.4f\n', model.validationMetrics.lowBias);
end

function print_calculate_spo2_snippet(model)

fprintf('\n================ calculate_spo2.m candidate ================\n');
fprintf('Selected model: %s\n', model.name);

if strcmp(model.name, 'WeightedLinear')
    coeffs = model.coeffs;
    fprintf('linearCoeffs = [%.9f, %.9f];\n', coeffs(1), coeffs(2));
    fprintf('Spo2 = linearCoeffs(1) * inputR + linearCoeffs(2);\n');
elseif strcmp(model.name, 'WeightedQuadratic')
    coeffs = model.coeffs;
    fprintf('quadraticCoeffs = [%.9f, %.9f, %.9f];\n', coeffs(1), coeffs(2), coeffs(3));
    fprintf('Spo2 = quadraticCoeffs(1) * inputR.^2 + quadraticCoeffs(2) * inputR + quadraticCoeffs(3);\n');
elseif strcmp(model.name, 'WeightedPiecewiseLinear')
    coeffs = model.coeffs;
    fprintf('piecewiseCoeffs = [%.9f, %.9f, %.9f, %.9f];\n', coeffs(1), coeffs(2), coeffs(3), coeffs(4));
    fprintf('Spo2 = (inputR <= piecewiseCoeffs(3)).*(piecewiseCoeffs(1) + piecewiseCoeffs(2) * inputR) + ...\n');
    fprintf('    (inputR > piecewiseCoeffs(3)).*(piecewiseCoeffs(1) + piecewiseCoeffs(2) * piecewiseCoeffs(3) + piecewiseCoeffs(4) * (inputR - piecewiseCoeffs(3)));\n');
elseif strcmp(model.name, 'WeightedLowSpO2Segmented')
    coeffs = model.coeffs;
    fprintf('segmentedCoeffs = [%.9f, %.9f, %.9f, %.9f, %.9f, %.9f];\n', ...
        coeffs(1), coeffs(2), coeffs(3), coeffs(4), coeffs(5), coeffs(6));
    fprintf('Spo2 = (inputR <= segmentedCoeffs(3)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * inputR) + ...\n');
    fprintf('    (inputR > segmentedCoeffs(3) & inputR <= segmentedCoeffs(5)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * segmentedCoeffs(3) + segmentedCoeffs(4) * (inputR - segmentedCoeffs(3))) + ...\n');
    fprintf('    (inputR > segmentedCoeffs(5)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * segmentedCoeffs(3) + segmentedCoeffs(4) * (segmentedCoeffs(5) - segmentedCoeffs(3)) + segmentedCoeffs(6) * (inputR - segmentedCoeffs(5)));\n');
elseif strcmp(model.name, 'ResidualCorrectedQuadratic')
    baseCoeffs = model.coeffs.base;
    residualCoeffs = model.coeffs.residual;
    fprintf('baseCoeffs = [%.9f, %.9f, %.9f];\n', baseCoeffs(1), baseCoeffs(2), baseCoeffs(3));
    fprintf('residualCoeffs = [%.9f, %.9f];\n', residualCoeffs(1), residualCoeffs(2));
    fprintf('baseSpo2 = baseCoeffs(1) * inputR.^2 + baseCoeffs(2) * inputR + baseCoeffs(3);\n');
    fprintf('Spo2 = baseSpo2 + residualCoeffs(1) + residualCoeffs(2) * max(zeros(size(baseSpo2)), 90 - baseSpo2);\n');
end

fprintf('Spo2 = max(min(Spo2, 100), 65);\n');
end
