/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * preprocess_ppg_window_shared.c
 *
 * Code generation for function 'preprocess_ppg_window_shared'
 *
 */

/* Include files */
#include "preprocess_ppg_window_shared.h"
#include "ac_filter.h"
#include "ac_normalize.h"
#include "align_signals.h"
#include "dc_ac_spliter.h"
#include "rt_nonfinite.h"
#include "sum.h"
#include <string.h>

/* Function Declarations */
static int c_align_target_to_reference_sha(const float referenceSignal[150],
                                           const float targetSignal[150],
                                           float alignedTarget[150]);

/* Function Definitions */
static int c_align_target_to_reference_sha(const float referenceSignal[150],
                                           const float targetSignal[150],
                                           float alignedTarget[150])
{
  float maxCorr;
  int delay;
  int i;
  int lag;
  int loop_ub;
  /*  initialization */
  /*  len = length(inputSig1);  */
  maxCorr = rtMinusInfF;
  delay = 0;
  /*  calculate the corr for each possible delay */
  for (lag = 0; lag < 21; lag++) {
    float tempCorr;
    if (lag - 10 < 0) {
      float b_targetSignal_data[149];
      for (i = 0; i <= lag + 139; i++) {
        b_targetSignal_data[i] =
            targetSignal[i] * referenceSignal[(i - lag) + 10];
      }
      tempCorr = sum(b_targetSignal_data, lag + 140);
    } else {
      float targetSignal_data[150];
      loop_ub = -lag;
      for (i = 0; i <= loop_ub + 159; i++) {
        targetSignal_data[i] =
            targetSignal[(lag + i) - 10] * referenceSignal[i];
      }
      tempCorr = sum(targetSignal_data, 160 - lag);
    }
    /*  update the maxCorr and delay */
    if (tempCorr > maxCorr) {
      maxCorr = tempCorr;
      delay = lag - 10;
    }
  }
  /*  normalized the corr (optional) */
  /*  normFactor = sqrt(sum(inputSig1.^2) * sum(inputSig2.^2)); */
  /*  maxCorr = maxCorr / normFactor; */
  memset(&alignedTarget[0], 0, 150U * sizeof(float));
  if (-delay == 0) {
    memcpy(&alignedTarget[0], &targetSignal[0], 150U * sizeof(float));
  } else if (-delay > 0) {
    for (i = 0; i <= delay + 149; i++) {
      alignedTarget[i - delay] = targetSignal[i];
    }
  } else {
    loop_ub = -delay;
    for (i = 0; i <= loop_ub + 149; i++) {
      alignedTarget[i] = targetSignal[delay + i];
    }
  }
  return delay;
}

double preprocess_ppg_window_shared(
    const float b_windowR[150], const float b_windowIR[150],
    const float b_windowG[150], double dcR[150], double dcIR[150],
    double dcG[150], float acGRaw[150], float acR[150], float acIR[150],
    float acG[150], float ppgFilteredR[150], float ppgFilteredIR[150],
    float ppgFilteredG[150], float ppgNormalizedG[150], int *delayR,
    int *delayIR)
{
  double outlierNumG;
  float ppgFilteredIRRaw[150];
  float ppgFilteredRRaw[150];
  memcpy(&acR[0], &b_windowR[0], 150U * sizeof(float));
  memcpy(&acIR[0], &b_windowIR[0], 150U * sizeof(float));
  memcpy(&acGRaw[0], &b_windowG[0], 150U * sizeof(float));
  dc_ac_spliter(acR, dcR);
  dc_ac_spliter(acIR, dcIR);
  dc_ac_spliter(acGRaw, dcG);
  /*  Preserve the raw aligned AC channels for the legacy PR path. */
  memcpy(&ppgFilteredRRaw[0], &acR[0], 150U * sizeof(float));
  memcpy(&ppgFilteredIRRaw[0], &acIR[0], 150U * sizeof(float));
  memcpy(&ppgFilteredG[0], &acGRaw[0], 150U * sizeof(float));
  memcpy(&acG[0], &acGRaw[0], 150U * sizeof(float));
  ac_filter(ppgFilteredRRaw);
  ac_filter(ppgFilteredIRRaw);
  outlierNumG = ac_filter(ppgFilteredG);
  *delayR = c_align_target_to_reference_sha(ppgFilteredG, ppgFilteredRRaw,
                                            ppgFilteredR);
  *delayIR = c_align_target_to_reference_sha(ppgFilteredG, ppgFilteredIRRaw,
                                             ppgFilteredIR);
  align_signals(acG, acR);
  align_signals(acG, acIR);
  ac_normalize(ppgFilteredG, ppgNormalizedG);
  return outlierNumG;
}

/* End of code generation (preprocess_ppg_window_shared.c) */
