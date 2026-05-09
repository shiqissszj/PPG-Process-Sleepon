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
#include "rt_nonfinite.h"
#include <string.h>

/* Variable Definitions */
static float PRSmoothBuffer[10];

/* Function Definitions */
float pr_smoothing(float inputPR, unsigned int b_outputCounter)
{
  float b_tmp_data[9];
  float outputPR;
  unsigned int b_qY;
  int i;
  unsigned int qY;
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
    float tmp_data[7];
    for (i = 0; i < 5; i++) {
      tmp_data[i] = PRSmoothBuffer[((int)b_outputCounter + i) - 5];
    }
    outputPR = b_median(tmp_data, 5);
  } else if (b_outputCounter >= 10U) {
    outputPR = c_median(PRSmoothBuffer);
    /*  Compute the median of the buffer */
  } else {
    int tmp_size;
    tmp_size = (int)b_outputCounter;
    memcpy(&b_tmp_data[0], &PRSmoothBuffer[0],
           (unsigned int)tmp_size * sizeof(float));
    outputPR = b_median(b_tmp_data, (int)b_outputCounter);
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
