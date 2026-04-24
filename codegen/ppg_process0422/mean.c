/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * mean.c
 *
 * Code generation for function 'mean'
 *
 */

/* Include files */
#include "mean.h"
#include "rt_nonfinite.h"

/* Function Definitions */
float b_mean(const float x_data[], int x_size)
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
  y /= (float)x_size;
  return y;
}

double c_mean(const double x[150])
{
  double y;
  int k;
  y = x[0];
  for (k = 0; k < 149; k++) {
    y += x[k + 1];
  }
  y /= 150.0;
  return y;
}

float d_mean(const float x[30])
{
  float y;
  int k;
  y = x[0];
  for (k = 0; k < 29; k++) {
    y += x[k + 1];
  }
  y /= 30.0F;
  return y;
}

float e_mean(const float x[25])
{
  float y;
  int k;
  y = x[0];
  for (k = 0; k < 24; k++) {
    y += x[k + 1];
  }
  y /= 25.0F;
  return y;
}

float mean(const float x[150])
{
  float y;
  int k;
  y = x[0];
  for (k = 0; k < 149; k++) {
    y += x[k + 1];
  }
  y /= 150.0F;
  return y;
}

/* End of code generation (mean.c) */
