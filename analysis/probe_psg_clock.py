"""比较 PSG 回放的时间轴。固定上轮每夜偏移、逐秒预测和 ECG 参考。"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.stats import theilslopes
from sklearn.model_selection import GroupKFold
from threadpoolctl import threadpool_limits

from probe_psg_multichannel import INPUT_ROOT
from train_pr_causal import FEATURES, REPLAY_DIR, train


def heldout_predictions():
    frames = [pd.read_pickle(p).assign(id=p.stem) for p in sorted(REPLAY_DIR.glob("psg_*.pkl"))]
    frame = pd.concat(frames, ignore_index=True)
    estimate = np.full(len(frame), np.nan)
    with threadpool_limits(limits=2):
        for training, test in GroupKFold(5).split(frame, groups=frame.id):
            model = train(frame.iloc[training])
            values = frame.iloc[test]
            estimate[test] = np.clip(np.floor(values.pr + model.predict(values[FEATURES]) + .5),30,220)
    frame["estimate"] = estimate
    return frame


def segment_maps(subject, targets):
    fields = ["ppg_segment_id","ppg_sample_time_unix_s","ppg_packet_time_unix_s"]
    raw = loadmat(INPUT_ROOT/subject/(subject+"_inputs.mat"),variable_names=fields,squeeze_me=True)
    times = raw["ppg_sample_time_unix_s"]
    receipts = raw["ppg_packet_time_unix_s"]
    breaks = np.r_[0, np.flatnonzero(np.diff(raw["ppg_segment_id"])!=0)+1, len(times)]
    maps = {name:np.full(len(targets),np.nan) for name in ("midpoint","receipt50","robustline")}
    hits = np.zeros(len(targets),int)
    for a,b in zip(breaks,breaks[1:]):
        if b-a < 2 or times[b-1] <= times[a]:
            continue
        mask = (targets>=times[a]) & (targets<=times[b-1])
        if not mask.any():
            continue
        hits[mask] += 1
        duration = times[b-1]-times[a]
        position = (targets[mask]-times[a]) * (b-a-1)/duration
        maps["midpoint"][mask] = (times[a]+times[b-1])/2 + (position-(b-a-1)/2)/50
        ii = np.arange(b-a)
        intercept = np.median(receipts[a:b]-ii/50)
        maps["receipt50"][mask] = intercept+position/50
        # Reduce receipt jitter in at most 61 consecutive blocks before fitting.
        blocks = np.array_split(ii,min(61,len(ii)))
        index = np.array([np.median(k) for k in blocks])
        receipt = np.array([np.median(receipts[a+k]) for k in blocks])
        slope = theilslopes(receipt,index)[0]
        maps["robustline"][mask] = np.median(receipt-slope*index)+slope*position
    for values in maps.values():
        values[hits!=1] = np.nan
    return maps


def main():
    frame = heldout_predictions()
    scores = []
    for name,q in frame.groupby("id"):
        target = q.time.to_numpy()
        maps = segment_maps("subject_"+name.split("_")[1],target)
        original = q.set_index("ref_index")[["reference","estimate"]]
        measures = original.copy()
        for method,new_time in maps.items():
            use = np.isfinite(new_time)
            shifted = q.ref_index.to_numpy()[use] + np.floor(new_time[use])-np.floor(target[use])
            pred = pd.Series(q.estimate.to_numpy()[use],index=shifted).groupby(level=0).median()
            measures[method] = pred.reindex(measures.index)
        paired = measures.dropna()
        errors = paired.drop(columns="reference").sub(paired.reference,axis=0)
        scores.append(dict(id=name,total=len(q),common=len(paired),
                           **np.sqrt(errors.pow(2).mean()).to_dict()))
    table=pd.DataFrame(scores).set_index("id")
    table.to_csv(Path(__file__).with_name("psg_clock_probe_results.csv"))
    print(table.round(3).to_string())
    print("means",table.iloc[:,2:].mean().to_dict(),"pairs",table.common.sum(),
          "improved",table.iloc[:,2:].lt(table.estimate,axis=0).sum().to_dict())


if __name__=="__main__":
    main()
