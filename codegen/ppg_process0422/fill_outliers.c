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
#include "abs.h"
#include "combineVectorElements.h"
#include "mean.h"
#include "rt_nonfinite.h"
#include <math.h>

/* Function Definitions */
double b_fill_outliers(float input_data[], const int *input_size)
{
  float b_input_data[300];
  float tmp_data[300];
  float deviationLimit;
  float lowerBound;
  float meanValue;
  int i;
  int loop_ub;
  bool b_tmp_data[300];
  /*  Lightweight clipping based on mean absolute deviation. */
  meanValue = b_mean(input_data, *input_size);
  /*  Scale the mean absolute deviation so the clipping width stays close to the
   */
  /*  legacy IQR-based behavior. This keeps the new implementation lightweight
   */
  /*  without collapsing the green-light confidence in the old PR pipeline. */
  loop_ub = *input_size;
  for (i = 0; i < loop_ub; i++) {
    b_input_data[i] = input_data[i] - meanValue;
  }
  int tmp_size;
  tmp_size = b_abs(b_input_data, loop_ub, tmp_data);
  deviationLimit = 1.80000007F * b_mean(tmp_data, tmp_size);
  lowerBound = meanValue - deviationLimit;
  meanValue += deviationLimit;
  /*  outlierIndexes = input < lowerBound | input > upperBound; */
  for (i = 0; i < loop_ub; i++) {
    bool b;
    deviationLimit = input_data[i];
    b = (deviationLimit < lowerBound);
    b_tmp_data[i] = (b || (deviationLimit > meanValue));
    if (b) {
      deviationLimit = lowerBound;
      input_data[i] = lowerBound;
    }
    if (deviationLimit > meanValue) {
      input_data[i] = meanValue;
    }
  }
  return combineVectorElements(b_tmp_data, loop_ub);
}

double fill_outliers(float input[150])
{
  double outlierNum;
  float y[150];
  float deviationLimit;
  float lowerBound;
  float meanValue;
  int b_y;
  int k;
  bool x[150];
  /*  Lightweight clipping based on mean absolute deviation. */
  meanValue = mean(input);
  for (k = 0; k < 150; k++) {
    y[k] = fabsf(input[k] - meanValue);
  }
  /*  Scale the mean absolute deviation so the clipping width stays close to the
   */
  /*  legacy IQR-based behavior. This keeps the new implementation lightweight
   */
  /*  without collapsing the green-light confidence in the old PR pipeline. */
  deviationLimit = 1.80000007F * mean(y);
  lowerBound = meanValue - deviationLimit;
  /*  outlierIndexes = input < lowerBound | input > upperBound; */
  for (k = 0; k < 150; k++) {
    float f;
    f = input[k];
    x[k] = ((f < lowerBound) || (f > meanValue + deviationLimit));
  }
  b_y = x[0];
  for (k = 0; k < 149; k++) {
    b_y += x[k + 1];
  }
  outlierNum = b_y;
  meanValue += deviationLimit;
  for (k = 0; k < 150; k++) {
    deviationLimit = input[k];
    if (deviationLimit < lowerBound) {
      deviationLimit = lowerBound;
      input[k] = lowerBound;
    }
    if (deviationLimit > meanValue) {
      input[k] = meanValue;
    }
  }
  return outlierNum;
}

/* End of code generation (fill_outliers.c) */
