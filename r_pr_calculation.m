function [outputR, outputPR, outputSQI, outputConfidenceR, outputConfidenceG] = r_pr_calculation(windowR, windowIR, windowG, samplingRate, outputCounter, bodyMove)

coder.inline('never')

% Parameters for period identification
pr1 = single(0.2);
pr2 = single(0.8);
confidence = single(1);

windowSize = single(length(windowR));

persistent previousG;
persistent previousConfidenceG;

if isempty(previousG)
    % initialize
    previousG = zeros(100, 1, 'single');
    previousConfidenceG = single(0.6);
end

if outputCounter == 1
    % initialize
    previousG = zeros(100, 1, 'single');
    previousConfidenceG = single(0.6);
end

[dcR, acR] = dc_ac_spliter(windowR,samplingRate);
[dcIR, acIR] = dc_ac_spliter(windowIR,samplingRate);
[dcG, acG] = dc_ac_spliter(windowG,samplingRate);


[ppgExpandedG, ~] = ac_filter([previousG;acG]);

previousG = [previousG(51:100);acG(1:50)];

% Signal filtering and normalization
% use customized alignsignals
[acG,acR,delay1] = align_signals(acG,acR);
[acG,acIR,delay2] = align_signals(acG,acIR);

[ppgFilteredR, ~] = ac_filter(acR);
[ppgFilteredIR, ~] = ac_filter(acIR);
[ppgFilteredG, outlierNumG] = ac_filter(acG);

ppgNormalizedExpandG = ac_normalize(ppgExpandedG);

% PR calculation
[~, peakLocG0] = find_peaks(ppgNormalizedExpandG, single(samplingRate)*pr1, single(-inf), single(0.025));
if length(peakLocG0) < 2
    confidence = single(0);
    PR = single(-1);
else
    deltaPR = mean(diff(peakLocG0));
    [~, peakLocG1] = find_peaks(ppgNormalizedExpandG,single(deltaPR*pr2),single(0.1), single(0));
    if length(peakLocG1) < 2
        confidence = single(0);
        PR = single(-1);
    else
        greenPeakDiff1 = diff(peakLocG1);
        deltaPR2 = rmoutliers(greenPeakDiff1);
        PR = single(60/(mean(deltaPR2)/single(samplingRate)));  %BPM
    end
    if length(peakLocG1) < 2 || PR < 35
        confidence = single(0);
        PR = single(-1);
    end
end

N1 = sum(ppgFilteredG .* ppgFilteredR);
D1 = sum(ppgFilteredG .* ppgFilteredIR);

N2 = mean(dcIR); 
D2 = mean(dcR);

% PI calculaton
PI = peak2peak(ppgFilteredR)/mean(dcR);

outputR = N1*N2 / (D1*D2);

outputPR = single(PR);
outputPI = PI;

% Confidence calculation
% Comment the following code to disable the signal calculation

% Obtain SQI for confidence calculation
xcorrR_G = sum(ppgFilteredG .* ppgFilteredR)/(sqrt(sum(ppgFilteredR .^2))*sqrt(sum(ppgFilteredG .^2)));
xcorrIR_G = sum(ppgFilteredG .* ppgFilteredIR)/(sqrt(sum(ppgFilteredIR .^2))*sqrt(sum(ppgFilteredG .^2)));
xcorrR_IR = sum(ppgFilteredIR .* ppgFilteredR)/(sqrt(sum(ppgFilteredIR .^2))*sqrt(sum(ppgFilteredR .^2)));

outputSQI = [xcorrR_G,xcorrIR_G,xcorrR_IR,0,0,0];

% Confidence of Green light
usedSampleRatio = (windowSize-outlierNumG-single(abs(delay1)))/length(windowR);
outputConfidenceG = usedSampleRatio^2;

% Confidence of Red light
if isnan(outputR) || PR < 0 || outputR <= 0 %|| outputR > 1.75
    confidence = single(0);
end

if confidence > 0
    confidence = max(xcorrR_G,0)*max(xcorrIR_G,0)*max(xcorrR_IR,0);
    confidence = min(confidence, 1);
    confidence = max(confidence, 0);
end

if PR > 0
    meanDeltaPeak = 60*50/PR;
    [maxCorrValueR, corrValuesR]=a_corr(acR, round(meanDeltaPeak*0.9), round(meanDeltaPeak*1.1));
    [maxCorrValueIR, corrValuesIR]=a_corr(acIR, round(meanDeltaPeak*0.9), round(meanDeltaPeak*1.1));
    [maxCorrValueG, corrValuesG]=a_corr(acG, round(meanDeltaPeak*0.9), round(meanDeltaPeak*1.1));
    outputSQI([4,5,6]) = [maxCorrValueR,maxCorrValueIR,maxCorrValueG];

    if maxCorrValueG < 0.75 || corrValuesG(round(meanDeltaPeak*0.1)) < 0.5
        outputConfidenceG = single(0);

    end
    if maxCorrValueR < 0.25 || maxCorrValueIR < 0.25 || bodyMove > 15
        confidence = single(0);
    end
end

outputConfidenceR = confidence;
% outputConfidenceR = 1;

if outputConfidenceG > 0.6
    outputConfidenceG = outputConfidenceG * 0.5 + previousConfidenceG * 0.5;
else
    outputConfidenceG = min(outputConfidenceG, previousConfidenceG);
end
previousConfidenceG = outputConfidenceG;

end

