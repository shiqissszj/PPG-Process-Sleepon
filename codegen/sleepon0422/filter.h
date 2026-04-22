/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * filter.h
 *
 * Code generation for function 'filter'
 *
 */

#ifndef FILTER_H
#define FILTER_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
int b_filter(const float x_data[], int x_size, float y_data[]);

void filter(const float b[7], const float a[7], const float x[150],
            float y[150]);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (filter.h) */
