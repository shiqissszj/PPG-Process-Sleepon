function [outputAC] = ac_normalize(inputAC)

coder.inline('never')

outputAC = (inputAC - ((max(inputAC)+min(inputAC))/2)) / (max(inputAC) - min(inputAC)) * 2;

end

