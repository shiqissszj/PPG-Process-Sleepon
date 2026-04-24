/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * any.c
 *
 * Code generation for function 'any'
 *
 */

/* Include files */
#include "any.h"
#include "rt_nonfinite.h"

/* Function Definitions */
bool any(const bool x_data[], int x_size)
{
  int ix;
  bool exitg1;
  bool y;
  y = false;
  ix = 1;
  exitg1 = false;
  while ((!exitg1) && (ix <= x_size)) {
    if (x_data[ix - 1]) {
      y = true;
      exitg1 = true;
    } else {
      ix++;
    }
  }
  return y;
}

/* End of code generation (any.c) */
