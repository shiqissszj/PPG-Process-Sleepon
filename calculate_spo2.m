function Spo2 = calculate_spo2(inputR)

coder.inline('never')

% Calibration candidates from R_SpO2_scatter_v2.m using R_SpO2_values_v2.mat
%
% Linear:
%   SpO2 = -38.673274 * R + 117.855417
%
% Quadratic:
%   SpO2 = -10.521128 * R^2 + -21.712300 * R + 111.509029
%
% PiecewiseLinear:
%   breakpoint = 0.575722
%   left  : SpO2 = 101.850707 + -8.228011 * R
%   right : continue from breakpoint with slope -42.901326

% Default active model: Linear
% linearFun = @(x, xdata) x(1) * xdata + x(2);
% linearCoeffs = [-38.673274, 117.855417];
% Spo2 = linearFun(linearCoeffs, inputR);
% linearFun = @(x,xdata)x(1)*xdata+x(2);
% linearCoeffs = [-39.9031385316171,120.345434717573];
%
% Spo2 = linearFun(linearCoeffs, inputR);

% Quadratic candidate
% quadraticFun = @(x, xdata) x(1) * xdata.^2 + x(2) * xdata + x(3);
% quadraticCoeffs = [-17.083025, -10.626567, 107.006690];
% quadraticCoeffs = [-5.709408, -25.587417, 110.219948];
% quadraticCoeffs = [-5.889659, -24.488090, 109.879903];
% Spo2 = quadraticFun(quadraticCoeffs, inputR);

% Piecewise-linear candidate
% piecewiseFun = @(b, x) (x <= b(3)).*(b(1) + b(2) * x) + ...
%     (x > b(3)).*(b(1) + b(2) * b(3) + b(4) * (x - b(3)));
% piecewiseCoeffs = [101.850707, -8.228011, 0.575722, -42.901326];
% Spo2 = piecewiseFun(piecewiseCoeffs, inputR);

% Current calibration from R_SpO2_scatter_for_calibration.m
% segmentedCoeffs = [111.681029336, -32.427245497, 0.840888038, -27.951537941, 1.028421640, -38.543077665];
% Spo2 = (inputR <= segmentedCoeffs(3)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * inputR) + ...
%     (inputR > segmentedCoeffs(3) & inputR <= segmentedCoeffs(5)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * segmentedCoeffs(3) + segmentedCoeffs(4) * (inputR - segmentedCoeffs(3))) + ...
%     (inputR > segmentedCoeffs(5)).*(segmentedCoeffs(1) + segmentedCoeffs(2) * segmentedCoeffs(3) + segmentedCoeffs(4) * (segmentedCoeffs(5) - segmentedCoeffs(3)) + segmentedCoeffs(6) * (inputR - segmentedCoeffs(5)));

% Current calibration from R_SpO2_scatter_for_calibration.m
quadraticCoeffs = [-1.755350847, -29.573163045, 110.586417515];
Spo2 = quadraticCoeffs(1) * inputR.^2 + quadraticCoeffs(2) * inputR + quadraticCoeffs(3);

Spo2 = max(min(Spo2, 100), 65);
end

