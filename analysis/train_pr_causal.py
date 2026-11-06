"""训练 PSG 因果 PR 校正器，并用已重放的公共有效秒评估各记录。"""
from pathlib import Path
import joblib
import numpy as np
import pandas as pd
from scipy.io import savemat
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.model_selection import GroupKFold
from threadpoolctl import threadpool_limits

PROJECT = Path(__file__).resolve().parent.parent
REPLAY_DIR = Path("/tmp/psg_step1_runs")
RESULTS_FILE = PROJECT / "analysis/pr_causal_results.csv"
MODEL_DIR = PROJECT / "variants/pr_causal"
FEATURES = ["pr", "cf", "move"]
for k in (-8, -4, -2, 0):
    FEATURES.extend(f"{field}_{k}" for field in ("pr", "raw", "cf"))
for width in (4, 10):
    FEATURES.extend((f"raw_med_past{width}", f"cf_med_past{width}"))


def train(frame):
    selected = frame.iloc[::5]
    counts = selected.id.value_counts()
    weights = 1 / selected.id.map(counts).to_numpy()
    model = HistGradientBoostingRegressor(
        max_iter=100, max_leaf_nodes=15, min_samples_leaf=100,
        learning_rate=0.08, l2_regularization=10, early_stopping=False, random_state=1,
    )
    with threadpool_limits(limits=2):
        model.fit(selected[FEATURES], selected.reference-selected.pr,
                  sample_weight=weights/weights.mean())
    return model


def export_matlab(model, filename):
    trees = [iteration[0].nodes for iteration in model._predictors]
    max_nodes = max(len(tree) for tree in trees)
    shape = (len(trees), max_nodes)
    fields = ("value", "feature_idx", "num_threshold", "missing_go_to_left", "left", "right", "is_leaf")
    arrays = {field: np.zeros(shape, dtype=np.float64) for field in fields}
    for i, tree in enumerate(trees):
        for field in fields:
            arrays[field][i, :len(tree)] = tree[field]
    arrays["baseline"] = float(model._baseline_prediction[0, 0])
    arrays["feature_names"] = np.array(FEATURES, dtype=object)
    savemat(filename, arrays, do_compression=True)


def main():
    rows = []
    for path in sorted(REPLAY_DIR.glob("*.pkl")):
        frame = pd.read_pickle(path)
        if frame.pr.isna().any():
            raise ValueError(f"缺少设备输出 {path.stem}")
        frame["id"] = path.stem
        rows.append(frame)
    all_data = pd.concat(rows, ignore_index=True)
    psg = all_data[all_data.id.str.startswith("psg_")].reset_index(drop=True)
    legacy = all_data[all_data.id.str.startswith("legacy_")].reset_index(drop=True)
    if psg.id.nunique() != 23 or legacy.id.nunique() != 73:
        raise ValueError(f"记录不完整: PSG={psg.id.nunique()}, legacy={legacy.id.nunique()}")
    prediction = np.full(len(psg), np.nan)
    for fold, (train_idx, test_idx) in enumerate(GroupKFold(5).split(psg, groups=psg.id), 1):
        model = train(psg.iloc[train_idx])
        with threadpool_limits(limits=2):
            prediction[test_idx] = psg.iloc[test_idx].pr + model.predict(psg.iloc[test_idx][FEATURES])
        print("fold", fold, "held-out", sorted(psg.iloc[test_idx].id.unique()), flush=True)
    psg["corrected"] = prediction
    full_model = train(psg)
    with threadpool_limits(limits=2):
        legacy["corrected"] = legacy.pr + full_model.predict(legacy[FEATURES])
    combined = pd.concat([psg, legacy], ignore_index=True)
    combined["corrected"] = np.clip(np.floor(combined.corrected + .5), 30, 220)
    combined["squared_error"] = (combined.corrected - combined.reference)**2
    combined["base_squared_error"] = (combined.pr - combined.reference)**2
    result = combined.groupby("id").agg(pairs=("reference", "size"),
               mse=("squared_error", "mean"), base_mse=("base_squared_error", "mean"))
    result["rmse"] = np.sqrt(result.pop("mse"))
    result["baseline_rmse"] = np.sqrt(result.pop("base_mse"))
    result.to_csv(RESULTS_FILE, index_label="No")
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(full_model, MODEL_DIR / "psg_model.joblib")
    export_matlab(full_model, MODEL_DIR / "psg_model.mat")
    for group, subset in (("PSG", result.loc[result.index.str.startswith("psg_")]),
                          ("legacy", result.loc[result.index.str.startswith("legacy_")])):
        print(group, len(subset), "baseline", subset.baseline_rmse.mean(),
              "new", subset.rmse.mean(), "improved", (subset.rmse < subset.baseline_rmse).sum(), flush=True)
    print("wrote", RESULTS_FILE, flush=True)


if __name__ == "__main__":
    main()
