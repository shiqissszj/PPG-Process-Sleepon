function Spo2 = calculate_spo2_beat30(inputR, model)
% Calculate SpO2 from beat-level R.
%
% This function is intentionally independent from calculate_spo2.m because
% beat30_r uses a different AC/DC extraction path and needs its own
% calibration. The default coefficients are only a bootstrap candidate.
% Run R_SpO2_scatter_beat30_calibration.m and copy the selected coefficients
% here before treating beat30 as a production SpO2 path.

coder.inline('never')

if nargin < 2 || isempty(model)
    model = 'bootstrapLinear';
end

if isstruct(model)
    Spo2 = apply_beat30_model(inputR, model);
else
    modelName = lower(char(model));
    switch modelName
        case {'bootstraplinear', 'default', 'linear'}
            % Bootstrap only. Replace with beat30-specific fitted values.
            linearCoeffs = [-32.500781164, 111.565386517];
            Spo2 = linearCoeffs(1) * inputR + linearCoeffs(2);

        case 'quadratic'
            % Bootstrap candidate copied from the current calibration family.
            quadraticCoeffs = [-5.889659, -24.488090, 109.879903];
            Spo2 = quadraticCoeffs(1) * inputR.^2 + quadraticCoeffs(2) * inputR + quadraticCoeffs(3);

        case 'piecewise'
            % Bootstrap candidate copied from the current calibration family.
            piecewiseCoeffs = [101.850707, -8.228011, 0.575722, -42.901326];
            Spo2 = (inputR <= piecewiseCoeffs(3)).*(piecewiseCoeffs(1) + piecewiseCoeffs(2) * inputR) + ...
                (inputR > piecewiseCoeffs(3)).*(piecewiseCoeffs(1) + piecewiseCoeffs(2) * piecewiseCoeffs(3) + piecewiseCoeffs(4) * (inputR - piecewiseCoeffs(3)));

        otherwise
            error('Unknown beat30 SpO2 model: %s', char(model));
    end
end

Spo2 = max(min(Spo2, 100), 65);
end

function Spo2 = apply_beat30_model(inputR, model)

modelName = string(model.name);

if modelName == "WeightedLinear"
    coeffs = model.coeffs;
    Spo2 = coeffs(1) * inputR + coeffs(2);
elseif modelName == "WeightedQuadratic"
    coeffs = model.coeffs;
    Spo2 = coeffs(1) * inputR.^2 + coeffs(2) * inputR + coeffs(3);
elseif modelName == "WeightedPiecewiseLinear"
    coeffs = model.coeffs;
    Spo2 = (inputR <= coeffs(3)).*(coeffs(1) + coeffs(2) * inputR) + ...
        (inputR > coeffs(3)).*(coeffs(1) + coeffs(2) * coeffs(3) + coeffs(4) * (inputR - coeffs(3)));
elseif modelName == "WeightedLowSpO2Segmented"
    coeffs = model.coeffs;
    Spo2 = (inputR <= coeffs(3)).*(coeffs(1) + coeffs(2) * inputR) + ...
        (inputR > coeffs(3) & inputR <= coeffs(5)).*(coeffs(1) + coeffs(2) * coeffs(3) + coeffs(4) * (inputR - coeffs(3))) + ...
        (inputR > coeffs(5)).*(coeffs(1) + coeffs(2) * coeffs(3) + coeffs(4) * (coeffs(5) - coeffs(3)) + coeffs(6) * (inputR - coeffs(5)));
else
    error('Unsupported beat30 calibration model struct: %s', model.name);
end
end
