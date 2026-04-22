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

/* Function Declarations */
static void binary_expand_op(emxArray_real_T *in1, float in2, float in3,
                             const float in4[150], int in5, int in6, int in7,
                             int in9, int in10, int in11);

/* Function Definitions */
static void binary_expand_op(emxArray_real_T *in1, float in2, float in3,
                             const float in4[150], int in5, int in6, int in7,
                             int in9, int in10, int in11)
{
  double *in1_data;
  float b_tmp_data[150];
  float in4_data[150];
  float tmp_data[150];
  float varargin_1;
  int i;
  int loop_ub;
  int stride_0_0;
  int stride_1_0;
  in1_data = in1->data;
  if (in7 + 1 == 1) {
    loop_ub = (in6 - in5) + 1;
  } else {
    loop_ub = in7 + 1;
  }
  stride_0_0 = ((in6 - in5) + 1 != 1);
  stride_1_0 = (in7 + 1 != 1);
  for (i = 0; i < loop_ub; i++) {
    in4_data[i] = in4[in5 + i * stride_0_0] * in4[i * stride_1_0];
  }
  stride_0_0 = in10 - in9;
  for (i = 0; i <= stride_0_0; i++) {
    varargin_1 = in4[in9 + i];
    tmp_data[i] = varargin_1 * varargin_1;
  }
  for (i = 0; i <= in11; i++) {
    varargin_1 = in4[i];
    b_tmp_data[i] = varargin_1 * varargin_1;
  }
  in1_data[(int)((in2 - in3) + 1.0F) - 1] =
      sum(in4_data, loop_ub) /
      (sqrtf(sum(tmp_data, stride_0_0 + 1)) * sqrtf(sum(b_tmp_data, in11 + 1)));
}

double a_corr(const float inputSig[150], float minLag, float maxLag,
              emxArray_real_T *corrValues)
{
  double *corrValues_data;
  int b_loop_ub;
  int i;
  int i1;
  int lag;
  int loop_ub;
  /*  initialization */
  /*  len = length(inputSig1);  */
  /*  corrValues = single(-Inf);  */
  /*  maxLagValueidx = int32(0);  */
  loop_ub = (int)((maxLag - minLag) + 1.0F);
  b_loop_ub = corrValues->size[0];
  corrValues->size[0] = loop_ub;
  emxEnsureCapacity_real_T(corrValues, b_loop_ub);
  corrValues_data = corrValues->data;
  for (i = 0; i < loop_ub; i++) {
    corrValues_data[i] = 0.0;
  }
  /*  calculate the corr for each possible delay */
  i1 = (int)(maxLag + (1.0F - minLag));
  for (lag = 0; lag < i1; lag++) {
    float b_lag;
    int c_loop_ub;
    int d_loop_ub;
    int i2;
    int i3;
    b_lag = minLag + (float)lag;
    if (b_lag + 1.0F > 150.0F) {
      loop_ub = 0;
      b_loop_ub = 0;
    } else {
      loop_ub = (int)(b_lag + 1.0F) - 1;
      b_loop_ub = 150;
    }
    if (150.0F - b_lag < 1.0F) {
      c_loop_ub = 0;
    } else {
      c_loop_ub = (int)(150.0F - b_lag);
    }
    if (b_lag + 1.0F > 150.0F) {
      i2 = 0;
      i3 = -1;
    } else {
      i2 = (int)(b_lag + 1.0F) - 1;
      i3 = 149;
    }
    d_loop_ub = b_loop_ub - loop_ub;
    if (d_loop_ub == c_loop_ub) {
      float b_tmp_data[150];
      float inputSig_data[150];
      float tmp_data[150];
      float varargin_1;
      for (i = 0; i < d_loop_ub; i++) {
        inputSig_data[i] = inputSig[loop_ub + i] * inputSig[i];
      }
      b_loop_ub = i3 - i2;
      for (i = 0; i <= b_loop_ub; i++) {
        varargin_1 = inputSig[i2 + i];
        tmp_data[i] = varargin_1 * varargin_1;
      }
      for (i = 0; i < c_loop_ub; i++) {
        varargin_1 = inputSig[i];
        b_tmp_data[i] = varargin_1 * varargin_1;
      }
      corrValues_data[(int)((b_lag - minLag) + 1.0F) - 1] =
          sum(inputSig_data, d_loop_ub) / (sqrtf(sum(tmp_data, b_loop_ub + 1)) *
                                           sqrtf(sum(b_tmp_data, c_loop_ub)));
    } else {
      binary_expand_op(corrValues, b_lag, minLag, inputSig, loop_ub,
                       b_loop_ub - 1, c_loop_ub - 1, i2, i3, c_loop_ub - 1);
      corrValues_data = corrValues->data;
    }
    /*  update the maxCorr and delay */
    /*  if tempCorr > corrValues */
    /*      corrValues = tempCorr; */
    /*      maxLagValueidx = lag; */
    /*  end */
  }
  return c_maximum(corrValues);
  /*  normalized the corr (optional) */
  /*  normFactor = sqrt(sum(inputSig1.^2) * sum(inputSig2.^2)); */
  /*  maxCorr = maxCorr / normFactor; */
}

/* End of code generation (a_corr.c) */
