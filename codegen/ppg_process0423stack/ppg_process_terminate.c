/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ppg_process_terminate.c
 *
 * Code generation for function 'ppg_process_terminate'
 *
 */

/* Include files */
#include "ppg_process_terminate.h"
#include "ac_filter.h"
#include "ppg_process.h"
#include "ppg_process_data.h"
#include "r_pr_calculation.h"
#include "r_pr_fix.h"
#include "r_smoothing.h"
#include "rt_nonfinite.h"

/* Function Definitions */
void ppg_process_terminate(void)
{
  ppg_process_emx_free();
  r_pr_calculation_emx_free();
  ac_filter_emx_free();
  r_pr_fix_emx_free();
  r_smoothing_emx_free();
  isInitialized_ppg_process = false;
}

/* End of code generation (ppg_process_terminate.c) */
