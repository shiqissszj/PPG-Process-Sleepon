function install_codegen_test_harness(outputDir)
%INSTALL_CODEGEN_TEST_HARNESS Copy the C-side waveform test harness.

arguments
    outputDir (1,:) char
end

supportDir = fullfile(fileparts(mfilename('fullpath')), 'codegen_test_support');
targetDir = char(outputDir);

if ~isfolder(targetDir)
    error('Output directory does not exist: %s', targetDir);
end

copyfile(fullfile(supportDir, 'spo2_pr_waveform_test.c'), ...
    fullfile(targetDir, 'spo2_pr_waveform_test.c'));
copyfile(fullfile(supportDir, 'Makefile'), fullfile(targetDir, 'Makefile'));
end
