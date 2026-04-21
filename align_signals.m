function [inputSig1, inputSig2, delay] = align_signals(inputSig1, inputSig2) %#codegen

coder.inline('never')
maxLag = int32(10);
sigLen = length(inputSig1);

% use simplified xcorr calculation
delay = int32(x_corr(inputSig2, inputSig1, maxLag));

% adjust the signal if delay is not 0
if delay > 0
    % aligned1 = [zeros(delay, 1); inputSig1(1:150-delay)];
    for ind = sigLen-delay:-1:1
        inputSig1(ind+delay) = inputSig1(ind);
    end
    for ind = delay:-1:1
        inputSig1(ind) = 0;
    end
elseif delay < 0
    % aligned2 = [zeros(-delay, 1); inputSig2(1:150+delay)];
    for ind = sigLen+delay:-1:1
        inputSig2(ind-delay) = inputSig2(ind);
    end
    for ind = -delay:-1:1
        inputSig2(ind) = 0;
    end
end
% if delay is 0, do nothing
end
