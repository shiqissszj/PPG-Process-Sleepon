/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * all.c
 *
 * Code generation for function 'all'
 *
 */

/* Include files */
#include "all.h"
#include "rt_nonfinite.h"

/* Function Definitions */
bool all(const bool x_data[], int x_size)
{
  int ix;
  bool exitg1;
  bool y;
  y = true;
  ix = 1;
  exitg1 = false;
  while ((!exitg1) && (ix <= x_size)) {
    if (!x_data[ix - 1]) {
      y = false;
      exitg1 = true;
    } else {
      ix++;
    }
  }
  return y;
}

/* End of code generation (all.c) */
