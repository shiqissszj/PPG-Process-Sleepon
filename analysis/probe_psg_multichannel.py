"""在现有 PSG 共同评价秒上，对比原后处理、增加绿光频谱、增加三色频谱。"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.fft import rfft
from scipy.io import loadmat
from scipy.signal import butter, sosfilt
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.model_selection import GroupKFold
from threadpoolctl import threadpool_limits

from train_pr_causal import FEATURES, REPLAY_DIR

INPUT_ROOT = Path("/Volumes/NewSSS/邵逸夫医院睡眠监测数据/PPG-PSG/Pulse_from_ECG_derived/python_inputs")
CHANNELS = {"g": "ppg_green_raw", "r": "ppg_red_raw", "ir": "ppg_ir_raw"}
WINDOWS = (6, 12)
FS = 50
NFFT = 1024
RESULT_PATH = Path(__file__).with_name("psg_multichannel_probe_results.csv")


def spectral_evidence(signal, ends, seconds):
    """Trailing window. Return strongest in-band frequency, power concentration, and peak dominance."""
    size = seconds * FS
    bins = np.arange(int(np.ceil(35*NFFT/(60*FS))), int(np.floor(220*NFFT/(60*FS)))+1)
    results = np.full((len(ends), 3), np.nan)
    window = np.hanning(size).astype(np.float32)
    offsets = np.arange(1-size, 1)
    for start in range(0, len(ends), 512):
        indexes = np.arange(start, min(start+512, len(ends)))
        indexes = indexes[ends[indexes] >= size-1]
        block = signal[ends[indexes, None] + offsets]
        if not len(block):
            continue
        spectrum = abs(rfft((block-block.mean(axis=1, keepdims=True))*window, n=NFFT))**2
        power = spectrum[:, bins]
        peak = np.argmax(power, axis=1)
        row = np.arange(len(peak))
        k = bins[peak]
        log_power = np.log(np.maximum(spectrum, 1e-20))
        left, center, right = (log_power[row, k+d] for d in (-1, 0, 1))
        denom = left-2*center+right
        delta = np.divide(.5*(left-right),denom,out=np.zeros_like(center),where=denom < -1e-8)
        bpm = (k+np.clip(delta,-.5,.5))*60*FS/NFFT
        near = np.abs(bins[None,:]-k[:,None]) * (60*FS/NFFT) <= 10
        total = power.sum(axis=1)
        top = power[row, peak]
        concentration = (power*near).sum(axis=1)/np.maximum(total, 1e-20)
        rival = np.where(near, 0, power).max(axis=1)
        values = np.column_stack([bpm, concentration, 1-rival/np.maximum(top,1e-20)])
        values[total <= 1e-16] = np.nan
        results[indexes] = values
    return results


def collect(path):
    data = pd.read_pickle(path).copy()
    subject = 'subject_' + path.stem.split('_')[1]
    keys = list(CHANNELS.values()) + ['ppg_segment_id','ppg_movement','ppg_sample_time_unix_s']
    raw = loadmat(INPUT_ROOT / subject / (subject+'_inputs.mat'), variable_names=keys,squeeze_me=True)
    time = raw['ppg_sample_time_unix_s']
    seg = raw['ppg_segment_id']
    valid = np.isfinite(time) & np.isfinite(raw['ppg_movement']) & np.isfinite(seg)
    for key in CHANNELS.values():
        valid &= np.isfinite(raw[key])
    contiguous = (np.diff(seg)==0) & (np.diff(time)>0) & (np.diff(time)<=2)
    starts = np.flatnonzero(valid & np.r_[True,~(valid[:-1]&contiguous)])
    stops = np.flatnonzero(valid & np.r_[~(valid[1:]&contiguous),True])+1
    sos = butter(3,[.5,4],btype='bandpass',fs=FS,output='sos')
    target = data.time.to_numpy()
    for channel, key in CHANNELS.items():
        arrays = {sec:np.full((len(data),3), np.nan) for sec in WINDOWS}
        for a,b in zip(starts,stops):
            if b-a < FS*min(WINDOWS):
                continue
            rows = np.flatnonzero((target>=time[a]) & (target<=time[b-1]))
            if not len(rows):
                continue
            values = raw[key][a:b].astype(float)
            filtered = sosfilt(sos,values-values[0]).astype(np.float32)
            ends = np.searchsorted(time[a:b],target[rows],side='right')-1
            for sec in WINDOWS:
                arrays[sec][rows] = spectral_evidence(filtered,ends,sec)
        for sec, arr in arrays.items():
            prefix=f'{channel}{sec}'
            data[prefix+'_diff']=arr[:,0]-data.pr
            data[prefix+'_conc']=arr[:,1]
            data[prefix+'_domin']=arr[:,2]
    data['id']=path.stem
    return data


def main():
    frames=[]
    for path in sorted(REPLAY_DIR.glob('psg_*.pkl')):
        frames.append(collect(path))
        print(path.stem, 'complete',flush=True)
    data=pd.concat(frames,ignore_index=True)
    extras = {ch:[f'{ch}{win}_{stat}' for win in WINDOWS for stat in ('diff','conc','domin')]
              for ch in CHANNELS}
    sets={'base':FEATURES,'green':FEATURES+extras['g'],
          'three':FEATURES+extras['g']+extras['r']+extras['ir']}
    split=list(GroupKFold(5).split(data,groups=data.id))
    for name,cols in sets.items():
        pred=np.empty(len(data))
        for tr,te in split:
            train=data.iloc[tr[::5]]
            weights=1/train.id.map(train.id.value_counts()).to_numpy()
            model=HistGradientBoostingRegressor(max_iter=100,max_leaf_nodes=15,min_samples_leaf=100,
                learning_rate=.08,l2_regularization=10,early_stopping=False,random_state=1)
            with threadpool_limits(limits=2):
                model.fit(train[cols],train.reference-train.pr,sample_weight=weights/weights.mean())
                pred[te]=model.predict(data.iloc[te][cols])+data.iloc[te].pr
        data[name+'_error']=np.clip(np.floor(pred+.5),30,220)-data.reference
    errors=[name+'_error' for name in sets]
    se=data[errors].pow(2)
    score=np.sqrt(se.groupby(data.id).mean())
    score.columns=list(sets)
    print('per night',score.round(3).to_string(),flush=True)
    print('macro',score.mean().to_dict(),'pooled',np.sqrt(se.mean()).to_dict(),
          'wins',score.lt(score.base,axis=0).sum().to_dict())
    prior=pd.read_csv(Path(__file__).with_name('pr_causal_results.csv')).set_index('No')
    np.testing.assert_allclose(score.base,prior.loc[score.index,'rmse'],atol=1e-6)
    bad=data.base_error.abs()>=10
    cover={ch:np.column_stack([abs(data[f'{ch}{win}_diff']+data.pr-data.reference)<=3
                               for win in WINDOWS]).any(axis=1) for ch in CHANNELS}
    any_channel=cover['g']|cover['r']|cover['ir']
    print('coverage: rows, baseline tail, green, any, added',
          len(data),bad.sum(),cover['g'][bad].mean(),any_channel[bad].mean(),
          (any_channel&~cover['g'])[bad].mean())
    print('tail fractions', (data[errors].abs()>=10).mean().to_dict())
    score.to_csv(RESULT_PATH,index_label='No')


if __name__=='__main__':
    main()
