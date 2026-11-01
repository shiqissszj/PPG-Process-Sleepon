function [maxCorrValue, corrValues] = a_corr(inputSig, minLag, maxLag)

% initialization
% len = length(inputSig1); 
% corrValues = single(-Inf); 
% maxLagValueidx = int32(0); 
corrValues = zeros(maxLag-minLag+1,1);

% calculate the corr for each possible delay
for lag = minLag:maxLag
    corrValues(lag-minLag+1) = sum(inputSig(lag+1:end) .* inputSig(1:end-lag))/(sqrt(sum(inputSig(lag+1:end) .^2))*sqrt(sum(inputSig(1:end-lag) .^2)));
    % update the maxCorr and delay
    % if tempCorr > corrValues
    %     corrValues = tempCorr;
    %     maxLagValueidx = lag;
    % end
end

maxCorrValue = max(corrValues);

% normalized the corr (optional)
% normFactor = sqrt(sum(inputSig1.^2) * sum(inputSig2.^2));
% maxCorr = maxCorr / normFactor;
end
