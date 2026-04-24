/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * a_corr.h
 *
 * Code generation for function 'a_corr'
 *
 */

#ifndef A_CORR_H
#define A_CORR_H

/* Include files */
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
double a_corr(const emxArray_real32_T *inputSig, float minLag, float maxLag,
              emxArray_real_T *corrValues);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (a_corr.h) */
