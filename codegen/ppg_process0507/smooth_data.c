/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * smooth_data.c
 *
 * Code generation for function 'smooth_data'
 *
 */

/* Include files */
#include "smooth_data.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"

/* Function Definitions */
void smooth_data(const emxArray_real32_T *signalIn,
                 emxArray_real_T *smoothedSignal)
{
  double *smoothedSignal_data;
  const float *signalIn_data;
  float windowSum;
  int count;
  int k;
  signalIn_data = signalIn->data;
  count = smoothedSignal->size[0];
  smoothedSignal->size[0] = 150;
  emxEnsureCapacity_real_T(smoothedSignal, count);
  smoothedSignal_data = smoothedSignal->data;
  /*  signal length */
  /*  use half window for boudary situation */
  /*  initialization */
  /*  Initialize sum for the first window considering boundary conditions */
  windowSum = signalIn_data[0];
  for (k = 0; k < 24; k++) {
    windowSum += signalIn_data[k + 1];
  }
  count = 25;
  /*  Actual count of elements in the initial window */
  /*  Initialize first smoothed value especially if it's within a boundary
   * condition */
  for (k = 0; k < 25; k++) {
    smoothedSignal_data[k] = windowSum / (float)count;
    /*  Only add new elements if we are not at the end */
    windowSum += signalIn_data[k + 25];
    count++;
  }
  /*  Smooth for every point after the initial part */
  for (k = 0; k < 100; k++) {
    /*  Add the next item in the window and remove the first one */
    windowSum = (windowSum + signalIn_data[k + 50]) - signalIn_data[k];
    /*  The count remains constant in the middle part */
    smoothedSignal_data[k + 25] = windowSum / 50.0F;
    /*  Here the window is always full-sized */
  }
  /*  Handle the end boundary where the window shrinks again */
  for (k = 0; k < 25; k++) {
    /*  Only subtract elements if we are not at the beginning */
    windowSum -= signalIn_data[k + 99];
    count--;
    smoothedSignal_data[k + 125] = windowSum / (float)count;
  }
}

/* End of code generation (smooth_data.c) */
