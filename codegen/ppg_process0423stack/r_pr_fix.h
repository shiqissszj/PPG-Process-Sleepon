/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * r_pr_fix.h
 *
 * Code generation for function 'r_pr_fix'
 *
 */

#ifndef R_PR_FIX_H
#define R_PR_FIX_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
float r_pr_fix(float inputR, float inputPR, float confidenceR,
               float confidenceG, unsigned int b_outputCounter, float *outputPR,
               float *outputConfidenceR);

void r_pr_fix_emx_free(void);

void r_pr_fix_emx_init(void);

void r_pr_fix_init(void);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (r_pr_fix.h) */
