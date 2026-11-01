function smoothedSignal = smooth_data(signalIn, windowSize)

coder.inline('never')

% signal length
n = length(signalIn);
% use half window for boudary situation
halfWin = floor(windowSize / 2);
% initialization
smoothedSignal = zeros(size(signalIn));

% Initialize sum for the first window considering boundary conditions
windowSum = sum(signalIn(1:halfWin));
count = halfWin; % Actual count of elements in the initial window

% Initialize first smoothed value especially if it's within a boundary condition
for i = 1:min(halfWin, n)
    smoothedSignal(i) = windowSum / count;
    % Only add new elements if we are not at the end
    if i + halfWin <= n
        windowSum = windowSum + signalIn(i + halfWin);
        count = count + 1;
    end
end

% Smooth for every point after the initial part
for i = (halfWin + 1):(n - halfWin)
    % Add the next item in the window and remove the first one
    windowSum = windowSum + signalIn(i + halfWin) - signalIn(i - halfWin);
    % The count remains constant in the middle part
    smoothedSignal(i) = windowSum / windowSize; % Here the window is always full-sized
end

% Handle the end boundary where the window shrinks again
for i = max(n - halfWin + 1, halfWin + 1):n
    % Only subtract elements if we are not at the beginning
    if i - halfWin > 1
        windowSum = windowSum - signalIn(i - halfWin - 1);
        count = count - 1;
    end
    smoothedSignal(i) = windowSum / count;
end
end
