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
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
double preprocess_ppg_window_shared(
    const float b_windowR[150], const float b_windowIR[150],
    const float b_windowG[150], double dcR[150], double dcIR[150],
    double dcG[150], float acGRaw[150], float acR[150], float acIR[150],
    float acG[150], float ppgFilteredR[150], float ppgFilteredIR[150],
    float ppgFilteredG[150], float ppgNormalizedG[150], int *delayR,
    int *delayIR);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (preprocess_ppg_window_shared.h) */
