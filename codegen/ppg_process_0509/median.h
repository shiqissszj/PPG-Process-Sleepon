/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * median.h
 *
 * Code generation for function 'median'
 *
 */

#ifndef MEDIAN_H
#define MEDIAN_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
float b_median(const float x_data[], int x_size);

float c_median(const float x[10]);

float median(const float x[30]);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (median.h) */
