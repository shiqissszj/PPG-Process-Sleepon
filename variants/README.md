# PR 算法对照版本

`SpO2_PR_catalog_main` 的 `PRVariant` 选项可切换以下实现；默认 `current` 保持项目根目录中的现有算法：

```matlab
[results, averages] = SpO2_PR_catalog_main("psg_11", ...
    struct('ShowPlots', false, 'PRVariant', "pr_a"));
```

- `pr_a`：仍以 6 秒窗口得到候选；连续候选支持偏离历史 PR 时，在现有 6 秒信号上比较旧周期与新周期，不增加持久 10 秒缓存。
- `pr_b`：触发条件同 A，但用滚动 10 秒绿光信号比较周期。增加约 2,000 字节的持久绿光缓存。
- `pr_c`：每秒都在滚动 10 秒信号上重新做两阶段峰检测并检查新周期。也增加约 2,000 字节持久缓存，计算量最高。

`RMSE_summary.xlsx` 中的 current/A/B/C 新列来自相同 Coder C 回放条件；四种输出共用 current 的偏移，并使用相同共同有效秒。偏移规则与旧 `estimate_time_offset` 对齐：最多搜索 ±120 秒，短序列进一步限为原始稠密输出向量长度的一半。目录版按完整参考时间轴估计该长度（3秒窗、1秒步长时约为 `numel(refTime)-3`），不按质量过滤后的有效设备点数缩小搜索范围；至少 5 对有效值，取最高相关性，不设相关性下限。`PR RMSE(0506)` 保留原值。`Common paired seconds` 表示该行四种输出与参考值都有效的共同秒数。

使用 `build_pr_variant_codegen("pr_a")`、`build_pr_variant_codegen("pr_b")` 或 `build_pr_variant_codegen("pr_c")` 可为对应变体生成 Cortex-M C 代码。该构建入口会切换到所选变体目录再调用 codegen，确保 MATLAB 当前目录优先规则不会选回项目根目录实现。

这三版用于同数据对照，`current` 仍是默认版本。部署前应结合 RMSE 表和目标 MCU 上的时延、RAM 实测决定是否启用。

## 因果后处理实验版

`pr_causal` 以现有算法最终 PR、raw PR、绿光置信度和体动为输入，用过去 10 秒的因果特征与训练得到的树模型修正最终 PR。

```matlab
[results, averages] = SpO2_PR_catalog_main("psg_9", ...
    struct('ShowPlots', false, 'PRVariant', "pr_causal"));
```

`pr_causal/psg_model.mat` 使用 23 条 PSG 全部数据训练，MATLAB 入口读取该固定模型。每段前 30 个输出保持 current，随后积累历史特征。模型含 100 棵树，尚未验证 MATLAB Coder 转换、固件内存、模型读取和耗时。

工作簿新增列使用每条 current 的偏移与 current/A/B/C 共用的有效秒。PSG 行使用五折按记录留出模型，legacy 行使用全部 PSG 训练的模型，属于跨来源评估。MATLAB 入口使用全部 PSG 训练的模型，并默认重新搜索该算法的偏移，因此直接运行某条 PSG 的 RMSE 不等于表格里的留出成绩。真实人员分组及独立新受试者评估尚未完成。

`analysis/pr_causal_results.csv` 含每条记录共同秒数、基线和因果模型 RMSE，`analysis/pr_causal_baseline.csv` 保留每条偏移和四种方法的回放基线。`analysis/train_pr_causal.py` 从本次原始回放产生的逐记录特征缓存训练并导出模型，缓存默认在临时目录 `/tmp/psg_step1_runs`。
