/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ppg_process_initialize.c
 *
 * Code generation for function 'ppg_process_initialize'
 *
 */

/* Include files */
#include "ppg_process_initialize.h"
#include "ppg_process.h"
#include "ppg_process_data.h"
#include "pr_smoothing.h"
#include "r_pr_calculation.h"
#include "r_pr_fix.h"
#include "r_smoothing.h"
#include "rt_nonfinite.h"

/* Function Definitions */
void ppg_process_initialize(void)
{
  ppg_process_init();
  r_pr_calculation_init();
  r_pr_fix_init();
  r_smoothing_init();
  pr_smoothing_init();
  isInitialized_ppg_process = true;
}

/* End of code generation (ppg_process_initialize.c) */
