/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * align_signals.c
 *
 * Code generation for function 'align_signals'
 *
 */

/* Include files */
#include "align_signals.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include "sum.h"

/* Function Definitions */
int align_signals(emxArray_real32_T *inputSig1, emxArray_real32_T *inputSig2)
{
  float maxCorr;
  float *b_inputSig2_data;
  float *inputSig1_data;
  float *inputSig2_data;
  int delay;
  int ind;
  int lag;
  int loop_ub;
  inputSig2_data = inputSig2->data;
  inputSig1_data = inputSig1->data;
  /*  use simplified xcorr calculation */
  /*  initialization */
  /*  len = length(inputSig1);  */
  maxCorr = rtMinusInfF;
  delay = 0;
  /*  calculate the corr for each possible delay */
  emxInit_real32_T(&inputSig2);
  emxInit_real32_T(&inputSig1);
  for (lag = 0; lag < 21; lag++) {
    float tempCorr;
    if (lag - 10 < 0) {
      loop_ub = inputSig1->size[0];
      inputSig1->size[0] = lag + 140;
      emxEnsureCapacity_real32_T(inputSig1, loop_ub);
      b_inputSig2_data = inputSig1->data;
      for (ind = 0; ind <= lag + 139; ind++) {
        b_inputSig2_data[ind] =
            inputSig2_data[ind] * inputSig1_data[(ind - lag) + 10];
      }
      tempCorr = sum(inputSig1);
    } else {
      loop_ub = inputSig2->size[0];
      inputSig2->size[0] = 160 - lag;
      emxEnsureCapacity_real32_T(inputSig2, loop_ub);
      b_inputSig2_data = inputSig2->data;
      loop_ub = -lag;
      for (ind = 0; ind <= loop_ub + 159; ind++) {
        b_inputSig2_data[ind] =
            inputSig2_data[(lag + ind) - 10] * inputSig1_data[ind];
      }
      tempCorr = sum(inputSig2);
    }
    /*  update the maxCorr and delay */
    if (tempCorr > maxCorr) {
      maxCorr = tempCorr;
      delay = lag - 10;
    }
  }
  emxFree_real32_T(&inputSig1);
  emxFree_real32_T(&inputSig2);
  /*  normalized the corr (optional) */
  /*  normFactor = sqrt(sum(inputSig1.^2) * sum(inputSig2.^2)); */
  /*  maxCorr = maxCorr / normFactor; */
  /*  adjust the signal if delay is not 0 */
  if (delay > 0) {
    /*  aligned1 = [zeros(delay, 1); inputSig1(1:150-delay)]; */
    loop_ub = 150 - delay;
    for (ind = loop_ub; ind >= 1; ind--) {
      inputSig1_data[(ind + delay) - 1] = inputSig1_data[ind - 1];
    }
    for (ind = delay; ind >= 1; ind--) {
      inputSig1_data[ind - 1] = 0.0F;
    }
  } else if (delay < 0) {
    /*  aligned2 = [zeros(-delay, 1); inputSig2(1:150+delay)]; */
    loop_ub = delay + 150;
    for (ind = loop_ub; ind >= 1; ind--) {
      inputSig2_data[(ind - delay) - 1] = inputSig2_data[ind - 1];
    }
    loop_ub = -delay;
    for (ind = loop_ub; ind >= 1; ind--) {
      inputSig2_data[ind - 1] = 0.0F;
    }
  }
  /*  if delay is 0, do nothing */
  return delay;
}

/* End of code generation (align_signals.c) */
