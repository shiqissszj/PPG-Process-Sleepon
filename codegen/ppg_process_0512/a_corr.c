/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * a_corr.c
 *
 * Code generation for function 'a_corr'
 *
 */

/* Include files */
#include "a_corr.h"
#include "minOrMax.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include "sum.h"
#include <math.h>

/* Function Definitions */
double a_corr(const emxArray_real32_T *inputSig, float minLag, float maxLag,
              emxArray_real_T *corrValues)
{
  emxArray_real32_T *b_inputSig;
  emxArray_real32_T *r;
  emxArray_real32_T *r1;
  double *corrValues_data;
  const float *inputSig_data;
  float *b_inputSig_data;
  int i;
  int i1;
  int i2;
  int lag;
  int loop_ub;
  inputSig_data = inputSig->data;
  /*  initialization */
  /*  len = length(inputSig1);  */
  /*  corrValues = single(-Inf);  */
  /*  maxLagValueidx = int32(0);  */
  loop_ub = (int)((maxLag - minLag) + 1.0F);
  i = corrValues->size[0];
  corrValues->size[0] = loop_ub;
  emxEnsureCapacity_real_T(corrValues, i);
  corrValues_data = corrValues->data;
  for (i1 = 0; i1 < loop_ub; i1++) {
    corrValues_data[i1] = 0.0;
  }
  /*  calculate the corr for each possible delay */
  i2 = (int)(maxLag + (1.0F - minLag));
  emxInit_real32_T(&b_inputSig);
  emxInit_real32_T(&r);
  emxInit_real32_T(&r1);
  for (lag = 0; lag < i2; lag++) {
    float b_lag;
    int b_loop_ub;
    int c_loop_ub;
    int i3;
    int i4;
    b_lag = minLag + (float)lag;
    if (b_lag + 1.0F > 150.0F) {
      loop_ub = 0;
      i = 0;
    } else {
      loop_ub = (int)(b_lag + 1.0F) - 1;
      i = 150;
    }
    if (150.0F - b_lag < 1.0F) {
      b_loop_ub = 0;
    } else {
      b_loop_ub = (int)(150.0F - b_lag);
    }
    if (b_lag + 1.0F > 150.0F) {
      i3 = 0;
      i4 = -1;
    } else {
      i3 = (int)(b_lag + 1.0F) - 1;
      i4 = 149;
    }
    c_loop_ub = i - loop_ub;
    if (c_loop_ub == b_loop_ub) {
      float varargin_1;
      i = b_inputSig->size[0];
      b_inputSig->size[0] = c_loop_ub;
      emxEnsureCapacity_real32_T(b_inputSig, i);
      b_inputSig_data = b_inputSig->data;
      for (i1 = 0; i1 < c_loop_ub; i1++) {
        b_inputSig_data[i1] = inputSig_data[loop_ub + i1] * inputSig_data[i1];
      }
      loop_ub = i4 - i3;
      i = r->size[0];
      r->size[0] = loop_ub + 1;
      emxEnsureCapacity_real32_T(r, i);
      b_inputSig_data = r->data;
      for (i1 = 0; i1 <= loop_ub; i1++) {
        varargin_1 = inputSig_data[i3 + i1];
        b_inputSig_data[i1] = varargin_1 * varargin_1;
      }
      i = r1->size[0];
      r1->size[0] = b_loop_ub;
      emxEnsureCapacity_real32_T(r1, i);
      b_inputSig_data = r1->data;
      for (i1 = 0; i1 < b_loop_ub; i1++) {
        varargin_1 = inputSig_data[i1];
        b_inputSig_data[i1] = varargin_1 * varargin_1;
      }
      corrValues_data[(int)((b_lag - minLag) + 1.0F) - 1] =
          sum(b_inputSig) / (sqrtf(sum(r)) * sqrtf(sum(r1)));
    } else {
      binary_expand_op(corrValues, b_lag, minLag, inputSig, loop_ub, i - 1,
                       b_loop_ub - 1, i3, i4, b_loop_ub - 1);
      corrValues_data = corrValues->data;
    }
    /*  update the maxCorr and delay */
    /*  if tempCorr > corrValues */
    /*      corrValues = tempCorr; */
    /*      maxLagValueidx = lag; */
    /*  end */
  }
  emxFree_real32_T(&r1);
  emxFree_real32_T(&r);
  emxFree_real32_T(&b_inputSig);
  return c_maximum(corrValues);
  /*  normalized the corr (optional) */
  /*  normFactor = sqrt(sum(inputSig1.^2) * sum(inputSig2.^2)); */
  /*  maxCorr = maxCorr / normFactor; */
}

void binary_expand_op(emxArray_real_T *in1, float in2, float in3,
                      const emxArray_real32_T *in4, int in5, int in6, int in7,
                      int in9, int in10, int in11)
{
  emxArray_real32_T *b_in4;
  emxArray_real32_T *r;
  emxArray_real32_T *r1;
  double *in1_data;
  const float *in4_data;
  float varargin_1;
  float *b_in4_data;
  int i;
  int loop_ub;
  int stride_0_0;
  int stride_1_0;
  in4_data = in4->data;
  in1_data = in1->data;
  emxInit_real32_T(&b_in4);
  if (in7 + 1 == 1) {
    loop_ub = (in6 - in5) + 1;
  } else {
    loop_ub = in7 + 1;
  }
  stride_0_0 = b_in4->size[0];
  b_in4->size[0] = loop_ub;
  emxEnsureCapacity_real32_T(b_in4, stride_0_0);
  b_in4_data = b_in4->data;
  stride_0_0 = ((in6 - in5) + 1 != 1);
  stride_1_0 = (in7 + 1 != 1);
  for (i = 0; i < loop_ub; i++) {
    b_in4_data[i] = in4_data[in5 + i * stride_0_0] * in4_data[i * stride_1_0];
  }
  emxInit_real32_T(&r);
  stride_1_0 = in10 - in9;
  stride_0_0 = r->size[0];
  r->size[0] = stride_1_0 + 1;
  emxEnsureCapacity_real32_T(r, stride_0_0);
  b_in4_data = r->data;
  for (i = 0; i <= stride_1_0; i++) {
    varargin_1 = in4_data[in9 + i];
    b_in4_data[i] = varargin_1 * varargin_1;
  }
  emxInit_real32_T(&r1);
  stride_0_0 = r1->size[0];
  r1->size[0] = in11 + 1;
  emxEnsureCapacity_real32_T(r1, stride_0_0);
  b_in4_data = r1->data;
  for (i = 0; i <= in11; i++) {
    varargin_1 = in4_data[i];
    b_in4_data[i] = varargin_1 * varargin_1;
  }
  in1_data[(int)((in2 - in3) + 1.0F) - 1] =
      sum(b_in4) / (sqrtf(sum(r)) * sqrtf(sum(r1)));
  emxFree_real32_T(&r1);
  emxFree_real32_T(&r);
  emxFree_real32_T(&b_in4);
}

/* End of code generation (a_corr.c) */
