"""用留存的 MATLAB 分阶段日志诊断 PSG PR。只读输入，打印按记录留出的结果。"""

from pathlib import Path

import numpy as np
import pandas as pd
from scipy.io import loadmat
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.model_selection import GroupKFold
from threadpoolctl import threadpool_limits


# 可替换为本机归档路径。两个日志目录分别对应 25 次可靠值均值回退和近期指数均值回退。
LOG_ROOT = Path("/tmp/pr-review.KDxzXh")
LONG_HISTORY_LOGS = LOG_ROOT / "stages"
RECENT_HISTORY_LOGS = LOG_ROOT / "ema"
REPLAY_RESULTS = Path("/tmp/pr-variants/variant_rmse_old_offset.csv")
TIME_OFFSETS = (-8, -4, -2, 0, 2, 4, 8)
FOLDS = 5
TRAIN_STRIDE = 5


def load_record(record_id, offset):
    long_log = loadmat(LONG_HISTORY_LOGS / f"{record_id}.mat", simplify_cells=True)
    recent_log = loadmat(RECENT_HISTORY_LOGS / f"{record_id}.mat", simplify_cells=True)
    long_values = long_log["outputLog"]
    recent_values = recent_log["outputLog"]
    # 两次回放在同一时间有相同的 raw PR、置信度和体动，仅回退策略不同。
    for col in (0, 2, 4, 5):
        np.testing.assert_allclose(long_values[:, col], recent_values[:, col], equal_nan=True)
    seconds = np.floor(long_values[:, 0]).astype(int) + 1
    samples = pd.DataFrame({
        "raw": long_values[:, 2],
        "cf": long_values[:, 4],
        "move": long_values[:, 5],
        "fixed": 0.5 * (long_values[:, 3] + recent_values[:, 3]),
    }, index=seconds)
    # 在逐次输出上重建 Current，再聚合到秒。预热 NaN 隔开各段。
    samples["pr"] = np.floor(samples.fixed.rolling(10).median() + 0.5)
    frame = samples.groupby(level=0).median()
    ref_log = long_log["refLog"]
    reference = pd.Series(ref_log[:, 1], index=np.rint(ref_log[:, 0]).astype(int))
    frame["ref"] = reference.reindex(frame.index - offset).values
    frame["raw"] = frame.raw.where(frame.raw.between(35, 220))
    seconds = frame.index.to_numpy()
    frame["run"] = np.cumsum((np.diff(seconds, prepend=seconds[0]-1) != 1) | frame.pr.isna())
    frame["id"] = record_id
    runs = frame.groupby("run")
    for k in TIME_OFFSETS:
        for field in ("pr", "raw", "cf"):
            shifted = runs[field].shift(-k)
            frame[f"{field}_{k}"] = shifted if field == "cf" else shifted - frame.pr
    for width in (4, 10):
        for field in ("raw", "cf"):
            median = runs[field].transform(lambda s: s.rolling(width, min_periods=1).median())
            frame[f"{field}_med_past{width}"] = median if field == "cf" else median - frame.pr
    return frame[frame.pr.notna() & frame.ref.between(30, 220)]


def predict_heldout(frame, features):
    residual = (frame.ref - frame.pr).to_numpy()
    predicted = np.full(len(frame), np.nan)
    for train, test in GroupKFold(FOLDS).split(frame, groups=frame.id):
        train = train[::TRAIN_STRIDE]
        ids = frame.iloc[train].id
        weights = 1 / ids.map(ids.value_counts()).to_numpy()
        model = HistGradientBoostingRegressor(
            max_iter=100, max_leaf_nodes=15, min_samples_leaf=100,
            learning_rate=0.08, l2_regularization=10, early_stopping=False, random_state=1,
        )
        with threadpool_limits(limits=2):
            model.fit(frame.iloc[train][features], residual[train], sample_weight=weights/weights.mean())
            predicted[test] = model.predict(frame.iloc[test][features])
    return frame.pr + predicted


def main():
    replay = pd.read_csv(REPLAY_RESULTS)
    records = replay[replay.No.str.startswith("psg_")]
    series = pd.concat([load_record(row.No, row.Offset_s) for row in records.itertuples()],
                       ignore_index=True)
    features = ["pr", "cf", "move"] + [col for col in series
                    if "_" in col and col.split("_")[0] in {"pr", "cf", "raw"}]
    future = {f"{field}_{k}" for k in TIME_OFFSETS if k > 0 for field in ("pr", "raw", "cf")}
    past = [col for col in features if col not in future]
    models = {"PR_only": ["pr"], "PR_history": [c for c in past if c == "pr" or c.startswith("pr_")],
              "causal": past, "lookahead8": features}
    errors = pd.DataFrame({"Current": (series.pr - series.ref)**2})
    for name, cols in models.items():
        estimate = predict_heldout(series, cols)
        errors[name] = (estimate - series.ref)**2
        if name in ("causal", "lookahead8"):
            errors[f"{name}_rounded"] = (np.floor(estimate + 0.5) - series.ref)**2
    per_record = np.sqrt(errors.groupby(series.id).mean())
    print("有效秒", len(series))
    print(per_record.round(3).to_string())
    print("逐记录等权", per_record.mean().round(4).to_dict())
    print("逐秒合并", np.sqrt(errors.mean()).round(4).to_dict())


if __name__ == "__main__":
    main()
