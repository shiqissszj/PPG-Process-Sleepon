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

/* Variable Definitions */
static bool previousConfidenceG_not_empty;

static emxArray_real32_T *previousPRG;

static bool previousPRG_not_empty;

static bool previousPRGValidCount_not_empty;

static emxArray_real32_T *expandedGreenInputBuffer;

static bool c_expandedGreenInputBuffer_not_;

/* Function Declarations */
static float robust_mean_peak_interval(const emxArray_real32_T *peakLocs);

/* Function Definitions */
static float robust_mean_peak_interval(const emxArray_real32_T *peakLocs)
{
  emxArray_real32_T *absDeviation;
  emxArray_real32_T *intervalBuffer;
  emxArray_real32_T *sortedValues;
  const float *peakLocs_data;
  float outputValue;
  float *absDeviation_data;
  float *intervalBuffer_data;
  float *sortedValues_data;
  int i;
  int insertIdx;
  int loop_ub;
  peakLocs_data = peakLocs->data;
  emxInit_real32_T(&intervalBuffer);
  insertIdx = intervalBuffer->size[0];
  intervalBuffer->size[0] = 49;
  emxEnsureCapacity_real32_T(intervalBuffer, insertIdx);
  intervalBuffer_data = intervalBuffer->data;
  for (i = 0; i < 49; i++) {
    intervalBuffer_data[i] = 0.0F;
  }
  loop_ub = peakLocs->size[0];
  for (i = 0; i <= loop_ub - 2; i++) {
    intervalBuffer_data[i] = peakLocs_data[i + 1] - peakLocs_data[i];
  }
  emxInit_real32_T(&sortedValues);
  emxInit_real32_T(&absDeviation);
  if (peakLocs->size[0] - 1 <= 2) {
    insertIdx = sortedValues->size[0];
    sortedValues->size[0] = peakLocs->size[0] - 1;
    emxEnsureCapacity_real32_T(sortedValues, insertIdx);
    sortedValues_data = sortedValues->data;
    for (i = 0; i <= loop_ub - 2; i++) {
      sortedValues_data[i] = intervalBuffer_data[i];
    }
  } else {
    double d;
    float deviation;
    int b_loop_ub;
    int middleIdx;
    bool exitg1;
    b_loop_ub = peakLocs->size[0] - 1;
    insertIdx = sortedValues->size[0];
    sortedValues->size[0] = peakLocs->size[0] - 1;
    emxEnsureCapacity_real32_T(sortedValues, insertIdx);
    sortedValues_data = sortedValues->data;
    for (i = 0; i <= loop_ub - 2; i++) {
      sortedValues_data[i] = intervalBuffer_data[i];
    }
    for (i = 0; i <= loop_ub - 3; i++) {
      outputValue = sortedValues_data[i + 1];
      insertIdx = i + 1;
      exitg1 = false;
      while ((!exitg1) && (insertIdx >= 1)) {
        deviation = sortedValues_data[insertIdx - 1];
        if (deviation > outputValue) {
          sortedValues_data[insertIdx] = deviation;
          insertIdx--;
        } else {
          exitg1 = true;
        }
      }
      sortedValues_data[insertIdx] = outputValue;
    }
    middleIdx = (int)floor((((double)peakLocs->size[0] - 1.0) + 1.0) / 2.0) - 1;
    d = b_mod((double)peakLocs->size[0] - 1.0);
    if (d == 1.0) {
      outputValue = sortedValues_data[middleIdx];
    } else {
      outputValue =
          (sortedValues_data[middleIdx] + sortedValues_data[middleIdx + 1]) *
          0.5F;
    }
    insertIdx = absDeviation->size[0];
    absDeviation->size[0] = peakLocs->size[0] - 1;
    emxEnsureCapacity_real32_T(absDeviation, insertIdx);
    absDeviation_data = absDeviation->data;
    for (i = 0; i < b_loop_ub; i++) {
      absDeviation_data[i] = 0.0F;
    }
    for (i = 0; i <= loop_ub - 2; i++) {
      deviation = intervalBuffer_data[i] - outputValue;
      if (deviation < 0.0F) {
        deviation = -deviation;
      }
      absDeviation_data[i] = deviation;
    }
    insertIdx = sortedValues->size[0];
    sortedValues->size[0] = peakLocs->size[0] - 1;
    emxEnsureCapacity_real32_T(sortedValues, insertIdx);
    sortedValues_data = sortedValues->data;
    for (i = 0; i < b_loop_ub; i++) {
      sortedValues_data[i] = absDeviation_data[i];
    }
    for (i = 0; i <= b_loop_ub - 2; i++) {
      outputValue = sortedValues_data[i + 1];
      insertIdx = i + 1;
      exitg1 = false;
      while ((!exitg1) && (insertIdx >= 1)) {
        deviation = sortedValues_data[insertIdx - 1];
        if (deviation > outputValue) {
          sortedValues_data[insertIdx] = deviation;
          insertIdx--;
        } else {
          exitg1 = true;
        }
      }
      sortedValues_data[insertIdx] = outputValue;
    }
    if (d == 1.0) {
      outputValue = sortedValues_data[middleIdx];
    } else {
      outputValue =
          (sortedValues_data[middleIdx] + sortedValues_data[middleIdx + 1]) *
          0.5F;
    }
    if (outputValue <= 1.0E-6F) {
      insertIdx = sortedValues->size[0];
      sortedValues->size[0] = peakLocs->size[0] - 1;
      emxEnsureCapacity_real32_T(sortedValues, insertIdx);
      sortedValues_data = sortedValues->data;
      for (i = 0; i <= loop_ub - 2; i++) {
        sortedValues_data[i] = intervalBuffer_data[i];
      }
    } else {
      outputValue *= 3.0F;
      middleIdx = 0;
      insertIdx = sortedValues->size[0];
      sortedValues->size[0] = peakLocs->size[0] - 1;
      emxEnsureCapacity_real32_T(sortedValues, insertIdx);
      sortedValues_data = sortedValues->data;
      for (i = 0; i < b_loop_ub; i++) {
        sortedValues_data[i] = 0.0F;
      }
      for (i = 0; i <= loop_ub - 2; i++) {
        if (absDeviation_data[i] <= outputValue) {
          middleIdx++;
          sortedValues_data[middleIdx - 1] = intervalBuffer_data[i];
        }
      }
      if (middleIdx > 0) {
        insertIdx = sortedValues->size[0];
        sortedValues->size[0] = middleIdx;
        emxEnsureCapacity_real32_T(sortedValues, insertIdx);
        sortedValues_data = sortedValues->data;
      } else {
        insertIdx = sortedValues->size[0];
        sortedValues->size[0] = peakLocs->size[0] - 1;
        emxEnsureCapacity_real32_T(sortedValues, insertIdx);
        sortedValues_data = sortedValues->data;
        for (i = 0; i <= loop_ub - 2; i++) {
          sortedValues_data[i] = intervalBuffer_data[i];
        }
      }
    }
  }
  emxFree_real32_T(&absDeviation);
  emxFree_real32_T(&intervalBuffer);
  outputValue = 0.0F;
  insertIdx = sortedValues->size[0];
  for (i = 0; i < insertIdx; i++) {
    outputValue += sortedValues_data[i];
  }
  outputValue /= (float)sortedValues->size[0];
  emxFree_real32_T(&sortedValues);
  return outputValue;
}

float r_pr_calculation(const emxArray_real32_T *b_windowR,
                       const emxArray_real32_T *b_windowIR,
                       const emxArray_real32_T *b_windowG,
                       unsigned int b_outputCounter, float bodyMove,
                       float *outputPR, float outputSQI[6],
                       float *outputConfidenceR, float *outputConfidenceG)
{
  static float previousConfidenceG;
  static unsigned int previousPRGValidCount;
  emxArray_real32_T *a__2;
  emxArray_real32_T *a__4;
  emxArray_real32_T *acG;
  emxArray_real32_T *acGRaw;
  emxArray_real32_T *acIR;
  emxArray_real32_T *acR;
  emxArray_real32_T *peakLocG0;
  emxArray_real32_T *peakLocG1;
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
  float D1;
  float N1;
  float PR;
  float confidence;
  float outputR;
  float usedSampleRatio;
  float xcorrIR_G;
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
  int loop_ub;
  unsigned int qY;
  int saturatedUnaryMinus;
  int x;
  bool isValid;
  expandedGreenInputBuffer_data = expandedGreenInputBuffer->data;
  previousPRG_data = previousPRG->data;
  emxInit_real32_T(&ppgFilteredG);
  saturatedUnaryMinus = ppgFilteredG->size[0];
  ppgFilteredG->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredG, saturatedUnaryMinus);
  emxInit_real32_T(&ppgFilteredIR);
  saturatedUnaryMinus = ppgFilteredIR->size[0];
  ppgFilteredIR->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredIR, saturatedUnaryMinus);
  emxInit_real32_T(&ppgFilteredR);
  saturatedUnaryMinus = ppgFilteredR->size[0];
  ppgFilteredR->size[0] = 150;
  emxEnsureCapacity_real32_T(ppgFilteredR, saturatedUnaryMinus);
  emxInit_real32_T(&acG);
  saturatedUnaryMinus = acG->size[0];
  acG->size[0] = 150;
  emxEnsureCapacity_real32_T(acG, saturatedUnaryMinus);
  emxInit_real32_T(&acIR);
  saturatedUnaryMinus = acIR->size[0];
  acIR->size[0] = 150;
  emxEnsureCapacity_real32_T(acIR, saturatedUnaryMinus);
  emxInit_real32_T(&acR);
  saturatedUnaryMinus = acR->size[0];
  acR->size[0] = 150;
  emxEnsureCapacity_real32_T(acR, saturatedUnaryMinus);
  emxInit_real32_T(&acGRaw);
  saturatedUnaryMinus = acGRaw->size[0];
  acGRaw->size[0] = 150;
  emxEnsureCapacity_real32_T(acGRaw, saturatedUnaryMinus);
  emxInit_real_T(&dcIR);
  saturatedUnaryMinus = dcIR->size[0];
  dcIR->size[0] = 150;
  emxEnsureCapacity_real_T(dcIR, saturatedUnaryMinus);
  emxInit_real_T(&dcR);
  saturatedUnaryMinus = dcR->size[0];
  dcR->size[0] = 150;
  emxEnsureCapacity_real_T(dcR, saturatedUnaryMinus);
  emxInit_real32_T(&a__2);
  saturatedUnaryMinus = a__2->size[0];
  a__2->size[0] = 150;
  emxEnsureCapacity_real32_T(a__2, saturatedUnaryMinus);
  emxInit_real_T(&a__1);
  saturatedUnaryMinus = a__1->size[0];
  a__1->size[0] = 150;
  emxEnsureCapacity_real_T(a__1, saturatedUnaryMinus);
  /*  Parameters for period identification */
  confidence = 1.0F;
  if (b_outputCounter == 1U) {
    /*  initialize */
    previousConfidenceG = 0.6F;
    previousConfidenceG_not_empty = true;
    saturatedUnaryMinus = previousPRG->size[0];
    previousPRG->size[0] = 150;
    emxEnsureCapacity_real32_T(previousPRG, saturatedUnaryMinus);
    previousPRG_data = previousPRG->data;
    for (i = 0; i < 150; i++) {
      previousPRG_data[i] = 0.0F;
    }
    previousPRG_not_empty = true;
    previousPRGValidCount = 0U;
    previousPRGValidCount_not_empty = true;
    saturatedUnaryMinus = expandedGreenInputBuffer->size[0];
    expandedGreenInputBuffer->size[0] = 300;
    emxEnsureCapacity_real32_T(expandedGreenInputBuffer, saturatedUnaryMinus);
    expandedGreenInputBuffer_data = expandedGreenInputBuffer->data;
    for (i = 0; i < 300; i++) {
      expandedGreenInputBuffer_data[i] = 0.0F;
    }
    c_expandedGreenInputBuffer_not_ = true;
  }
  if (!previousConfidenceG_not_empty) {
    previousConfidenceG = 0.6F;
    previousConfidenceG_not_empty = true;
  }
  if (!previousPRG_not_empty) {
    saturatedUnaryMinus = previousPRG->size[0];
    previousPRG->size[0] = 150;
    emxEnsureCapacity_real32_T(previousPRG, saturatedUnaryMinus);
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
    saturatedUnaryMinus = expandedGreenInputBuffer->size[0];
    expandedGreenInputBuffer->size[0] = 300;
    emxEnsureCapacity_real32_T(expandedGreenInputBuffer, saturatedUnaryMinus);
    expandedGreenInputBuffer_data = expandedGreenInputBuffer->data;
    for (i = 0; i < 300; i++) {
      expandedGreenInputBuffer_data[i] = 0.0F;
    }
    c_expandedGreenInputBuffer_not_ = true;
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
  if (previousPRGValidCount > 0U) {
    saturatedUnaryMinus = (int)previousPRGValidCount;
    for (i = 0; i < saturatedUnaryMinus; i++) {
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
  saturatedUnaryMinus = ppgExpandedG->size[0];
  ppgExpandedG->size[0] = (int)previousPRGValidCount + 150;
  emxEnsureCapacity_real32_T(ppgExpandedG, saturatedUnaryMinus);
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
  emxInit_real32_T(&a__4);
  emxInit_real32_T(&peakLocG0);
  find_peaks(ppgNormalizedG, a__4, peakLocG0);
  expandedGreenInputBuffer_data = peakLocG0->data;
  if (peakLocG0->size[0] < 2) {
    confidence = 0.0F;
    PR = -1.0F;
  } else {
    bool guard1;
    xcorrR_IR = 0.0F;
    saturatedUnaryMinus = peakLocG0->size[0];
    for (i = 0; i <= saturatedUnaryMinus - 2; i++) {
      xcorrR_IR += expandedGreenInputBuffer_data[i + 1] -
                   expandedGreenInputBuffer_data[i];
    }
    emxInit_real32_T(&peakLocG1);
    b_find_peaks(ppgNormalizedG,
                 xcorrR_IR / ((float)peakLocG0->size[0] - 1.0F) * 0.8F, a__4,
                 peakLocG1);
    guard1 = false;
    if (peakLocG1->size[0] < 2) {
      guard1 = true;
    } else {
      PR = 60.0F / (robust_mean_peak_interval(peakLocG1) / 50.0F);
      /* BPM */
      if (PR < 35.0F) {
        guard1 = true;
      }
    }
    if (guard1) {
      confidence = 0.0F;
      PR = -1.0F;
    }
    emxFree_real32_T(&peakLocG1);
  }
  emxFree_real32_T(&peakLocG0);
  emxFree_real32_T(&a__4);
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
  xcorrIR_G = sqrtf(xcorrR_IR);
  y_tmp = sqrtf(usedSampleRatio);
  xcorrR_G = N1 / (y_tmp * xcorrIR_G);
  for (i = 0; i < 150; i++) {
    a__2_data[i] = ppgFilteredIR_data[i] * ppgFilteredIR_data[i];
  }
  usedSampleRatio = a__2_data[0];
  for (i = 0; i < 149; i++) {
    usedSampleRatio += a__2_data[i + 1];
  }
  emxFree_real32_T(&a__2);
  xcorrR_IR = sqrtf(usedSampleRatio);
  xcorrIR_G = D1 / (xcorrR_IR * xcorrIR_G);
  for (i = 0; i < 150; i++) {
    acGRaw_data[i] = ppgFilteredIR_data[i] * ppgFilteredR_data[i];
  }
  usedSampleRatio = acGRaw_data[0];
  for (i = 0; i < 149; i++) {
    usedSampleRatio += acGRaw_data[i + 1];
  }
  emxFree_real32_T(&acGRaw);
  xcorrR_IR = usedSampleRatio / (xcorrR_IR * y_tmp);
  outputSQI[0] = xcorrR_G;
  outputSQI[1] = xcorrIR_G;
  outputSQI[2] = xcorrR_IR;
  outputSQI[3] = 0.0F;
  outputSQI[4] = 0.0F;
  outputSQI[5] = 0.0F;
  if (x <= MIN_int32_T) {
    saturatedUnaryMinus = MAX_int32_T;
  } else {
    saturatedUnaryMinus = -x;
  }
  if (b_x <= MIN_int32_T) {
    loop_ub = MAX_int32_T;
  } else {
    loop_ub = -b_x;
  }
  if (x < 0) {
    x = saturatedUnaryMinus;
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
  xcorrR_IR = ((fmaxf(xcorrR_G, 0.0F) + fmaxf(xcorrIR_G, 0.0F)) +
               fmaxf(xcorrR_IR, 0.0F)) /
              3.0F;
  N1 = fminf(
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
    confidence = fminf(xcorrR_IR * (0.55F * N1 + 0.45F), 1.0F);
  }
  if ((xcorrR_G < 0.25F) || (xcorrIR_G < 0.25F)) {
    confidence = 0.0F;
  } else if ((bodyMove > 20.0F) && (N1 < 0.5F)) {
    confidence *= 0.4F;
  }
  if (PR > 0.0F) {
    usedSampleRatio = 3000.0F / PR;
    xcorrR_IR = roundf(usedSampleRatio * 0.9F);
    N1 = roundf(usedSampleRatio * 1.1F);
    emxInit_real_T(&corrValuesR);
    N2 = a_corr(acR, xcorrR_IR, N1, corrValuesR);
    D2 = a_corr(acIR, xcorrR_IR, N1, corrValuesR);
    outlierNumG = a_corr(acG, xcorrR_IR, N1, corrValuesR);
    corrValuesR_data = corrValuesR->data;
    outputSQI[3] = (float)N2;
    outputSQI[4] = (float)D2;
    outputSQI[5] = (float)outlierNumG;
    xcorrR_IR = 1.0F;
    if (outlierNumG < 0.75) {
      xcorrR_IR = fmaxf((float)outlierNumG / 0.75F, 0.2F);
    }
    outlierNumG =
        corrValuesR_data[(int)fminf(fmaxf(roundf(usedSampleRatio * 0.1F), 1.0F),
                                    (float)corrValuesR->size[0]) -
                         1];
    emxFree_real_T(&corrValuesR);
    if (outlierNumG < 0.5) {
      xcorrR_IR *= fmaxf((float)outlierNumG / 0.5F, 0.2F);
    }
    /*  Startup windows are noisier after moving to 3 s. Use a soft penalty */
    /*  instead of hard-zeroing the PR confidence so raw PR can still seed the
     */
    /*  fix and smoothing stages. */
    if (b_outputCounter <= 8U) {
      *outputConfidenceG *= fmaxf(xcorrR_IR, 0.45F);
    } else {
      *outputConfidenceG *= xcorrR_IR;
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
  c_expandedGreenInputBuffer_not_ = false;
  previousPRGValidCount_not_empty = false;
  previousPRG_not_empty = false;
  previousConfidenceG_not_empty = false;
}

/* End of code generation (r_pr_calculation.c) */
