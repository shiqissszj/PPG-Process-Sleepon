function [dcR, dcIR, dcG, acGRaw, acR, acIR, acG, ppgFilteredR, ppgFilteredIR, ppgFilteredG, ppgNormalizedG, outlierNumG, delayR, delayIR] = ...
    preprocess_ppg_window_shared(windowR, windowIR, windowG, samplingRate)

coder.inline('never')

[dcR, acRRaw] = dc_ac_spliter(windowR, samplingRate);
[dcIR, acIRRaw] = dc_ac_spliter(windowIR, samplingRate);
[dcG, acGRaw] = dc_ac_spliter(windowG, samplingRate);

[ppgFilteredRRaw, ~] = ac_filter(acRRaw);
[ppgFilteredIRRaw, ~] = ac_filter(acIRRaw);
[ppgFilteredG, outlierNumG] = ac_filter(acGRaw);

[ppgFilteredR, delayR] = align_target_to_reference_shared(ppgFilteredG, ppgFilteredRRaw, int32(10));
[ppgFilteredIR, delayIR] = align_target_to_reference_shared(ppgFilteredG, ppgFilteredIRRaw, int32(10));

% Preserve the raw aligned AC channels for the legacy PR path.
acG = acGRaw;
acR = acRRaw;
acIR = acIRRaw;
[acG, acR, ~] = align_signals(acG, acR);
[acG, acIR, ~] = align_signals(acG, acIR);

ppgNormalizedG = ac_normalize(ppgFilteredG);
end

function [alignedTarget, delay] = align_target_to_reference_shared(referenceSignal, targetSignal, maxLag)

delay = x_corr(targetSignal, referenceSignal, maxLag);
alignedTarget = shift_signal_shared(targetSignal, -double(delay));
end

function outputSignal = shift_signal_shared(inputSignal, shiftSamples)

signalLength = length(inputSignal);
outputSignal = zeros(size(inputSignal), 'like', inputSignal);

if shiftSamples == 0
    outputSignal = inputSignal;
elseif shiftSamples > 0
    if shiftSamples < signalLength
        outputSignal(shiftSamples + 1:end) = inputSignal(1:end - shiftSamples);
    end
else
    shiftSamples = -shiftSamples;
    if shiftSamples < signalLength
        outputSignal(1:end - shiftSamples) = inputSignal(shiftSamples + 1:end);
    end
end
end
