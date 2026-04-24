/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * r_smoothing.c
 *
 * Code generation for function 'r_smoothing'
 *
 */

/* Include files */
#include "r_smoothing.h"
#include "median.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"

/* Variable Definitions */
static emxArray_real32_T *RSmoothBuffer1;

static bool RSmoothBuffer1_not_empty;

static emxArray_real32_T *RSmoothBuffer2;

static bool RSmoothBuffer2_not_empty;

/* Function Definitions */
float r_smoothing(float inputR, unsigned int b_outputCounter)
{
  emxArray_real32_T *r;
  float outputR;
  float *RSmoothBuffer1_data;
  float *RSmoothBuffer2_data;
  float *r1;
  int b_i;
  unsigned int b_qY;
  int i;
  unsigned int qY;
  RSmoothBuffer2_data = RSmoothBuffer2->data;
  RSmoothBuffer1_data = RSmoothBuffer1->data;
  /*  parameters */
  /*  smooth method 1: use moving median */
  /*  initialize the static local buffer */
  if ((!RSmoothBuffer1_not_empty) || (!RSmoothBuffer2_not_empty)) {
    RSmoothBuffer1_not_empty = true;
    i = RSmoothBuffer1->size[0];
    RSmoothBuffer1->size[0] = 30;
    emxEnsureCapacity_real32_T(RSmoothBuffer1, i);
    RSmoothBuffer1_data = RSmoothBuffer1->data;
    i = RSmoothBuffer2->size[0];
    RSmoothBuffer2->size[0] = 30;
    emxEnsureCapacity_real32_T(RSmoothBuffer2, i);
    RSmoothBuffer2_data = RSmoothBuffer2->data;
    for (b_i = 0; b_i < 30; b_i++) {
      RSmoothBuffer1_data[b_i] = 0.0F;
      RSmoothBuffer2_data[b_i] = 0.0F;
    }
    RSmoothBuffer2_not_empty = true;
  }
  if (b_outputCounter == 1U) {
    i = RSmoothBuffer1->size[0];
    RSmoothBuffer1->size[0] = 30;
    emxEnsureCapacity_real32_T(RSmoothBuffer1, i);
    RSmoothBuffer1_data = RSmoothBuffer1->data;
    i = RSmoothBuffer2->size[0];
    RSmoothBuffer2->size[0] = 30;
    emxEnsureCapacity_real32_T(RSmoothBuffer2, i);
    RSmoothBuffer2_data = RSmoothBuffer2->data;
    for (b_i = 0; b_i < 30; b_i++) {
      RSmoothBuffer1_data[b_i] = 0.0F;
      RSmoothBuffer2_data[b_i] = 0.0F;
    }
  }
  /*  Update the first buffer and compute the first level of smoothed values */
  /*  Circular buffer index */
  qY = b_outputCounter - 1U;
  if (b_outputCounter - 1U > b_outputCounter) {
    qY = 0U;
  }
  qY -= qY / 30U * 30U;
  b_qY = qY + 1U;
  if (qY + 1U < qY) {
    b_qY = MAX_uint32_T;
  }
  /*  Insert the new value */
  RSmoothBuffer1_data[(int)b_qY - 1] = inputR;
  /*  compute the first level of smoothed values */
  if (b_outputCounter >= 30U) {
    RSmoothBuffer2_data[(int)b_qY - 1] = median(RSmoothBuffer1);
    /*  Compute the median of the buffer */
    outputR = median(RSmoothBuffer2);
    /*  Compute the median of the buffer */
  } else {
    int loop_ub;
    emxInit_real32_T(&r);
    i = r->size[0];
    r->size[0] = (int)b_outputCounter;
    emxEnsureCapacity_real32_T(r, i);
    r1 = r->data;
    loop_ub = (int)b_outputCounter;
    for (b_i = 0; b_i < loop_ub; b_i++) {
      r1[b_i] = RSmoothBuffer1_data[b_i];
    }
    RSmoothBuffer2_data[(int)b_qY - 1] = b_median(r);
    /*  For initial values when buffer is not full */
    i = r->size[0];
    r->size[0] = (int)b_outputCounter;
    emxEnsureCapacity_real32_T(r, i);
    r1 = r->data;
    for (b_i = 0; b_i < loop_ub; b_i++) {
      r1[b_i] = RSmoothBuffer2_data[b_i];
    }
    outputR = b_median(r);
    emxFree_real32_T(&r);
    /*  For initial values when buffer is not full */
  }
  /*  Update the second buffer with the first level smoothed value and compute
   * the second level */
  /*  Insert the new value */
  /*  compute the second level of smoothed values */
  return outputR;
}

void r_smoothing_emx_free(void)
{
  emxFree_real32_T(&RSmoothBuffer1);
  emxFree_real32_T(&RSmoothBuffer2);
}

void r_smoothing_emx_init(void)
{
  int i;
  emxInit_real32_T(&RSmoothBuffer1);
  i = RSmoothBuffer1->size[0];
  RSmoothBuffer1->size[0] = 30;
  emxEnsureCapacity_real32_T(RSmoothBuffer1, i);
  emxInit_real32_T(&RSmoothBuffer2);
  i = RSmoothBuffer2->size[0];
  RSmoothBuffer2->size[0] = 30;
  emxEnsureCapacity_real32_T(RSmoothBuffer2, i);
}

void r_smoothing_init(void)
{
  RSmoothBuffer2_not_empty = false;
  RSmoothBuffer1_not_empty = false;
}

/* End of code generation (r_smoothing.c) */
