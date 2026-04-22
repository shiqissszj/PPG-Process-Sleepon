/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * minOrMax.c
 *
 * Code generation for function 'minOrMax'
 *
 */

/* Include files */
#include "minOrMax.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"

/* Function Definitions */
float b_maximum(const float x_data[], int x_size)
{
  float ex;
  int b_k;
  if (x_size <= 2) {
    if (x_size == 0) {
      ex = rtNaNF;
    } else if (x_size == 1) {
      ex = x_data[0];
    } else if ((x_data[0] < x_data[1]) ||
               (rtIsNaNF(x_data[0]) && (!rtIsNaNF(x_data[1])))) {
      ex = x_data[1];
    } else {
      ex = x_data[0];
    }
  } else {
    int idx;
    if (!rtIsNaNF(x_data[0])) {
      idx = 1;
    } else {
      int k;
      bool exitg1;
      idx = 0;
      k = 2;
      exitg1 = false;
      while ((!exitg1) && (k <= x_size)) {
        if (!rtIsNaNF(x_data[k - 1])) {
          idx = k;
          exitg1 = true;
        } else {
          k++;
        }
      }
    }
    if (idx == 0) {
      ex = x_data[0];
    } else {
      ex = x_data[idx - 1];
      idx++;
      for (b_k = idx; b_k <= x_size; b_k++) {
        float f;
        f = x_data[b_k - 1];
        if (ex < f) {
          ex = f;
        }
      }
    }
  }
  return ex;
}

float b_minimum(const float x_data[], int x_size)
{
  float ex;
  int b_k;
  if ((unsigned short)(x_size - 1) + 1 <= 2) {
    if ((unsigned short)(x_size - 1) == 0) {
      ex = x_data[0];
    } else {
      ex = x_data[x_size - 1];
      if ((!(x_data[0] > ex)) && ((!rtIsNaNF(x_data[0])) || rtIsNaNF(ex))) {
        ex = x_data[0];
      }
    }
  } else {
    int idx;
    if (!rtIsNaNF(x_data[0])) {
      idx = 1;
    } else {
      int k;
      bool exitg1;
      idx = 0;
      k = 2;
      exitg1 = false;
      while ((!exitg1) && (k <= x_size)) {
        if (!rtIsNaNF(x_data[k - 1])) {
          idx = k;
          exitg1 = true;
        } else {
          k++;
        }
      }
    }
    if (idx == 0) {
      ex = x_data[0];
    } else {
      ex = x_data[idx - 1];
      idx++;
      for (b_k = idx; b_k <= x_size; b_k++) {
        float f;
        f = x_data[b_k - 1];
        if (ex > f) {
          ex = f;
        }
      }
    }
  }
  return ex;
}

double c_maximum(const emxArray_real_T *x)
{
  const double *x_data;
  double ex;
  int b_k;
  int last;
  x_data = x->data;
  last = x->size[0];
  if (x->size[0] <= 2) {
    if (x->size[0] == 1) {
      ex = x_data[0];
    } else {
      ex = x_data[x->size[0] - 1];
      if ((!(x_data[0] < ex)) && ((!rtIsNaN(x_data[0])) || rtIsNaN(ex))) {
        ex = x_data[0];
      }
    }
  } else {
    int idx;
    if (!rtIsNaN(x_data[0])) {
      idx = 1;
    } else {
      int k;
      bool exitg1;
      idx = 0;
      k = 2;
      exitg1 = false;
      while ((!exitg1) && (k <= last)) {
        if (!rtIsNaN(x_data[k - 1])) {
          idx = k;
          exitg1 = true;
        } else {
          k++;
        }
      }
    }
    if (idx == 0) {
      ex = x_data[0];
    } else {
      ex = x_data[idx - 1];
      idx++;
      for (b_k = idx; b_k <= last; b_k++) {
        double d;
        d = x_data[b_k - 1];
        if (ex < d) {
          ex = d;
        }
      }
    }
  }
  return ex;
}

float maximum(const float x[150])
{
  float ex;
  int b_k;
  int idx;
  if (!rtIsNaNF(x[0])) {
    idx = 1;
  } else {
    int k;
    bool exitg1;
    idx = 0;
    k = 2;
    exitg1 = false;
    while ((!exitg1) && (k <= 150)) {
      if (!rtIsNaNF(x[k - 1])) {
        idx = k;
        exitg1 = true;
      } else {
        k++;
      }
    }
  }
  if (idx == 0) {
    ex = x[0];
  } else {
    ex = x[idx - 1];
    idx++;
    for (b_k = idx; b_k < 151; b_k++) {
      float f;
      f = x[b_k - 1];
      if (ex < f) {
        ex = f;
      }
    }
  }
  return ex;
}

float minimum(const float x[150])
{
  float ex;
  int b_k;
  int idx;
  if (!rtIsNaNF(x[0])) {
    idx = 1;
  } else {
    int k;
    bool exitg1;
    idx = 0;
    k = 2;
    exitg1 = false;
    while ((!exitg1) && (k <= 150)) {
      if (!rtIsNaNF(x[k - 1])) {
        idx = k;
        exitg1 = true;
      } else {
        k++;
      }
    }
  }
  if (idx == 0) {
    ex = x[0];
  } else {
    ex = x[idx - 1];
    idx++;
    for (b_k = idx; b_k < 151; b_k++) {
      float f;
      f = x[b_k - 1];
      if (ex > f) {
        ex = f;
      }
    }
  }
  return ex;
}

/* End of code generation (minOrMax.c) */
