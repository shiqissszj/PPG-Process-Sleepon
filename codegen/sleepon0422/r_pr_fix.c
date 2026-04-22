/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * r_pr_fix.c
 *
 * Code generation for function 'r_pr_fix'
 *
 */

/* Include files */
#include "r_pr_fix.h"
#include "mean.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"
#include <string.h>

/* Variable Definitions */
static bool fixBufferR_not_empty;

static bool fixBufferPR_not_empty;

static bool confidenceBuffer_not_empty;

static bool reliableCounterR_not_empty;

static bool reliableCounterG_not_empty;

static bool prSeeded_not_empty;

/* Function Definitions */
float r_pr_fix(float inputR, float inputPR, float confidenceR,
               float confidenceG, unsigned int b_outputCounter, float *outputPR,
               float *outputConfidenceR)
{
  static float confidenceBuffer[30];
  static float fixBufferPR[25];
  static float fixBufferR[25];
  static unsigned int reliableCounterG;
  static unsigned int reliableCounterR;
  static bool prSeeded;
  float tmp_data[30];
  float c_tmp_data[24];
  float b_tmp_data[23];
  float fallbackPR;
  float outputR;
  unsigned int b_qY;
  int i;
  int loop_ub;
  unsigned int qY;
  /*  smooth the confidence */
  /*  fix the output if the confidence is low */
  /*  parameters */
  /*  initialize the static local buffer */
  if (b_outputCounter == 1U) {
    fixBufferR_not_empty = true;
    memset(&fixBufferR[0], 0, 25U * sizeof(float));
    memset(&fixBufferPR[0], 0, 25U * sizeof(float));
    fixBufferPR_not_empty = true;
    memset(&confidenceBuffer[0], 0, 30U * sizeof(float));
    confidenceBuffer_not_empty = true;
    reliableCounterR = 0U;
    reliableCounterR_not_empty = true;
    reliableCounterG = 0U;
    reliableCounterG_not_empty = true;
    prSeeded = false;
    prSeeded_not_empty = true;
  }
  if (!fixBufferR_not_empty) {
    memset(&fixBufferR[0], 0, 25U * sizeof(float));
    fixBufferR_not_empty = true;
  }
  if (!fixBufferPR_not_empty) {
    memset(&fixBufferPR[0], 0, 25U * sizeof(float));
    fixBufferPR_not_empty = true;
  }
  if (!confidenceBuffer_not_empty) {
    memset(&confidenceBuffer[0], 0, 30U * sizeof(float));
    confidenceBuffer_not_empty = true;
  }
  if (!reliableCounterR_not_empty) {
    reliableCounterR = 0U;
    reliableCounterR_not_empty = true;
  }
  if (!reliableCounterG_not_empty) {
    reliableCounterG = 0U;
    reliableCounterG_not_empty = true;
  }
  if (!prSeeded_not_empty) {
    prSeeded = false;
    prSeeded_not_empty = true;
  }
  /*  smooth the confidence */
  qY = b_outputCounter - 1U;
  if (b_outputCounter - 1U > b_outputCounter) {
    qY = 0U;
  }
  qY -= qY / 30U * 30U;
  b_qY = qY + 1U;
  if (qY + 1U < qY) {
    b_qY = MAX_uint32_T;
  }
  confidenceBuffer[(int)b_qY - 1] = confidenceR;
  /*  if confidenceR>0.6 */
  /*      confidenceBuffer(confidenceBufferIndex) = confidenceR; */
  /*  else */
  /*      confidenceBuffer(confidenceBufferIndex) = 0; */
  /*  end */
  if (confidenceR > 0.0F) {
    if (b_outputCounter > 30U) {
      *outputConfidenceR = d_mean(confidenceBuffer);
      /*  outputConfidenceR = min(mean(confidenceBuffer),confidenceR); */
    } else {
      loop_ub = (int)b_outputCounter;
      if (loop_ub - 1 >= 0) {
        memcpy(&tmp_data[0], &confidenceBuffer[0],
               (unsigned int)loop_ub * sizeof(float));
      }
      *outputConfidenceR = b_mean(tmp_data, (int)b_outputCounter);
      /*  outputConfidenceR =
       * min(mean(confidenceBuffer(1:outputCounter-1)),confidenceR); */
    }
  } else {
    *outputConfidenceR = 0.0F;
  }
  if (*outputConfidenceR > 0.45F) {
    qY = reliableCounterR + 1U;
    if (reliableCounterR + 1U < reliableCounterR) {
      qY = MAX_uint32_T;
    }
    reliableCounterR = qY;
  }
  if (confidenceG > 0.55F) {
    qY = reliableCounterG + 1U;
    if (reliableCounterG + 1U < reliableCounterG) {
      qY = MAX_uint32_T;
    }
    reliableCounterG = qY;
  }
  if ((!prSeeded) && (inputPR > 0.0F) && (confidenceG > 0.35F)) {
    for (i = 0; i < 25; i++) {
      fixBufferPR[i] = inputPR;
    }
    if (reliableCounterG < 1U) {
      reliableCounterG = 1U;
    }
    prSeeded = true;
  }
  /*  Circular buffer index */
  if ((*outputConfidenceR < 0.45F) || (confidenceR < 0.45F)) {
    /*  fix the R and PR value */
    if (reliableCounterR >= 25U) {
      outputR = e_mean(fixBufferR);
      if ((!rtIsInfF(inputR)) && (!rtIsNaNF(inputR)) && (inputR > 0.0F)) {
        outputR = outputR * (1.0F - confidenceR) + inputR * confidenceR;
      }
    } else if (reliableCounterR > 1U) {
      qY = reliableCounterR - 1U;
      if (reliableCounterR - 1U > reliableCounterR) {
        qY = 0U;
      }
      loop_ub = (int)qY;
      if (loop_ub - 1 >= 0) {
        memcpy(&b_tmp_data[0], &fixBufferR[0],
               (unsigned int)loop_ub * sizeof(float));
      }
      outputR = b_mean(b_tmp_data, (int)qY);
      if ((!rtIsInfF(inputR)) && (!rtIsNaNF(inputR)) && (inputR > 0.0F)) {
        outputR = outputR * (1.0F - confidenceR) + inputR * confidenceR;
      }
    } else if ((!rtIsInfF(inputR)) && (!rtIsNaNF(inputR)) && (inputR > 0.0F)) {
      outputR = 0.35F * (1.0F - confidenceR) + inputR * confidenceR;
    } else {
      outputR = 0.35F;
    }
  } else {
    /*  keep the original value */
    outputR = inputR;
  }
  if (confidenceG < 0.55F) {
    /*  fix the R and PR value */
    if (reliableCounterG > 25U) {
      fallbackPR = e_mean(fixBufferPR);
    } else if (reliableCounterG > 1U) {
      qY = reliableCounterG - 1U;
      if (reliableCounterG - 1U > reliableCounterG) {
        qY = 0U;
      }
      loop_ub = (int)qY;
      if (loop_ub - 1 >= 0) {
        memcpy(&c_tmp_data[0], &fixBufferPR[0],
               (unsigned int)loop_ub * sizeof(float));
      }
      fallbackPR = b_mean(c_tmp_data, (int)qY);
    } else {
      fallbackPR = 60.0F;
    }
    if ((inputPR > 0.0F) && (confidenceG > 0.35F)) {
      float prBlend;
      prBlend = (confidenceG - 0.35F) / 0.200000018F;
      fallbackPR = fallbackPR * (1.0F - prBlend) + inputPR * prBlend;
    } else if ((inputPR > 0.0F) && (reliableCounterG == 0U)) {
      fallbackPR = inputPR;
    }
  } else {
    /*  keep the original value */
    fallbackPR = inputPR;
  }
  /*  update the buffer for fix */
  if (*outputConfidenceR >= 0.45F) {
    /* || outputCounter <= fixBufferSize  */
    qY = reliableCounterR - 1U;
    if (reliableCounterR - 1U > reliableCounterR) {
      qY = 0U;
    }
    qY -= qY / 25U * 25U;
    b_qY = qY + 1U;
    if (qY + 1U < qY) {
      b_qY = MAX_uint32_T;
    }
    fixBufferR[(int)b_qY - 1] = outputR;
    /*  fixBufferR = [fixBufferR(2:fixBufferSize);fixedR]; */
  }
  if (confidenceG >= 0.55F) {
    /* || outputCounter <= fixBufferSize  */
    qY = reliableCounterG - 1U;
    if (reliableCounterG - 1U > reliableCounterG) {
      qY = 0U;
    }
    qY -= qY / 25U * 25U;
    b_qY = qY + 1U;
    if (qY + 1U < qY) {
      b_qY = MAX_uint32_T;
    }
    fixBufferPR[(int)b_qY - 1] = fallbackPR;
    /*  fixBufferPR = [fixBufferPR(2:fixBufferSize);fixedPR]; */
  }
  *outputPR = fallbackPR;
  return outputR;
}

void r_pr_fix_init(void)
{
  prSeeded_not_empty = false;
  reliableCounterG_not_empty = false;
  reliableCounterR_not_empty = false;
  confidenceBuffer_not_empty = false;
  fixBufferPR_not_empty = false;
  fixBufferR_not_empty = false;
}

/* End of code generation (r_pr_fix.c) */
