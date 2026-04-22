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
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
double ac_filter(float inputAC[150]);

double b_ac_filter(float inputAC_data[], int *inputAC_size);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (ac_filter.h) */
