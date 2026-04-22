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
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
float b_mean(const float x_data[], int x_size);

double c_mean(const double x[150]);

float d_mean(const float x[30]);

float e_mean(const float x[25]);

float mean(const float x[150]);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (mean.h) */
