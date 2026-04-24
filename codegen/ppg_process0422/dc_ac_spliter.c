/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * dc_ac_spliter.c
 *
 * Code generation for function 'dc_ac_spliter'
 *
 */

/* Include files */
#include "dc_ac_spliter.h"
#include "rt_nonfinite.h"
#include "smooth_data.h"

/* Function Definitions */
void dc_ac_spliter(float singalIn[150], double DC[150])
{
  int i;
  smooth_data(singalIn, DC);
  for (i = 0; i < 150; i++) {
    singalIn[i] -= (float)DC[i];
  }
}

/* End of code generation (dc_ac_spliter.c) */
