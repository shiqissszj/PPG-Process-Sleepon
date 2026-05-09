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
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include "sum.h"

/* Function Declarations */
static int
c_align_target_to_reference_sha(const emxArray_real32_T *referenceSignal,
                                const emxArray_real32_T *targetSignal,
                                emxArray_real32_T *alignedTarget);

/* Function Definitions */
static int
c_align_target_to_reference_sha(const emxArray_real32_T *referenceSignal,
                                const emxArray_real32_T *targetSignal,
                                emxArray_real32_T *alignedTarget)
{
  emxArray_real32_T *b_targetSignal;
  const float *referenceSignal_data;
  const float *targetSignal_data;
  float maxCorr;
  float *alignedTarget_data;
  float *b_targetSignal_data;
  int delay;
  int i;
  int lag;
  int loop_ub;
  targetSignal_data = targetSignal->data;
  referenceSignal_data = referenceSignal->data;
  loop_ub = alignedTarget->size[0];
  alignedTarget->size[0] = 150;
  emxEnsureCapacity_real32_T(alignedTarget, loop_ub);
  alignedTarget_data = alignedTarget->data;
  /*  initialization */
  /*  len = length(inputSig1);  */
  maxCorr = rtMinusInfF;
  delay = 0;
  /*  calculate the corr for each possible delay */
  emxInit_real32_T(&alignedTarget);
  emxInit_real32_T(&b_targetSignal);
  for (lag = 0; lag < 21; lag++) {
    float tempCorr;
    if (lag - 10 < 0) {
      loop_ub = b_targetSignal->size[0];
      b_targetSignal->size[0] = lag + 140;
      emxEnsureCapacity_real32_T(b_targetSignal, loop_ub);
      b_targetSignal_data = b_targetSignal->data;
      for (i = 0; i <= lag + 139; i++) {
        b_targetSignal_data[i] =
            targetSignal_data[i] * referenceSignal_data[(i - lag) + 10];
      }
      tempCorr = sum(b_targetSignal);
    } else {
      loop_ub = alignedTarget->size[0];
      alignedTarget->size[0] = 160 - lag;
      emxEnsureCapacity_real32_T(alignedTarget, loop_ub);
      b_targetSignal_data = alignedTarget->data;
      loop_ub = -lag;
      for (i = 0; i <= loop_ub + 159; i++) {
        b_targetSignal_data[i] =
            targetSignal_data[(lag + i) - 10] * referenceSignal_data[i];
      }
      tempCorr = sum(alignedTarget);
    }
    /*  update the maxCorr and delay */
    if (tempCorr > maxCorr) {
      maxCorr = tempCorr;
      delay = lag - 10;
    }
  }
  emxFree_real32_T(&b_targetSignal);
  emxFree_real32_T(&alignedTarget);
  /*  normalized the corr (optional) */
  /*  normFactor = sqrt(sum(inputSig1.^2) * sum(inputSig2.^2)); */
  /*  maxCorr = maxCorr / normFactor; */
  for (i = 0; i < 150; i++) {
    alignedTarget_data[i] = 0.0F;
  }
  if (-delay == 0) {
    for (i = 0; i < 150; i++) {
      alignedTarget_data[i] = targetSignal_data[i];
    }
  } else if (-delay > 0) {
    for (i = 0; i <= delay + 149; i++) {
      alignedTarget_data[i - delay] = targetSignal_data[i];
    }
  } else {
    loop_ub = -delay;
    for (i = 0; i <= loop_ub + 149; i++) {
      alignedTarget_data[i] = targetSignal_data[delay + i];
    }
  }
  return delay;
}

double preprocess_ppg_window_shared(
    const emxArray_real32_T *b_windowR, const emxArray_real32_T *b_windowIR,
    const emxArray_real32_T *b_windowG, emxArray_real_T *dcR,
    emxArray_real_T *dcIR, emxArray_real_T *dcG, emxArray_real32_T *acGRaw,
    emxArray_real32_T *acR, emxArray_real32_T *acIR, emxArray_real32_T *acG,
    emxArray_real32_T *ppgFilteredR, emxArray_real32_T *ppgFilteredIR,
    emxArray_real32_T *ppgFilteredG, emxArray_real32_T *ppgNormalizedG,
    int *delayR, int *delayIR)
{
  emxArray_real32_T *ppgFilteredIRRaw;
  emxArray_real32_T *ppgFilteredRRaw;
  double outlierNumG;
  const float *windowG_data;
  const float *windowIR_data;
  const float *windowR_data;
  float *acGRaw_data;
  float *acG_data;
  float *acIR_data;
  float *acR_data;
  float *ppgFilteredG_data;
  float *ppgFilteredIRRaw_data;
  float *ppgFilteredRRaw_data;
  int b_delayIR;
  int b_delayR;
  int i;
  windowG_data = b_windowG->data;
  windowIR_data = b_windowIR->data;
  windowR_data = b_windowR->data;
  emxInit_real32_T(&ppgFilteredIRRaw);
  b_delayR = ppgFilteredIRRaw->size[0];
  ppgFilteredIRRaw->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredIRRaw, b_delayR);
  ppgFilteredIRRaw_data = ppgFilteredIRRaw->data;
  emxInit_real32_T(&ppgFilteredRRaw);
  b_delayR = ppgFilteredRRaw->size[0];
  ppgFilteredRRaw->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredRRaw, b_delayR);
  ppgFilteredRRaw_data = ppgFilteredRRaw->data;
  b_delayR = ppgNormalizedG->size[0];
  ppgNormalizedG->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgNormalizedG, b_delayR);
  b_delayR = ppgFilteredG->size[0];
  ppgFilteredG->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredG, b_delayR);
  ppgFilteredG_data = ppgFilteredG->data;
  b_delayR = ppgFilteredIR->size[0];
  ppgFilteredIR->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredIR, b_delayR);
  b_delayR = ppgFilteredR->size[0];
  ppgFilteredR->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredR, b_delayR);
  b_delayR = acG->size[0];
  acG->size[0] = 150;
  emxEnsureCapacity_real32_T(acG, b_delayR);
  acG_data = acG->data;
  b_delayR = acIR->size[0];
  acIR->size[0] = 150;
  emxEnsureCapacity_real32_T(acIR, b_delayR);
  acIR_data = acIR->data;
  b_delayR = acR->size[0];
  acR->size[0] = 150;
  emxEnsureCapacity_real32_T(acR, b_delayR);
  acR_data = acR->data;
  b_delayR = acGRaw->size[0];
  acGRaw->size[0] = 150;
  emxEnsureCapacity_real32_T(acGRaw, b_delayR);
  acGRaw_data = acGRaw->data;
  b_delayR = dcG->size[0];
  dcG->size[0] = 150;
  emxEnsureCapacity_real_T(dcG, b_delayR);
  b_delayR = dcIR->size[0];
  dcIR->size[0] = 150;
  emxEnsureCapacity_real_T(dcIR, b_delayR);
  b_delayR = dcR->size[0];
  dcR->size[0] = 150;
  emxEnsureCapacity_real_T(dcR, b_delayR);
  for (i = 0; i < 150; i++) {
    acR_data[i] = windowR_data[i];
    acIR_data[i] = windowIR_data[i];
    acGRaw_data[i] = windowG_data[i];
  }
  dc_ac_spliter(acR, dcR);
  acR_data = acR->data;
  dc_ac_spliter(acIR, dcIR);
  acIR_data = acIR->data;
  dc_ac_spliter(acGRaw, dcG);
  acGRaw_data = acGRaw->data;
  for (i = 0; i < 150; i++) {
    ppgFilteredRRaw_data[i] = acR_data[i];
  }
  ac_filter(ppgFilteredRRaw);
  for (i = 0; i < 150; i++) {
    ppgFilteredIRRaw_data[i] = acIR_data[i];
  }
  ac_filter(ppgFilteredIRRaw);
  for (i = 0; i < 150; i++) {
    ppgFilteredG_data[i] = acGRaw_data[i];
  }
  outlierNumG = ac_filter(ppgFilteredG);
  b_delayR = c_align_target_to_reference_sha(ppgFilteredG, ppgFilteredRRaw,
                                             ppgFilteredR);
  emxFree_real32_T(&ppgFilteredRRaw);
  b_delayIR = c_align_target_to_reference_sha(ppgFilteredG, ppgFilteredIRRaw,
                                              ppgFilteredIR);
  emxFree_real32_T(&ppgFilteredIRRaw);
  /*  Preserve the raw aligned AC channels for the legacy PR path. */
  for (i = 0; i < 150; i++) {
    acG_data[i] = acGRaw_data[i];
  }
  align_signals(acG, acR);
  align_signals(acG, acIR);
  ac_normalize(ppgFilteredG, ppgNormalizedG);
  *delayR = b_delayR;
  *delayIR = b_delayIR;
  return outlierNumG;
}

/* End of code generation (preprocess_ppg_window_shared.c) */
