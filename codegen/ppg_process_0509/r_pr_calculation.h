/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * r_pr_calculation.h
 *
 * Code generation for function 'r_pr_calculation'
 *
 */

#ifndef R_PR_CALCULATION_H
#define R_PR_CALCULATION_H

/* Include files */
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
float r_pr_calculation(const emxArray_real32_T *b_windowR,
                       const emxArray_real32_T *b_windowIR,
                       const emxArray_real32_T *b_windowG,
                       unsigned int b_outputCounter, float bodyMove,
                       float *outputPR, float outputSQI[6],
                       float *outputConfidenceR, float *outputConfidenceG);

void r_pr_calculation_emx_free(void);

void r_pr_calculation_emx_init(void);

void r_pr_calculation_init(void);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (r_pr_calculation.h) */
