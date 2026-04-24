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
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include <math.h>

/* Function Definitions */
void b_abs(const emxArray_real32_T *x, emxArray_real32_T *y)
{
  const float *x_data;
  float *y_data;
  int i;
  int i1;
  int k;
  x_data = x->data;
  i = x->size[0];
  i1 = y->size[0];
  y->size[0] = x->size[0];
  emxEnsureCapacity_real32_T(y, i1);
  y_data = y->data;
  for (k = 0; k < i; k++) {
    y_data[k] = fabsf(x_data[k]);
  }
}

/* End of code generation (abs.c) */
