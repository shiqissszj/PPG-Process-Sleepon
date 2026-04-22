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
#include "rt_nonfinite.h"

/* Function Definitions */
void smooth_data(const float signalIn[150], double smoothedSignal[150])
{
  float windowSum;
  int count;
  int k;
  /*  signal length */
  /*  use half window for boudary situation */
  /*  initialization */
  /*  Initialize sum for the first window considering boundary conditions */
  windowSum = signalIn[0];
  for (k = 0; k < 24; k++) {
    windowSum += signalIn[k + 1];
  }
  count = 25;
  /*  Actual count of elements in the initial window */
  /*  Initialize first smoothed value especially if it's within a boundary
   * condition */
  for (k = 0; k < 25; k++) {
    smoothedSignal[k] = windowSum / (float)count;
    /*  Only add new elements if we are not at the end */
    windowSum += signalIn[k + 25];
    count++;
  }
  /*  Smooth for every point after the initial part */
  for (k = 0; k < 100; k++) {
    /*  Add the next item in the window and remove the first one */
    windowSum = (windowSum + signalIn[k + 50]) - signalIn[k];
    /*  The count remains constant in the middle part */
    smoothedSignal[k + 25] = windowSum / 50.0F;
    /*  Here the window is always full-sized */
  }
  /*  Handle the end boundary where the window shrinks again */
  for (k = 0; k < 25; k++) {
    /*  Only subtract elements if we are not at the beginning */
    windowSum -= signalIn[k + 99];
    count--;
    smoothedSignal[k + 125] = windowSum / (float)count;
  }
}

/* End of code generation (smooth_data.c) */
