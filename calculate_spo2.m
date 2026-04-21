function Spo2 = calculate_spo2(inputR)

coder.inline('never')

% piecewiseFun = @(b, x) ...
%     (x <= b(3)).*(b(1) + b(2)*x) + ...
%     (x > b(3) & x <= b(6)).*(b(1) + b(2)*b(3) + b(4)*(x - b(3))) + ...
%     (x > b(6)).*(b(1) + b(2)*b(3) + b(4)*(b(6) - b(3)) + b(5)*(x - b(6)));
% modelCoeffs = [113.5;-26.34;0.7;-54.55;-38.55;0.87;]; % 0628_2

linearFun = @(x,xdata)x(1)*xdata+x(2);
linearCoeffs = [-39.9031385316171,120.345434717573];

Spo2 = linearFun(linearCoeffs, inputR);
Spo2 = max(min(Spo2, 100), 65);
end

