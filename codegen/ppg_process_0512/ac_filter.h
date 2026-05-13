/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ac_filter.h
 *
 * Code generation for function 'ac_filter'
 *
 */

#ifndef AC_FILTER_H
#define AC_FILTER_H

/* Include files */
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
double ac_filter(emxArray_real32_T *inputAC);

void ac_filter_emx_free(void);

void ac_filter_emx_init(void);

void ac_filter_init(void);

double b_ac_filter(emxArray_real32_T *inputAC);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (ac_filter.h) */
