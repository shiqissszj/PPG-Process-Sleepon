function [lagValue, maxCorr] = x_corr(inputSig1, inputSig2, maxLag)

% initialization
% len = length(inputSig1); 
maxCorr = single(-Inf); 
lagValue = int32(0); 

% calculate the corr for each possible delay
for lag = -maxLag:maxLag
    if lag < 0
        tempCorr = sum(inputSig1(1:end+lag) .* inputSig2(-lag+1:end));
    else
        tempCorr = sum(inputSig1(lag+1:end) .* inputSig2(1:end-lag));
    end

    % update the maxCorr and delay
    if tempCorr > maxCorr
        maxCorr = tempCorr;
        lagValue = lag;
    end
end

% normalized the corr (optional)
% normFactor = sqrt(sum(inputSig1.^2) * sum(inputSig2.^2));
% maxCorr = maxCorr / normFactor;
end
