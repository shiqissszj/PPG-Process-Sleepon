/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * calculate_spo2.c
 *
 * Code generation for function 'calculate_spo2'
 *
 */

/* Include files */
#include "calculate_spo2.h"
#include "rt_nonfinite.h"
#include <math.h>

/* Function Definitions */
float calculate_spo2(float inputR)
{
  /*  Calibration candidates from R_SpO2_scatter_v2.m using R_SpO2_values_v2.mat
   */
  /*  */
  /*  Linear: */
  /*    SpO2 = -38.673274 * R + 117.855417 */
  /*  */
  /*  Quadratic: */
  /*    SpO2 = -10.521128 * R^2 + -21.712300 * R + 111.509029 */
  /*  */
  /*  PiecewiseLinear: */
  /*    breakpoint = 0.575722 */
  /*    left  : SpO2 = 101.850707 + -8.228011 * R */
  /*    right : continue from breakpoint with slope -42.901326 */
  /*  Default active model: Linear */
  /*  linearFun = @(x, xdata) x(1) * xdata + x(2); */
  /*  linearCoeffs = [-38.673274, 117.855417]; */
  /*  Spo2 = linearFun(linearCoeffs, inputR); */
  /*  linearFun = @(x,xdata)x(1)*xdata+x(2); */
  /*  linearCoeffs = [-39.9031385316171,120.345434717573]; */
  /*  */
  /*  Spo2 = linearFun(linearCoeffs, inputR); */
  /*  Quadratic candidate */
  /*  quadraticCoeffs = [-17.083025, -10.626567, 107.006690]; */
  /*  quadraticCoeffs = [-5.709408, -25.587417, 110.219948]; */
  /*  Piecewise-linear candidate */
  /*  piecewiseFun = @(b, x) (x <= b(3)).*(b(1) + b(2) * x) + ... */
  /*      (x > b(3)).*(b(1) + b(2) * b(3) + b(4) * (x - b(3))); */
  /*  piecewiseCoeffs = [101.850707, -8.228011, 0.575722, -42.901326]; */
  /*  Spo2 = piecewiseFun(piecewiseCoeffs, inputR); */
  return fmaxf(
      fminf((-5.88965893F * (inputR * inputR) + -24.4880905F * inputR) +
                109.879906F,
            100.0F),
      65.0F);
}

/* End of code generation (calculate_spo2.c) */
