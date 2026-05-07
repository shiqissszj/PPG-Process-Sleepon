/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * r_pr_calculation.c
 *
 * Code generation for function 'r_pr_calculation'
 *
 */

/* Include files */
#include "r_pr_calculation.h"
#include "a_corr.h"
#include "ac_filter.h"
#include "ac_normalize.h"
#include "find_peaks.h"
#include "mean.h"
#include "minOrMax.h"
#include "mod.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "preprocess_ppg_window_shared.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"
#include <math.h>
#include <string.h>

/* Variable Definitions */
static bool previousConfidenceG_not_empty;

static emxArray_real32_T *previousPRG;

static bool previousPRG_not_empty;

static bool previousPRGValidCount_not_empty;

static emxArray_real32_T *expandedGreenInputBuffer;

static bool c_expandedGreenInputBuffer_not_;

static bool trackedPR_not_empty;

static bool trackedConfidence_not_empty;

/* Function Declarations */
static float estimate_tail_tracked_pr(const float peakLocs_data[],
                                      int peakLocs_size,
                                      double validHistoryCount,
                                      float trackedPR);

/* Function Definitions */
static float estimate_tail_tracked_pr(const float peakLocs_data[],
                                      int peakLocs_size,
                                      double validHistoryCount, float trackedPR)
{
  float intervalBuffer[49];
  float robustBuffer[49];
  float sortedRobustIntervals_data[49];
  float trackedBuffer[49];
  float f;
  float outputPR;
  int idx;
  int insertIdx;
  int robustCount;
  int tailIntervalCount;
  bool exitg1;
  memset(&trackedBuffer[0], 0, 49U * sizeof(float));
  memset(&intervalBuffer[0], 0, 49U * sizeof(float));
  tailIntervalCount = 0;
  for (idx = 0; idx <= peakLocs_size - 2; idx++) {
    outputPR = peakLocs_data[idx + 1];
    if (outputPR >= (float)validHistoryCount + 1.0F) {
      tailIntervalCount++;
      intervalBuffer[tailIntervalCount - 1] = outputPR - peakLocs_data[idx];
    }
  }
  if (tailIntervalCount == 0) {
    for (idx = 0; idx <= peakLocs_size - 2; idx++) {
      intervalBuffer[idx] = peakLocs_data[idx + 1] - peakLocs_data[idx];
    }
    tailIntervalCount = peakLocs_size - 1;
  }
  if (tailIntervalCount > 4) {
    intervalBuffer[0] = intervalBuffer[tailIntervalCount - 4];
    intervalBuffer[1] = intervalBuffer[tailIntervalCount - 3];
    intervalBuffer[2] = intervalBuffer[tailIntervalCount - 2];
    intervalBuffer[3] = intervalBuffer[tailIntervalCount - 1];
    tailIntervalCount = 4;
  }
  if (tailIntervalCount - 1 >= 0) {
    memcpy(&sortedRobustIntervals_data[0], &intervalBuffer[0],
           (unsigned int)tailIntervalCount * sizeof(float));
  }
  for (idx = 0; idx <= tailIntervalCount - 2; idx++) {
    outputPR = sortedRobustIntervals_data[idx + 1];
    insertIdx = idx + 1;
    exitg1 = false;
    while ((!exitg1) && (insertIdx >= 1)) {
      f = sortedRobustIntervals_data[insertIdx - 1];
      if (f > outputPR) {
        sortedRobustIntervals_data[insertIdx] = f;
        insertIdx--;
      } else {
        exitg1 = true;
      }
    }
    sortedRobustIntervals_data[insertIdx] = outputPR;
  }
  insertIdx = (int)floor(((double)tailIntervalCount + 1.0) / 2.0);
  if (b_mod(tailIntervalCount) == 1.0) {
    outputPR = sortedRobustIntervals_data[insertIdx - 1];
  } else {
    outputPR = (sortedRobustIntervals_data[insertIdx - 1] +
                sortedRobustIntervals_data[insertIdx]) *
               0.5F;
  }
  memset(&robustBuffer[0], 0, 49U * sizeof(float));
  robustCount = 0;
  for (idx = 0; idx < tailIntervalCount; idx++) {
    f = intervalBuffer[idx];
    if ((f >= outputPR * 0.75F) && (f <= outputPR * 1.25F)) {
      robustCount++;
      robustBuffer[robustCount - 1] = f;
    }
  }
  if (robustCount == 0) {
    memcpy(&robustBuffer[0], &intervalBuffer[0],
           (unsigned int)tailIntervalCount * sizeof(float));
    robustCount = tailIntervalCount;
  }
  if (trackedPR > 0.0F) {
    outputPR = 3000.0F / trackedPR;
    insertIdx = 0;
    for (idx = 0; idx < robustCount; idx++) {
      f = robustBuffer[idx];
      if ((f >= outputPR * 0.8F) && (f <= outputPR * 1.2F)) {
        insertIdx++;
        trackedBuffer[insertIdx - 1] = f;
      }
    }
    if (insertIdx > 0) {
      memcpy(&robustBuffer[0], &trackedBuffer[0],
             (unsigned int)insertIdx * sizeof(float));
      robustCount = insertIdx;
    }
  }
  if (robustCount - 1 >= 0) {
    memcpy(&sortedRobustIntervals_data[0], &robustBuffer[0],
           (unsigned int)robustCount * sizeof(float));
  }
  for (idx = 0; idx <= robustCount - 2; idx++) {
    outputPR = sortedRobustIntervals_data[idx + 1];
    insertIdx = idx + 1;
    exitg1 = false;
    while ((!exitg1) && (insertIdx >= 1)) {
      f = sortedRobustIntervals_data[insertIdx - 1];
      if (f > outputPR) {
        sortedRobustIntervals_data[insertIdx] = f;
        insertIdx--;
      } else {
        exitg1 = true;
      }
    }
    sortedRobustIntervals_data[insertIdx] = outputPR;
  }
  insertIdx = (int)floor(((double)robustCount + 1.0) / 2.0);
  if (b_mod(robustCount) == 1.0) {
    outputPR = sortedRobustIntervals_data[insertIdx - 1];
  } else {
    outputPR = (sortedRobustIntervals_data[insertIdx - 1] +
                sortedRobustIntervals_data[insertIdx]) *
               0.5F;
  }
  if (rtIsInfF(outputPR) || rtIsNaNF(outputPR) || (outputPR <= 0.0F)) {
    outputPR = -1.0F;
  } else {
    outputPR = 3000.0F / outputPR;
  }
  return outputPR;
}

float r_pr_calculation(const emxArray_real32_T *b_windowR,
                       const emxArray_real32_T *b_windowIR,
                       const emxArray_real32_T *b_windowG,
                       unsigned int b_outputCounter, float bodyMove,
                       float *outputPR, float outputSQI[6],
                       float *outputConfidenceR, float *outputConfidenceG)
{
  static float previousConfidenceG;
  static float trackedConfidence;
  static float trackedPR;
  static unsigned int previousPRGValidCount;
  emxArray_real32_T *a__2;
  emxArray_real32_T *acG;
  emxArray_real32_T *acGRaw;
  emxArray_real32_T *acIR;
  emxArray_real32_T *acR;
  emxArray_real32_T *ppgExpandedG;
  emxArray_real32_T *ppgFilteredG;
  emxArray_real32_T *ppgFilteredIR;
  emxArray_real32_T *ppgFilteredR;
  emxArray_real32_T *ppgNormalizedG;
  emxArray_real_T *a__1;
  emxArray_real_T *corrValuesR;
  emxArray_real_T *dcIR;
  emxArray_real_T *dcR;
  double D2;
  double N2;
  double guardD2_tmp;
  double outlierNumG;
  double *corrValuesR_data;
  float a__4_data[50];
  float peakLocG0_data[50];
  float D1;
  float N1;
  float PR;
  float b_y_tmp;
  float confidence;
  float outputR;
  float usedSampleRatio;
  float xcorrR_G;
  float xcorrR_IR;
  float y_tmp;
  float *a__2_data;
  float *acGRaw_data;
  float *expandedGreenInputBuffer_data;
  float *ppgExpandedG_data;
  float *ppgFilteredG_data;
  float *ppgFilteredIR_data;
  float *ppgFilteredR_data;
  float *previousPRG_data;
  int b_x;
  int i;
  int jumpLimit;
  int loop_ub;
  unsigned int qY;
  unsigned int validHistoryCount;
  int x;
  bool isValid;
  expandedGreenInputBuffer_data = expandedGreenInputBuffer->data;
  previousPRG_data = previousPRG->data;
  emxInit_real32_T(&ppgFilteredG);
  jumpLimit = ppgFilteredG->size[0];
  ppgFilteredG->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredG, jumpLimit);
  emxInit_real32_T(&ppgFilteredIR);
  jumpLimit = ppgFilteredIR->size[0];
  ppgFilteredIR->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredIR, jumpLimit);
  emxInit_real32_T(&ppgFilteredR);
  jumpLimit = ppgFilteredR->size[0];
  ppgFilteredR->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredR, jumpLimit);
  emxInit_real32_T(&acG);
  jumpLimit = acG->size[0];
  acG->size[0] = 150;
  emxEnsureCapacity_real32_T(acG, jumpLimit);
  emxInit_real32_T(&acIR);
  jumpLimit = acIR->size[0];
  acIR->size[0] = 150;
  emxEnsureCapacity_real32_T(acIR, jumpLimit);
  emxInit_real32_T(&acR);
  jumpLimit = acR->size[0];
  acR->size[0] = 150;
  emxEnsureCapacity_real32_T(acR, jumpLimit);
  emxInit_real32_T(&acGRaw);
  jumpLimit = acGRaw->size[0];
  acGRaw->size[0] = 150;
  emxEnsureCapacity_real32_T(acGRaw, jumpLimit);
  emxInit_real_T(&dcIR);
  jumpLimit = dcIR->size[0];
  dcIR->size[0] = 150;
  emxEnsureCapacity_real_T(dcIR, jumpLimit);
  emxInit_real_T(&dcR);
  jumpLimit = dcR->size[0];
  dcR->size[0] = 150;
  emxEnsureCapacity_real_T(dcR, jumpLimit);
  emxInit_real32_T(&a__2);
  jumpLimit = a__2->size[0];
  a__2->size[0] = 150;
  emxEnsureCapacity_real32_T(a__2, jumpLimit);
  emxInit_real_T(&a__1);
  jumpLimit = a__1->size[0];
  a__1->size[0] = 150;
  emxEnsureCapacity_real_T(a__1, jumpLimit);
  /*  Parameters for period identification */
  confidence = 1.0F;
  if (b_outputCounter == 1U) {
    /*  initialize */
    previousConfidenceG = 0.6F;
    previousConfidenceG_not_empty = true;
    jumpLimit = previousPRG->size[0];
    previousPRG->size[0] = 150;
    emxEnsureCapacity_real32_T(previousPRG, jumpLimit);
    previousPRG_data = previousPRG->data;
    for (i = 0; i < 150; i++) {
      previousPRG_data[i] = 0.0F;
    }
    previousPRG_not_empty = true;
    previousPRGValidCount = 0U;
    previousPRGValidCount_not_empty = true;
    jumpLimit = expandedGreenInputBuffer->size[0];
    expandedGreenInputBuffer->size[0] = 300;
    emxEnsureCapacity_real32_T(expandedGreenInputBuffer, jumpLimit);
    expandedGreenInputBuffer_data = expandedGreenInputBuffer->data;
    for (i = 0; i < 300; i++) {
      expandedGreenInputBuffer_data[i] = 0.0F;
    }
    c_expandedGreenInputBuffer_not_ = true;
    trackedPR = -1.0F;
    trackedPR_not_empty = true;
    trackedConfidence = 0.0F;
    trackedConfidence_not_empty = true;
  }
  if (!previousConfidenceG_not_empty) {
    previousConfidenceG = 0.6F;
    previousConfidenceG_not_empty = true;
  }
  if (!previousPRG_not_empty) {
    jumpLimit = previousPRG->size[0];
    previousPRG->size[0] = 150;
    emxEnsureCapacity_real32_T(previousPRG, jumpLimit);
    previousPRG_data = previousPRG->data;
    for (i = 0; i < 150; i++) {
      previousPRG_data[i] = 0.0F;
    }
    previousPRG_not_empty = true;
  }
  if (!previousPRGValidCount_not_empty) {
    previousPRGValidCount = 0U;
    previousPRGValidCount_not_empty = true;
  }
  if (!c_expandedGreenInputBuffer_not_) {
    jumpLimit = expandedGreenInputBuffer->size[0];
    expandedGreenInputBuffer->size[0] = 300;
    emxEnsureCapacity_real32_T(expandedGreenInputBuffer, jumpLimit);
    expandedGreenInputBuffer_data = expandedGreenInputBuffer->data;
    for (i = 0; i < 300; i++) {
      expandedGreenInputBuffer_data[i] = 0.0F;
    }
    c_expandedGreenInputBuffer_not_ = true;
  }
  if (!trackedPR_not_empty) {
    trackedPR = -1.0F;
    trackedPR_not_empty = true;
  }
  if (!trackedConfidence_not_empty) {
    trackedConfidence = 0.0F;
    trackedConfidence_not_empty = true;
  }
  outlierNumG = preprocess_ppg_window_shared(
      b_windowR, b_windowIR, b_windowG, dcR, dcIR, a__1, acGRaw, acR, acIR, acG,
      ppgFilteredR, ppgFilteredIR, ppgFilteredG, a__2, &x, &b_x);
  a__2_data = a__2->data;
  ppgFilteredG_data = ppgFilteredG->data;
  ppgFilteredIR_data = ppgFilteredIR->data;
  ppgFilteredR_data = ppgFilteredR->data;
  acGRaw_data = acGRaw->data;
  emxFree_real_T(&a__1);
  /*  Preserve the legacy PR behavior: peak detection uses an expanded green */
  /*  signal built from a rolling history plus the current aligned AC green. */
  validHistoryCount = previousPRGValidCount;
  if (previousPRGValidCount > 0U) {
    jumpLimit = (int)previousPRGValidCount;
    for (i = 0; i < jumpLimit; i++) {
      expandedGreenInputBuffer_data[i] =
          previousPRG_data[(i - (int)previousPRGValidCount) + 150];
    }
  }
  for (i = 0; i < 150; i++) {
    expandedGreenInputBuffer_data[(int)previousPRGValidCount + i] =
        acGRaw_data[i];
  }
  loop_ub = (int)previousPRGValidCount;
  emxInit_real32_T(&ppgExpandedG);
  jumpLimit = ppgExpandedG->size[0];
  ppgExpandedG->size[0] = (int)previousPRGValidCount + 150;
  emxEnsureCapacity_real32_T(ppgExpandedG, jumpLimit);
  ppgExpandedG_data = ppgExpandedG->data;
  for (i = 0; i <= loop_ub + 149; i++) {
    ppgExpandedG_data[i] = expandedGreenInputBuffer_data[i];
  }
  b_ac_filter(ppgExpandedG);
  emxInit_real32_T(&ppgNormalizedG);
  b_ac_normalize(ppgExpandedG, ppgNormalizedG);
  emxFree_real32_T(&ppgExpandedG);
  for (i = 0; i < 100; i++) {
    previousPRG_data[i] = previousPRG_data[i + 50];
  }
  for (i = 0; i < 50; i++) {
    previousPRG_data[i + 100] = acGRaw_data[i];
  }
  qY = previousPRGValidCount + 50U;
  if (previousPRGValidCount + 50U < previousPRGValidCount) {
    qY = MAX_uint32_T;
  }
  if (qY <= 150U) {
    previousPRGValidCount = qY;
  } else {
    previousPRGValidCount = 150U;
  }
  /*  PR calculation */
  find_peaks(ppgNormalizedG, a__4_data, peakLocG0_data, &loop_ub);
  if (loop_ub < 2) {
    confidence = 0.0F;
    PR = -1.0F;
  } else {
    bool guard1;
    usedSampleRatio = 0.0F;
    for (i = 0; i <= loop_ub - 2; i++) {
      usedSampleRatio += peakLocG0_data[i + 1] - peakLocG0_data[i];
    }
    b_find_peaks(ppgNormalizedG,
                 usedSampleRatio / ((float)loop_ub - 1.0F) * 0.8F, a__4_data,
                 peakLocG0_data, &jumpLimit);
    guard1 = false;
    if (jumpLimit < 2) {
      guard1 = true;
    } else {
      PR = estimate_tail_tracked_pr(peakLocG0_data, jumpLimit,
                                    validHistoryCount, trackedPR);
      if (PR < 35.0F) {
        guard1 = true;
      }
    }
    if (guard1) {
      confidence = 0.0F;
      PR = -1.0F;
    }
  }
  emxFree_real32_T(&ppgNormalizedG);
  /*  PI calculaton */
  for (i = 0; i < 150; i++) {
    acGRaw_data[i] = ppgFilteredG_data[i] * ppgFilteredR_data[i];
  }
  N1 = acGRaw_data[0];
  for (i = 0; i < 149; i++) {
    N1 += acGRaw_data[i + 1];
  }
  for (i = 0; i < 150; i++) {
    acGRaw_data[i] = ppgFilteredG_data[i] * ppgFilteredIR_data[i];
  }
  D1 = acGRaw_data[0];
  for (i = 0; i < 149; i++) {
    D1 += acGRaw_data[i + 1];
  }
  N2 = mean(dcIR);
  emxFree_real_T(&dcIR);
  D2 = mean(dcR);
  emxFree_real_T(&dcR);
  for (i = 0; i < 150; i++) {
    a__2_data[i] = fabsf(acGRaw_data[i]);
  }
  guardD2_tmp = fabs(D2);
  if ((!rtIsInfF(N1)) && (!rtIsNaNF(N1)) &&
      ((!rtIsInfF(D1)) && (!rtIsNaNF(D1))) &&
      ((!rtIsInf(N2)) && (!rtIsNaN(N2))) &&
      ((!rtIsInf(D2)) && (!rtIsNaN(D2))) &&
      (fabsf(D1) > 0.001F * b_mean(a__2) + 1.0E-6F) &&
      (guardD2_tmp > 0.001F * (float)guardD2_tmp + 1.0E-6F)) {
    isValid = true;
  } else {
    isValid = false;
  }
  if (!isValid) {
    outputR = rtNaNF;
  } else {
    outputR = N1 * (float)N2 / (D1 * (float)D2);
    isValid = ((!rtIsInfF(outputR)) && (!rtIsNaNF(outputR)));
    if (!isValid) {
      outputR = rtNaNF;
    }
  }
  *outputPR = PR;
  /*  Confidence calculation */
  /*  Comment the following code to disable the signal calculation */
  /*  Obtain SQI for confidence calculation */
  for (i = 0; i < 150; i++) {
    a__2_data[i] = ppgFilteredG_data[i] * ppgFilteredG_data[i];
    acGRaw_data[i] = ppgFilteredR_data[i] * ppgFilteredR_data[i];
  }
  xcorrR_IR = a__2_data[0];
  usedSampleRatio = acGRaw_data[0];
  for (i = 0; i < 149; i++) {
    xcorrR_IR += a__2_data[i + 1];
    usedSampleRatio += acGRaw_data[i + 1];
  }
  y_tmp = sqrtf(xcorrR_IR);
  b_y_tmp = sqrtf(usedSampleRatio);
  xcorrR_G = N1 / (b_y_tmp * y_tmp);
  for (i = 0; i < 150; i++) {
    a__2_data[i] = ppgFilteredIR_data[i] * ppgFilteredIR_data[i];
  }
  xcorrR_IR = a__2_data[0];
  for (i = 0; i < 149; i++) {
    xcorrR_IR += a__2_data[i + 1];
  }
  emxFree_real32_T(&a__2);
  usedSampleRatio = sqrtf(xcorrR_IR);
  N1 = D1 / (usedSampleRatio * y_tmp);
  for (i = 0; i < 150; i++) {
    acGRaw_data[i] = ppgFilteredIR_data[i] * ppgFilteredR_data[i];
  }
  xcorrR_IR = acGRaw_data[0];
  for (i = 0; i < 149; i++) {
    xcorrR_IR += acGRaw_data[i + 1];
  }
  emxFree_real32_T(&acGRaw);
  xcorrR_IR /= usedSampleRatio * b_y_tmp;
  outputSQI[0] = xcorrR_G;
  outputSQI[1] = N1;
  outputSQI[2] = xcorrR_IR;
  outputSQI[3] = 0.0F;
  outputSQI[4] = 0.0F;
  outputSQI[5] = 0.0F;
  if (x <= MIN_int32_T) {
    jumpLimit = MAX_int32_T;
  } else {
    jumpLimit = -x;
  }
  if (b_x <= MIN_int32_T) {
    loop_ub = MAX_int32_T;
  } else {
    loop_ub = -b_x;
  }
  if (x < 0) {
    x = jumpLimit;
  }
  if (b_x < 0) {
    b_x = loop_ub;
  }
  if (x >= b_x) {
    b_x = x;
  }
  usedSampleRatio = fminf(
      fmaxf(((150.0F - (float)outlierNumG) - (float)b_x) / 150.0F, 0.0F), 1.0F);
  /*  Confidence of Green light for the legacy PR path */
  *outputConfidenceG = usedSampleRatio * usedSampleRatio;
  /*  Confidence of Red light / SpO2 path */
  xcorrR_IR =
      ((fmaxf(xcorrR_G, 0.0F) + fmaxf(N1, 0.0F)) + fmaxf(xcorrR_IR, 0.0F)) /
      3.0F;
  usedSampleRatio = fminf(
      fmaxf(0.75F * xcorrR_IR * usedSampleRatio *
                    ((float)(((maximum(ppgFilteredG) - minimum(ppgFilteredG) >
                               1.0E-6F) +
                              (maximum(ppgFilteredR) - minimum(ppgFilteredR) >
                               1.0E-6F)) +
                             (maximum(ppgFilteredIR) - minimum(ppgFilteredIR) >
                              1.0E-6F)) /
                     3.0F) +
                0.25F,
            0.0F),
      1.0F);
  emxFree_real32_T(&ppgFilteredG);
  emxFree_real32_T(&ppgFilteredIR);
  emxFree_real32_T(&ppgFilteredR);
  if ((!isValid) || (outputR <= 0.0F)) {
    confidence = 0.0F;
  }
  if (confidence > 0.0F) {
    confidence = fminf(xcorrR_IR * (0.55F * usedSampleRatio + 0.45F), 1.0F);
  }
  if ((xcorrR_G < 0.25F) || (N1 < 0.25F)) {
    confidence = 0.0F;
  } else if ((bodyMove > 20.0F) && (usedSampleRatio < 0.5F)) {
    confidence *= 0.4F;
  }
  if (PR > 0.0F) {
    N1 = 3000.0F / PR;
    xcorrR_IR = roundf(N1 * 0.9F);
    usedSampleRatio = roundf(N1 * 1.1F);
    emxInit_real_T(&corrValuesR);
    N2 = a_corr(acR, xcorrR_IR, usedSampleRatio, corrValuesR);
    D2 = a_corr(acIR, xcorrR_IR, usedSampleRatio, corrValuesR);
    outlierNumG = a_corr(acG, xcorrR_IR, usedSampleRatio, corrValuesR);
    corrValuesR_data = corrValuesR->data;
    outputSQI[3] = (float)N2;
    outputSQI[4] = (float)D2;
    outputSQI[5] = (float)outlierNumG;
    usedSampleRatio = 1.0F;
    if (outlierNumG < 0.75) {
      usedSampleRatio = fmaxf((float)outlierNumG / 0.75F, 0.2F);
    }
    outlierNumG = corrValuesR_data[(int)fminf(fmaxf(roundf(N1 * 0.1F), 1.0F),
                                              (float)corrValuesR->size[0]) -
                                   1];
    emxFree_real_T(&corrValuesR);
    if (outlierNumG < 0.5) {
      usedSampleRatio *= fmaxf((float)outlierNumG / 0.5F, 0.2F);
    }
    /*  Startup windows are noisier after moving to 3 s. Use a soft penalty */
    /*  instead of hard-zeroing the PR confidence so raw PR can still seed the
     */
    /*  fix and smoothing stages. */
    if (b_outputCounter <= 8U) {
      *outputConfidenceG *= fmaxf(usedSampleRatio, 0.45F);
    } else {
      *outputConfidenceG *= usedSampleRatio;
    }
    if ((N2 < 0.25) || (D2 < 0.25) || (bodyMove > 15.0F)) {
      *outputConfidenceG *= 0.4F;
    }
  }
  emxFree_real32_T(&acG);
  emxFree_real32_T(&acIR);
  emxFree_real32_T(&acR);
  *outputConfidenceR = confidence;
  /*  outputConfidenceR = 1; */
  if (*outputConfidenceG > 0.6) {
    *outputConfidenceG = *outputConfidenceG * 0.5F + previousConfidenceG * 0.5F;
  } else {
    *outputConfidenceG = fminf(*outputConfidenceG, previousConfidenceG);
  }
  previousConfidenceG = *outputConfidenceG;
  usedSampleRatio = 0.45F;
  if ((PR > 0.0F) && (PR < 50.0F)) {
    usedSampleRatio = 0.6F;
  }
  if ((PR > 0.0F) && (*outputConfidenceG > usedSampleRatio)) {
    if (trackedPR < 0.0F) {
      trackedPR = PR;
    } else {
      jumpLimit = 10;
      if (bodyMove > 10.0F) {
        jumpLimit = 16;
      }
      usedSampleRatio = fabsf(PR - trackedPR);
      xcorrR_IR =
          0.3F -
          0.18F * fminf(fmaxf(usedSampleRatio / (float)jumpLimit, 0.0F), 1.0F);
      if (bodyMove > 10.0F) {
        xcorrR_IR *= 0.8F;
      }
      if ((usedSampleRatio > (float)jumpLimit * 1.5F) &&
          (*outputConfidenceG < 0.75F)) {
        xcorrR_IR *= 0.5F;
      }
      xcorrR_IR = fmaxf(xcorrR_IR, 0.08F);
      trackedPR = trackedPR * (1.0F - xcorrR_IR) + PR * xcorrR_IR;
    }
    usedSampleRatio = trackedConfidence * 0.55F + *outputConfidenceG * 0.45F;
  } else if (*outputConfidenceG < 0.2F) {
    usedSampleRatio = trackedConfidence * 0.7F;
    if (usedSampleRatio < 0.15F) {
      trackedPR = -1.0F;
    }
  } else {
    usedSampleRatio = trackedConfidence * 0.8F + *outputConfidenceG * 0.2F;
  }
  trackedConfidence = usedSampleRatio;
  return outputR;
}

void r_pr_calculation_emx_free(void)
{
  emxFree_real32_T(&previousPRG);
  emxFree_real32_T(&expandedGreenInputBuffer);
}

void r_pr_calculation_emx_init(void)
{
  int i;
  emxInit_real32_T(&previousPRG);
  i = previousPRG->size[0];
  previousPRG->size[0] = 150;
  emxEnsureCapacity_real32_T(previousPRG, i);
  emxInit_real32_T(&expandedGreenInputBuffer);
  i = expandedGreenInputBuffer->size[0];
  expandedGreenInputBuffer->size[0] = 300;
  emxEnsureCapacity_real32_T(expandedGreenInputBuffer, i);
}

void r_pr_calculation_init(void)
{
  trackedConfidence_not_empty = false;
  trackedPR_not_empty = false;
  c_expandedGreenInputBuffer_not_ = false;
  previousPRGValidCount_not_empty = false;
  previousPRG_not_empty = false;
  previousConfidenceG_not_empty = false;
}

/* End of code generation (r_pr_calculation.c) */
