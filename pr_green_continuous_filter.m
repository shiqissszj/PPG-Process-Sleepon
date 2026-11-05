function filtered = pr_green_continuous_filter(sample, inputCounter)
% Causal 0.5–4 Hz Butterworth filter for the continuous green PR stream.
% Three second-order sections avoid the numerical sensitivity of a single
% sixth-order direct form. Reset at the beginning of each contiguous run.
coder.inline('never')
persistent states origin
if isempty(states) || inputCounter == 1
    states = zeros(3,2);
    origin = double(sample);
end

% Subtracting a fixed origin limits the DC magnitude without changing the
% steady-state bandpass response. State is preserved for every sample.
x = (double(sample) - origin) * 0.0071676674266445;
b1 = [2, 0, -2];
b2 = [1, -1, 1];
a1 = [-1.60845130562052, -1.49185771869160, -1.94425865513380];
a2 = [0.63461929754415, 0.684231570723871, 0.948442983580670];
for section = 1:3
    y = x + states(section,1);
    states(section,1) = b1(section)*x - a1(section)*y + states(section,2);
    states(section,2) = b2(section)*x - a2(section)*y;
    x = y;
end
filtered = single(x);
end
