function [results, averages, details] = SpO2_PR_catalog_main(recordIDs, options)
% 统一数据目录入口。直接点击 Run 使用下方默认配置。
% 示例：
% [results, averages] = SpO2_PR_catalog_main("psg_11");
% [results, averages] = SpO2_PR_catalog_main(["legacy_2017","psg_11"]);
% [results, averages] = SpO2_PR_catalog_main([2001,2017]); % 数字仅代表旧 Data_id
% [results, averages] = SpO2_PR_catalog_main("all_enabled", struct('ShowPlots',false));
% 默认遍历全部目录行；禁用行标记为 skipped_disabled。
% 强制处理禁用行：SpO2_PR_catalog_main("all_records", struct('RespectEnabled',false,'ShowPlots',false))。
% 保存结果：writetable(results,'catalog_results.csv'); writetable(averages,'catalog_averages.csv');
% MAT 心率参考切换：struct('MatPRReference',"EDF")，默认 "ECG"。
% PR 算法对照：PRVariant 可设为 "current"、"pr_a"、"pr_b"、"pr_c" 或 "pr_causal"。
% 返回逐记录结果、平均结果；可选第三输出保留每秒比较波形。
% 不保存图像/CSV/MAT，不修改目录表。每条记录只画一张图（PR、SpO2两面板）。
% 新入口统一规则：参考PR不截断到100；不前向填补缺失；每段跳过前30个输出。
% enabled默认遵守。明确测试未启用记录可设置RespectEnabled=false；
% 仍必须有有效的体动与TXT裁剪参数，MAT仍须列入当前manifest。

%% 常用配置（均可直接在这里修改）
% Click Run to replay the records currently enabled in data_catalog.xlsx.
DEFAULT_RECORD_IDS = "all_enabled";
% DEFAULT_RECORD_IDS = ["psg_midpoint50_9", "psg_midpoint50_16", "legacy_204"];


CODE_DIR = fileparts(mfilename('fullpath'));
cfg = struct;
cfg.CatalogPath = fullfile(CODE_DIR, 'data_catalog.xlsx');
cfg.MatPRReference = "ECG";  % "ECG" 或 "EDF"，不自动替换参考来源
cfg.ShowPlots = false;
cfg.FigureVisible = 'off';
cfg.RespectEnabled = true;
cfg.AutoOffset = true;
cfg.MaxOffsetSeconds = 120;  % 与SpO2_PR_main一致，输出序列最多搜索±120秒
cfg.MinOffsetPairs = 5;      % 与estimate_time_offset一致
cfg.MinOffsetCorrelation = -1; % 旧规则只取最高相关性，不设0.20门槛
cfg.MaxPairDistanceSeconds = 0.35;
cfg.IgnoreFirstOutputsPerRun = 30;
cfg.HRValidRange = [30,220];
cfg.SpO2ValidRange = [50,100];
cfg.SampleRate = 50;        % ppg_process固定50Hz，不可任意修改
cfg.PRVariant = "current"; % current, pr_a, pr_b, pr_c, pr_causal

if nargin < 1 || isempty(recordIDs), recordIDs = DEFAULT_RECORD_IDS; end
if nargin >= 2
    assert(isstruct(options) && isscalar(options), 'options必须是标量struct。');
    names = fieldnames(options);
    for i = 1:numel(names)
        assert(isfield(cfg,names{i}), '未知配置：%s', names{i});
        cfg.(names{i}) = options.(names{i});
    end
end
cfg.MatPRReference = upper(string(cfg.MatPRReference));
assert(ismember(cfg.MatPRReference,["ECG","EDF"]), 'MatPRReference必须为ECG或EDF。');
assert(cfg.SampleRate == 50, 'ppg_process要求50Hz。');
validateattributes(cfg.MaxOffsetSeconds,{'numeric'},{'scalar','integer','nonnegative','finite'});
validateattributes(cfg.MinOffsetPairs,{'numeric'},{'scalar','integer','>=',2});
validateattributes(cfg.IgnoreFirstOutputsPerRun,{'numeric'},{'scalar','integer','nonnegative'});
addpath(CODE_DIR,'-begin');
cfg.PRVariant = string(cfg.PRVariant);
assert(ismember(cfg.PRVariant,["current","pr_a","pr_b","pr_c","pr_causal"]), '未知PRVariant。');
variantNames = ["pr_a","pr_b","pr_c","pr_causal"];
for variantIndex = 1:numel(variantNames)
    variantPath = fullfile(CODE_DIR,'variants',char(variantNames(variantIndex)));
    if contains([path pathsep],[variantPath pathsep])
        rmpath(variantPath);
    end
end
algorithmFolder = CODE_DIR;
if cfg.PRVariant ~= "current"
    variantPath = fullfile(CODE_DIR,'variants',char(cfg.PRVariant));
    addpath(variantPath,'-begin');
    restoreVariantPath = onCleanup(@()rmpath(variantPath));
    algorithmFolder = variantPath;
end
clear ppg_process r_pr_calculation pr_causal_postprocess
previousFolder = pwd;
restoreFolder = onCleanup(@()cd(previousFolder));
cd(algorithmFolder); % MATLAB 当前目录优先；切入所选目录以确保调用对应算法版本
clear ppg_process r_pr_calculation pr_causal_postprocess
catalog = readtable(cfg.CatalogPath,'Sheet','Records','TextType','string','VariableNamingRule','preserve');
required = {'record_id','input_type','absolute_path','enabled', ...
    'legacy_offset_samples','legacy_drop_start_samples','legacy_drop_end_samples','source_index_path'};
assert(all(ismember(required,catalog.Properties.VariableNames)), '目录表缺少必需字段。');
catalog.record_id = string(catalog.record_id);
assert(numel(unique(catalog.record_id)) == height(catalog), '目录中的record_id重复，请先修正。');
enabled = logicalValues(catalog.enabled);
if isnumeric(recordIDs)
    validateattributes(recordIDs,{'numeric'},{'vector','integer','finite','nonnegative'});
    recordIDs = "legacy_" + string(recordIDs);
else
    recordIDs = string(recordIDs);
end
recordIDs = recordIDs(:);
if isscalar(recordIDs) && recordIDs == "all_enabled"
    recordIDs = catalog.record_id(enabled);
elseif isscalar(recordIDs) && recordIDs == "all_records"
    recordIDs = catalog.record_id;
end
recordIDs = unique(recordIDs,'stable');
assert(~isempty(recordIDs), '没有选中任何记录。');
rows = repmat(emptyResult(),numel(recordIDs),1);
details = cell(numel(recordIDs),1);
fprintf('目录：%s\n本次 %d 条记录，MAT PR参考：%s\n',cfg.CatalogPath,numel(recordIDs),cfg.MatPRReference);
for k = 1:numel(recordIDs)
    result = emptyResult(); result.RecordID = recordIDs(k);
    fprintf('\n[%d/%d] %s\n',k,numel(recordIDs),recordIDs(k));
    try
        index = find(catalog.record_id == recordIDs(k));
        assert(~isempty(index),'目录中不存在record_id：%s',recordIDs(k));
        row = catalog(index,:);
        result.InputType = string(row.input_type);
        result.Dataset = string(row.dataset);
        if cfg.RespectEnabled && ~enabled(index)
            result.Status = "skipped_disabled";
            result.Message = "目录enabled=FALSE；未运行。";
        else
            assert(isfile(row.absolute_path),'数据文件不存在：%s',row.absolute_path);
            input = loadRecord(row,cfg);
            output = replayPPG(input,cfg);
            pr = compareSeries(output.time,output.pr,input.refTime,input.refPR,cfg.HRValidRange,cfg);
            spo2 = compareSeries(output.time,output.spo2,input.refTime,input.refSpO2,cfg.SpO2ValidRange,cfg);
            result.PRReference = input.prReference;
            result.SpO2Reference = input.spo2Reference;
            result.BaseIndexOffsetSamples = input.baseSamples;
            result.PRRMSEBefore = pr.rawRMSE; result.PRRMSE = pr.rmse;
            result.SpO2RMSEBefore = spo2.rawRMSE; result.SpO2RMSE = spo2.rmse;
            result.PRPairs = pr.count; result.SpO2Pairs = spo2.count;
            result.PRSSE = pr.sse; result.SpO2SSE = spo2.sse;
            result.PRAutoOffsetSeconds = pr.offset;
            result.SpO2AutoOffsetSeconds = spo2.offset;
            result.PRTotalShiftSeconds = -input.baseSamples/cfg.SampleRate + pr.offset;
            result.SpO2TotalShiftSeconds = -input.baseSamples/cfg.SampleRate + spo2.offset;
            result.PROffsetStatus = pr.status; result.SpO2OffsetStatus = spo2.status;
            result.Status = "ok";
            if pr.count == 0 || spo2.count == 0
                result.Status = "partial_no_pairs";
                result.Message = "至少一项无有效配对；该项RMSE为NaN，不计入该项平均值。";
            end
            fprintf('  PR   RMSE %.4f -> %.4f | auto %+g s | N=%d | %s\n',pr.rawRMSE,pr.rmse,pr.offset,pr.count,pr.status);
            fprintf('  SpO2 RMSE %.4f -> %.4f | auto %+g s | N=%d | %s\n',spo2.rawRMSE,spo2.rmse,spo2.offset,spo2.count,spo2.status);
            if nargout > 2
                details{k} = struct('PR',pr,'SpO2',spo2,'Output',output,'Config',cfg);
            end
            if cfg.ShowPlots
                try
                    plotComparison(result,input,pr,spo2,cfg);
                catch plotError
                    result.Message = result.Message + " 绘图失败：" + string(plotError.message);
                    warning('Catalog:Plot','%s',result.Message);
                end
            end
        end
    catch exception
        result.Status = "failed";
        result.Message = string(exception.message);
    end
    rows(k) = result;
    if result.Status ~= "ok", fprintf('  %s: %s\n',result.Status,result.Message); end
end
results = struct2table(rows);
averages = summarizeResults(results);
fprintf('\n逐记录结果（偏移单位：秒）\n');
disp(results(:,{'RecordID','Dataset','InputType','PRReference','PRRMSE','SpO2RMSE','PRAutoOffsetSeconds','SpO2AutoOffsetSeconds','PRPairs','SpO2Pairs','Status'}));
fprintf('平均RMSE（逐记录等权）与总体RMSE（汇总有效配对点）\n');
disp(averages);
fprintf('ALL_SELECTED为跨数据集描述性汇总；按Dataset和Reference分组的结果适合比较时间轴版本。\n');
if nargout == 0
    assignin('base','catalogResults',results);
    assignin('base','catalogAverages',averages);
end
end

function value = logicalValues(values)
value = ismember(lower(strtrim(string(values))),["true","1","yes"]);
end

function result = emptyResult()
result = struct('RecordID',"",'Dataset',"",'InputType',"",'PRReference',"",'SpO2Reference',"", ...
    'BaseIndexOffsetSamples',NaN,'PRRMSEBefore',NaN,'PRRMSE',NaN,'SpO2RMSEBefore',NaN,'SpO2RMSE',NaN, ...
    'PRPairs',0,'SpO2Pairs',0,'PRSSE',0,'SpO2SSE',0,'PRAutoOffsetSeconds',NaN, ...
    'SpO2AutoOffsetSeconds',NaN,'PRTotalShiftSeconds',NaN,'SpO2TotalShiftSeconds',NaN, ...
    'PROffsetStatus',"",'SpO2OffsetStatus',"",'Status',"",'Message',"");
end

function input = loadRecord(row,cfg)
switch string(row.input_type)
    case "prepared_mat"
        manifestPath = string(row.source_index_path);
        assert(isfile(manifestPath),'MAT的manifest不存在：%s',manifestPath);
        manifest = jsondecode(fileread(manifestPath));
        assert(ismember(string(manifest.status),["complete","completed_with_failures"]),'Python预处理尚未完成。');
        [~,stem] = fileparts(row.absolute_path);
        subject = extractBetween(string(stem),"subject_","_inputs");
        assert(isscalar(subject) && any(string(manifest.prepared_subjects)==subject),'该MAT不在当前manifest的成功清单中。');
        data = load(row.absolute_path);
        keys = {'ppg_red_raw','ppg_ir_raw','ppg_green_raw','ppg_movement','ppg_sample_time_unix_s', ...
            'ppg_segment_id','edf_bin_end_unix_s','edf_spo2_1hz','edf_spo2_valid'};
        if cfg.MatPRReference == "ECG"
            keys = [keys,{'ecg_hr_1hz','ecg_hr_coverage_s'}];
        else
            keys = [keys,{'edf_pulse_1hz','edf_pulse_valid'}];
        end
        assert(all(isfield(data,keys)),'MAT缺少当前流程必需字段。');
        input.ppg = single([data.ppg_red_raw(:),data.ppg_ir_raw(:),data.ppg_green_raw(:)]);
        input.move = single(data.ppg_movement(:));
        input.time = double(data.ppg_sample_time_unix_s(:));
        input.segment = double(data.ppg_segment_id(:));
        input.refTime = double(data.edf_bin_end_unix_s(:));
        input.refSpO2 = double(data.edf_spo2_1hz(:));
        input.refSpO2(~logical(data.edf_spo2_valid(:))) = NaN;
        if isfield(data,'edf_spo2_xml_artifact')
            input.refSpO2(logical(data.edf_spo2_xml_artifact(:))) = NaN;
        end
        if cfg.MatPRReference == "ECG"
            input.refPR = double(data.ecg_hr_1hz(:));
            input.refPR(~(double(data.ecg_hr_coverage_s(:))>=0.5)) = NaN;
            if isfield(data,'ecg_hr_quality_valid')
                input.refPR(~logical(data.ecg_hr_quality_valid(:))) = NaN;
            end
            input.prReference = "ECG_HR";
        else
            input.refPR = double(data.edf_pulse_1hz(:));
            input.refPR(~logical(data.edf_pulse_valid(:))) = NaN;
            input.prReference = "EDF_Pulse";
        end
        input.spo2Reference = "EDF_SpO2";
        input.baseSamples = 0;
    case "merged_txt"
        input = loadMergedTXT(row,cfg);
    otherwise
        error('不支持的input_type：%s',row.input_type);
end
n = size(input.ppg,1);
assert(all([numel(input.move),numel(input.time),numel(input.segment)]==n),'PPG输入长度不一致。');
assert(numel(input.refPR)==numel(input.refTime) && numel(input.refSpO2)==numel(input.refTime),'参考值和时间长度不一致。');
assert(all(isfinite(input.refTime)) && all(diff(input.refTime)>0),'参考时间必须有限且严格递增。');
end

function input = loadMergedTXT(row,cfg)
parameters = [str2double(string(row.legacy_offset_samples)), ...
    str2double(string(row.legacy_drop_start_samples)),str2double(string(row.legacy_drop_end_samples))];
assert(all(isfinite(parameters)) && all(parameters==fix(parameters)) && all(parameters(2:3)>=0), ...
    'TXT需要目录中明确的offset/start/end采样点参数；未登记记录请先补齐，零必须明确填写0。');
offset=parameters(1); firstDrop=parameters(2); lastDrop=parameters(3);
opts = detectImportOptions(row.absolute_path,'FileType','text','Delimiter',',','VariableNamingRule','preserve');
names = string(opts.VariableNames);
lowerNames = lower(strtrim(names));
requested = ["ppg_r","ppg_ir","ppg_g","movement","checkme_hr","checkme_spo2"];
[present,indices] = ismember(requested,lowerNames);
assert(all(present),'TXT缺少字段：%s。不能将其他列当作体动或参考值。',strjoin(requested(~present),', '));
selected = names(indices);
opts.SelectedVariableNames = cellstr(selected);
opts = setvartype(opts,cellstr(selected),'double');
data = readtable(row.absolute_path,opts);
n = height(data);
refRows = (firstDrop+1:n-lastDrop).';
sensorRows = refRows-offset;
assert(~isempty(refRows) && all(sensorRows>=1 & sensorRows<=n),'TXT裁剪/偏移超出数据范围，请检查目录参数。');
input.ppg = single(data{sensorRows,cellstr(names(indices(1:3)))});
input.move = single(data{sensorRows,char(names(indices(4)))});
input.time = (0:numel(sensorRows)-1).'/cfg.SampleRate;
input.segment = ones(numel(sensorRows),1);
% 延续旧脚本的50Hz行序列：聚合TXT秒级时间戳可能回跳，不能当作丢包依据。
% 此格式无可靠原始包计数，无法像prepared_mat一样恢复源采集断点。
rawPR = data{refRows,char(names(indices(5)))};
rawSpO2 = data{refRows,char(names(indices(6)))};
seconds = floor(numel(refRows)/cfg.SampleRate);
assert(seconds>0,'TXT有效时长不足1秒。');
input.refTime = (1:seconds).';
input.refPR = windowMode(rawPR,seconds,cfg.SampleRate);
input.refSpO2 = windowMode(rawSpO2,seconds,cfg.SampleRate);
input.baseSamples = offset;
input.prReference = "TXT_Checkme_PR";
input.spo2Reference = "TXT_Checkme_SpO2";
end

function output = windowMode(values,n,fs)
output = nan(n,1);
for j=1:n
    v=values((j-1)*fs+1:j*fs); v=v(isfinite(v) & v>0);
    if ~isempty(v), output(j)=mode(v); end
end
end

function output = replayPPG(input,cfg)
valid = all(isfinite(input.ppg),2) & isfinite(input.move) & isfinite(input.time) & isfinite(input.segment);
same = diff(input.segment)==0 & diff(input.time)>0 & diff(input.time)<=2;
starts = find(valid & [true; ~valid(1:end-1) | ~same]);
ends = find(valid & [~valid(2:end) | ~same; true]);
assert(numel(starts)==numel(ends),'PPG连续片段边界不匹配。');
capacity = ceil(size(input.ppg,1)/50)+numel(starts);
time=nan(capacity,1); pr=time; spo2=time; count=0;
for run=1:numel(starts)
    first=starts(run); last=ends(run);
    if last-first+1<150, continue; end
    clear ppg_process r_pr_calculation r_pr_fix r_smoothing pr_smoothing ac_filter dc_ac_spliter find_peaks
    runCount=0;
    for i=first:last
        [flag,hr,oxygen]=ppg_process(input.ppg(i,1),input.ppg(i,2),input.ppg(i,3),uint32(i-first+1),input.move(i));
        if flag
            count=count+1; runCount=runCount+1;
            time(count)=input.time(i);
            if runCount>cfg.IgnoreFirstOutputsPerRun
                pr(count)=double(hr); spo2(count)=double(oxygen);
            end
        end
    end
end
assert(count>0,'没有足够长、且包含有效PPG和Movement的连续片段。');
[time,order]=sort(time(1:count)); pr=pr(order); spo2=spo2(order);
[time,keep]=unique(time,'stable');
output=struct('time',time,'pr',pr(keep),'spo2',spo2(keep));
end

function c = compareSeries(deviceTime,device,refTime,reference,range,cfg)
good=isfinite(deviceTime) & isfinite(device) & device>=range(1) & device<=range(2);
deviceTime=floor(deviceTime(good))+1; device=device(good);
[deviceTime,~,group]=unique(deviceTime,'sorted');
if ~isempty(device), device=accumarray(group,device,[],@median); end
reference(~isfinite(reference) | reference<range(1) | reference>range(2))=NaN;
c=struct('time',[],'reference',[],'device',[],'offset',0,'rawRMSE',NaN,'rmse',NaN, ...
    'count',0,'sse',0,'status',"no_common_valid_data",'searchCorrelation',NaN);
refGood=isfinite(reference);
if numel(deviceTime)<2 || ~any(refGood), return; end
lo=max(min(deviceTime),min(refTime(refGood))); hi=min(max(deviceTime),max(refTime(refGood)));
if hi<=lo, return; end
% 与EDF比较脚本一致：固定共同参考时间窗，右边界不计入。
use=refTime>=lo & refTime<hi;
t=refTime(use); ref=reference(use);
% 旧版PR和参考向量按完整记录预分配；3秒窗、1秒步长使长度约为秒级参考轴长度-3。
% 这里按完整时间轴估计N，避免质量过滤后有效设备点变少而错误缩窄旧版搜索范围。
seriesLength=max(0,numel(refTime)-3);
maxLag=min(cfg.MaxOffsetSeconds,floor(seriesLength/2));
raw=pairValues(t,deviceTime,device,0,cfg.MaxPairDistanceSeconds);
[c.rawRMSE,~,~]=metrics(raw,ref);
c.status="offset_search_disabled";
if cfg.AutoOffset
    best=-Inf; bestLag=0;
    for lag=-maxLag:maxLag
        estimate=pairValues(t,deviceTime,device,lag,cfg.MaxPairDistanceSeconds);
        keep=isfinite(estimate) & isfinite(ref);
        if sum(keep)<cfg.MinOffsetPairs || std(estimate(keep))==0 || std(ref(keep))==0, continue; end
        corrMatrix=corrcoef(estimate(keep),ref(keep)); value=corrMatrix(1,2);
        if isfinite(value) && value>best
            best=value; bestLag=lag;
        end
    end
    if isfinite(best), c.searchCorrelation=best; end
    if isfinite(best) && best>=cfg.MinOffsetCorrelation
        c.offset=bestLag; c.status="offset_estimated";
    else
        c.status="offset_rejected_low_correlation_or_pair_count";
    end
end
c.time=t; c.reference=ref;
c.device=pairValues(t,deviceTime,device,c.offset,cfg.MaxPairDistanceSeconds);
[c.rmse,c.count,c.sse]=metrics(c.device,ref);
end

function values = pairValues(t,deviceTime,device,lag,tolerance)
target=t+lag;
indices=interp1(deviceTime,(1:numel(deviceTime)).',target,'nearest',NaN);
values=nan(size(t)); valid=isfinite(indices);
positions=find(valid); indices=round(indices(valid));
close=abs(deviceTime(indices)-target(valid))<=tolerance;
values(positions(close))=device(indices(close));
end

function [rmse,n,sse] = metrics(estimate,reference)
keep=isfinite(estimate) & isfinite(reference); n=sum(keep);
sse=sum((estimate(keep)-reference(keep)).^2); rmse=NaN;
if n>0, rmse=sqrt(sse/n); end
end

function averages = summarizeResults(results)
rows=struct('Group',{},'Dataset',{},'Signal',{},'Reference',{},'RecordCount',{},'PairCount',{},'MeanRMSE',{},'PooledRMSE',{});
for signal=["PR","SpO2"]
    rmse=results.(signal+"RMSE"); pairs=results.(signal+"Pairs"); sse=results.(signal+"SSE");
    refs=results.(signal+"Reference"); datasets=results.Dataset;
    valid=isfinite(rmse) & pairs>0;
    allGroups=struct('Group',"ALL_SELECTED",'Dataset',"ALL_SELECTED", ...
        'Reference',"ALL_SELECTED",'Mask',valid);
    groups=allGroups;
    datasetNames=unique(datasets(valid),'stable');
    for datasetIndex=1:numel(datasetNames)
        datasetMask=valid & datasets==datasetNames(datasetIndex);
        referenceNames=unique(refs(datasetMask),'stable');
        for referenceIndex=1:numel(referenceNames)
            referenceMask=datasetMask & refs==referenceNames(referenceIndex);
            groups(end+1)=struct('Group',datasetNames(datasetIndex), ...
                'Dataset',datasetNames(datasetIndex),'Reference',referenceNames(referenceIndex), ...
                'Mask',referenceMask); %#ok<AGROW>
        end
    end
    for g=1:numel(groups)
        use=groups(g).Mask;
        n=sum(pairs(use)); pooled=NaN; average=NaN;
        if n>0, pooled=sqrt(sum(sse(use))/n); average=mean(rmse(use)); end
        rows(end+1)=struct('Group',groups(g).Group,'Dataset',groups(g).Dataset, ...
            'Signal',signal,'Reference',groups(g).Reference,'RecordCount',sum(use), ...
            'PairCount',n,'MeanRMSE',average,'PooledRMSE',pooled); %#ok<AGROW>
    end
end
averages=struct2table(rows);
end

function plotComparison(result,input,pr,spo2,cfg)
fig=figure('Name',char(result.RecordID),'NumberTitle','off','Color','w', ...
    'Visible',cfg.FigureVisible,'Position',[100,100,1200,700]);
layout=tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
title(layout,result.RecordID+'  PPG comparison','Interpreter','none');
allTimes=[pr.time;spo2.time];
if isempty(allTimes), origin=input.refTime(1); else, origin=min(allTimes); end
ax1=nexttile(layout); drawPanel(ax1,pr,input.prReference,"PR (bpm)",origin,result.PRTotalShiftSeconds);
ax2=nexttile(layout); drawPanel(ax2,spo2,input.spo2Reference,"SpO2 (%)",origin,result.SpO2TotalShiftSeconds);
linkaxes([ax1,ax2],'x'); xlabel(ax2,'Time from comparison start (min)');
drawnow;
end

function drawPanel(ax,c,referenceName,unit,origin,totalShift)
% NaN保留缺失位置，不将缺失秒压缩成相邻点。
plot(ax,(c.time-origin)/60,c.reference,'Color',[0.15,0.35,0.75],'DisplayName',referenceName); hold(ax,'on');
plot(ax,(c.time-origin)/60,c.device,'Color',[0.85,0.25,0.15],'DisplayName','PPG algorithm (aligned)');
ylabel(ax,unit); grid(ax,'on');
legend(ax,'Location','northoutside','Orientation','horizontal','Interpreter','none');
label=sprintf('Auto offset: %+g s | Total shift: %+g s\nRMSE: %.3f -> %.3f | Valid pairs: %d\n%s', ...
    c.offset,totalShift,c.rawRMSE,c.rmse,c.count,c.status);
text(ax,0.01,0.03,label,'Units','normalized','VerticalAlignment','bottom', ...
    'BackgroundColor','w','Margin',3,'FontSize',9,'Interpreter','none');
% 正偏移：算法值出现在参考之后。图中将算法时间向左移动该偏移。
end
