/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * find_peaks.c
 *
 * Code generation for function 'find_peaks'
 *
 */

/* Include files */
#include "find_peaks.h"
#include "abs.h"
#include "all.h"
#include "minOrMax.h"
#include "rt_nonfinite.h"
#include "sort.h"
#include <math.h>
#include <string.h>

/* Function Definitions */
int b_find_peaks(const float inputSig_data[], int inputSig_size,
                 float minDistance, float peaks_data[], float locs_data[],
                 int *locs_size)
{
  float tmp_data[300];
  float candidatePeaks_data[50];
  int iidx_data[50];
  int b_i;
  int countCandidatePeak;
  int i;
  int numValidPeaks;
  int peaks_size;
  unsigned char candidateLocs[50];
  bool exitg1;
  /*  Detect candidate peaks, filter them by minimun peak height */
  for (i = 0; i < 50; i++) {
    candidateLocs[i] = 0U;
  }
  countCandidatePeak = 0;
  peaks_size = 0;
  exitg1 = false;
  while ((!exitg1) && (peaks_size <= inputSig_size - 3)) {
    float f;
    f = inputSig_data[peaks_size + 1];
    if ((f > inputSig_data[peaks_size]) &&
        (f >= inputSig_data[peaks_size + 2]) && (f > 0.1F)) {
      unsigned char u;
      countCandidatePeak++;
      if ((double)peaks_size + 2.0 < 256.0) {
        u = (unsigned char)((double)peaks_size + 2.0);
      } else {
        u = MAX_uint8_T;
      }
      candidateLocs[countCandidatePeak - 1] = u;
      if (countCandidatePeak >= 50) {
        exitg1 = true;
      } else {
        peaks_size++;
      }
    } else {
      peaks_size++;
    }
  }
  /*  Preallocate arrays for peaks and locations */
  /*  maxNumPeaks = length(candidatePeaks); */
  for (i = 0; i < countCandidatePeak; i++) {
    candidatePeaks_data[i] = inputSig_data[candidateLocs[i] - 1];
    peaks_data[i] = 0.0F;
    locs_data[i] = 0.0F;
  }
  numValidPeaks = 0;
  /*  Keep track of the number of valid peaks */
  /*  Sort by peak height in descending order */
  sort(candidatePeaks_data, &countCandidatePeak, iidx_data);
  for (b_i = 0; b_i < countCandidatePeak; b_i++) {
    bool guard1;
    /*  Check minimum distance constraint */
    guard1 = false;
    if (numValidPeaks == 0) {
      guard1 = true;
    } else {
      float candidateLocs_data[50];
      bool b_tmp_data[50];
      for (i = 0; i < numValidPeaks; i++) {
        candidateLocs_data[i] =
            (float)candidateLocs[iidx_data[b_i] - 1] - locs_data[i];
      }
      peaks_size = b_abs(candidateLocs_data, numValidPeaks, tmp_data);
      for (i = 0; i < peaks_size; i++) {
        b_tmp_data[i] = (tmp_data[i] > minDistance);
      }
      if (all(b_tmp_data, peaks_size)) {
        guard1 = true;
      }
    }
    if (guard1) {
      numValidPeaks++;
      peaks_data[numValidPeaks - 1] = candidatePeaks_data[b_i];
      locs_data[numValidPeaks - 1] = candidateLocs[iidx_data[b_i] - 1];
    }
  }
  /*  Trim the arrays to the actual number of valid peaks found */
  if (numValidPeaks < 1) {
    *locs_size = 0;
  } else {
    *locs_size = numValidPeaks;
  }
  /*  Sort the locations (and corresponding peaks) in ascending order */
  peaks_size = b_sort(locs_data, locs_size, iidx_data);
  for (i = 0; i < peaks_size; i++) {
    candidatePeaks_data[i] = peaks_data[iidx_data[i] - 1];
  }
  if (peaks_size - 1 >= 0) {
    memcpy(&peaks_data[0], &candidatePeaks_data[0],
           (unsigned int)peaks_size * sizeof(float));
  }
  return peaks_size;
}

int find_peaks(const float inputSig_data[], int inputSig_size,
               float peaks_data[], float locs_data[], int *locs_size)
{
  float b_inputSig_data[300];
  float candidatePeaks_data[50];
  float peak;
  int iidx_data[50];
  int b_i;
  int countCandidatePeak;
  int i;
  int numValidPeaks;
  int peaks_size;
  unsigned char candidateLocs[50];
  unsigned char leftBase_tmp;
  bool exitg1;
  /*  Detect candidate peaks, filter them by minimun peak height */
  for (i = 0; i < 50; i++) {
    candidateLocs[i] = 0U;
  }
  countCandidatePeak = 0;
  peaks_size = 0;
  exitg1 = false;
  while ((!exitg1) && (peaks_size <= inputSig_size - 3)) {
    peak = inputSig_data[peaks_size + 1];
    if ((peak > inputSig_data[peaks_size]) &&
        (peak >= inputSig_data[peaks_size + 2])) {
      countCandidatePeak++;
      if ((double)peaks_size + 2.0 < 256.0) {
        leftBase_tmp = (unsigned char)((double)peaks_size + 2.0);
      } else {
        leftBase_tmp = MAX_uint8_T;
      }
      candidateLocs[countCandidatePeak - 1] = leftBase_tmp;
      if (countCandidatePeak >= 50) {
        exitg1 = true;
      } else {
        peaks_size++;
      }
    } else {
      peaks_size++;
    }
  }
  /*  Preallocate arrays for peaks and locations */
  /*  maxNumPeaks = length(candidatePeaks); */
  for (i = 0; i < countCandidatePeak; i++) {
    candidatePeaks_data[i] = inputSig_data[candidateLocs[i] - 1];
    peaks_data[i] = 0.0F;
    locs_data[i] = 0.0F;
  }
  numValidPeaks = 0;
  /*  Keep track of the number of valid peaks */
  /*  Sort by peak height in descending order */
  sort(candidatePeaks_data, &countCandidatePeak, iidx_data);
  for (b_i = 0; b_i < countCandidatePeak; b_i++) {
    bool guard1;
    peak = candidatePeaks_data[b_i];
    /*  Check minimum distance constraint */
    guard1 = false;
    if (numValidPeaks == 0) {
      guard1 = true;
    } else {
      float candidateLocs_data[50];
      bool tmp_data[50];
      for (i = 0; i < numValidPeaks; i++) {
        candidateLocs_data[i] =
            (float)candidateLocs[iidx_data[b_i] - 1] - locs_data[i];
      }
      peaks_size = b_abs(candidateLocs_data, numValidPeaks, b_inputSig_data);
      for (i = 0; i < peaks_size; i++) {
        tmp_data[i] = (b_inputSig_data[i] > 10.0F);
      }
      if (all(tmp_data, peaks_size)) {
        guard1 = true;
      }
    }
    if (guard1) {
      float c_inputSig_data[255];
      int c_i;
      int i1;
      int loop_ub;
      int rightBase;
      /*  Find left and right bases */
      leftBase_tmp = candidateLocs[iidx_data[b_i] - 1];
      peaks_size = leftBase_tmp;
      while ((peaks_size > 1) && (inputSig_data[peaks_size - 2] <= peak)) {
        peaks_size--;
      }
      rightBase = leftBase_tmp;
      while ((rightBase < inputSig_size) &&
             (inputSig_data[rightBase] <= peak)) {
        rightBase++;
      }
      /*  Determine prominence */
      if (peaks_size > leftBase_tmp) {
        c_i = 0;
        peaks_size = 0;
      } else {
        c_i = peaks_size - 1;
        peaks_size = leftBase_tmp;
      }
      if (leftBase_tmp > rightBase) {
        i1 = 0;
        rightBase = 0;
      } else {
        i1 = leftBase_tmp - 1;
      }
      /*  Check prominence constraint */
      loop_ub = peaks_size - c_i;
      for (i = 0; i < loop_ub; i++) {
        c_inputSig_data[i] = inputSig_data[c_i + i];
      }
      peaks_size = rightBase - i1;
      for (i = 0; i < peaks_size; i++) {
        b_inputSig_data[i] = inputSig_data[i1 + i];
      }
      peak = candidatePeaks_data[b_i];
      if (peak - fmaxf(b_minimum(c_inputSig_data, loop_ub),
                       b_minimum(b_inputSig_data, peaks_size)) >=
          0.025F) {
        numValidPeaks++;
        peaks_data[numValidPeaks - 1] = peak;
        locs_data[numValidPeaks - 1] = leftBase_tmp;
      }
    }
  }
  /*  Trim the arrays to the actual number of valid peaks found */
  if (numValidPeaks < 1) {
    *locs_size = 0;
  } else {
    *locs_size = numValidPeaks;
  }
  /*  Sort the locations (and corresponding peaks) in ascending order */
  peaks_size = b_sort(locs_data, locs_size, iidx_data);
  for (i = 0; i < peaks_size; i++) {
    candidatePeaks_data[i] = peaks_data[iidx_data[i] - 1];
  }
  if (peaks_size - 1 >= 0) {
    memcpy(&peaks_data[0], &candidatePeaks_data[0],
           (unsigned int)peaks_size * sizeof(float));
  }
  return peaks_size;
}

/* End of code generation (find_peaks.c) */
