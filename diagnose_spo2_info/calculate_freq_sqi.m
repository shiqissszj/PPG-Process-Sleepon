function [PRAmplRatio,DCAmplRatio] = calculate_freq_sqi(inputSignal, samplingRate, PR)
% samplingRate = single(samplingRate);
% Parameters for zero-padding
% desiredResolution = 0.1;  % Hz, adjust this as needed for finer resolution
desiredResolution = 0.2;  % Hz, adjust this as needed for finer resolution
maxPR = 180;
minPR = 30;
maxPRFreqInd = round(maxPR/60/desiredResolution)+1;
minPRFreqInd = round(minPR/60/desiredResolution)+1;
N = length(inputSignal);
N_fft = max(N, ceil(samplingRate / desiredResolution)); % Calculate the new length after zero-padding

% Apply FFT to the zero-padded signal
% freqs = (0:(N_fft/2)) * (samplingRate / N_fft);  % Frequency range after zero-padding
% fftSpectrum = abs(fft(inputSignal, N_fft));  % Perform FFT with zero-padding
% fftSpectrum = fftSpectrum(1:N_fft/2+1);  % Use only the positive side of the FFT

% use my fft
fftSpectrum = my_fft(inputSignal, double(N_fft), maxPRFreqInd);

PRFreqInd = round(PR/60/desiredResolution)+1;
PRFreqInd = min(PRFreqInd, maxPRFreqInd-1);
% % desiredResolution = 0.05
% if PRFreqInd <= 1
%     fftPRAmpl = sum(fftSpectrum(20-1:20+1));
% else
%     fftPRAmpl = sum(fftSpectrum(PRFreqInd-1:PRFreqInd+1));
% end
% % desiredResolution = 0.1
% if PRFreqInd <= 1
%     fftPRAmpl = sum(fftSpectrum(10-1:10+1));
% else
%     fftPRAmpl = sum(fftSpectrum(PRFreqInd-1:PRFreqInd+1));
% end
% desiredResolution = 0.2
if PRFreqInd <= 1
    fftPRAmpl = sum(fftSpectrum(5));
else
    fftPRAmpl = sum(fftSpectrum(PRFreqInd));
end
DCAmpl = sum(fftSpectrum(1:minPRFreqInd));
fftAmplAll = sum(fftSpectrum(1:maxPRFreqInd));

PRAmplRatio = fftPRAmpl/fftAmplAll;
DCAmplRatio = DCAmpl/fftAmplAll;

% figure(8); plot(freqs, fftSpectrum)

% test = abs(my_fft(inputSignal, double(N_fft), maxPRFreqInd));
% test = test(1:N_fft/2+1);
% figure(9); plot(freqs, test)
end