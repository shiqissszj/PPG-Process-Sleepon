/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * smooth_data.h
 *
 * Code generation for function 'smooth_data'
 *
 */

#ifndef SMOOTH_DATA_H
#define SMOOTH_DATA_H

/* Include files */
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
void smooth_data(const emxArray_real32_T *signalIn,
                 emxArray_real_T *smoothedSignal);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (smooth_data.h) */
