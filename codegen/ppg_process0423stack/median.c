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
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "quickselect.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"

/* Function Definitions */
float b_median(const emxArray_real32_T *x)
{
  emxArray_real32_T *a__4;
  const float *x_data;
  float y;
  float *a__4_data;
  int i;
  int j2;
  int j3;
  int k;
  int n;
  x_data = x->data;
  n = x->size[0];
  k = 0;
  emxInit_real32_T(&a__4);
  int exitg1;
  do {
    exitg1 = 0;
    if (k <= n - 1) {
      if (rtIsNaNF(x_data[k])) {
        y = rtNaNF;
        exitg1 = 1;
      } else {
        k++;
      }
    } else {
      if (n <= 4) {
        if (n == 1) {
          y = x_data[0];
        } else if (n == 2) {
          if (((x_data[0] < 0.0F) != (x_data[1] < 0.0F)) ||
              rtIsInfF(x_data[0])) {
            y = (x_data[0] + x_data[1]) / 2.0F;
          } else {
            y = x_data[0] + (x_data[1] - x_data[0]) / 2.0F;
          }
        } else if (n == 3) {
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
        midm1 = n >> 1;
        if (((unsigned int)n & 1U) == 0U) {
          k = a__4->size[0];
          a__4->size[0] = n;
          emxEnsureCapacity_real32_T(a__4, k);
          a__4_data = a__4->data;
          for (i = 0; i < n; i++) {
            a__4_data[i] = x_data[i];
          }
          y = b_quickselect(a__4, midm1 + 1, n, &k, &j3);
          if (midm1 < k) {
            float b;
            b = b_quickselect(a__4, midm1, j3 - 1, &k, &j2);
            if (((y < 0.0F) != (b < 0.0F)) || rtIsInfF(y)) {
              y = (y + b) / 2.0F;
            } else {
              y += (b - y) / 2.0F;
            }
          }
        } else {
          k = a__4->size[0];
          a__4->size[0] = n;
          emxEnsureCapacity_real32_T(a__4, k);
          a__4_data = a__4->data;
          for (i = 0; i < n; i++) {
            a__4_data[i] = x_data[i];
          }
          y = b_quickselect(a__4, midm1 + 1, n, &k, &j2);
        }
      }
      exitg1 = 1;
    }
  } while (exitg1 == 0);
  emxFree_real32_T(&a__4);
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

float median(const emxArray_real32_T *x)
{
  emxArray_real32_T *v;
  const float *x_data;
  float y;
  float *v_data;
  int a__3;
  int i;
  int ilast;
  int k;
  x_data = x->data;
  emxInit_real32_T(&v);
  k = v->size[0];
  v->size[0] = 30;
  emxEnsureCapacity_real32_T(v, k);
  v_data = v->data;
  k = 0;
  int exitg1;
  do {
    exitg1 = 0;
    if (k < 30) {
      if (rtIsNaNF(x_data[k])) {
        y = rtNaNF;
        exitg1 = 1;
      } else {
        k++;
      }
    } else {
      for (i = 0; i < 30; i++) {
        v_data[i] = x_data[i];
      }
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
  emxFree_real32_T(&v);
  return y;
}

/* End of code generation (median.c) */
