/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ac_filter.c
 *
 * Code generation for function 'ac_filter'
 *
 */

/* Include files */
#include "ac_filter.h"
#include "fill_outliers.h"
#include "filter.h"
#include "ppg_process_data.h"
#include "rt_nonfinite.h"
#include <string.h>

/* Function Definitions */
double ac_filter(float inputAC[150])
{
  double outlierNum;
  float b_fv[150];
  float b_inputAC[150];
  int i;
  /*  threshold for outlier filter */
  /*  use customized filloutliers function */
  outlierNum = fill_outliers(inputAC);
  /*  use zero-phase digital filter */
  /*  a, b are parameters for butter bandpass filter */
  /*  [b, a] = butter(3, [0.5/(0.5*50), 4/(0.5*50)], 'bandpass'); */
  /*  Forward filter */
  /*  Reverse and filter */
  /*  reverse and output */
  filter(fv, fv1, inputAC, b_inputAC);
  for (i = 0; i < 150; i++) {
    b_fv[i] = b_inputAC[149 - i];
  }
  filter(fv, fv1, b_fv, inputAC);
  for (i = 0; i < 150; i++) {
    b_inputAC[i] = inputAC[149 - i];
  }
  memcpy(&inputAC[0], &b_inputAC[0], 150U * sizeof(float));
  return outlierNum;
}

double b_ac_filter(float inputAC_data[], int *inputAC_size)
{
  double outlierNum;
  float b_forward_filtered_data[300];
  float forward_filtered_data[300];
  int forward_filtered;
  int forward_filtered_size;
  int i;
  /*  threshold for outlier filter */
  /*  use customized filloutliers function */
  outlierNum = b_fill_outliers(inputAC_data, inputAC_size);
  /*  use zero-phase digital filter */
  /*  a, b are parameters for butter bandpass filter */
  /*  [b, a] = butter(3, [0.5/(0.5*50), 4/(0.5*50)], 'bandpass'); */
  /*  Forward filter */
  forward_filtered_size =
      b_filter(inputAC_data, *inputAC_size, forward_filtered_data);
  /*  Reverse and filter */
  forward_filtered = forward_filtered_size - 1;
  for (i = 0; i <= forward_filtered; i++) {
    b_forward_filtered_data[i] =
        forward_filtered_data[(forward_filtered_size - i) - 1];
  }
  if (forward_filtered_size - 1 >= 0) {
    memcpy(&forward_filtered_data[0], &b_forward_filtered_data[0],
           (unsigned int)forward_filtered_size * sizeof(float));
  }
  *inputAC_size =
      b_filter(forward_filtered_data, forward_filtered_size, inputAC_data);
  /*  reverse and output */
  forward_filtered_size = *inputAC_size - 1;
  forward_filtered = forward_filtered_size + 1;
  for (i = 0; i <= forward_filtered_size; i++) {
    forward_filtered_data[i] = inputAC_data[forward_filtered_size - i];
  }
  *inputAC_size = forward_filtered_size + 1;
  if (forward_filtered - 1 >= 0) {
    memcpy(&inputAC_data[0], &forward_filtered_data[0],
           (unsigned int)forward_filtered * sizeof(float));
  }
  return outlierNum;
}

/* End of code generation (ac_filter.c) */
