function outputPR = pr_causal_postprocess(currentPR, rawPR, confidenceG, movement, outputCounter)
% Causal residual model trained on PSG records. Input uses one output per second.
% During the first 30 emitted windows, features are deliberately unpopulated
% to match the evaluation warmup. Reset state at each new continuous run.

persistent model historyPR historyRaw historyConfidence
if isempty(model)
    modelPath = fullfile(fileparts(mfilename('fullpath')), 'psg_model.mat');
    model = load(modelPath);
end
if isempty(historyPR) || outputCounter == 1
    historyPR = nan(10,1);
    historyRaw = nan(10,1);
    historyConfidence = nan(10,1);
end

outputPR = currentPR;
if outputCounter <= 30
    return
end
if ~isfinite(currentPR) || currentPR < 30 || currentPR > 220
    historyPR(:) = NaN;
    historyRaw(:) = NaN;
    historyConfidence(:) = NaN;
    return
end

if ~isfinite(rawPR) || rawPR < 35 || rawPR > 220
    rawPR = NaN;
end
historyPR = [historyPR(2:end); double(currentPR)];
historyRaw = [historyRaw(2:end); double(rawPR)];
historyConfidence = [historyConfidence(2:end); double(confidenceG)];

features = nan(19,1);
features(1:3) = [double(currentPR); double(confidenceG); double(movement)];
offsets = [8, 4, 2, 0];
for k = 1:numel(offsets)
    index = 10 - offsets(k);
    firstFeature = 4 + (k-1)*3;
    features(firstFeature) = historyPR(index) - currentPR;
    features(firstFeature+1) = historyRaw(index) - currentPR;
    features(firstFeature+2) = historyConfidence(index);
end
widths = [4,10];
for k = 1:numel(widths)
    index = (11-widths(k)):10;
    raw = historyRaw(index);
    confidence = historyConfidence(index);
    raw = raw(isfinite(raw));
    confidence = confidence(isfinite(confidence));
    if ~isempty(raw)
        features(16 + (k-1)*2) = median(raw) - currentPR;
    end
    if ~isempty(confidence)
        features(17 + (k-1)*2) = median(confidence);
    end
end

residual = model.baseline;
for tree = 1:size(model.value,1)
    node = 1;
    while model.is_leaf(tree,node) == 0
        feature = features(model.feature_idx(tree,node)+1);
        if isnan(feature)
            takeLeft = model.missing_go_to_left(tree,node) ~= 0;
        else
            takeLeft = feature <= model.num_threshold(tree,node);
        end
        if takeLeft
            node = model.left(tree,node)+1;
        else
            node = model.right(tree,node)+1;
        end
    end
    residual = residual + model.value(tree,node);
end
outputPR = single(min(max(round(double(currentPR)+residual),30),220));
end
