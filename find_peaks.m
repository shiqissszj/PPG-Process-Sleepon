function [peaks, locs] = find_peaks(inputSig, minDistance, minPeakHeight, minPeakProminence)

coder.inline('never')
maxPeakNum = 50;

% Detect candidate peaks, filter them by minimun peak height
% The expanded green window can contain 300 samples.
candidateLocs = zeros(maxPeakNum, 1, 'uint16');
countCandidatePeak = 0;
for idx = 2:length(inputSig)-1
    if inputSig(idx) > inputSig(idx-1) && inputSig(idx) >= inputSig(idx+1) && inputSig(idx) > minPeakHeight
        countCandidatePeak = countCandidatePeak + 1;
        candidateLocs(countCandidatePeak) = idx;
        if countCandidatePeak >= maxPeakNum
            break
        end
    end
end

candidatePeaks = zeros(countCandidatePeak, 1, 'single');
for idx = 1:countCandidatePeak
    candidatePeaks(idx) = inputSig(candidateLocs(idx));
end

% Preallocate arrays for peaks and locations
% maxNumPeaks = length(candidatePeaks);
maxNumPeaks = countCandidatePeak;
peaks = zeros(maxNumPeaks, 1, 'single');
locs = zeros(maxNumPeaks, 1, 'single');
numValidPeaks = 0; % Keep track of the number of valid peaks

% Sort by peak height in descending order
[sortedPeaks, sortedIdx] = sort(candidatePeaks, 'descend');
sortedLocs = candidateLocs(sortedIdx);

for i = 1:length(sortedPeaks)
    peak = sortedPeaks(i);
    loc = single(sortedLocs(i));

    % Check minimum distance constraint
    if numValidPeaks == 0 || all(abs(loc - locs(1:numValidPeaks)) > minDistance)
        if minPeakProminence > 0
            % Find left and right bases
            leftBase = loc;
            leftMin = inputSig(loc);
            while leftBase > 1 && inputSig(leftBase - 1) <= peak
                leftBase = leftBase - 1;
                leftMin = min(leftMin, inputSig(leftBase));
            end

            rightBase = loc;
            rightMin = inputSig(loc);
            while rightBase < length(inputSig) && inputSig(rightBase + 1) <= peak
                rightBase = rightBase + 1;
                rightMin = min(rightMin, inputSig(rightBase));
            end

            % Determine prominence
            minHeight = max(leftMin, rightMin);
            prominence = peak - minHeight;

            % Check prominence constraint
            if prominence >= minPeakProminence
                numValidPeaks = numValidPeaks + 1;
                peaks(numValidPeaks) = peak;
                locs(numValidPeaks) = loc;
            end
        else
            numValidPeaks = numValidPeaks + 1;
            peaks(numValidPeaks) = peak;
            locs(numValidPeaks) = loc;
        end
    end
end

% Trim the arrays to the actual number of valid peaks found
peaks = peaks(1:numValidPeaks);
locs = locs(1:numValidPeaks);

% Sort the locations (and corresponding peaks) in ascending order
[locs, sortedIndex] = sort(locs);
peaks = peaks(sortedIndex);
end
