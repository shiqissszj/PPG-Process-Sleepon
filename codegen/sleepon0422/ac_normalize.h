/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ac_normalize.h
 *
 * Code generation for function 'ac_normalize'
 *
 */

#ifndef AC_NORMALIZE_H
#define AC_NORMALIZE_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
void ac_normalize(const float inputAC[150], float outputAC[150]);

int b_ac_normalize(const float inputAC_data[], int inputAC_size,
                   float outputAC_data[]);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (ac_normalize.h) */
