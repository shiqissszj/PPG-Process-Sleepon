function [DC, singalIn] = dc_ac_spliter(singalIn,samplingRate)

coder.inline('never')

DC = smooth_data(singalIn, single(samplingRate));

singalIn = singalIn - DC;

end

