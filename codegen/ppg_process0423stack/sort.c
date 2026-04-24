/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * sort.c
 *
 * Code generation for function 'sort'
 *
 */

/* Include files */
#include "sort.h"
#include "ppg_process_emxutil.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"
#include "sortIdx.h"
#include "rt_nonfinite.h"

/* Function Definitions */
void b_sort(emxArray_real32_T *x, emxArray_int32_T *idx)
{
  emxArray_int32_T *iwork;
  emxArray_real32_T *vwork;
  float *vwork_data;
  float *x_data;
  float *xwork_data;
  int dim;
  int i;
  int i1;
  int j;
  int k;
  int vstride;
  int *idx_data;
  int *iidx_data;
  int *iwork_data;
  x_data = x->data;
  dim = 2;
  if (x->size[0] != 1) {
    dim = 1;
  }
  if (dim <= 1) {
    i = x->size[0];
  } else {
    i = 1;
  }
  emxInit_real32_T(&vwork);
  i1 = vwork->size[0];
  vwork->size[0] = i;
  emxEnsureCapacity_real32_T(vwork, i1);
  vwork_data = vwork->data;
  i1 = idx->size[0];
  idx->size[0] = x->size[0];
  emxEnsureCapacity_int32_T(idx, i1);
  idx_data = idx->data;
  vstride = 1;
  i1 = dim - 2;
  for (k = 0; k <= i1; k++) {
    vstride *= x->size[0];
  }
  emxInit_int32_T(&idx);
  emxInit_int32_T(&iwork);
  emxInit_real32_T(&x);
  for (j = 0; j < vstride; j++) {
    int loop_ub;
    for (k = 0; k < i; k++) {
      vwork_data[k] = x_data[j + k * vstride];
    }
    loop_ub = vwork->size[0];
    i1 = idx->size[0];
    idx->size[0] = vwork->size[0];
    emxEnsureCapacity_int32_T(idx, i1);
    iidx_data = idx->data;
    for (k = 0; k < loop_ub; k++) {
      iidx_data[k] = 0;
    }
    if (vwork->size[0] != 0) {
      float x4[4];
      int i2;
      int i4;
      int ib;
      int nNaNs;
      signed char idx4[4];
      i1 = iwork->size[0];
      iwork->size[0] = vwork->size[0];
      emxEnsureCapacity_int32_T(iwork, i1);
      iwork_data = iwork->data;
      for (k = 0; k < loop_ub; k++) {
        iwork_data[k] = 0;
      }
      i1 = x->size[0];
      x->size[0] = vwork->size[0];
      emxEnsureCapacity_real32_T(x, i1);
      xwork_data = x->data;
      x4[0] = 0.0F;
      idx4[0] = 0;
      x4[1] = 0.0F;
      idx4[1] = 0;
      x4[2] = 0.0F;
      idx4[2] = 0;
      x4[3] = 0.0F;
      idx4[3] = 0;
      nNaNs = 0;
      ib = 0;
      for (k = 0; k < loop_ub; k++) {
        if (rtIsNaNF(vwork_data[k])) {
          dim = (loop_ub - nNaNs) - 1;
          iidx_data[dim] = k + 1;
          xwork_data[dim] = vwork_data[k];
          nNaNs++;
        } else {
          ib++;
          idx4[ib - 1] = (signed char)(k + 1);
          x4[ib - 1] = vwork_data[k];
          if (ib == 4) {
            float f;
            float f1;
            int b_i1;
            int b_i2;
            dim = k - nNaNs;
            if (x4[0] <= x4[1]) {
              i1 = 1;
              i2 = 2;
            } else {
              i1 = 2;
              i2 = 1;
            }
            if (x4[2] <= x4[3]) {
              ib = 3;
              i4 = 4;
            } else {
              ib = 4;
              i4 = 3;
            }
            f = x4[i1 - 1];
            f1 = x4[ib - 1];
            if (f <= f1) {
              if (x4[i2 - 1] <= f1) {
                b_i1 = i1;
                b_i2 = i2;
                i1 = ib;
                i2 = i4;
              } else if (x4[i2 - 1] <= x4[i4 - 1]) {
                b_i1 = i1;
                b_i2 = ib;
                i1 = i2;
                i2 = i4;
              } else {
                b_i1 = i1;
                b_i2 = ib;
                i1 = i4;
              }
            } else if (f <= x4[i4 - 1]) {
              if (x4[i2 - 1] <= x4[i4 - 1]) {
                b_i1 = ib;
                b_i2 = i1;
                i1 = i2;
                i2 = i4;
              } else {
                b_i1 = ib;
                b_i2 = i1;
                i1 = i4;
              }
            } else {
              b_i1 = ib;
              b_i2 = i4;
            }
            iidx_data[dim - 3] = idx4[b_i1 - 1];
            iidx_data[dim - 2] = idx4[b_i2 - 1];
            iidx_data[dim - 1] = idx4[i1 - 1];
            iidx_data[dim] = idx4[i2 - 1];
            vwork_data[dim - 3] = x4[b_i1 - 1];
            vwork_data[dim - 2] = x4[b_i2 - 1];
            vwork_data[dim - 1] = x4[i1 - 1];
            vwork_data[dim] = x4[i2 - 1];
            ib = 0;
          }
        }
      }
      i4 = vwork->size[0] - nNaNs;
      if (ib > 0) {
        signed char perm[4];
        perm[1] = 0;
        perm[2] = 0;
        perm[3] = 0;
        if (ib == 1) {
          perm[0] = 1;
        } else if (ib == 2) {
          if (x4[0] <= x4[1]) {
            perm[0] = 1;
            perm[1] = 2;
          } else {
            perm[0] = 2;
            perm[1] = 1;
          }
        } else if (x4[0] <= x4[1]) {
          if (x4[1] <= x4[2]) {
            perm[0] = 1;
            perm[1] = 2;
            perm[2] = 3;
          } else if (x4[0] <= x4[2]) {
            perm[0] = 1;
            perm[1] = 3;
            perm[2] = 2;
          } else {
            perm[0] = 3;
            perm[1] = 1;
            perm[2] = 2;
          }
        } else if (x4[0] <= x4[2]) {
          perm[0] = 2;
          perm[1] = 1;
          perm[2] = 3;
        } else if (x4[1] <= x4[2]) {
          perm[0] = 2;
          perm[1] = 3;
          perm[2] = 1;
        } else {
          perm[0] = 3;
          perm[1] = 2;
          perm[2] = 1;
        }
        dim = (unsigned char)ib;
        for (k = 0; k < dim; k++) {
          i1 = (i4 - ib) + k;
          i2 = perm[k];
          iidx_data[i1] = idx4[i2 - 1];
          vwork_data[i1] = x4[i2 - 1];
        }
      }
      dim = nNaNs >> 1;
      for (k = 0; k < dim; k++) {
        i1 = i4 + k;
        i2 = iidx_data[i1];
        ib = (loop_ub - k) - 1;
        iidx_data[i1] = iidx_data[ib];
        iidx_data[ib] = i2;
        vwork_data[i1] = xwork_data[ib];
        vwork_data[ib] = xwork_data[i1];
      }
      if (((unsigned int)nNaNs & 1U) != 0U) {
        i1 = i4 + dim;
        vwork_data[i1] = xwork_data[i1];
      }
      if (i4 > 1) {
        i2 = i4 >> 2;
        ib = 4;
        while (i2 > 1) {
          if (((unsigned int)i2 & 1U) != 0U) {
            i2--;
            dim = ib * i2;
            i1 = i4 - dim;
            if (i1 > ib) {
              b_merge(idx, vwork, dim, ib, i1 - ib, iwork, x);
              vwork_data = vwork->data;
              iidx_data = idx->data;
            }
          }
          dim = ib << 1;
          i2 >>= 1;
          for (k = 0; k < i2; k++) {
            b_merge(idx, vwork, k * dim, ib, ib, iwork, x);
            vwork_data = vwork->data;
            iidx_data = idx->data;
          }
          ib = dim;
        }
        if (i4 > ib) {
          b_merge(idx, vwork, 0, ib, i4 - ib, iwork, x);
          vwork_data = vwork->data;
          iidx_data = idx->data;
        }
      }
    }
    for (k = 0; k < i; k++) {
      dim = j + k * vstride;
      x_data[dim] = vwork_data[k];
      idx_data[dim] = iidx_data[k];
    }
  }
  emxFree_real32_T(&x);
  emxFree_int32_T(&iwork);
  emxFree_int32_T(&idx);
  emxFree_real32_T(&vwork);
}

void sort(emxArray_real32_T *x, emxArray_int32_T *idx)
{
  emxArray_int32_T *iwork;
  emxArray_real32_T *vwork;
  float *vwork_data;
  float *x_data;
  float *xwork_data;
  int dim;
  int i;
  int i1;
  int j;
  int k;
  int vstride;
  int *idx_data;
  int *iidx_data;
  int *iwork_data;
  x_data = x->data;
  dim = 2;
  if (x->size[0] != 1) {
    dim = 1;
  }
  if (dim <= 1) {
    i = x->size[0];
  } else {
    i = 1;
  }
  emxInit_real32_T(&vwork);
  i1 = vwork->size[0];
  vwork->size[0] = i;
  emxEnsureCapacity_real32_T(vwork, i1);
  vwork_data = vwork->data;
  i1 = idx->size[0];
  idx->size[0] = x->size[0];
  emxEnsureCapacity_int32_T(idx, i1);
  idx_data = idx->data;
  vstride = 1;
  i1 = dim - 2;
  for (k = 0; k <= i1; k++) {
    vstride *= x->size[0];
  }
  emxInit_int32_T(&idx);
  emxInit_int32_T(&iwork);
  emxInit_real32_T(&x);
  for (j = 0; j < vstride; j++) {
    int loop_ub;
    for (k = 0; k < i; k++) {
      vwork_data[k] = x_data[j + k * vstride];
    }
    loop_ub = vwork->size[0];
    i1 = idx->size[0];
    idx->size[0] = vwork->size[0];
    emxEnsureCapacity_int32_T(idx, i1);
    iidx_data = idx->data;
    for (k = 0; k < loop_ub; k++) {
      iidx_data[k] = 0;
    }
    if (vwork->size[0] != 0) {
      float x4[4];
      int i2;
      int i4;
      int ib;
      int nNaNs;
      signed char idx4[4];
      i1 = iwork->size[0];
      iwork->size[0] = vwork->size[0];
      emxEnsureCapacity_int32_T(iwork, i1);
      iwork_data = iwork->data;
      for (k = 0; k < loop_ub; k++) {
        iwork_data[k] = 0;
      }
      i1 = x->size[0];
      x->size[0] = vwork->size[0];
      emxEnsureCapacity_real32_T(x, i1);
      xwork_data = x->data;
      x4[0] = 0.0F;
      idx4[0] = 0;
      x4[1] = 0.0F;
      idx4[1] = 0;
      x4[2] = 0.0F;
      idx4[2] = 0;
      x4[3] = 0.0F;
      idx4[3] = 0;
      nNaNs = 0;
      ib = 0;
      for (k = 0; k < loop_ub; k++) {
        if (rtIsNaNF(vwork_data[k])) {
          dim = (loop_ub - nNaNs) - 1;
          iidx_data[dim] = k + 1;
          xwork_data[dim] = vwork_data[k];
          nNaNs++;
        } else {
          ib++;
          idx4[ib - 1] = (signed char)(k + 1);
          x4[ib - 1] = vwork_data[k];
          if (ib == 4) {
            float f;
            float f1;
            int b_i1;
            int b_i2;
            dim = k - nNaNs;
            if (x4[0] >= x4[1]) {
              i1 = 1;
              i2 = 2;
            } else {
              i1 = 2;
              i2 = 1;
            }
            if (x4[2] >= x4[3]) {
              ib = 3;
              i4 = 4;
            } else {
              ib = 4;
              i4 = 3;
            }
            f = x4[i1 - 1];
            f1 = x4[ib - 1];
            if (f >= f1) {
              if (x4[i2 - 1] >= f1) {
                b_i1 = i1;
                b_i2 = i2;
                i1 = ib;
                i2 = i4;
              } else if (x4[i2 - 1] >= x4[i4 - 1]) {
                b_i1 = i1;
                b_i2 = ib;
                i1 = i2;
                i2 = i4;
              } else {
                b_i1 = i1;
                b_i2 = ib;
                i1 = i4;
              }
            } else if (f >= x4[i4 - 1]) {
              if (x4[i2 - 1] >= x4[i4 - 1]) {
                b_i1 = ib;
                b_i2 = i1;
                i1 = i2;
                i2 = i4;
              } else {
                b_i1 = ib;
                b_i2 = i1;
                i1 = i4;
              }
            } else {
              b_i1 = ib;
              b_i2 = i4;
            }
            iidx_data[dim - 3] = idx4[b_i1 - 1];
            iidx_data[dim - 2] = idx4[b_i2 - 1];
            iidx_data[dim - 1] = idx4[i1 - 1];
            iidx_data[dim] = idx4[i2 - 1];
            vwork_data[dim - 3] = x4[b_i1 - 1];
            vwork_data[dim - 2] = x4[b_i2 - 1];
            vwork_data[dim - 1] = x4[i1 - 1];
            vwork_data[dim] = x4[i2 - 1];
            ib = 0;
          }
        }
      }
      i4 = vwork->size[0] - nNaNs;
      if (ib > 0) {
        signed char perm[4];
        perm[1] = 0;
        perm[2] = 0;
        perm[3] = 0;
        if (ib == 1) {
          perm[0] = 1;
        } else if (ib == 2) {
          if (x4[0] >= x4[1]) {
            perm[0] = 1;
            perm[1] = 2;
          } else {
            perm[0] = 2;
            perm[1] = 1;
          }
        } else if (x4[0] >= x4[1]) {
          if (x4[1] >= x4[2]) {
            perm[0] = 1;
            perm[1] = 2;
            perm[2] = 3;
          } else if (x4[0] >= x4[2]) {
            perm[0] = 1;
            perm[1] = 3;
            perm[2] = 2;
          } else {
            perm[0] = 3;
            perm[1] = 1;
            perm[2] = 2;
          }
        } else if (x4[0] >= x4[2]) {
          perm[0] = 2;
          perm[1] = 1;
          perm[2] = 3;
        } else if (x4[1] >= x4[2]) {
          perm[0] = 2;
          perm[1] = 3;
          perm[2] = 1;
        } else {
          perm[0] = 3;
          perm[1] = 2;
          perm[2] = 1;
        }
        dim = (unsigned char)ib;
        for (k = 0; k < dim; k++) {
          i1 = (i4 - ib) + k;
          i2 = perm[k];
          iidx_data[i1] = idx4[i2 - 1];
          vwork_data[i1] = x4[i2 - 1];
        }
      }
      dim = nNaNs >> 1;
      for (k = 0; k < dim; k++) {
        i1 = i4 + k;
        i2 = iidx_data[i1];
        ib = (loop_ub - k) - 1;
        iidx_data[i1] = iidx_data[ib];
        iidx_data[ib] = i2;
        vwork_data[i1] = xwork_data[ib];
        vwork_data[ib] = xwork_data[i1];
      }
      if (((unsigned int)nNaNs & 1U) != 0U) {
        i1 = i4 + dim;
        vwork_data[i1] = xwork_data[i1];
      }
      if (i4 > 1) {
        i2 = i4 >> 2;
        ib = 4;
        while (i2 > 1) {
          if (((unsigned int)i2 & 1U) != 0U) {
            i2--;
            dim = ib * i2;
            i1 = i4 - dim;
            if (i1 > ib) {
              merge(idx, vwork, dim, ib, i1 - ib, iwork, x);
              xwork_data = x->data;
              iwork_data = iwork->data;
              vwork_data = vwork->data;
              iidx_data = idx->data;
            }
          }
          dim = ib << 1;
          i2 >>= 1;
          for (k = 0; k < i2; k++) {
            merge(idx, vwork, k * dim, ib, ib, iwork, x);
            xwork_data = x->data;
            iwork_data = iwork->data;
            vwork_data = vwork->data;
            iidx_data = idx->data;
          }
          ib = dim;
        }
        if (i4 > ib) {
          merge(idx, vwork, 0, ib, i4 - ib, iwork, x);
          xwork_data = x->data;
          iwork_data = iwork->data;
          vwork_data = vwork->data;
          iidx_data = idx->data;
        }
      }
      if ((nNaNs > 0) && (i4 > 0)) {
        for (k = 0; k < nNaNs; k++) {
          dim = i4 + k;
          xwork_data[k] = vwork_data[dim];
          iwork_data[k] = iidx_data[dim];
        }
        for (k = i4; k >= 1; k--) {
          dim = (nNaNs + k) - 1;
          vwork_data[dim] = vwork_data[k - 1];
          iidx_data[dim] = iidx_data[k - 1];
        }
        for (k = 0; k < nNaNs; k++) {
          vwork_data[k] = xwork_data[k];
          iidx_data[k] = iwork_data[k];
        }
      }
    }
    for (k = 0; k < i; k++) {
      i1 = j + k * vstride;
      x_data[i1] = vwork_data[k];
      idx_data[i1] = iidx_data[k];
    }
  }
  emxFree_real32_T(&x);
  emxFree_int32_T(&iwork);
  emxFree_int32_T(&idx);
  emxFree_real32_T(&vwork);
}

/* End of code generation (sort.c) */
