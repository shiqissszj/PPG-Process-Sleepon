/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * mean.h
 *
 * Code generation for function 'mean'
 *
 */

#ifndef MEAN_H
#define MEAN_H

/* Include files */
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
float b_mean(const emxArray_real32_T *x);

float c_mean(const float x[30]);

float d_mean(const float x_data[], int x_size);

float e_mean(const float x[25]);

double mean(const emxArray_real_T *x);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (mean.h) */
