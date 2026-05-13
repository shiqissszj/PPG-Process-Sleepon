/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * mod.c
 *
 * Code generation for function 'mod'
 *
 */

/* Include files */
#include "mod.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"
#include <math.h>

/* Function Definitions */
double b_mod(double x)
{
  double r;
  r = fmod(x, 2.0);
  if (r == 0.0) {
    r = 0.0;
  }
  return r;
}

double c_mod(double x)
{
  double r;
  if (rtIsNaN(x) || rtIsInf(x)) {
    r = rtNaN;
  } else {
    r = fmod(x, 25.0);
    if (r == 0.0) {
      r = 0.0;
    }
  }
  return r;
}

/* End of code generation (mod.c) */
