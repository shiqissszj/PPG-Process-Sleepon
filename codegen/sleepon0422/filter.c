/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * filter.c
 *
 * Code generation for function 'filter'
 *
 */

/* Include files */
#include "filter.h"
#include "ppg_process_data.h"
#include "rt_nonfinite.h"
#include <string.h>

/* Function Definitions */
int b_filter(const float x_data[], int x_size, float y_data[])
{
  int j;
  int k;
  int nx;
  int y_size;
  nx = x_size - 1;
  y_size = x_size;
  if (x_size - 1 >= 0) {
    memset(&y_data[0], 0, (unsigned int)x_size * sizeof(float));
  }
  for (k = 0; k <= nx; k++) {
    float as;
    int a_tmp;
    int naxpy;
    a_tmp = (x_size - k) - 1;
    naxpy = a_tmp + 1;
    if (naxpy > 7) {
      naxpy = 7;
    }
    for (j = 0; j < naxpy; j++) {
      int y_tmp;
      y_tmp = k + j;
      y_data[y_tmp] += x_data[k] * fv[j];
    }
    if (a_tmp <= 6) {
      naxpy = a_tmp;
    } else {
      naxpy = 6;
    }
    as = -y_data[k];
    for (j = 0; j < naxpy; j++) {
      a_tmp = (k + j) + 1;
      y_data[a_tmp] += as * fv1[j + 1];
    }
  }
  return y_size;
}

void filter(const float b[7], const float a[7], const float x[150],
            float y[150])
{
  int j;
  int k;
  memset(&y[0], 0, 150U * sizeof(float));
  for (k = 0; k < 150; k++) {
    float as;
    int i;
    int y_tmp;
    if (150 - k < 7) {
      i = 149 - k;
    } else {
      i = 6;
    }
    for (j = 0; j <= i; j++) {
      y_tmp = k + j;
      y[y_tmp] += x[k] * b[j];
    }
    if (149 - k < 6) {
      i = 148 - k;
    } else {
      i = 5;
    }
    as = -y[k];
    for (j = 0; j <= i; j++) {
      y_tmp = (k + j) + 1;
      y[y_tmp] += as * a[j + 1];
    }
  }
}

/* End of code generation (filter.c) */
