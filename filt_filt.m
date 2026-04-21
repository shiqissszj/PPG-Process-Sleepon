function filtered_signal = filt_filt(b, a, inputSignal)
% Forward filter
forward_filtered = filter(b, a, inputSignal);

% Reverse and filter
reversed_signal = forward_filtered(end:-1:1);
reversed_filtered = filter(b, a, reversed_signal);

% reverse and output
filtered_signal = reversed_filtered(end:-1:1);
end
