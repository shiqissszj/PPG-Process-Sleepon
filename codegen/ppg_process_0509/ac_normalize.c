/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ac_normalize.c
 *
 * Code generation for function 'ac_normalize'
 *
 */

/* Include files */
#include "ac_normalize.h"
#include "minOrMax.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"

/* Function Definitions */
void ac_normalize(const emxArray_real32_T *inputAC, emxArray_real32_T *outputAC)
{
  const float *inputAC_data;
  float b_outputAC_tmp;
  float outputAC_tmp;
  float z;
  float *outputAC_data;
  int b_i;
  int i;
  inputAC_data = inputAC->data;
  i = outputAC->size[0];
  outputAC->size[0] = 150;
  emxEnsureCapacity_real32_T(outputAC, i);
  outputAC_data = outputAC->data;
  outputAC_tmp = maximum(inputAC);
  b_outputAC_tmp = minimum(inputAC);
  z = (outputAC_tmp + b_outputAC_tmp) / 2.0F;
  outputAC_tmp -= b_outputAC_tmp;
  for (b_i = 0; b_i < 150; b_i++) {
    outputAC_data[b_i] = (inputAC_data[b_i] - z) / outputAC_tmp * 2.0F;
  }
}

void b_ac_normalize(const emxArray_real32_T *inputAC,
                    emxArray_real32_T *outputAC)
{
  const float *inputAC_data;
  float maxval;
  float minval;
  float z;
  float *outputAC_data;
  int i;
  int i1;
  int loop_ub;
  inputAC_data = inputAC->data;
  maxval = b_maximum(inputAC);
  minval = b_minimum(inputAC);
  z = (maxval + minval) / 2.0F;
  maxval -= minval;
  loop_ub = inputAC->size[0];
  i = outputAC->size[0];
  outputAC->size[0] = inputAC->size[0];
  emxEnsureCapacity_real32_T(outputAC, i);
  outputAC_data = outputAC->data;
  for (i1 = 0; i1 < loop_ub; i1++) {
    outputAC_data[i1] = (inputAC_data[i1] - z) / maxval * 2.0F;
  }
}

/* End of code generation (ac_normalize.c) */
