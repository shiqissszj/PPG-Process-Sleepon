/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ppg_process.c
 *
 * Code generation for function 'ppg_process'
 *
 */

/* Include files */
#include "ppg_process.h"
#include "calculate_spo2.h"
#include "ppg_process_data.h"
#include "ppg_process_initialize.h"
#include "pr_smoothing.h"
#include "r_pr_calculation.h"
#include "r_pr_fix.h"
#include "r_smoothing.h"
#include "rt_nonfinite.h"
#include <math.h>
#include <string.h>

/* Variable Definitions */
static float windowR[150];

static float windowIR[150];

static float windowG[150];

static unsigned int outputCounter;

static bool beginCalculation;

static bool bufferR_not_empty;

static bool bufferIR_not_empty;

static bool bufferG_not_empty;

/* Function Definitions */
void ppg_process(float inputSampleR, float inputSampleIR, float inputSampleG,
                 unsigned int inputCounter, float bodyMove, bool *outputFlag,
                 float *outputPR, float *outputSpO2, float outputPI_data[],
                 int outputPI_size[2], float *confidenceR, float *R)
{
  static float bufferG[50];
  static float bufferIR[50];
  static float bufferR[50];
  float b_confidenceR;
  float confidenceG;
  float fixedPR;
  float smoothedR;
  unsigned int b_qY;
  int i;
  unsigned int qY;
  if (!isInitialized_ppg_process) {
    ppg_process_initialize();
  }
  /*  paremeters */
  /*  Sampling rate in Hz */
  /*  Window length in seconds */
  /*  1 second step */
  /*  claim the static local buffer and variables */
  /*  persistent inputCounter; */
  if ((!bufferR_not_empty) || (!bufferIR_not_empty) || (!bufferG_not_empty)) {
    bufferR_not_empty = true;
    bufferIR_not_empty = true;
    memset(&bufferR[0], 0, 50U * sizeof(float));
    memset(&bufferIR[0], 0, 50U * sizeof(float));
    memset(&bufferG[0], 0, 50U * sizeof(float));
    bufferG_not_empty = true;
  }
  /*  initialize the static local buffer */
  /*  if isempty(inputCounter) */
  /*      inputCounter = 0; */
  /*  end */
  if (inputCounter == 1U) {
    /*  initialize */
    memset(&windowR[0], 0, 150U * sizeof(float));
    memset(&windowIR[0], 0, 150U * sizeof(float));
    memset(&windowG[0], 0, 150U * sizeof(float));
    outputCounter = 0U;
    beginCalculation = false;
  }
  /*  save the input sample in the buffer */
  qY = inputCounter - 1U;
  if (inputCounter - 1U > inputCounter) {
    qY = 0U;
  }
  qY -= qY / 50U * 50U;
  b_qY = qY + 1U;
  if (qY + 1U < qY) {
    b_qY = MAX_uint32_T;
  }
  bufferR[(int)b_qY - 1] = inputSampleR;
  bufferIR[(int)b_qY - 1] = inputSampleIR;
  bufferG[(int)b_qY - 1] = inputSampleG;
  /*  the calculation begins only if the buffer is full */
  if (inputCounter >= 150U) {
    beginCalculation = true;
  } else if (inputCounter - inputCounter / 50U * 50U == 0U) {
    for (i = 0; i < 100; i++) {
      windowR[i] = windowR[i + 50];
    }
    memcpy(&windowR[100], &bufferR[0], 50U * sizeof(float));
    for (i = 0; i < 100; i++) {
      windowIR[i] = windowIR[i + 50];
    }
    memcpy(&windowIR[100], &bufferIR[0], 50U * sizeof(float));
    for (i = 0; i < 100; i++) {
      windowG[i] = windowG[i + 50];
    }
    memcpy(&windowG[100], &bufferG[0], 50U * sizeof(float));
  }
  /*  calculation the output every stepSize samples */
  if (beginCalculation && (inputCounter - inputCounter / 50U * 50U == 0U)) {
    float PI[6];
    *outputFlag = true;
    qY = outputCounter + 1U;
    if (outputCounter + 1U < outputCounter) {
      qY = MAX_uint32_T;
    }
    outputCounter = qY;
    /*  update the process window */
    for (i = 0; i < 100; i++) {
      windowR[i] = windowR[i + 50];
    }
    memcpy(&windowR[100], &bufferR[0], 50U * sizeof(float));
    for (i = 0; i < 100; i++) {
      windowIR[i] = windowIR[i + 50];
    }
    memcpy(&windowIR[100], &bufferIR[0], 50U * sizeof(float));
    for (i = 0; i < 100; i++) {
      windowG[i] = windowG[i + 50];
    }
    float b_R;
    memcpy(&windowG[100], &bufferG[0], 50U * sizeof(float));
    /*  calculate the raw R and PR value as well as the confidence */
    b_R = r_pr_calculation(windowR, windowIR, windowG, outputCounter, bodyMove,
                           &smoothedR, PI, &b_confidenceR, &confidenceG);
    *R = b_R;
    /*  fix the R and PR value based on the confidence */
    smoothedR = r_pr_fix(b_R, smoothedR, b_confidenceR, confidenceG,
                         outputCounter, &fixedPR, confidenceR);
    /*  smooth the R and PR value */
    smoothedR = r_smoothing(smoothedR, outputCounter);
    *outputPR = pr_smoothing(fixedPR, outputCounter);
    *outputPR = roundf(*outputPR);
    *outputSpO2 = calculate_spo2(smoothedR);
    outputPI_size[0] = 1;
    outputPI_size[1] = 6;
    for (i = 0; i < 6; i++) {
      outputPI_data[i] = PI[i];
    }
  } else {
    *outputFlag = false;
    *outputPR = 0.0F;
    *outputSpO2 = 0.0F;
    /*  linearSpO2 = single(NaN); */
    outputPI_size[0] = 1;
    outputPI_size[1] = 1;
    outputPI_data[0] = 0.0F;
    *confidenceR = 0.0F;
    *R = 0.0F;
  }
}

void ppg_process_init(void)
{
  bufferG_not_empty = false;
  bufferIR_not_empty = false;
  bufferR_not_empty = false;
  memset(&windowR[0], 0, 150U * sizeof(float));
  memset(&windowIR[0], 0, 150U * sizeof(float));
  memset(&windowG[0], 0, 150U * sizeof(float));
  outputCounter = 0U;
  beginCalculation = false;
}

/* End of code generation (ppg_process.c) */
