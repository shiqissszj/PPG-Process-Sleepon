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
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
void ac_normalize(const emxArray_real32_T *inputAC,
                  emxArray_real32_T *outputAC);

void b_ac_normalize(const emxArray_real32_T *inputAC,
                    emxArray_real32_T *outputAC);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (ac_normalize.h) */
