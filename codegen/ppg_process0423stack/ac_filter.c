/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ac_filter.c
 *
 * Code generation for function 'ac_filter'
 *
 */

/* Include files */
#include "ac_filter.h"
#include "fill_outliers.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"

/* Variable Definitions */
static emxArray_real32_T *forwardBuffer;

static emxArray_real32_T *reverseBuffer;

static const float fv[7] = {0.00716766F, 0.0F, -0.021503F,  0.0F,
                            0.021503F,   0.0F, -0.00716766F};

static const float fv1[7] = {1.0F,         -5.04456758F, 10.6946774F,
                             -12.2173738F, 7.94145632F,  -2.78601027F,
                             0.411839128F};

/* Function Definitions */
double ac_filter(emxArray_real32_T *inputAC)
{
  double outlierNum;
  float accValue;
  float *b_inputAC_data;
  float *forwardBuffer_data;
  float *inputAC_data;
  float *reverseBuffer_data;
  int i;
  int inputIdx;
  int sampleIdx;
  reverseBuffer_data = reverseBuffer->data;
  forwardBuffer_data = forwardBuffer->data;
  inputAC_data = inputAC->data;
  emxInit_real32_T(&inputAC);
  inputIdx = inputAC->size[0];
  inputAC->size[0] = 150;
  emxEnsureCapacity_real32_T(inputAC, inputIdx);
  b_inputAC_data = inputAC->data;
  /*  threshold for outlier filter */
  /*  use customized filloutliers function */
  for (i = 0; i < 150; i++) {
    b_inputAC_data[i] = inputAC_data[i];
  }
  outlierNum = fill_outliers(inputAC);
  b_inputAC_data = inputAC->data;
  /*  use zero-phase digital filter */
  /*  a, b are parameters for butter bandpass filter */
  /*  [b, a] = butter(3, [0.5/(0.5*50), 4/(0.5*50)], 'bandpass'); */
  for (sampleIdx = 0; sampleIdx < 150; sampleIdx++) {
    accValue = 0.0F;
    for (i = 0; i < 7; i++) {
      inputIdx = sampleIdx - i;
      if (inputIdx >= 0) {
        accValue += fv[i] * b_inputAC_data[inputIdx];
      }
    }
    for (i = 0; i < 6; i++) {
      inputIdx = sampleIdx - i;
      if (inputIdx >= 1) {
        accValue -= fv1[i + 1] * forwardBuffer_data[inputIdx - 1];
      }
    }
    forwardBuffer_data[sampleIdx] = accValue;
  }
  emxFree_real32_T(&inputAC);
  for (i = 0; i < 150; i++) {
    reverseBuffer_data[i] = forwardBuffer_data[149 - i];
  }
  for (sampleIdx = 0; sampleIdx < 150; sampleIdx++) {
    accValue = 0.0F;
    for (i = 0; i < 7; i++) {
      inputIdx = sampleIdx - i;
      if (inputIdx >= 0) {
        accValue += fv[i] * reverseBuffer_data[inputIdx];
      }
    }
    for (i = 0; i < 6; i++) {
      inputIdx = sampleIdx - i;
      if (inputIdx >= 1) {
        accValue -= fv1[i + 1] * forwardBuffer_data[inputIdx - 1];
      }
    }
    forwardBuffer_data[sampleIdx] = accValue;
  }
  for (i = 0; i < 150; i++) {
    inputAC_data[i] = forwardBuffer_data[149 - i];
  }
  return outlierNum;
}

void ac_filter_emx_free(void)
{
  emxFree_real32_T(&forwardBuffer);
  emxFree_real32_T(&reverseBuffer);
}

void ac_filter_emx_init(void)
{
  int i;
  emxInit_real32_T(&forwardBuffer);
  i = forwardBuffer->size[0];
  forwardBuffer->size[0] = 300;
  emxEnsureCapacity_real32_T(forwardBuffer, i);
  emxInit_real32_T(&reverseBuffer);
  i = reverseBuffer->size[0];
  reverseBuffer->size[0] = 300;
  emxEnsureCapacity_real32_T(reverseBuffer, i);
}

void ac_filter_init(void)
{
  float *forwardBuffer_data;
  float *reverseBuffer_data;
  int b_i;
  int i;
  i = forwardBuffer->size[0];
  forwardBuffer->size[0] = 300;
  emxEnsureCapacity_real32_T(forwardBuffer, i);
  forwardBuffer_data = forwardBuffer->data;
  i = reverseBuffer->size[0];
  reverseBuffer->size[0] = 300;
  emxEnsureCapacity_real32_T(reverseBuffer, i);
  reverseBuffer_data = reverseBuffer->data;
  for (b_i = 0; b_i < 300; b_i++) {
    forwardBuffer_data[b_i] = 0.0F;
    reverseBuffer_data[b_i] = 0.0F;
  }
}

double b_ac_filter(emxArray_real32_T *inputAC)
{
  double outlierNum;
  float accValue;
  float *forwardBuffer_data;
  float *inputAC_data;
  float *reverseBuffer_data;
  int coeffIdx;
  int i;
  int inputIdx;
  int sampleCount;
  int sampleIdx;
  reverseBuffer_data = reverseBuffer->data;
  forwardBuffer_data = forwardBuffer->data;
  /*  threshold for outlier filter */
  /*  use customized filloutliers function */
  outlierNum = b_fill_outliers(inputAC);
  inputAC_data = inputAC->data;
  /*  use zero-phase digital filter */
  /*  a, b are parameters for butter bandpass filter */
  /*  [b, a] = butter(3, [0.5/(0.5*50), 4/(0.5*50)], 'bandpass'); */
  sampleCount = inputAC->size[0] - 1;
  i = inputAC->size[0];
  for (sampleIdx = 0; sampleIdx < i; sampleIdx++) {
    accValue = 0.0F;
    for (coeffIdx = 0; coeffIdx < 7; coeffIdx++) {
      inputIdx = sampleIdx - coeffIdx;
      if (inputIdx >= 0) {
        accValue += fv[coeffIdx] * inputAC_data[inputIdx];
      }
    }
    for (coeffIdx = 0; coeffIdx < 6; coeffIdx++) {
      inputIdx = sampleIdx - coeffIdx;
      if (inputIdx >= 1) {
        accValue -= fv1[coeffIdx + 1] * forwardBuffer_data[inputIdx - 1];
      }
    }
    forwardBuffer_data[sampleIdx] = accValue;
  }
  for (coeffIdx = 0; coeffIdx < i; coeffIdx++) {
    reverseBuffer_data[coeffIdx] = forwardBuffer_data[sampleCount - coeffIdx];
  }
  for (sampleIdx = 0; sampleIdx < i; sampleIdx++) {
    accValue = 0.0F;
    for (coeffIdx = 0; coeffIdx < 7; coeffIdx++) {
      inputIdx = sampleIdx - coeffIdx;
      if (inputIdx >= 0) {
        accValue += fv[coeffIdx] * reverseBuffer_data[inputIdx];
      }
    }
    for (coeffIdx = 0; coeffIdx < 6; coeffIdx++) {
      inputIdx = sampleIdx - coeffIdx;
      if (inputIdx >= 1) {
        accValue -= fv1[coeffIdx + 1] * forwardBuffer_data[inputIdx - 1];
      }
    }
    forwardBuffer_data[sampleIdx] = accValue;
  }
  for (coeffIdx = 0; coeffIdx < i; coeffIdx++) {
    inputAC_data[coeffIdx] = forwardBuffer_data[sampleCount - coeffIdx];
  }
  return outlierNum;
}

/* End of code generation (ac_filter.c) */
