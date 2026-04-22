/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * diff.c
 *
 * Code generation for function 'diff'
 *
 */

/* Include files */
#include "diff.h"
#include "rt_nonfinite.h"

/* Function Definitions */
int diff(const float x_data[], int x_size, float y_data[])
{
  float work_data;
  int m;
  int y_size;
  y_size = x_size - 1;
  work_data = x_data[0];
  for (m = 2; m <= x_size; m++) {
    float tmp2;
    tmp2 = work_data;
    work_data = x_data[m - 1];
    y_data[m - 2] = work_data - tmp2;
  }
  return y_size;
}

/* End of code generation (diff.c) */
