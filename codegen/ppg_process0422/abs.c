/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * abs.c
 *
 * Code generation for function 'abs'
 *
 */

/* Include files */
#include "abs.h"
#include "rt_nonfinite.h"
#include <math.h>

/* Function Definitions */
int b_abs(const float x_data[], int x_size, float y_data[])
{
  int k;
  int y_size;
  y_size = x_size;
  for (k = 0; k < x_size; k++) {
    y_data[k] = fabsf(x_data[k]);
  }
  return y_size;
}

/* End of code generation (abs.c) */
