/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * quickselect.h
 *
 * Code generation for function 'quickselect'
 *
 */

#ifndef QUICKSELECT_H
#define QUICKSELECT_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
float b_quickselect(float v[30], int n, int vlen, int *nfirst, int *nlast);

float c_quickselect(float v[10], int n, int vlen, int *nfirst, int *nlast);

float quickselect(float v_data[], int n, int vlen, int *nfirst, int *nlast);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (quickselect.h) */
