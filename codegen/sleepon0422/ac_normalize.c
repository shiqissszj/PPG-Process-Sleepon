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
#include "rt_nonfinite.h"

/* Function Definitions */
void ac_normalize(const float inputAC[150], float outputAC[150])
{
  float b_outputAC_tmp;
  float outputAC_tmp;
  float z;
  int i;
  outputAC_tmp = maximum(inputAC);
  b_outputAC_tmp = minimum(inputAC);
  z = (outputAC_tmp + b_outputAC_tmp) / 2.0F;
  outputAC_tmp -= b_outputAC_tmp;
  for (i = 0; i < 150; i++) {
    outputAC[i] = (inputAC[i] - z) / outputAC_tmp * 2.0F;
  }
}

int b_ac_normalize(const float inputAC_data[], int inputAC_size,
                   float outputAC_data[])
{
  float maxval;
  float minval;
  float z;
  int i;
  int outputAC_size;
  maxval = b_maximum(inputAC_data, inputAC_size);
  minval = b_minimum(inputAC_data, inputAC_size);
  z = (maxval + minval) / 2.0F;
  maxval -= minval;
  outputAC_size = inputAC_size;
  for (i = 0; i < inputAC_size; i++) {
    outputAC_data[i] = (inputAC_data[i] - z) / maxval * 2.0F;
  }
  return outputAC_size;
}

/* End of code generation (ac_normalize.c) */
