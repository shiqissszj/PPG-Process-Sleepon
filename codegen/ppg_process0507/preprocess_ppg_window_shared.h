/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * preprocess_ppg_window_shared.h
 *
 * Code generation for function 'preprocess_ppg_window_shared'
 *
 */

#ifndef PREPROCESS_PPG_WINDOW_SHARED_H
#define PREPROCESS_PPG_WINDOW_SHARED_H

/* Include files */
#include "ppg_process_types.h"
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
double preprocess_ppg_window_shared(
    const emxArray_real32_T *b_windowR, const emxArray_real32_T *b_windowIR,
    const emxArray_real32_T *b_windowG, emxArray_real_T *dcR,
    emxArray_real_T *dcIR, emxArray_real_T *dcG, emxArray_real32_T *acGRaw,
    emxArray_real32_T *acR, emxArray_real32_T *acIR, emxArray_real32_T *acG,
    emxArray_real32_T *ppgFilteredR, emxArray_real32_T *ppgFilteredIR,
    emxArray_real32_T *ppgFilteredG, emxArray_real32_T *ppgNormalizedG,
    int *delayR, int *delayIR);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (preprocess_ppg_window_shared.h) */
