/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * minOrMax.h
 *
 * Code generation for function 'minOrMax'
 *
 */

#ifndef MINORMAX_H
#define MINORMAX_H

/* Include files */
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
float b_maximum(const emxArray_real32_T *x);

float b_minimum(const emxArray_real32_T *x);

double c_maximum(const emxArray_real_T *x);

float maximum(const emxArray_real32_T *x);

float minimum(const emxArray_real32_T *x);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (minOrMax.h) */
