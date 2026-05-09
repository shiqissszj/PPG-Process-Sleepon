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
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include "smooth_data.h"

/* Function Definitions */
void dc_ac_spliter(emxArray_real32_T *singalIn, emxArray_real_T *DC)
{
  double *DC_data;
  float *singalIn_data;
  int i;
  int i1;
  singalIn_data = singalIn->data;
  i = DC->size[0];
  DC->size[0] = 150;
  emxEnsureCapacity_real_T(DC, i);
  smooth_data(singalIn, DC);
  DC_data = DC->data;
  for (i1 = 0; i1 < 150; i1++) {
    singalIn_data[i1] -= (float)DC_data[i1];
  }
}

/* End of code generation (dc_ac_spliter.c) */
