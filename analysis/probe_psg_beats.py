"""用已发生的光电脉搏过零点提取逐搏间期，在固定偏移及相同有效秒上消融。"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.signal import butter, sosfilt
from sklearn.model_selection import GroupKFold
from sklearn.ensemble import HistGradientBoostingRegressor
from threadpoolctl import threadpool_limits

from train_pr_causal import FEATURES, REPLAY_DIR
from probe_psg_multichannel import INPUT_ROOT, CHANNELS, FS


def beat_features(signal, ends):
    cross = np.flatnonzero((signal[:-1]<=0)&(signal[1:]>0))
    output = np.full((len(ends),10), np.nan)
    if len(cross)<6:
        return output
    beat = cross - signal[cross]/(signal[cross+1]-signal[cross])
    rate = 60*FS/np.diff(beat)
    rate[(rate<35)|(rate>220)] = np.nan
    # Latest completed intervals at four causal instants. Repeated invalid
    # intervals and long gaps remain missing rather than carrying old rates.
    for column, delay in enumerate((0,2,4,6)):
        now = ends-delay*FS
        j = np.searchsorted(beat[1:],now,side='right')-1
        safe = np.clip(j,0,len(rate)-1)
        valid = (j>=0)&((now-beat[safe+1])<=1.75*FS)
        output[valid,column] = rate[safe[valid]]
    j=np.searchsorted(beat[1:],ends,side='right')-1
    for k in range(1,4):
        safe=np.clip(j-k,0,len(rate)-1)
        valid=(j>=k)&(ends-beat[safe+1]<6*FS)
        output[valid,3+k]=rate[safe[valid]]
    safe=np.clip(j,0,len(rate)-1)
    output[j>=0,7]=np.minimum((ends-beat[safe[j>=0]+1])/FS,10)
    # One-second duration-weighted mean of completed intervals, with quality
    # coverage. The target bin ends 4 s before the current optical sample.
    stop=ends-4*FS; start=stop-FS
    valid_rate=np.nan_to_num(rate)
    def integral(t, v):
        summed=np.r_[0,np.cumsum(v*np.diff(beat))]
        tt=np.clip(t,beat[0],beat[-1])
        k=np.clip(np.searchsorted(beat,tt,side='right')-1,0,len(v)-1)
        return summed[k]+(tt-beat[k])*v[k]
    # Any interval longer than 4 seconds has invalid rate and weight zero;
    # a currently uncompleted interval can never contribute.
    coverage=(integral(stop,np.isfinite(rate))-integral(start,np.isfinite(rate)))
    weighted=integral(stop,valid_rate)-integral(start,valid_rate)
    output[:,8]=np.divide(weighted,coverage,out=np.full(len(ends),np.nan),where=coverage>.5*FS)
    output[:,9]=coverage/FS
    return output


def collect(path):
    data=pd.read_pickle(path).copy(); sid='subject_'+path.stem.split('_')[1]
    keys=list(CHANNELS.values())+['ppg_sample_time_unix_s','ppg_segment_id','ppg_movement']
    raw=loadmat(INPUT_ROOT/sid/(sid+'_inputs.mat'),squeeze_me=True,variable_names=keys)
    times=raw['ppg_sample_time_unix_s'];seg=raw['ppg_segment_id'];target=data.time.to_numpy()
    valid=np.isfinite(times)&np.isfinite(seg)&np.isfinite(raw['ppg_movement'])
    for key in CHANNELS.values():
        valid &= np.isfinite(raw[key])
    continuity=(np.diff(seg)==0)&(np.diff(times)>0)&(np.diff(times)<=2)
    starts=np.flatnonzero(valid&np.r_[True,~(valid[:-1]&continuity)])
    stops=np.flatnonzero(valid&np.r_[~(valid[1:]&continuity),True])+1
    sos=butter(3,[.5,4],btype='bandpass',fs=FS,output='sos')
    for ch,key in CHANNELS.items():
        features=np.full((len(target),10),np.nan)
        for a,b in zip(starts,stops):
            rows=np.flatnonzero((target>=times[a])&(target<=times[b-1]))
            if len(rows)==0:
                continue
            values=raw[key][a:b].astype(float)
            signal=sosfilt(sos,values-values[0])
            ends=np.searchsorted(times[a:b],target[rows],side='right')-1
            features[rows]=beat_features(signal,ends)
        for k in range(10):
            data[f'{ch}_beat{k}']=features[:,k] if k in (7,9) else features[:,k]-data.pr
    return data.assign(id=path.stem)


def main():
    data=pd.concat([collect(path) for path in sorted(REPLAY_DIR.glob('psg_*.pkl'))],ignore_index=True)
    methods={'base':FEATURES,'green_beat':FEATURES+[f'g_beat{k}' for k in range(10)],
             'three_beat':FEATURES+[f'{c}_beat{k}' for c in CHANNELS for k in range(10)]}
    for name,features in methods.items():
        predictions=np.full(len(data),np.nan)
        for tr,te in GroupKFold(5).split(data,groups=data.id):
            train=data.iloc[tr[::5]];weights=1/train.id.map(train.id.value_counts()).to_numpy()
            model=HistGradientBoostingRegressor(max_iter=100,max_leaf_nodes=15,min_samples_leaf=100,
                        learning_rate=.08,l2_regularization=10,early_stopping=False,random_state=1)
            with threadpool_limits(limits=2):
                model.fit(train[features],train.reference-train.pr,sample_weight=weights/weights.mean())
                predictions[te]=model.predict(data.iloc[te][features])+data.iloc[te].pr
        data[name]=np.clip(np.floor(predictions+.5),30,220)-data.reference
    se=data[list(methods)].pow(2)
    score=np.sqrt(se.groupby(data.id).mean())
    print(score.round(3).to_string())
    print('mean',score.mean().to_dict(),'pooled',np.sqrt(se.mean()).to_dict(),'n',len(data))
    print('wins',score.lt(score.base,axis=0).sum().to_dict())
    score.to_csv(Path(__file__).with_name('psg_beat_probe_results.csv'))


if __name__=='__main__':
    main()
