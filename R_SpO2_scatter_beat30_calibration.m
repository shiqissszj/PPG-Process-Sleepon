function [models, bestModel, modelTable] = R_SpO2_scatter_beat30_calibration(matFilename, outputDir)
% Fit beat30_r -> SpO2 calibration candidates.
%
% First run:
%   SpO2_PR_main_beat30
%
% Then run:
%   R_SpO2_scatter_beat30_calibration
%
% Outputs:
%   diagnostics_beat30/R_SpO2_calibration_beat30_results.mat
%   diagnostics_beat30/beat30_calibration_model_table.csv
%   diagnostics_beat30/calculate_spo2_beat30_candidates.txt
%   diagnostics_beat30/calculate_spo2_beat30_fitted.m

if nargin < 1 || isempty(matFilename)
    matFilename = fullfile(fileparts(mfilename('fullpath')), 'diagnostics_beat30', 'R_SpO2_values_beat30.mat');
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(fileparts(mfilename('fullpath')), 'diagnostics_beat30');
end
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

rng(42);

validationRatio = 0.30;
lowSpO2Threshold = 90;
veryLowSpO2Threshold = 85;
highSpO2Boundary = 95;
plotRRange = 0:0.005:1.6;
plotSpO2Range = [65, 100];

defaultWeight = 1.0;
lowSpO2Weight = 3.0;
veryLowSpO2Weight = 5.0;
highSpO2Weight = 0.9;

loadedData = load(matFilename);
if isfield(loadedData, 'R_SpO2_values_beat30')
    R_SpO2_values = loadedData.R_SpO2_values_beat30;
elseif isfield(loadedData, 'R_SpO2_values')
    R_SpO2_values = loadedData.R_SpO2_values;
else
    error('MAT file does not contain R_SpO2_values_beat30 or R_SpO2_values: %s', matFilename);
end

dataIDList = [];
if isfield(loadedData, 'dataIDList')
    dataIDList = loadedData.dataIDList;
end

[allR, allSpO2, allRecordId] = flatten_record_cells_beat30(R_SpO2_values, dataIDList);
baseMask = isfinite(allR) & isfinite(allSpO2) & allR > 0 & allR < 3 & allSpO2 >= 65 & allSpO2 <= 100;
allR = allR(baseMask);
allSpO2 = allSpO2(baseMask);
allRecordId = allRecordId(baseMask);

if isempty(allR)
    error('No valid beat30 calibration pairs found in %s.', matFilename);
end

[uniqueRecords, recordHasLow] = summarize_records_beat30(allRecordId, allSpO2, lowSpO2Threshold);
[trainingRecords, validationRecords] = stratified_record_split_beat30(uniqueRecords, recordHasLow, validationRatio);

trainMaskRaw = ismember(allRecordId, trainingRecords);
validationMask = ismember(allRecordId, validationRecords);

trainRawR = allR(trainMaskRaw);
trainRawSpO2 = allSpO2(trainMaskRaw);
trainRawRecordId = allRecordId(trainMaskRaw);

validationR = allR(validationMask);
validationSpO2 = allSpO2(validationMask);
validationRecordId = allRecordId(validationMask);

[trainR, trainSpO2, keepMask, cleaningSummary] = clean_training_pairs_beat30( ...
    trainRawR, trainRawSpO2, lowSpO2Threshold, highSpO2Boundary);
trainRecordId = trainRawRecordId(keepMask);
trainWeights = build_training_weights_beat30(trainSpO2, lowSpO2Threshold, veryLowSpO2Threshold, ...
    highSpO2Boundary, defaultWeight, lowSpO2Weight, veryLowSpO2Weight, highSpO2Weight);

fprintf('Calibration MAT: %s\n', matFilename);
fprintf('Records: %d | train %d | validation %d\n', numel(uniqueRecords), numel(trainingRecords), numel(validationRecords));
fprintf('Pairs: total %d | train raw %d | train cleaned %d | validation %d\n', ...
    numel(allR), numel(trainRawR), numel(trainR), numel(validationR));
fprintf('Low-SpO2 train <= %.0f: %d | validation: %d\n', ...
    lowSpO2Threshold, sum(trainSpO2 <= lowSpO2Threshold), sum(validationSpO2 <= lowSpO2Threshold));
fprintf('Training outliers removed: %d\n', cleaningSummary.removedOutlierCount);

models = cell(4, 1);
models{1} = fit_weighted_linear_beat30(trainR, trainSpO2, trainWeights);
models{2} = fit_weighted_quadratic_beat30(trainR, trainSpO2, trainWeights);
models{3} = fit_weighted_piecewise_beat30(trainR, trainSpO2, trainWeights);
models{4} = fit_weighted_low_segmented_beat30(trainR, trainSpO2, trainWeights);

for idx = 1:numel(models)
    models{idx}.trainMetrics = evaluate_model_beat30(models{idx}, trainR, trainSpO2, lowSpO2Threshold);
    models{idx}.validationMetrics = evaluate_model_beat30(models{idx}, validationR, validationSpO2, lowSpO2Threshold);
    models{idx}.curveY = apply_model_beat30(models{idx}, plotRRange);
    models{idx}.isMonotonic = all(diff(models{idx}.curveY) <= 1e-6);
    models{idx}.selectionScore = models{idx}.validationMetrics.rmse * 0.35 + ...
        models{idx}.validationMetrics.lowRmse * 0.45 + ...
        abs(models{idx}.validationMetrics.lowBias) * 0.20;
end

bestIdx = choose_best_model_beat30(models);
bestModel = models{bestIdx};
modelTable = build_model_table_beat30(models);

fprintf('\n================ Beat30 Calibration Models ================\n');
disp(modelTable);
fprintf('Recommended beat30 model: %s\n', bestModel.name);
fprintf('Formula: %s\n', bestModel.description);

writetable(modelTable, fullfile(outputDir, 'beat30_calibration_model_table.csv'));
write_candidate_formula_file_beat30(models, bestModel, fullfile(outputDir, 'calculate_spo2_beat30_candidates.txt'));
write_best_calculate_function_beat30(bestModel, fullfile(outputDir, 'calculate_spo2_beat30_fitted.m'));

save(fullfile(outputDir, 'R_SpO2_calibration_beat30_results.mat'), ...
    'matFilename', 'R_SpO2_values', 'dataIDList', 'trainingRecords', 'validationRecords', ...
    'trainRawR', 'trainRawSpO2', 'trainRawRecordId', ...
    'trainR', 'trainSpO2', 'trainRecordId', 'trainWeights', ...
    'validationR', 'validationSpO2', 'validationRecordId', ...
    'models', 'bestIdx', 'bestModel', 'modelTable', 'cleaningSummary', ...
    'lowSpO2Threshold', 'veryLowSpO2Threshold', 'highSpO2Boundary', ...
    'defaultWeight', 'lowSpO2Weight', 'veryLowSpO2Weight', 'highSpO2Weight');

plot_calibration_results_beat30(outputDir, trainRawR, trainRawSpO2, trainR, trainSpO2, ...
    validationR, validationSpO2, models, bestModel, plotRRange, plotSpO2Range);
end

function [allR, allSpO2, allRecordId] = flatten_record_cells_beat30(inputCells, dataIDList)

allR = [];
allSpO2 = [];
allRecordId = [];

for recordIdx = 1:length(inputCells)
    pairs = inputCells{recordIdx};
    if isempty(pairs) || size(pairs, 2) < 2
        continue
    end
    if ~isempty(dataIDList) && numel(dataIDList) >= recordIdx
        recordId = dataIDList(recordIdx);
    else
        recordId = recordIdx;
    end
    sampleCount = size(pairs, 1);
    allR = [allR; pairs(:, 1)]; %#ok<AGROW>
    allSpO2 = [allSpO2; pairs(:, 2)]; %#ok<AGROW>
    allRecordId = [allRecordId; repmat(recordId, sampleCount, 1)]; %#ok<AGROW>
end
end

function [uniqueRecords, recordHasLow] = summarize_records_beat30(recordId, spo2, lowThreshold)

uniqueRecords = unique(recordId, 'stable');
recordHasLow = false(size(uniqueRecords));
for idx = 1:numel(uniqueRecords)
    mask = recordId == uniqueRecords(idx);
    recordHasLow(idx) = any(spo2(mask) <= lowThreshold);
end
end

function [trainingRecords, validationRecords] = stratified_record_split_beat30(uniqueRecords, recordHasLow, validationRatio)

lowRecords = uniqueRecords(recordHasLow);
normalRecords = uniqueRecords(~recordHasLow);
lowRecords = lowRecords(randperm(numel(lowRecords)));
normalRecords = normalRecords(randperm(numel(normalRecords)));

validationLowCount = max(1, round(numel(lowRecords) * validationRatio));
validationNormalCount = max(1, round(numel(normalRecords) * validationRatio));
validationLowCount = min(validationLowCount, max(numel(lowRecords) - 1, 0));
validationNormalCount = min(validationNormalCount, max(numel(normalRecords) - 1, 0));

validationRecords = [lowRecords(1:validationLowCount); normalRecords(1:validationNormalCount)];
trainingRecords = setdiff(uniqueRecords, validationRecords, 'stable');
end

function [cleanR, cleanSpO2, keepMask, summary] = clean_training_pairs_beat30(rawR, rawSpO2, lowThreshold, highBoundary)

baseMask = isfinite(rawR) & isfinite(rawSpO2) & rawR > 0 & rawSpO2 >= 65 & rawSpO2 <= 100;
rawR = rawR(baseMask);
rawSpO2 = rawSpO2(baseMask);

if numel(rawR) < 20
    cleanR = rawR;
    cleanSpO2 = rawSpO2;
    keepMask = baseMask;
    summary.removedOutlierCount = 0;
    return
end

coeffs = polyfit(rawR, rawSpO2, 1);
predicted = polyval(coeffs, rawR);
residual = abs(rawSpO2 - predicted);

keepLocal = true(size(rawR));
lowMask = rawSpO2 <= lowThreshold;
midMask = rawSpO2 > lowThreshold & rawSpO2 < highBoundary;
highMask = rawSpO2 >= highBoundary;

keepLocal(midMask) = residual(midMask) <= max(2.5, prctile(residual(midMask), 90));
keepLocal(highMask) = residual(highMask) <= max(2.0, prctile(residual(highMask), 85));
% Preserve low-SpO2 points more aggressively; they carry the most useful
% calibration information.
keepLocal(lowMask) = residual(lowMask) <= max(4.0, prctile(residual(lowMask), 95));

cleanR = rawR(keepLocal);
cleanSpO2 = rawSpO2(keepLocal);

keepMask = false(size(baseMask));
baseIndices = find(baseMask);
keepMask(baseIndices(keepLocal)) = true;
summary.removedOutlierCount = sum(~keepLocal);
end

function weights = build_training_weights_beat30(spo2, lowThreshold, veryLowThreshold, highBoundary, defaultWeight, lowWeight, veryLowWeight, highWeight)

weights = ones(size(spo2)) * defaultWeight;
weights(spo2 <= lowThreshold) = lowWeight;
weights(spo2 <= veryLowThreshold) = veryLowWeight;
weights(spo2 >= highBoundary) = highWeight;
end

function model = fit_weighted_linear_beat30(r, spo2, weights)

coeffs = weighted_polyfit_beat30(r, spo2, 1, weights);
model.name = "WeightedLinear";
model.coeffs = coeffs;
model.predictFn = @(x) coeffs(1) * x + coeffs(2);
model.description = sprintf('SpO2 = %.9f * R + %.9f', coeffs(1), coeffs(2));
end

function model = fit_weighted_quadratic_beat30(r, spo2, weights)

coeffs = weighted_polyfit_beat30(r, spo2, 2, weights);
model.name = "WeightedQuadratic";
model.coeffs = coeffs;
model.predictFn = @(x) coeffs(1) * x.^2 + coeffs(2) * x + coeffs(3);
model.description = sprintf('SpO2 = %.9f * R^2 + %.9f * R + %.9f', coeffs(1), coeffs(2), coeffs(3));
end

function model = fit_weighted_piecewise_beat30(r, spo2, weights)

piecewiseFun = @(b, x) (x <= b(3)).*(b(1) + b(2) * x) + ...
    (x > b(3)).*(b(1) + b(2) * b(3) + b(4) * (x - b(3)));

lineCoeffs = weighted_polyfit_beat30(r, spo2, 1, weights);
lowerBreakpoint = prctile(r, 25);
upperBreakpoint = prctile(r, 75);
initial = [lineCoeffs(2), lineCoeffs(1), median(r), lineCoeffs(1) * 1.5];
objective = @(b) weighted_piecewise_objective_beat30(b, r, spo2, weights, piecewiseFun, lowerBreakpoint, upperBreakpoint);
coeffs = fminsearch(objective, initial, optimset('Display', 'off'));
coeffs(3) = min(max(coeffs(3), lowerBreakpoint), upperBreakpoint);

model.name = "WeightedPiecewiseLinear";
model.coeffs = coeffs;
model.predictFn = @(x) piecewiseFun(coeffs, x);
model.description = sprintf('SpO2 = piecewise([%.9f %.9f %.9f %.9f])', coeffs(1), coeffs(2), coeffs(3), coeffs(4));
end

function model = fit_weighted_low_segmented_beat30(r, spo2, weights)

segmentFun = @(b, x) (x <= b(3)).*(b(1) + b(2) * x) + ...
    (x > b(3) & x <= b(5)).*(b(1) + b(2) * b(3) + b(4) * (x - b(3))) + ...
    (x > b(5)).*(b(1) + b(2) * b(3) + b(4) * (b(5) - b(3)) + b(6) * (x - b(5)));

lineCoeffs = weighted_polyfit_beat30(r, spo2, 1, weights);
break1 = prctile(r, 35);
break2 = prctile(r, 70);
initial = [lineCoeffs(2), lineCoeffs(1) * 0.7, break1, lineCoeffs(1), break2, lineCoeffs(1) * 1.6];
objective = @(b) weighted_segment_objective_beat30(b, r, spo2, weights, segmentFun);
coeffs = fminsearch(objective, initial, optimset('Display', 'off'));
coeffs(3) = min(max(coeffs(3), prctile(r, 20)), prctile(r, 60));
coeffs(5) = min(max(coeffs(5), coeffs(3) + 0.02), prctile(r, 85));

model.name = "WeightedLowSpO2Segmented";
model.coeffs = coeffs;
model.predictFn = @(x) segmentFun(coeffs, x);
model.description = sprintf('SpO2 = segmented([%.9f %.9f %.9f %.9f %.9f %.9f])', ...
    coeffs(1), coeffs(2), coeffs(3), coeffs(4), coeffs(5), coeffs(6));
end

function coeffs = weighted_polyfit_beat30(x, y, degree, weights)

x = x(:);
y = y(:);
weights = weights(:);
validMask = isfinite(x) & isfinite(y) & isfinite(weights) & weights > 0;
x = x(validMask);
y = y(validMask);
weights = weights(validMask);

vander = zeros(numel(x), degree + 1);
for idx = 0:degree
    vander(:, degree + 1 - idx) = x .^ idx;
end

w = sqrt(weights);
coeffs = (vander .* w) \ (y .* w);
coeffs = coeffs(:).';
end

function value = weighted_piecewise_objective_beat30(coeffs, r, spo2, weights, piecewiseFun, lowerBreakpoint, upperBreakpoint)

if coeffs(3) < lowerBreakpoint || coeffs(3) > upperBreakpoint
    value = 1e6 + abs(coeffs(3) - median([lowerBreakpoint, upperBreakpoint])) * 1e4;
    return
end
prediction = piecewiseFun(coeffs, r);
value = mean(weights .* (prediction - spo2).^2, 'omitnan');
value = value + monotonic_penalty_beat30(coeffs, piecewiseFun, r);
end

function value = weighted_segment_objective_beat30(coeffs, r, spo2, weights, segmentFun)

if coeffs(5) <= coeffs(3)
    value = 1e6 + abs(coeffs(5) - coeffs(3)) * 1e4;
    return
end
prediction = segmentFun(coeffs, r);
value = mean(weights .* (prediction - spo2).^2, 'omitnan');
value = value + monotonic_penalty_beat30(coeffs, segmentFun, r);
end

function penalty = monotonic_penalty_beat30(coeffs, modelFun, r)

denseX = linspace(max(0.01, prctile(r, 1)), prctile(r, 99), 200);
denseY = modelFun(coeffs, denseX);
upwardSteps = diff(denseY);
penalty = 1000 * sum(max(upwardSteps, 0).^2);
end

function metrics = evaluate_model_beat30(model, r, spo2, lowThreshold)

prediction = apply_model_beat30(model, r);
validMask = isfinite(prediction) & isfinite(spo2) & spo2 > 0;
prediction = prediction(validMask);
spo2 = spo2(validMask);

if isempty(spo2)
    metrics = empty_metrics_beat30();
    return
end

errorValue = prediction - spo2;
lowMask = spo2 <= lowThreshold;

metrics.rmse = sqrt(mean(errorValue .^ 2));
metrics.mae = mean(abs(errorValue));
metrics.bias = mean(errorValue);
metrics.corr = safe_corr_beat30_cal(prediction, spo2);
metrics.lowSampleCount = sum(lowMask);
if any(lowMask)
    metrics.lowRmse = sqrt(mean(errorValue(lowMask) .^ 2));
    metrics.lowBias = mean(errorValue(lowMask));
else
    metrics.lowRmse = metrics.rmse;
    metrics.lowBias = metrics.bias;
end
end

function metrics = empty_metrics_beat30()

metrics.rmse = NaN;
metrics.mae = NaN;
metrics.bias = NaN;
metrics.corr = NaN;
metrics.lowSampleCount = 0;
metrics.lowRmse = NaN;
metrics.lowBias = NaN;
end

function y = apply_model_beat30(model, x)

y = model.predictFn(x);
y = max(min(y, 100), 65);
end

function bestIdx = choose_best_model_beat30(models)

scores = nan(numel(models), 1);
for idx = 1:numel(models)
    if models{idx}.isMonotonic
        scores(idx) = models{idx}.selectionScore;
    end
end
if all(~isfinite(scores))
    for idx = 1:numel(models)
        scores(idx) = models{idx}.selectionScore;
    end
end
[~, bestIdx] = min(scores);
end

function modelTable = build_model_table_beat30(models)

modelName = strings(numel(models), 1);
formula = strings(numel(models), 1);
isMonotonic = false(numel(models), 1);
selectionScore = nan(numel(models), 1);
trainRmse = nan(numel(models), 1);
trainCorr = nan(numel(models), 1);
validationRmse = nan(numel(models), 1);
validationCorr = nan(numel(models), 1);
validationLowRmse = nan(numel(models), 1);
validationLowBias = nan(numel(models), 1);
validationLowCount = nan(numel(models), 1);

for idx = 1:numel(models)
    modelName(idx) = models{idx}.name;
    formula(idx) = models{idx}.description;
    isMonotonic(idx) = models{idx}.isMonotonic;
    selectionScore(idx) = models{idx}.selectionScore;
    trainRmse(idx) = models{idx}.trainMetrics.rmse;
    trainCorr(idx) = models{idx}.trainMetrics.corr;
    validationRmse(idx) = models{idx}.validationMetrics.rmse;
    validationCorr(idx) = models{idx}.validationMetrics.corr;
    validationLowRmse(idx) = models{idx}.validationMetrics.lowRmse;
    validationLowBias(idx) = models{idx}.validationMetrics.lowBias;
    validationLowCount(idx) = models{idx}.validationMetrics.lowSampleCount;
end

modelTable = table(modelName, formula, isMonotonic, selectionScore, ...
    trainRmse, trainCorr, validationRmse, validationCorr, ...
    validationLowRmse, validationLowBias, validationLowCount);
end

function write_candidate_formula_file_beat30(models, bestModel, outputPath)

fid = fopen(outputPath, 'w');
if fid < 0
    warning('Could not write candidate formula file: %s', outputPath);
    return
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'Beat30 calibration candidates\n');
fprintf(fid, 'Recommended model: %s\n\n', bestModel.name);
for idx = 1:numel(models)
    fprintf(fid, 'Model: %s\n', models{idx}.name);
    fprintf(fid, 'Formula: %s\n', models{idx}.description);
    fprintf(fid, 'Validation RMSE: %.6f\n', models{idx}.validationMetrics.rmse);
    fprintf(fid, 'Validation Corr: %.6f\n', models{idx}.validationMetrics.corr);
    fprintf(fid, 'Validation Low RMSE: %.6f\n', models{idx}.validationMetrics.lowRmse);
    fprintf(fid, 'Validation Low Bias: %.6f\n\n', models{idx}.validationMetrics.lowBias);
end

fprintf(fid, '================ calculate_spo2_beat30.m snippet ================\n');
write_model_snippet_beat30(fid, bestModel, 'inputR');
fprintf(fid, 'Spo2 = max(min(Spo2, 100), 65);\n');
end

function write_best_calculate_function_beat30(bestModel, outputPath)

fid = fopen(outputPath, 'w');
if fid < 0
    warning('Could not write fitted function: %s', outputPath);
    return
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'function Spo2 = calculate_spo2_beat30_fitted(inputR)\n');
fprintf(fid, '%% Auto-generated by R_SpO2_scatter_beat30_calibration.m\n');
write_model_snippet_beat30(fid, bestModel, 'inputR');
fprintf(fid, 'Spo2 = max(min(Spo2, 100), 65);\n');
fprintf(fid, 'end\n');
end

function write_model_snippet_beat30(fid, model, inputName)

if model.name == "WeightedLinear"
    c = model.coeffs;
    fprintf(fid, 'linearCoeffs = [%.12f, %.12f];\n', c(1), c(2));
    fprintf(fid, 'Spo2 = linearCoeffs(1) * %s + linearCoeffs(2);\n', inputName);
elseif model.name == "WeightedQuadratic"
    c = model.coeffs;
    fprintf(fid, 'quadraticCoeffs = [%.12f, %.12f, %.12f];\n', c(1), c(2), c(3));
    fprintf(fid, 'Spo2 = quadraticCoeffs(1) * %s.^2 + quadraticCoeffs(2) * %s + quadraticCoeffs(3);\n', inputName, inputName);
elseif model.name == "WeightedPiecewiseLinear"
    c = model.coeffs;
    fprintf(fid, 'piecewiseCoeffs = [%.12f, %.12f, %.12f, %.12f];\n', c(1), c(2), c(3), c(4));
    fprintf(fid, 'Spo2 = (%s <= piecewiseCoeffs(3)).*(piecewiseCoeffs(1) + piecewiseCoeffs(2) * %s) + ...\n', inputName, inputName);
    fprintf(fid, '    (%s > piecewiseCoeffs(3)).*(piecewiseCoeffs(1) + piecewiseCoeffs(2) * piecewiseCoeffs(3) + piecewiseCoeffs(4) * (%s - piecewiseCoeffs(3)));\n', inputName, inputName);
elseif model.name == "WeightedLowSpO2Segmented"
    c = model.coeffs;
    fprintf(fid, 'segmentedCoeffs = [%.12f, %.12f, %.12f, %.12f, %.12f, %.12f];\n', c(1), c(2), c(3), c(4), c(5), c(6));
    fprintf(fid, 'Spo2 = (%s <= segmentedCoeffs(3)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * %s) + ...\n', inputName, inputName);
    fprintf(fid, '    (%s > segmentedCoeffs(3) & %s <= segmentedCoeffs(5)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * segmentedCoeffs(3) + segmentedCoeffs(4) * (%s - segmentedCoeffs(3))) + ...\n', inputName, inputName, inputName);
    fprintf(fid, '    (%s > segmentedCoeffs(5)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * segmentedCoeffs(3) + segmentedCoeffs(4) * (segmentedCoeffs(5) - segmentedCoeffs(3)) + segmentedCoeffs(6) * (%s - segmentedCoeffs(5)));\n', inputName, inputName);
end
end

function plot_calibration_results_beat30(outputDir, trainRawR, trainRawSpO2, trainR, trainSpO2, validationR, validationSpO2, models, bestModel, plotRRange, plotSpO2Range)

figure(401);
clf;
hold on;
scatter(trainRawR, trainRawSpO2, 5, [0.80, 0.80, 0.80], 'filled');
scatter(trainR, trainSpO2, 5, [0.10, 0.45, 0.90], 'filled');
scatter(validationR, validationSpO2, 5, [0.95, 0.45, 0.10], 'filled');
for idx = 1:numel(models)
    plot(plotRRange, models{idx}.curveY, 'LineWidth', 1.4);
end
xlabel('beat30 R');
ylabel('SpO2');
ylim(plotSpO2Range);
title('Beat30 R-SpO2 Calibration Candidates');
legend('Train raw', 'Train cleaned', 'Validation', ...
    models{1}.name, models{2}.name, models{3}.name, models{4}.name, 'Location', 'best');
grid on;
hold off;
print(gcf, '-dpng', fullfile(outputDir, 'beat30_calibration_candidates.png'), '-r220');

figure(402);
clf;
scatter(validationR, validationSpO2, 6, [0.95, 0.45, 0.10], 'filled');
hold on;
plot(plotRRange, apply_model_beat30(bestModel, plotRRange), 'r', 'LineWidth', 2);
xlabel('beat30 R');
ylabel('SpO2');
ylim(plotSpO2Range);
title(sprintf('Beat30 Validation: %s', bestModel.name));
grid on;
hold off;
print(gcf, '-dpng', fullfile(outputDir, 'beat30_calibration_best_validation.png'), '-r220');
end

function output = safe_corr_beat30_cal(a, b)

a = double(a(:));
b = double(b(:));
mask = isfinite(a) & isfinite(b);
if sum(mask) < 5
    output = NaN;
    return
end
a = a(mask) - mean(a(mask));
b = b(mask) - mean(b(mask));
denom = sqrt(sum(a .^ 2)) * sqrt(sum(b .^ 2));
if denom <= 1e-12
    output = NaN;
else
    output = sum(a .* b) / denom;
end
end
