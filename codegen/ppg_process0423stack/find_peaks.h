/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * find_peaks.h
 *
 * Code generation for function 'find_peaks'
 *
 */

#ifndef FIND_PEAKS_H
#define FIND_PEAKS_H

/* Include files */
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
void b_find_peaks(const emxArray_real32_T *inputSig, float minDistance,
                  emxArray_real32_T *peaks, emxArray_real32_T *locs);

void find_peaks(const emxArray_real32_T *inputSig, emxArray_real32_T *peaks,
                emxArray_real32_T *locs);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (find_peaks.h) */
