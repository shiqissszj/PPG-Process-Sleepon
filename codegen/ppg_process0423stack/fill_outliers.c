/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * fill_outliers.c
 *
 * Code generation for function 'fill_outliers'
 *
 */

/* Include files */
#include "fill_outliers.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"

/* Function Definitions */
double b_fill_outliers(emxArray_real32_T *input)
{
  double outlierNum;
  float deviation;
  float lowerBound;
  float meanValue;
  float sumValue;
  float *input_data;
  int i;
  int idx;
  input_data = input->data;
  outlierNum = 0.0;
  /*  Lightweight clipping based on mean absolute deviation. */
  sumValue = 0.0F;
  i = input->size[0];
  for (idx = 0; idx < i; idx++) {
    sumValue += input_data[idx];
  }
  meanValue = sumValue / (float)input->size[0];
  sumValue = 0.0F;
  for (idx = 0; idx < i; idx++) {
    deviation = input_data[idx] - meanValue;
    if (deviation < 0.0F) {
      deviation = -deviation;
    }
    sumValue += deviation;
  }
  /*  Scale the mean absolute deviation so the clipping width stays close to the
   */
  /*  legacy IQR-based behavior. This keeps the new implementation lightweight
   */
  /*  without collapsing the green-light confidence in the old PR pipeline. */
  sumValue = 1.80000007F * (sumValue / (float)input->size[0]);
  lowerBound = meanValue - sumValue;
  sumValue += meanValue;
  for (idx = 0; idx < i; idx++) {
    deviation = input_data[idx];
    if (deviation < lowerBound) {
      input_data[idx] = lowerBound;
      outlierNum++;
    } else if (deviation > sumValue) {
      input_data[idx] = sumValue;
      outlierNum++;
    }
  }
  return outlierNum;
}

double fill_outliers(emxArray_real32_T *input)
{
  double outlierNum;
  float deviation;
  float lowerBound;
  float meanValue;
  float sumValue;
  float *input_data;
  int idx;
  input_data = input->data;
  outlierNum = 0.0;
  /*  Lightweight clipping based on mean absolute deviation. */
  sumValue = 0.0F;
  for (idx = 0; idx < 150; idx++) {
    sumValue += input_data[idx];
  }
  meanValue = sumValue / 150.0F;
  sumValue = 0.0F;
  for (idx = 0; idx < 150; idx++) {
    deviation = input_data[idx] - meanValue;
    if (deviation < 0.0F) {
      deviation = -deviation;
    }
    sumValue += deviation;
  }
  /*  Scale the mean absolute deviation so the clipping width stays close to the
   */
  /*  legacy IQR-based behavior. This keeps the new implementation lightweight
   */
  /*  without collapsing the green-light confidence in the old PR pipeline. */
  sumValue = 1.80000007F * (sumValue / 150.0F);
  lowerBound = meanValue - sumValue;
  sumValue += meanValue;
  for (idx = 0; idx < 150; idx++) {
    deviation = input_data[idx];
    if (deviation < lowerBound) {
      input_data[idx] = lowerBound;
      outlierNum++;
    } else if (deviation > sumValue) {
      input_data[idx] = sumValue;
      outlierNum++;
    }
  }
  return outlierNum;
}

/* End of code generation (fill_outliers.c) */
