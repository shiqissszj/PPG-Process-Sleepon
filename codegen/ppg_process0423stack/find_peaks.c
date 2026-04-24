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
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include "sort.h"
#include <math.h>

/* Function Definitions */
void b_find_peaks(const emxArray_real32_T *inputSig, float minDistance,
                  emxArray_real32_T *peaks, emxArray_real32_T *locs)
{
  emxArray_int32_T *iidx;
  emxArray_real32_T *b_candidateLocs;
  emxArray_real32_T *candidatePeaks;
  emxArray_real32_T *r;
  const float *inputSig_data;
  float *candidateLocs_data;
  float *candidatePeaks_data;
  float *locs_data;
  float *peaks_data;
  int b_i;
  int c_i;
  int countCandidatePeak;
  int i;
  int idx;
  int numValidPeaks;
  int *iidx_data;
  unsigned char candidateLocs[50];
  bool exitg1;
  inputSig_data = inputSig->data;
  /*  Detect candidate peaks, filter them by minimun peak height */
  for (i = 0; i < 50; i++) {
    candidateLocs[i] = 0U;
  }
  countCandidatePeak = 0;
  idx = 0;
  exitg1 = false;
  while ((!exitg1) && (idx <= inputSig->size[0] - 3)) {
    float f;
    f = inputSig_data[idx + 1];
    if ((f > inputSig_data[idx]) && (f >= inputSig_data[idx + 2]) &&
        (f > 0.1F)) {
      unsigned char u;
      countCandidatePeak++;
      if ((double)idx + 2.0 < 256.0) {
        u = (unsigned char)((double)idx + 2.0);
      } else {
        u = MAX_uint8_T;
      }
      candidateLocs[countCandidatePeak - 1] = u;
      if (countCandidatePeak >= 50) {
        exitg1 = true;
      } else {
        idx++;
      }
    } else {
      idx++;
    }
  }
  emxInit_real32_T(&candidatePeaks);
  idx = candidatePeaks->size[0];
  candidatePeaks->size[0] = countCandidatePeak;
  emxEnsureCapacity_real32_T(candidatePeaks, idx);
  candidatePeaks_data = candidatePeaks->data;
  /*  Preallocate arrays for peaks and locations */
  /*  maxNumPeaks = length(candidatePeaks); */
  idx = peaks->size[0];
  peaks->size[0] = countCandidatePeak;
  emxEnsureCapacity_real32_T(peaks, idx);
  peaks_data = peaks->data;
  idx = locs->size[0];
  locs->size[0] = countCandidatePeak;
  emxEnsureCapacity_real32_T(locs, idx);
  locs_data = locs->data;
  for (i = 0; i < countCandidatePeak; i++) {
    candidatePeaks_data[i] = inputSig_data[candidateLocs[i] - 1];
    peaks_data[i] = 0.0F;
    locs_data[i] = 0.0F;
  }
  numValidPeaks = 0;
  /*  Keep track of the number of valid peaks */
  /*  Sort by peak height in descending order */
  emxInit_int32_T(&iidx);
  sort(candidatePeaks, iidx);
  iidx_data = iidx->data;
  candidatePeaks_data = candidatePeaks->data;
  b_i = candidatePeaks->size[0];
  emxInit_real32_T(&r);
  emxInit_real32_T(&b_candidateLocs);
  for (c_i = 0; c_i < b_i; c_i++) {
    bool guard1;
    /*  Check minimum distance constraint */
    guard1 = false;
    if (numValidPeaks == 0) {
      guard1 = true;
    } else {
      bool tmp_data[50];
      idx = b_candidateLocs->size[0];
      b_candidateLocs->size[0] = numValidPeaks;
      emxEnsureCapacity_real32_T(b_candidateLocs, idx);
      candidateLocs_data = b_candidateLocs->data;
      for (i = 0; i < numValidPeaks; i++) {
        candidateLocs_data[i] =
            (float)candidateLocs[iidx_data[c_i] - 1] - locs_data[i];
      }
      b_abs(b_candidateLocs, r);
      candidateLocs_data = r->data;
      idx = r->size[0];
      countCandidatePeak = r->size[0];
      for (i = 0; i < idx; i++) {
        tmp_data[i] = (candidateLocs_data[i] > minDistance);
      }
      if (all(tmp_data, countCandidatePeak)) {
        guard1 = true;
      }
    }
    if (guard1) {
      numValidPeaks++;
      peaks_data[numValidPeaks - 1] = candidatePeaks_data[c_i];
      locs_data[numValidPeaks - 1] = candidateLocs[iidx_data[c_i] - 1];
    }
  }
  emxFree_real32_T(&b_candidateLocs);
  emxFree_real32_T(&r);
  /*  Trim the arrays to the actual number of valid peaks found */
  if (numValidPeaks < 1) {
    numValidPeaks = 0;
  }
  idx = peaks->size[0];
  peaks->size[0] = numValidPeaks;
  emxEnsureCapacity_real32_T(peaks, idx);
  peaks_data = peaks->data;
  idx = locs->size[0];
  locs->size[0] = numValidPeaks;
  emxEnsureCapacity_real32_T(locs, idx);
  /*  Sort the locations (and corresponding peaks) in ascending order */
  b_sort(locs, iidx);
  iidx_data = iidx->data;
  countCandidatePeak = iidx->size[0];
  idx = candidatePeaks->size[0];
  candidatePeaks->size[0] = iidx->size[0];
  emxEnsureCapacity_real32_T(candidatePeaks, idx);
  candidatePeaks_data = candidatePeaks->data;
  for (i = 0; i < countCandidatePeak; i++) {
    candidatePeaks_data[i] = peaks_data[iidx_data[i] - 1];
  }
  idx = peaks->size[0];
  peaks->size[0] = iidx->size[0];
  emxFree_int32_T(&iidx);
  emxEnsureCapacity_real32_T(peaks, idx);
  peaks_data = peaks->data;
  for (i = 0; i < countCandidatePeak; i++) {
    peaks_data[i] = candidatePeaks_data[i];
  }
  emxFree_real32_T(&candidatePeaks);
}

void find_peaks(const emxArray_real32_T *inputSig, emxArray_real32_T *peaks,
                emxArray_real32_T *locs)
{
  emxArray_int32_T *iidx;
  emxArray_real32_T *b_candidateLocs;
  emxArray_real32_T *b_inputSig;
  emxArray_real32_T *c_inputSig;
  emxArray_real32_T *candidatePeaks;
  emxArray_real32_T *r;
  const float *inputSig_data;
  float peak;
  float *b_inputSig_data;
  float *candidatePeaks_data;
  float *locs_data;
  float *peaks_data;
  int b_i;
  int c_i;
  int countCandidatePeak;
  int i;
  int leftBase;
  int numValidPeaks;
  int *iidx_data;
  unsigned char candidateLocs[50];
  unsigned char leftBase_tmp;
  bool exitg1;
  inputSig_data = inputSig->data;
  /*  Detect candidate peaks, filter them by minimun peak height */
  for (i = 0; i < 50; i++) {
    candidateLocs[i] = 0U;
  }
  countCandidatePeak = 0;
  leftBase = 0;
  exitg1 = false;
  while ((!exitg1) && (leftBase <= inputSig->size[0] - 3)) {
    peak = inputSig_data[leftBase + 1];
    if ((peak > inputSig_data[leftBase]) &&
        (peak >= inputSig_data[leftBase + 2])) {
      countCandidatePeak++;
      if ((double)leftBase + 2.0 < 256.0) {
        leftBase_tmp = (unsigned char)((double)leftBase + 2.0);
      } else {
        leftBase_tmp = MAX_uint8_T;
      }
      candidateLocs[countCandidatePeak - 1] = leftBase_tmp;
      if (countCandidatePeak >= 50) {
        exitg1 = true;
      } else {
        leftBase++;
      }
    } else {
      leftBase++;
    }
  }
  emxInit_real32_T(&candidatePeaks);
  leftBase = candidatePeaks->size[0];
  candidatePeaks->size[0] = countCandidatePeak;
  emxEnsureCapacity_real32_T(candidatePeaks, leftBase);
  candidatePeaks_data = candidatePeaks->data;
  /*  Preallocate arrays for peaks and locations */
  /*  maxNumPeaks = length(candidatePeaks); */
  leftBase = peaks->size[0];
  peaks->size[0] = countCandidatePeak;
  emxEnsureCapacity_real32_T(peaks, leftBase);
  peaks_data = peaks->data;
  leftBase = locs->size[0];
  locs->size[0] = countCandidatePeak;
  emxEnsureCapacity_real32_T(locs, leftBase);
  locs_data = locs->data;
  for (i = 0; i < countCandidatePeak; i++) {
    candidatePeaks_data[i] = inputSig_data[candidateLocs[i] - 1];
    peaks_data[i] = 0.0F;
    locs_data[i] = 0.0F;
  }
  numValidPeaks = 0;
  /*  Keep track of the number of valid peaks */
  /*  Sort by peak height in descending order */
  emxInit_int32_T(&iidx);
  sort(candidatePeaks, iidx);
  iidx_data = iidx->data;
  candidatePeaks_data = candidatePeaks->data;
  b_i = candidatePeaks->size[0];
  emxInit_real32_T(&r);
  emxInit_real32_T(&b_candidateLocs);
  emxInit_real32_T(&b_inputSig);
  emxInit_real32_T(&c_inputSig);
  for (c_i = 0; c_i < b_i; c_i++) {
    bool guard1;
    peak = candidatePeaks_data[c_i];
    /*  Check minimum distance constraint */
    guard1 = false;
    if (numValidPeaks == 0) {
      guard1 = true;
    } else {
      bool tmp_data[50];
      leftBase = b_candidateLocs->size[0];
      b_candidateLocs->size[0] = numValidPeaks;
      emxEnsureCapacity_real32_T(b_candidateLocs, leftBase);
      b_inputSig_data = b_candidateLocs->data;
      for (i = 0; i < numValidPeaks; i++) {
        b_inputSig_data[i] =
            (float)candidateLocs[iidx_data[c_i] - 1] - locs_data[i];
      }
      b_abs(b_candidateLocs, r);
      b_inputSig_data = r->data;
      countCandidatePeak = r->size[0];
      leftBase = r->size[0];
      for (i = 0; i < countCandidatePeak; i++) {
        tmp_data[i] = (b_inputSig_data[i] > 10.0F);
      }
      if (all(tmp_data, leftBase)) {
        guard1 = true;
      }
    }
    if (guard1) {
      int i1;
      int i2;
      int rightBase;
      /*  Find left and right bases */
      leftBase_tmp = candidateLocs[iidx_data[c_i] - 1];
      leftBase = leftBase_tmp;
      while ((leftBase > 1) && (inputSig_data[leftBase - 2] <= peak)) {
        leftBase--;
      }
      rightBase = leftBase_tmp;
      while ((rightBase < inputSig->size[0]) &&
             (inputSig_data[rightBase] <= peak)) {
        rightBase++;
      }
      /*  Determine prominence */
      if (leftBase > leftBase_tmp) {
        i1 = 0;
        countCandidatePeak = 0;
      } else {
        i1 = leftBase - 1;
        countCandidatePeak = leftBase_tmp;
      }
      if (leftBase_tmp > rightBase) {
        i2 = 0;
        rightBase = 0;
      } else {
        i2 = leftBase_tmp - 1;
      }
      /*  Check prominence constraint */
      leftBase = countCandidatePeak - i1;
      countCandidatePeak = b_inputSig->size[0];
      b_inputSig->size[0] = leftBase;
      emxEnsureCapacity_real32_T(b_inputSig, countCandidatePeak);
      b_inputSig_data = b_inputSig->data;
      for (i = 0; i < leftBase; i++) {
        b_inputSig_data[i] = inputSig_data[i1 + i];
      }
      leftBase = rightBase - i2;
      countCandidatePeak = c_inputSig->size[0];
      c_inputSig->size[0] = leftBase;
      emxEnsureCapacity_real32_T(c_inputSig, countCandidatePeak);
      b_inputSig_data = c_inputSig->data;
      for (i = 0; i < leftBase; i++) {
        b_inputSig_data[i] = inputSig_data[i2 + i];
      }
      if (candidatePeaks_data[c_i] -
              fmaxf(b_minimum(b_inputSig), b_minimum(c_inputSig)) >=
          0.025F) {
        numValidPeaks++;
        peaks_data[numValidPeaks - 1] = candidatePeaks_data[c_i];
        locs_data[numValidPeaks - 1] = leftBase_tmp;
      }
    }
  }
  emxFree_real32_T(&c_inputSig);
  emxFree_real32_T(&b_inputSig);
  emxFree_real32_T(&b_candidateLocs);
  emxFree_real32_T(&r);
  /*  Trim the arrays to the actual number of valid peaks found */
  if (numValidPeaks < 1) {
    numValidPeaks = 0;
  }
  leftBase = peaks->size[0];
  peaks->size[0] = numValidPeaks;
  emxEnsureCapacity_real32_T(peaks, leftBase);
  peaks_data = peaks->data;
  leftBase = locs->size[0];
  locs->size[0] = numValidPeaks;
  emxEnsureCapacity_real32_T(locs, leftBase);
  /*  Sort the locations (and corresponding peaks) in ascending order */
  b_sort(locs, iidx);
  iidx_data = iidx->data;
  countCandidatePeak = iidx->size[0];
  leftBase = candidatePeaks->size[0];
  candidatePeaks->size[0] = iidx->size[0];
  emxEnsureCapacity_real32_T(candidatePeaks, leftBase);
  candidatePeaks_data = candidatePeaks->data;
  for (i = 0; i < countCandidatePeak; i++) {
    candidatePeaks_data[i] = peaks_data[iidx_data[i] - 1];
  }
  leftBase = peaks->size[0];
  peaks->size[0] = iidx->size[0];
  emxFree_int32_T(&iidx);
  emxEnsureCapacity_real32_T(peaks, leftBase);
  peaks_data = peaks->data;
  for (i = 0; i < countCandidatePeak; i++) {
    peaks_data[i] = candidatePeaks_data[i];
  }
  emxFree_real32_T(&candidatePeaks);
}

/* End of code generation (find_peaks.c) */
