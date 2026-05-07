/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * median.c
 *
 * Code generation for function 'median'
 *
 */

/* Include files */
#include "median.h"
#include "quickselect.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"
#include <string.h>

/* Function Definitions */
float b_median(const float x_data[], int x_size)
{
  float a__4_data[29];
  float y;
  int j2;
  int j3;
  int k;
  k = 0;
  int exitg1;
  do {
    exitg1 = 0;
    if (k <= x_size - 1) {
      if (rtIsNaNF(x_data[k])) {
        y = rtNaNF;
        exitg1 = 1;
      } else {
        k++;
      }
    } else {
      if (x_size <= 4) {
        if (x_size == 1) {
          y = x_data[0];
        } else if (x_size == 2) {
          if (((x_data[0] < 0.0F) != (x_data[1] < 0.0F)) ||
              rtIsInfF(x_data[0])) {
            y = (x_data[0] + x_data[1]) / 2.0F;
          } else {
            y = x_data[0] + (x_data[1] - x_data[0]) / 2.0F;
          }
        } else if (x_size == 3) {
          if (x_data[0] < x_data[1]) {
            if (x_data[1] < x_data[2]) {
              k = 1;
            } else if (x_data[0] < x_data[2]) {
              k = 2;
            } else {
              k = 0;
            }
          } else if (x_data[0] < x_data[2]) {
            k = 0;
          } else if (x_data[1] < x_data[2]) {
            k = 2;
          } else {
            k = 1;
          }
          y = x_data[k];
        } else {
          if (x_data[0] < x_data[1]) {
            if (x_data[1] < x_data[2]) {
              k = 0;
              j2 = 1;
              j3 = 2;
            } else if (x_data[0] < x_data[2]) {
              k = 0;
              j2 = 2;
              j3 = 1;
            } else {
              k = 2;
              j2 = 0;
              j3 = 1;
            }
          } else if (x_data[0] < x_data[2]) {
            k = 1;
            j2 = 0;
            j3 = 2;
          } else if (x_data[1] < x_data[2]) {
            k = 1;
            j2 = 2;
            j3 = 0;
          } else {
            k = 2;
            j2 = 1;
            j3 = 0;
          }
          if (x_data[k] < x_data[3]) {
            if (x_data[3] < x_data[j3]) {
              if (((x_data[j2] < 0.0F) != (x_data[3] < 0.0F)) ||
                  rtIsInfF(x_data[j2])) {
                y = (x_data[j2] + x_data[3]) / 2.0F;
              } else {
                y = x_data[j2] + (x_data[3] - x_data[j2]) / 2.0F;
              }
            } else if (((x_data[j2] < 0.0F) != (x_data[j3] < 0.0F)) ||
                       rtIsInfF(x_data[j2])) {
              y = (x_data[j2] + x_data[j3]) / 2.0F;
            } else {
              y = x_data[j2] + (x_data[j3] - x_data[j2]) / 2.0F;
            }
          } else if (((x_data[k] < 0.0F) != (x_data[j2] < 0.0F)) ||
                     rtIsInfF(x_data[k])) {
            y = (x_data[k] + x_data[j2]) / 2.0F;
          } else {
            y = x_data[k] + (x_data[j2] - x_data[k]) / 2.0F;
          }
        }
      } else {
        int midm1;
        midm1 = x_size >> 1;
        if (((unsigned int)x_size & 1U) == 0U) {
          memcpy(&a__4_data[0], &x_data[0],
                 (unsigned int)x_size * sizeof(float));
          y = b_quickselect(a__4_data, midm1 + 1, x_size, &k, &j3);
          if (midm1 < k) {
            float b;
            b = b_quickselect(a__4_data, midm1, j3 - 1, &k, &j2);
            if (((y < 0.0F) != (b < 0.0F)) || rtIsInfF(y)) {
              y = (y + b) / 2.0F;
            } else {
              y += (b - y) / 2.0F;
            }
          }
        } else {
          memcpy(&a__4_data[0], &x_data[0],
                 (unsigned int)x_size * sizeof(float));
          y = b_quickselect(a__4_data, midm1 + 1, x_size, &k, &j2);
        }
      }
      exitg1 = 1;
    }
  } while (exitg1 == 0);
  return y;
}

float c_median(const float x[10])
{
  float y;
  int a__3;
  int i;
  int ilast;
  int k;
  k = 0;
  int exitg1;
  do {
    exitg1 = 0;
    if (k < 10) {
      if (rtIsNaNF(x[k])) {
        y = rtNaNF;
        exitg1 = 1;
      } else {
        k++;
      }
    } else {
      float v[10];
      for (i = 0; i < 10; i++) {
        v[i] = x[i];
      }
      y = c_quickselect(v, 6, 10, &k, &ilast);
      if (k > 5) {
        float b;
        b = c_quickselect(v, 5, ilast - 1, &k, &a__3);
        if (((y < 0.0F) != (b < 0.0F)) || rtIsInfF(y)) {
          y = (y + b) / 2.0F;
        } else {
          y += (b - y) / 2.0F;
        }
      }
      exitg1 = 1;
    }
  } while (exitg1 == 0);
  return y;
}

float median(const float x[30])
{
  float v[30];
  float y;
  int a__3;
  int ilast;
  int k;
  k = 0;
  int exitg1;
  do {
    exitg1 = 0;
    if (k < 30) {
      if (rtIsNaNF(x[k])) {
        y = rtNaNF;
        exitg1 = 1;
      } else {
        k++;
      }
    } else {
      memcpy(&v[0], &x[0], 30U * sizeof(float));
      y = quickselect(v, 16, 30, &k, &ilast);
      if (k > 15) {
        float b;
        b = quickselect(v, 15, ilast - 1, &k, &a__3);
        if (((y < 0.0F) != (b < 0.0F)) || rtIsInfF(y)) {
          y = (y + b) / 2.0F;
        } else {
          y += (b - y) / 2.0F;
        }
      }
      exitg1 = 1;
    }
  } while (exitg1 == 0);
  return y;
}

/* End of code generation (median.c) */
