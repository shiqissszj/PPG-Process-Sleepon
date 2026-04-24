/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * main.c
 *
 * Code generation for function 'main'
 *
 */

/*************************************************************************/
/* This automatically generated example C main file shows how to call    */
/* entry-point functions that MATLAB Coder generated. You must customize */
/* this file for your application. Do not modify this file directly.     */
/* Instead, make a copy of this file, modify it, and integrate it into   */
/* your development environment.                                         */
/*                                                                       */
/* This file initializes entry-point function arguments to a default     */
/* size and value before calling the entry-point functions. It does      */
/* not store or use any values returned from the entry-point functions.  */
/* If necessary, it does pre-allocate memory for returned values.        */
/* You can use this file as a starting point for a main function that    */
/* you can deploy in your application.                                   */
/*                                                                       */
/* After you copy the file, and before you deploy it, you must make the  */
/* following changes:                                                    */
/* * For variable-size function arguments, change the example sizes to   */
/* the sizes that your application requires.                             */
/* * Change the example values of function arguments to the values that  */
/* your application requires.                                            */
/* * If the entry-point functions return values, store these values or   */
/* otherwise use them as required by your application.                   */
/*                                                                       */
/*************************************************************************/

/* Include files */
#include "main.h"
#include "ppg_process.h"
#include "ppg_process_initialize.h"
#include "ppg_process_terminate.h"
#include "rt_nonfinite.h"

/* Function Declarations */
static float argInit_real32_T(void);

static unsigned int argInit_uint32_T(void);

/* Function Definitions */
static float argInit_real32_T(void)
{
  return 0.0F;
}

static unsigned int argInit_uint32_T(void)
{
  return 0U;
}

int main(int argc, char **argv)
{
  (void)argc;
  (void)argv;
  /* Initialize the application.
You do not need to do this more than one time. */
  ppg_process_initialize();
  /* Invoke the entry-point functions.
You can call entry-point functions multiple times. */
  main_ppg_process();
  /* Terminate the application.
You do not need to do this more than one time. */
  ppg_process_terminate();
  return 0;
}

void main_ppg_process(void)
{
  float outputPI_data[6];
  float R;
  float confidenceR;
  float inputSampleR_tmp;
  float outputPR;
  float outputSpO2;
  int outputPI_size[2];
  bool outputFlag;
  /* Initialize function 'ppg_process' input arguments. */
  inputSampleR_tmp = argInit_real32_T();
  /* Call the entry-point 'ppg_process'. */
  ppg_process(inputSampleR_tmp, inputSampleR_tmp, inputSampleR_tmp,
              argInit_uint32_T(), inputSampleR_tmp, &outputFlag, &outputPR,
              &outputSpO2, outputPI_data, outputPI_size, &confidenceR, &R);
}

/* End of code generation (main.c) */
