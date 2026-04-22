/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ppg_process.h
 *
 * Code generation for function 'ppg_process'
 *
 */

#ifndef PPG_PROCESS_H
#define PPG_PROCESS_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
extern void ppg_process(float inputSampleR, float inputSampleIR,
                        float inputSampleG, unsigned int inputCounter,
                        float bodyMove, bool *outputFlag, float *outputPR,
                        float *outputSpO2, float outputPI_data[],
                        int outputPI_size[2], float *confidenceR, float *R,
                        float *rawPR, float *confidenceG, float *fixedPR);

void ppg_process_init(void);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (ppg_process.h) */
