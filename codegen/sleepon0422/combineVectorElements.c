/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * combineVectorElements.c
 *
 * Code generation for function 'combineVectorElements'
 *
 */

/* Include files */
#include "combineVectorElements.h"
#include "rt_nonfinite.h"

/* Function Definitions */
int combineVectorElements(const bool x_data[], int x_size)
{
  int k;
  int y;
  y = x_data[0];
  for (k = 2; k <= x_size; k++) {
    y += x_data[k - 1];
  }
  return y;
}

/* End of code generation (combineVectorElements.c) */
