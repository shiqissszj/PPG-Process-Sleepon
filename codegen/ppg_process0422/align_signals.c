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
#include "rt_nonfinite.h"
#include "sum.h"

/* Function Definitions */
int align_signals(float inputSig1[150], float inputSig2[150])
{
  float maxCorr;
  int delay;
  int ind;
  int lag;
  int loop_ub;
  /*  use simplified xcorr calculation */
  /*  initialization */
  /*  len = length(inputSig1);  */
  maxCorr = rtMinusInfF;
  delay = 0;
  /*  calculate the corr for each possible delay */
  for (lag = 0; lag < 21; lag++) {
    float tempCorr;
    if (lag - 10 < 0) {
      float b_inputSig2_data[149];
      for (ind = 0; ind <= lag + 139; ind++) {
        b_inputSig2_data[ind] = inputSig2[ind] * inputSig1[(ind - lag) + 10];
      }
      tempCorr = sum(b_inputSig2_data, lag + 140);
    } else {
      float inputSig2_data[150];
      loop_ub = -lag;
      for (ind = 0; ind <= loop_ub + 159; ind++) {
        inputSig2_data[ind] = inputSig2[(lag + ind) - 10] * inputSig1[ind];
      }
      tempCorr = sum(inputSig2_data, 160 - lag);
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
  /*  adjust the signal if delay is not 0 */
  if (delay > 0) {
    /*  aligned1 = [zeros(delay, 1); inputSig1(1:150-delay)]; */
    loop_ub = 150 - delay;
    for (ind = loop_ub; ind >= 1; ind--) {
      inputSig1[(ind + delay) - 1] = inputSig1[ind - 1];
    }
    for (ind = delay; ind >= 1; ind--) {
      inputSig1[ind - 1] = 0.0F;
    }
  } else if (delay < 0) {
    /*  aligned2 = [zeros(-delay, 1); inputSig2(1:150+delay)]; */
    loop_ub = delay + 150;
    for (ind = loop_ub; ind >= 1; ind--) {
      inputSig2[(ind - delay) - 1] = inputSig2[ind - 1];
    }
    loop_ub = -delay;
    for (ind = loop_ub; ind >= 1; ind--) {
      inputSig2[ind - 1] = 0.0F;
    }
  }
  /*  if delay is 0, do nothing */
  return delay;
}

/* End of code generation (align_signals.c) */
