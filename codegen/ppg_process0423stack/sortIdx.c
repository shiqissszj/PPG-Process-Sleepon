/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * sortIdx.c
 *
 * Code generation for function 'sortIdx'
 *
 */

/* Include files */
#include "sortIdx.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"

/* Function Definitions */
void b_merge(emxArray_int32_T *idx, emxArray_real32_T *x, int offset, int np,
             int nq, emxArray_int32_T *iwork, emxArray_real32_T *xwork)
{
  float *x_data;
  float *xwork_data;
  int j;
  int *idx_data;
  int *iwork_data;
  xwork_data = xwork->data;
  iwork_data = iwork->data;
  x_data = x->data;
  idx_data = idx->data;
  if (nq != 0) {
    int iout;
    int n;
    int p;
    int q;
    n = np + nq;
    for (j = 0; j < n; j++) {
      q = offset + j;
      iwork_data[j] = idx_data[q];
      xwork_data[j] = x_data[q];
    }
    p = 0;
    q = np;
    iout = offset - 1;
    int exitg1;
    do {
      exitg1 = 0;
      iout++;
      if (xwork_data[p] <= xwork_data[q]) {
        idx_data[iout] = iwork_data[p];
        x_data[iout] = xwork_data[p];
        if (p + 1 < np) {
          p++;
        } else {
          exitg1 = 1;
        }
      } else {
        idx_data[iout] = iwork_data[q];
        x_data[iout] = xwork_data[q];
        if (q + 1 < n) {
          q++;
        } else {
          q = iout - p;
          for (j = p + 1; j <= np; j++) {
            iout = q + j;
            idx_data[iout] = iwork_data[j - 1];
            x_data[iout] = xwork_data[j - 1];
          }
          exitg1 = 1;
        }
      }
    } while (exitg1 == 0);
  }
}

void merge(emxArray_int32_T *idx, emxArray_real32_T *x, int offset, int np,
           int nq, emxArray_int32_T *iwork, emxArray_real32_T *xwork)
{
  float *x_data;
  float *xwork_data;
  int j;
  int *idx_data;
  int *iwork_data;
  xwork_data = xwork->data;
  iwork_data = iwork->data;
  x_data = x->data;
  idx_data = idx->data;
  if (nq != 0) {
    int iout;
    int n;
    int p;
    int q;
    n = np + nq;
    for (j = 0; j < n; j++) {
      q = offset + j;
      iwork_data[j] = idx_data[q];
      xwork_data[j] = x_data[q];
    }
    p = 0;
    q = np;
    iout = offset - 1;
    int exitg1;
    do {
      exitg1 = 0;
      iout++;
      if (xwork_data[p] >= xwork_data[q]) {
        idx_data[iout] = iwork_data[p];
        x_data[iout] = xwork_data[p];
        if (p + 1 < np) {
          p++;
        } else {
          exitg1 = 1;
        }
      } else {
        idx_data[iout] = iwork_data[q];
        x_data[iout] = xwork_data[q];
        if (q + 1 < n) {
          q++;
        } else {
          q = iout - p;
          for (j = p + 1; j <= np; j++) {
            iout = q + j;
            idx_data[iout] = iwork_data[j - 1];
            x_data[iout] = xwork_data[j - 1];
          }
          exitg1 = 1;
        }
      }
    } while (exitg1 == 0);
  }
}

/* End of code generation (sortIdx.c) */
