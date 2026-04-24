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
#include "rt_nonfinite.h"
#include "sortIdx.h"
#include "rt_nonfinite.h"
#include <string.h>

/* Function Definitions */
int b_sort(float x_data[], const int *x_size, int idx_data[])
{
  float vwork_data[50];
  int dim;
  int idx_size;
  int j;
  int k;
  int vstride;
  int vwork_size;
  dim = 2;
  if (*x_size != 1) {
    dim = 1;
  }
  if (dim <= 1) {
    vwork_size = *x_size;
  } else {
    vwork_size = 1;
  }
  idx_size = *x_size;
  vstride = 1;
  dim -= 2;
  for (k = 0; k <= dim; k++) {
    vstride *= *x_size;
  }
  for (j = 0; j < vstride; j++) {
    int iidx_data[50];
    for (k = 0; k < vwork_size; k++) {
      vwork_data[k] = x_data[j + k * vstride];
      iidx_data[k] = 0;
    }
    if (vwork_size != 0) {
      float xwork_data[50];
      float x4[4];
      int iwork_data[50];
      int i1;
      int i2;
      int i4;
      int ib;
      int nNaNs;
      signed char idx4[4];
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
      for (k = 0; k < vwork_size; k++) {
        iwork_data[k] = 0;
        if (rtIsNaNF(vwork_data[k])) {
          dim = (vwork_size - nNaNs) - 1;
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
            int i;
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
                i = i1;
                b_i1 = i2;
                i1 = ib;
                i2 = i4;
              } else if (x4[i2 - 1] <= x4[i4 - 1]) {
                i = i1;
                b_i1 = ib;
                i1 = i2;
                i2 = i4;
              } else {
                i = i1;
                b_i1 = ib;
                i1 = i4;
              }
            } else if (f <= x4[i4 - 1]) {
              if (x4[i2 - 1] <= x4[i4 - 1]) {
                i = ib;
                b_i1 = i1;
                i1 = i2;
                i2 = i4;
              } else {
                i = ib;
                b_i1 = i1;
                i1 = i4;
              }
            } else {
              i = ib;
              b_i1 = i4;
            }
            iidx_data[dim - 3] = idx4[i - 1];
            iidx_data[dim - 2] = idx4[b_i1 - 1];
            iidx_data[dim - 1] = idx4[i1 - 1];
            iidx_data[dim] = idx4[i2 - 1];
            vwork_data[dim - 3] = x4[i - 1];
            vwork_data[dim - 2] = x4[b_i1 - 1];
            vwork_data[dim - 1] = x4[i1 - 1];
            vwork_data[dim] = x4[i2 - 1];
            ib = 0;
          }
        }
      }
      i4 = vwork_size - nNaNs;
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
        ib = (vwork_size - k) - 1;
        iidx_data[i1] = iidx_data[ib];
        iidx_data[ib] = i2;
        vwork_data[i1] = xwork_data[ib];
        vwork_data[ib] = xwork_data[i1];
      }
      if (((unsigned int)nNaNs & 1U) != 0U) {
        dim += i4;
        vwork_data[dim] = xwork_data[dim];
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
              b_merge(iidx_data, vwork_data, dim, ib, i1 - ib, iwork_data,
                      xwork_data);
            }
          }
          dim = ib << 1;
          i2 >>= 1;
          for (k = 0; k < i2; k++) {
            b_merge(iidx_data, vwork_data, k * dim, ib, ib, iwork_data,
                    xwork_data);
          }
          ib = dim;
        }
        if (i4 > ib) {
          b_merge(iidx_data, vwork_data, 0, ib, i4 - ib, iwork_data,
                  xwork_data);
        }
      }
    }
    for (k = 0; k < vwork_size; k++) {
      dim = j + k * vstride;
      x_data[dim] = vwork_data[k];
      idx_data[dim] = iidx_data[k];
    }
  }
  return idx_size;
}

int sort(float x_data[], const int *x_size, int idx_data[])
{
  float vwork_data[50];
  float xwork_data[50];
  int iidx_data[50];
  int iwork_data[50];
  int dim;
  int idx_size;
  int j;
  int k;
  int vstride;
  int vwork_size;
  dim = 2;
  if (*x_size != 1) {
    dim = 1;
  }
  if (dim <= 1) {
    vwork_size = *x_size;
  } else {
    vwork_size = 1;
  }
  idx_size = *x_size;
  vstride = 1;
  dim -= 2;
  for (k = 0; k <= dim; k++) {
    vstride *= *x_size;
  }
  for (j = 0; j < vstride; j++) {
    for (k = 0; k < vwork_size; k++) {
      vwork_data[k] = x_data[j + k * vstride];
      iidx_data[k] = 0;
    }
    if (vwork_size != 0) {
      float x4[4];
      int i1;
      int i2;
      int i4;
      int ib;
      int nNaNs;
      signed char idx4[4];
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
      for (k = 0; k < vwork_size; k++) {
        iwork_data[k] = 0;
        if (rtIsNaNF(vwork_data[k])) {
          dim = (vwork_size - nNaNs) - 1;
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
            int i;
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
                i = i1;
                b_i1 = i2;
                i1 = ib;
                i2 = i4;
              } else if (x4[i2 - 1] >= x4[i4 - 1]) {
                i = i1;
                b_i1 = ib;
                i1 = i2;
                i2 = i4;
              } else {
                i = i1;
                b_i1 = ib;
                i1 = i4;
              }
            } else if (f >= x4[i4 - 1]) {
              if (x4[i2 - 1] >= x4[i4 - 1]) {
                i = ib;
                b_i1 = i1;
                i1 = i2;
                i2 = i4;
              } else {
                i = ib;
                b_i1 = i1;
                i1 = i4;
              }
            } else {
              i = ib;
              b_i1 = i4;
            }
            iidx_data[dim - 3] = idx4[i - 1];
            iidx_data[dim - 2] = idx4[b_i1 - 1];
            iidx_data[dim - 1] = idx4[i1 - 1];
            iidx_data[dim] = idx4[i2 - 1];
            vwork_data[dim - 3] = x4[i - 1];
            vwork_data[dim - 2] = x4[b_i1 - 1];
            vwork_data[dim - 1] = x4[i1 - 1];
            vwork_data[dim] = x4[i2 - 1];
            ib = 0;
          }
        }
      }
      i4 = vwork_size - nNaNs;
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
        ib = (vwork_size - k) - 1;
        iidx_data[i1] = iidx_data[ib];
        iidx_data[ib] = i2;
        vwork_data[i1] = xwork_data[ib];
        vwork_data[ib] = xwork_data[i1];
      }
      if (((unsigned int)nNaNs & 1U) != 0U) {
        dim += i4;
        vwork_data[dim] = xwork_data[dim];
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
              merge(iidx_data, vwork_data, dim, ib, i1 - ib, iwork_data,
                    xwork_data);
            }
          }
          dim = ib << 1;
          i2 >>= 1;
          for (k = 0; k < i2; k++) {
            merge(iidx_data, vwork_data, k * dim, ib, ib, iwork_data,
                  xwork_data);
          }
          ib = dim;
        }
        if (i4 > ib) {
          merge(iidx_data, vwork_data, 0, ib, i4 - ib, iwork_data, xwork_data);
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
        memcpy(&vwork_data[0], &xwork_data[0],
               (unsigned int)nNaNs * sizeof(float));
        memcpy(&iidx_data[0], &iwork_data[0],
               (unsigned int)nNaNs * sizeof(int));
      }
    }
    for (k = 0; k < vwork_size; k++) {
      dim = j + k * vstride;
      x_data[dim] = vwork_data[k];
      idx_data[dim] = iidx_data[k];
    }
  }
  return idx_size;
}

/* End of code generation (sort.c) */
