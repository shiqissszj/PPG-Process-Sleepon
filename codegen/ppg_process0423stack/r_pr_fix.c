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
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"

/* Variable Definitions */
static emxArray_real32_T *fixBufferR;

static bool fixBufferR_not_empty;

static emxArray_real32_T *fixBufferPR;

static bool fixBufferPR_not_empty;

static emxArray_real32_T *confidenceBuffer;

static bool confidenceBuffer_not_empty;

static bool reliableCounterR_not_empty;

static bool reliableCounterG_not_empty;

static bool prSeeded_not_empty;

/* Function Definitions */
float r_pr_fix(float inputR, float inputPR, float confidenceR,
               float confidenceG, unsigned int b_outputCounter, float *outputPR,
               float *outputConfidenceR)
{
  static unsigned int reliableCounterG;
  static unsigned int reliableCounterR;
  static bool prSeeded;
  emxArray_real32_T *r;
  emxArray_real32_T *r2;
  emxArray_real32_T *r3;
  float fallbackPR;
  float outputR;
  float *confidenceBuffer_data;
  float *fixBufferPR_data;
  float *fixBufferR_data;
  float *r1;
  int b_loop_ub;
  unsigned int b_qY;
  int i;
  int loop_ub;
  unsigned int qY;
  confidenceBuffer_data = confidenceBuffer->data;
  fixBufferPR_data = fixBufferPR->data;
  fixBufferR_data = fixBufferR->data;
  /*  smooth the confidence */
  /*  fix the output if the confidence is low */
  /*  parameters */
  /*  initialize the static local buffer */
  if (b_outputCounter == 1U) {
    fixBufferR_not_empty = true;
    loop_ub = fixBufferR->size[0];
    fixBufferR->size[0] = 25;
    emxEnsureCapacity_real32_T(fixBufferR, loop_ub);
    fixBufferR_data = fixBufferR->data;
    loop_ub = fixBufferPR->size[0];
    fixBufferPR->size[0] = 25;
    emxEnsureCapacity_real32_T(fixBufferPR, loop_ub);
    fixBufferPR_data = fixBufferPR->data;
    for (i = 0; i < 25; i++) {
      fixBufferR_data[i] = 0.0F;
      fixBufferPR_data[i] = 0.0F;
    }
    fixBufferPR_not_empty = true;
    loop_ub = confidenceBuffer->size[0];
    confidenceBuffer->size[0] = 30;
    emxEnsureCapacity_real32_T(confidenceBuffer, loop_ub);
    confidenceBuffer_data = confidenceBuffer->data;
    for (i = 0; i < 30; i++) {
      confidenceBuffer_data[i] = 0.0F;
    }
    confidenceBuffer_not_empty = true;
    reliableCounterR = 0U;
    reliableCounterR_not_empty = true;
    reliableCounterG = 0U;
    reliableCounterG_not_empty = true;
    prSeeded = false;
    prSeeded_not_empty = true;
  }
  if (!fixBufferR_not_empty) {
    loop_ub = fixBufferR->size[0];
    fixBufferR->size[0] = 25;
    emxEnsureCapacity_real32_T(fixBufferR, loop_ub);
    fixBufferR_data = fixBufferR->data;
    for (i = 0; i < 25; i++) {
      fixBufferR_data[i] = 0.0F;
    }
    fixBufferR_not_empty = true;
  }
  if (!fixBufferPR_not_empty) {
    loop_ub = fixBufferPR->size[0];
    fixBufferPR->size[0] = 25;
    emxEnsureCapacity_real32_T(fixBufferPR, loop_ub);
    fixBufferPR_data = fixBufferPR->data;
    for (i = 0; i < 25; i++) {
      fixBufferPR_data[i] = 0.0F;
    }
    fixBufferPR_not_empty = true;
  }
  if (!confidenceBuffer_not_empty) {
    loop_ub = confidenceBuffer->size[0];
    confidenceBuffer->size[0] = 30;
    emxEnsureCapacity_real32_T(confidenceBuffer, loop_ub);
    confidenceBuffer_data = confidenceBuffer->data;
    for (i = 0; i < 30; i++) {
      confidenceBuffer_data[i] = 0.0F;
    }
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
  confidenceBuffer_data[(int)b_qY - 1] = confidenceR;
  /*  if confidenceR>0.6 */
  /*      confidenceBuffer(confidenceBufferIndex) = confidenceR; */
  /*  else */
  /*      confidenceBuffer(confidenceBufferIndex) = 0; */
  /*  end */
  if (confidenceR > 0.0F) {
    if (b_outputCounter > 30U) {
      *outputConfidenceR = c_mean(confidenceBuffer);
      /*  outputConfidenceR = min(mean(confidenceBuffer),confidenceR); */
    } else {
      emxInit_real32_T(&r);
      loop_ub = r->size[0];
      r->size[0] = (int)b_outputCounter;
      emxEnsureCapacity_real32_T(r, loop_ub);
      r1 = r->data;
      loop_ub = (int)b_outputCounter;
      for (i = 0; i < loop_ub; i++) {
        r1[i] = confidenceBuffer_data[i];
      }
      *outputConfidenceR = d_mean(r);
      emxFree_real32_T(&r);
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
    loop_ub = fixBufferPR->size[0];
    fixBufferPR->size[0] = 25;
    emxEnsureCapacity_real32_T(fixBufferPR, loop_ub);
    fixBufferPR_data = fixBufferPR->data;
    for (i = 0; i < 25; i++) {
      fixBufferPR_data[i] = inputPR;
    }
    if (reliableCounterG < 1U) {
      reliableCounterG = 1U;
    }
    prSeeded = true;
  }
  /*  Circular buffer index */
  emxInit_real32_T(&r2);
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
      b_loop_ub = (int)qY;
      loop_ub = r2->size[0];
      r2->size[0] = (int)qY;
      emxEnsureCapacity_real32_T(r2, loop_ub);
      confidenceBuffer_data = r2->data;
      for (i = 0; i < b_loop_ub; i++) {
        confidenceBuffer_data[i] = fixBufferR_data[i];
      }
      outputR = d_mean(r2);
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
  emxFree_real32_T(&r2);
  if (confidenceG < 0.55F) {
    /*  fix the R and PR value */
    if (reliableCounterG > 25U) {
      fallbackPR = e_mean(fixBufferPR);
    } else if (reliableCounterG > 1U) {
      qY = reliableCounterG - 1U;
      if (reliableCounterG - 1U > reliableCounterG) {
        qY = 0U;
      }
      b_loop_ub = (int)qY;
      emxInit_real32_T(&r3);
      loop_ub = r3->size[0];
      r3->size[0] = (int)qY;
      emxEnsureCapacity_real32_T(r3, loop_ub);
      confidenceBuffer_data = r3->data;
      for (i = 0; i < b_loop_ub; i++) {
        confidenceBuffer_data[i] = fixBufferPR_data[i];
      }
      fallbackPR = d_mean(r3);
      emxFree_real32_T(&r3);
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
    fixBufferR_data[(int)b_qY - 1] = outputR;
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
    fixBufferPR_data[(int)b_qY - 1] = fallbackPR;
    /*  fixBufferPR = [fixBufferPR(2:fixBufferSize);fixedPR]; */
  }
  *outputPR = fallbackPR;
  return outputR;
}

void r_pr_fix_emx_free(void)
{
  emxFree_real32_T(&fixBufferR);
  emxFree_real32_T(&fixBufferPR);
  emxFree_real32_T(&confidenceBuffer);
}

void r_pr_fix_emx_init(void)
{
  int i;
  emxInit_real32_T(&fixBufferR);
  i = fixBufferR->size[0];
  fixBufferR->size[0] = 25;
  emxEnsureCapacity_real32_T(fixBufferR, i);
  emxInit_real32_T(&fixBufferPR);
  i = fixBufferPR->size[0];
  fixBufferPR->size[0] = 25;
  emxEnsureCapacity_real32_T(fixBufferPR, i);
  emxInit_real32_T(&confidenceBuffer);
  i = confidenceBuffer->size[0];
  confidenceBuffer->size[0] = 30;
  emxEnsureCapacity_real32_T(confidenceBuffer, i);
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
