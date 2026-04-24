/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * sum.c
 *
 * Code generation for function 'sum'
 *
 */

/* Include files */
#include "sum.h"
#include "rt_nonfinite.h"

/* Function Definitions */
float sum(const float x_data[], int x_size)
{
  float y;
  int k;
  if (x_size == 0) {
    y = 0.0F;
  } else {
    y = x_data[0];
    for (k = 2; k <= x_size; k++) {
      y += x_data[k - 1];
    }
  }
  return y;
}

/* End of code generation (sum.c) */
