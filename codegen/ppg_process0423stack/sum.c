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
#include "ppg_process_types.h"
#include "rt_nonfinite.h"

/* Function Definitions */
float sum(const emxArray_real32_T *x)
{
  const float *x_data;
  float y;
  int k;
  int vlen;
  x_data = x->data;
  vlen = x->size[0];
  if (x->size[0] == 0) {
    y = 0.0F;
  } else {
    y = x_data[0];
    for (k = 2; k <= vlen; k++) {
      y += x_data[k - 1];
    }
  }
  return y;
}

/* End of code generation (sum.c) */
