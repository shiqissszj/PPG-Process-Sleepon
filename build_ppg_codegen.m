function build_ppg_codegen(varargin)
%BUILD_PPG_CODEGEN Generate C code for ppg_process with scriptable options.
%
% Common examples:
%   build_ppg_codegen
%   build_ppg_codegen('OutputDir', 'codegen_static_no_openmp_bool', ...
%                     'MultiInstanceCode', false)
%
% Name-value options:
%   'OutputDir'                         output folder for generated files
%   'MultiInstanceCode'                false -> static state, true -> reentrant state
%   'EnableOpenMP'                     enable/disable OpenMP support
%   'EnableAutoParallelization'        enable/disable auto parallelization
%   'UseBuiltInCTypes'                 true -> bool/float/unsigned int style
%   'EnableDynamicMemoryAllocation'    enable/disable dynamic memory allocation
%   'DynamicMemoryAllocationThreshold' threshold in bytes
%   'DynamicMemoryAllocationForFixedSizeArrays'
%                                      whether fixed-size arrays may use heap
%   'GenerateReport'                   whether to generate HTML report
%   'ProdHWDeviceType'                 production hardware target, for example
%                                      'ARM Compatible->ARM Cortex-M'
%   'GenCodeOnly'                      true -> generate source only, no objects/libs
%   'GenerateMakefile'                 whether to generate makefiles
%   'GenerateExampleMain'              'GenerateCodeOnly', 'DoNotGenerate',
%                                      or 'GenerateCodeAndCompile'

parser = inputParser;
parser.FunctionName = mfilename;

addParameter(parser, 'OutputDir', 'codegen_script_output', @isTextScalar);
addParameter(parser, 'MultiInstanceCode', false, @isLogicalScalar);
addParameter(parser, 'EnableOpenMP', false, @isLogicalScalar);
addParameter(parser, 'EnableAutoParallelization', false, @isLogicalScalar);
addParameter(parser, 'UseBuiltInCTypes', true, @isLogicalScalar);
addParameter(parser, 'EnableDynamicMemoryAllocation', true, @isLogicalScalar);
addParameter(parser, 'DynamicMemoryAllocationThreshold', 1280, @isNonnegativeScalar);
addParameter(parser, 'DynamicMemoryAllocationForFixedSizeArrays', false, @isLogicalScalar);
addParameter(parser, 'GenerateReport', true, @isLogicalScalar);
addParameter(parser, 'ProdHWDeviceType', '', @isTextScalar);
addParameter(parser, 'GenCodeOnly', true, @isLogicalScalar);
addParameter(parser, 'GenerateMakefile', false, @isLogicalScalar);
addParameter(parser, 'GenerateExampleMain', 'GenerateCodeOnly', @isTextScalar);

parse(parser, varargin{:});
opts = parser.Results;

cfg = coder.config('lib');
cfg.TargetLang = 'C';
cfg.GenerateReport = opts.GenerateReport;
cfg.MultiInstanceCode = opts.MultiInstanceCode;
cfg.EnableOpenMP = opts.EnableOpenMP;
cfg.EnableAutoParallelization = opts.EnableAutoParallelization;
cfg.EnableDynamicMemoryAllocation = opts.EnableDynamicMemoryAllocation;
cfg.DynamicMemoryAllocationThreshold = opts.DynamicMemoryAllocationThreshold;
cfg.DynamicMemoryAllocationForFixedSizeArrays = opts.DynamicMemoryAllocationForFixedSizeArrays;
cfg.GenCodeOnly = opts.GenCodeOnly;
cfg.GenerateMakefile = opts.GenerateMakefile;
cfg.GenerateExampleMain = char(opts.GenerateExampleMain);

if strlength(string(opts.ProdHWDeviceType)) > 0
    cfg.HardwareImplementation.ProdHWDeviceType = char(opts.ProdHWDeviceType);
end

if opts.UseBuiltInCTypes
    cfg.DataTypeReplacement = 'CBuiltIn';
else
    cfg.DataTypeReplacement = 'CoderTypeDefs';
end

args = {single(0), single(0), single(0), uint32(1), single(0)};

fprintf('Generating C code for ppg_process...\n');
fprintf('  OutputDir: %s\n', char(opts.OutputDir));
fprintf('  MultiInstanceCode: %d\n', opts.MultiInstanceCode);
fprintf('  EnableOpenMP: %d\n', opts.EnableOpenMP);
fprintf('  EnableAutoParallelization: %d\n', opts.EnableAutoParallelization);
fprintf('  UseBuiltInCTypes: %d\n', opts.UseBuiltInCTypes);
fprintf('  EnableDynamicMemoryAllocation: %d\n', opts.EnableDynamicMemoryAllocation);
fprintf('  DynamicMemoryAllocationThreshold: %d\n', opts.DynamicMemoryAllocationThreshold);
fprintf('  DynamicMemoryAllocationForFixedSizeArrays: %d\n', ...
    opts.DynamicMemoryAllocationForFixedSizeArrays);
fprintf('  GenCodeOnly: %d\n', opts.GenCodeOnly);
fprintf('  GenerateMakefile: %d\n', opts.GenerateMakefile);
fprintf('  GenerateExampleMain: %s\n', char(opts.GenerateExampleMain));
if strlength(string(opts.ProdHWDeviceType)) > 0
    fprintf('  ProdHWDeviceType: %s\n', char(opts.ProdHWDeviceType));
else
    fprintf('  ProdHWDeviceType: default MATLAB host\n');
end

codegenArgs = {'-config', cfg, ...
    '-d', char(opts.OutputDir), ...
    'ppg_process', ...
    '-args', args};

if opts.GenerateReport
    codegenArgs{end + 1} = '-report';
end

codegen(codegenArgs{:});

if exist('install_codegen_test_harness', 'file') == 2
    install_codegen_test_harness(char(opts.OutputDir));
    fprintf('Installed waveform test harness into %s\n', char(opts.OutputDir));
end
end

function tf = isTextScalar(value)
tf = (ischar(value) && isrow(value)) || (isstring(value) && isscalar(value));
end

function tf = isLogicalScalar(value)
tf = islogical(value) && isscalar(value);
end

function tf = isNonnegativeScalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value >= 0;
end
