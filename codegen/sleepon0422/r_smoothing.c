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
#include "rt_nonfinite.h"
#include <string.h>

/* Variable Definitions */
static bool RSmoothBuffer1_not_empty;

static bool RSmoothBuffer2_not_empty;

/* Function Definitions */
float r_smoothing(float inputR, unsigned int b_outputCounter)
{
  static float RSmoothBuffer1[30];
  static float RSmoothBuffer2[30];
  float tmp_data[29];
  float outputR;
  unsigned int b_qY;
  unsigned int qY;
  /*  parameters */
  /*  smooth method 1: use moving median */
  /*  initialize the static local buffer */
  if ((!RSmoothBuffer1_not_empty) || (!RSmoothBuffer2_not_empty)) {
    RSmoothBuffer1_not_empty = true;
    memset(&RSmoothBuffer1[0], 0, 30U * sizeof(float));
    memset(&RSmoothBuffer2[0], 0, 30U * sizeof(float));
    RSmoothBuffer2_not_empty = true;
  }
  if (b_outputCounter == 1U) {
    memset(&RSmoothBuffer1[0], 0, 30U * sizeof(float));
    memset(&RSmoothBuffer2[0], 0, 30U * sizeof(float));
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
  RSmoothBuffer1[(int)b_qY - 1] = inputR;
  /*  compute the first level of smoothed values */
  if (b_outputCounter >= 30U) {
    RSmoothBuffer2[(int)b_qY - 1] = b_median(RSmoothBuffer1);
    /*  Compute the median of the buffer */
    outputR = b_median(RSmoothBuffer2);
    /*  Compute the median of the buffer */
  } else {
    int tmp_size;
    tmp_size = (int)b_outputCounter;
    if (tmp_size - 1 >= 0) {
      memcpy(&tmp_data[0], &RSmoothBuffer1[0],
             (unsigned int)tmp_size * sizeof(float));
    }
    RSmoothBuffer2[(int)b_qY - 1] = median(tmp_data, (int)b_outputCounter);
    /*  For initial values when buffer is not full */
    tmp_size = (int)b_outputCounter;
    if (tmp_size - 1 >= 0) {
      memcpy(&tmp_data[0], &RSmoothBuffer2[0],
             (unsigned int)tmp_size * sizeof(float));
    }
    outputR = median(tmp_data, (int)b_outputCounter);
    /*  For initial values when buffer is not full */
  }
  /*  Update the second buffer with the first level smoothed value and compute
   * the second level */
  /*  Insert the new value */
  /*  compute the second level of smoothed values */
  return outputR;
}

void r_smoothing_init(void)
{
  RSmoothBuffer2_not_empty = false;
  RSmoothBuffer1_not_empty = false;
}

/* End of code generation (r_smoothing.c) */
