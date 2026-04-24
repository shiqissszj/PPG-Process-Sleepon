/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * pr_smoothing.c
 *
 * Code generation for function 'pr_smoothing'
 *
 */

/* Include files */
#include "pr_smoothing.h"
#include "median.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include <string.h>

/* Variable Definitions */
static float PRSmoothBuffer[10];

/* Function Definitions */
float pr_smoothing(float inputPR, unsigned int b_outputCounter)
{
  emxArray_real32_T c_tmp_data;
  float b_tmp_data[9];
  float tmp_data[7];
  float outputPR;
  unsigned int b_qY;
  int i;
  unsigned int qY;
  int tmp_size;
  /*  parameters */
  /*  initialize the static local buffer */
  if (b_outputCounter == 1U) {
    for (i = 0; i < 10; i++) {
      PRSmoothBuffer[i] = 0.0F;
    }
  }
  /*  Circular buffer index */
  /*  Insert the new value */
  qY = b_outputCounter - 1U;
  if (b_outputCounter - 1U > b_outputCounter) {
    qY = 0U;
  }
  qY -= qY / 10U * 10U;
  b_qY = qY + 1U;
  if (qY + 1U < qY) {
    b_qY = MAX_uint32_T;
  }
  PRSmoothBuffer[(int)b_qY - 1] = inputPR;
  if (b_outputCounter <= 4U) {
    outputPR = inputPR;
  } else if (b_outputCounter <= 7U) {
    tmp_size = 5;
    for (i = 0; i < 5; i++) {
      tmp_data[i] = PRSmoothBuffer[((int)b_outputCounter + i) - 5];
    }
    c_tmp_data.data = &tmp_data[0];
    c_tmp_data.size = &tmp_size;
    c_tmp_data.allocatedSize = 7;
    c_tmp_data.numDimensions = 1;
    c_tmp_data.canFreeData = false;
    outputPR = b_median(&c_tmp_data);
  } else if (b_outputCounter >= 10U) {
    outputPR = c_median(PRSmoothBuffer);
    /*  Compute the median of the buffer */
  } else {
    tmp_size = (int)b_outputCounter;
    memcpy(&b_tmp_data[0], &PRSmoothBuffer[0],
           (unsigned int)tmp_size * sizeof(float));
    c_tmp_data.data = &b_tmp_data[0];
    c_tmp_data.size = &tmp_size;
    c_tmp_data.allocatedSize = 9;
    c_tmp_data.numDimensions = 1;
    c_tmp_data.canFreeData = false;
    outputPR = b_median(&c_tmp_data);
    /*  For initial values when buffer is not full */
  }
  return outputPR;
}

void pr_smoothing_init(void)
{
  int i;
  for (i = 0; i < 10; i++) {
    PRSmoothBuffer[i] = 0.0F;
  }
}

/* End of code generation (pr_smoothing.c) */
