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
#include "abs.h"
#include "ac_filter.h"
#include "ac_normalize.h"
#include "any.h"
#include "diff.h"
#include "find_peaks.h"
#include "mean.h"
#include "median.h"
#include "minOrMax.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "preprocess_ppg_window_shared.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"
#include <math.h>
#include <string.h>

/* Variable Definitions */
static bool previousConfidenceG_not_empty;

static bool previousPRG_not_empty;

static bool previousPRGValidCount_not_empty;

/* Function Definitions */
float r_pr_calculation(const float b_windowR[150], const float b_windowIR[150],
                       const float b_windowG[150], unsigned int b_outputCounter,
                       float bodyMove, float *outputPR, float outputSQI[6],
                       float *outputConfidenceR, float *outputConfidenceG)
{
  static float previousPRG[150];
  static float previousConfidenceG;
  static unsigned int previousPRGValidCount;
  emxArray_real_T *corrValuesR;
  double a__1[150];
  double dcIR[150];
  double dcR[150];
  double D2;
  double N2;
  double guardD2_tmp;
  double outlierNumG;
  double *corrValuesR_data;
  float ppgExpandedInputG_data[300];
  float ppgNormalizedG_data[300];
  float a__2[150];
  float acG[150];
  float acGRaw[150];
  float acIR[150];
  float acR[150];
  float ppgFilteredG[150];
  float ppgFilteredIR[150];
  float ppgFilteredR[150];
  float a__4_data[50];
  float peakLocG0_data[50];
  float greenPeakDiff1_data[49];
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
  int b_x;
  int i;
  int loop_ub;
  int peakLocG0_size;
  int ppgExpandedInputG_size;
  unsigned int qY;
  int x;
  bool isValid;
  /*  Parameters for period identification */
  confidence = 1.0F;
  if (b_outputCounter == 1U) {
    /*  initialize */
    previousConfidenceG = 0.6F;
    previousConfidenceG_not_empty = true;
    memset(&previousPRG[0], 0, 150U * sizeof(float));
    previousPRG_not_empty = true;
    previousPRGValidCount = 0U;
    previousPRGValidCount_not_empty = true;
  }
  if (!previousConfidenceG_not_empty) {
    previousConfidenceG = 0.6F;
    previousConfidenceG_not_empty = true;
  }
  if (!previousPRG_not_empty) {
    memset(&previousPRG[0], 0, 150U * sizeof(float));
    previousPRG_not_empty = true;
  }
  if (!previousPRGValidCount_not_empty) {
    previousPRGValidCount = 0U;
    previousPRGValidCount_not_empty = true;
  }
  outlierNumG = preprocess_ppg_window_shared(
      b_windowR, b_windowIR, b_windowG, dcR, dcIR, a__1, acGRaw, acR, acIR, acG,
      ppgFilteredR, ppgFilteredIR, ppgFilteredG, a__2, &x, &b_x);
  /*  Preserve the legacy PR behavior: peak detection uses an expanded green */
  /*  signal built from a rolling history plus the current aligned AC green. */
  if (previousPRGValidCount > 0U) {
    ppgExpandedInputG_size = (int)previousPRGValidCount + 150;
    loop_ub = (int)previousPRGValidCount - 150;
    for (i = 0; i <= loop_ub + 149; i++) {
      ppgExpandedInputG_data[i] =
          previousPRG[(i - (int)previousPRGValidCount) + 150];
    }
    for (i = 0; i < 150; i++) {
      ppgExpandedInputG_data[i + (int)previousPRGValidCount] = acGRaw[i];
    }
  } else {
    ppgExpandedInputG_size = 150;
    memcpy(&ppgExpandedInputG_data[0], &acGRaw[0], 150U * sizeof(float));
  }
  b_ac_filter(ppgExpandedInputG_data, &ppgExpandedInputG_size);
  loop_ub = b_ac_normalize(ppgExpandedInputG_data, ppgExpandedInputG_size,
                           ppgNormalizedG_data);
  for (i = 0; i < 100; i++) {
    previousPRG[i] = previousPRG[i + 50];
  }
  memcpy(&previousPRG[100], &acGRaw[0], 50U * sizeof(float));
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
  find_peaks(ppgNormalizedG_data, loop_ub, a__4_data, peakLocG0_data,
             &peakLocG0_size);
  if (peakLocG0_size < 2) {
    confidence = 0.0F;
    PR = -1.0F;
  } else {
    bool guard1;
    ppgExpandedInputG_size =
        diff(peakLocG0_data, peakLocG0_size, ppgExpandedInputG_data);
    b_find_peaks(ppgNormalizedG_data, loop_ub,
                 b_mean(ppgExpandedInputG_data, ppgExpandedInputG_size) * 0.8F,
                 a__4_data, peakLocG0_data, &peakLocG0_size);
    guard1 = false;
    if (peakLocG0_size < 2) {
      guard1 = true;
    } else {
      loop_ub = diff(peakLocG0_data, peakLocG0_size, greenPeakDiff1_data);
      if (loop_ub <= 2) {
        ppgExpandedInputG_size = loop_ub;
        if (loop_ub - 1 >= 0) {
          memcpy(&ppgExpandedInputG_data[0], &greenPeakDiff1_data[0],
                 (unsigned int)loop_ub * sizeof(float));
        }
      } else {
        float b_greenPeakDiff1_data[49];
        xcorrR_IR = median(greenPeakDiff1_data, loop_ub);
        for (i = 0; i < loop_ub; i++) {
          b_greenPeakDiff1_data[i] = greenPeakDiff1_data[i] - xcorrR_IR;
        }
        ppgExpandedInputG_size =
            b_abs(b_greenPeakDiff1_data, loop_ub, ppgExpandedInputG_data);
        xcorrR_IR = median(ppgExpandedInputG_data, ppgExpandedInputG_size);
        if (xcorrR_IR <= 1.0E-6F) {
          ppgExpandedInputG_size = loop_ub;
          memcpy(&ppgExpandedInputG_data[0], &greenPeakDiff1_data[0],
                 (unsigned int)loop_ub * sizeof(float));
        } else {
          bool keepMask_data[49];
          xcorrR_IR *= 3.0F;
          for (i = 0; i < ppgExpandedInputG_size; i++) {
            keepMask_data[i] = (ppgExpandedInputG_data[i] <= xcorrR_IR);
          }
          if (any(keepMask_data, ppgExpandedInputG_size)) {
            loop_ub = 0;
            peakLocG0_size = 0;
            for (i = 0; i < ppgExpandedInputG_size; i++) {
              if (keepMask_data[i]) {
                loop_ub++;
                ppgExpandedInputG_data[peakLocG0_size] = greenPeakDiff1_data[i];
                peakLocG0_size++;
              }
            }
            ppgExpandedInputG_size = loop_ub;
          } else {
            ppgExpandedInputG_size = loop_ub;
            memcpy(&ppgExpandedInputG_data[0], &greenPeakDiff1_data[0],
                   (unsigned int)loop_ub * sizeof(float));
          }
        }
      }
      PR = 60.0F /
           (b_mean(ppgExpandedInputG_data, ppgExpandedInputG_size) / 50.0F);
      /* BPM */
      if (PR < 35.0F) {
        guard1 = true;
      }
    }
    if (guard1) {
      confidence = 0.0F;
      PR = -1.0F;
    }
  }
  /*  PI calculaton */
  for (i = 0; i < 150; i++) {
    acGRaw[i] = ppgFilteredG[i] * ppgFilteredR[i];
  }
  N1 = acGRaw[0];
  for (i = 0; i < 149; i++) {
    N1 += acGRaw[i + 1];
  }
  for (i = 0; i < 150; i++) {
    acGRaw[i] = ppgFilteredG[i] * ppgFilteredIR[i];
  }
  D1 = acGRaw[0];
  for (i = 0; i < 149; i++) {
    D1 += acGRaw[i + 1];
  }
  N2 = c_mean(dcIR);
  D2 = c_mean(dcR);
  for (i = 0; i < 150; i++) {
    a__2[i] = fabsf(acGRaw[i]);
  }
  guardD2_tmp = fabs(D2);
  if ((!rtIsInfF(N1)) && (!rtIsNaNF(N1)) &&
      ((!rtIsInfF(D1)) && (!rtIsNaNF(D1))) &&
      ((!rtIsInf(N2)) && (!rtIsNaN(N2))) &&
      ((!rtIsInf(D2)) && (!rtIsNaN(D2))) &&
      (fabsf(D1) > 0.001F * mean(a__2) + 1.0E-6F) &&
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
    xcorrR_IR = ppgFilteredG[i];
    a__2[i] = xcorrR_IR * xcorrR_IR;
    xcorrR_IR = ppgFilteredR[i];
    acGRaw[i] = xcorrR_IR * xcorrR_IR;
  }
  xcorrR_IR = a__2[0];
  usedSampleRatio = acGRaw[0];
  for (i = 0; i < 149; i++) {
    xcorrR_IR += a__2[i + 1];
    usedSampleRatio += acGRaw[i + 1];
  }
  xcorrIR_G = sqrtf(xcorrR_IR);
  y_tmp = sqrtf(usedSampleRatio);
  xcorrR_G = N1 / (y_tmp * xcorrIR_G);
  for (i = 0; i < 150; i++) {
    usedSampleRatio = ppgFilteredIR[i];
    a__2[i] = usedSampleRatio * usedSampleRatio;
  }
  usedSampleRatio = a__2[0];
  for (i = 0; i < 149; i++) {
    usedSampleRatio += a__2[i + 1];
  }
  xcorrR_IR = sqrtf(usedSampleRatio);
  xcorrIR_G = D1 / (xcorrR_IR * xcorrIR_G);
  for (i = 0; i < 150; i++) {
    acGRaw[i] = ppgFilteredIR[i] * ppgFilteredR[i];
  }
  usedSampleRatio = acGRaw[0];
  for (i = 0; i < 149; i++) {
    usedSampleRatio += acGRaw[i + 1];
  }
  xcorrR_IR = usedSampleRatio / (xcorrR_IR * y_tmp);
  outputSQI[0] = xcorrR_G;
  outputSQI[1] = xcorrIR_G;
  outputSQI[2] = xcorrR_IR;
  outputSQI[3] = 0.0F;
  outputSQI[4] = 0.0F;
  outputSQI[5] = 0.0F;
  if (x <= MIN_int32_T) {
    loop_ub = MAX_int32_T;
  } else {
    loop_ub = -x;
  }
  if (b_x <= MIN_int32_T) {
    peakLocG0_size = MAX_int32_T;
  } else {
    peakLocG0_size = -b_x;
  }
  if (x < 0) {
    x = loop_ub;
  }
  if (b_x < 0) {
    b_x = peakLocG0_size;
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

void r_pr_calculation_init(void)
{
  previousPRGValidCount_not_empty = false;
  previousPRG_not_empty = false;
  previousConfidenceG_not_empty = false;
}

/* End of code generation (r_pr_calculation.c) */
