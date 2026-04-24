/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * quickselect.c
 *
 * Code generation for function 'quickselect'
 *
 */

/* Include files */
#include "quickselect.h"
#include "ppg_process_types.h"
#include "rt_nonfinite.h"

/* Function Declarations */
static int b_thirdOfFive(const float v[10], int ia, int ib);

static int thirdOfFive(const emxArray_real32_T *v, int ia, int ib);

/* Function Definitions */
static int b_thirdOfFive(const float v[10], int ia, int ib)
{
  int im;
  if ((ia == ib) || (ia + 1 == ib)) {
    im = ia;
  } else if ((ia + 2 == ib) || (ia + 3 == ib)) {
    float v4;
    v4 = v[ia - 1];
    if (v4 < v[ia]) {
      if (v[ia] < v[ia + 1]) {
        im = ia + 1;
      } else if (v4 < v[ia + 1]) {
        im = ia + 2;
      } else {
        im = ia;
      }
    } else if (v4 < v[ia + 1]) {
      im = ia;
    } else if (v[ia] < v[ia + 1]) {
      im = ia + 2;
    } else {
      im = ia + 1;
    }
  } else {
    float v4;
    float v5;
    int j2;
    int j3;
    int j4;
    int j5;
    v4 = v[ia - 1];
    if (v4 < v[ia]) {
      if (v[ia] < v[ia + 1]) {
        im = ia;
        j2 = ia;
        j3 = ia + 2;
      } else if (v4 < v[ia + 1]) {
        im = ia;
        j2 = ia + 1;
        j3 = ia + 1;
      } else {
        im = ia + 2;
        j2 = ia - 1;
        j3 = ia + 1;
      }
    } else if (v4 < v[ia + 1]) {
      im = ia + 1;
      j2 = ia - 1;
      j3 = ia + 2;
    } else if (v[ia] < v[ia + 1]) {
      im = ia + 1;
      j2 = ia + 1;
      j3 = ia;
    } else {
      im = ia + 2;
      j2 = ia;
      j3 = ia;
    }
    j4 = ia;
    j5 = ia + 1;
    v4 = v[ia + 2];
    v5 = v[ia + 3];
    if (v5 < v4) {
      j4 = ia + 1;
      j5 = ia;
      v5 = v4;
      v4 = v[ia + 3];
    }
    if (!(v5 < v[im - 1])) {
      if (v5 < v[j2]) {
        im = j5 + 3;
      } else if (v4 < v[j2]) {
        im = j2 + 1;
      } else if (v4 < v[j3 - 1]) {
        im = j4 + 3;
      } else {
        im = j3;
      }
    }
  }
  return im;
}

static int thirdOfFive(const emxArray_real32_T *v, int ia, int ib)
{
  const float *v_data;
  int im;
  v_data = v->data;
  if ((ia == ib) || (ia + 1 == ib)) {
    im = ia;
  } else if ((ia + 2 == ib) || (ia + 3 == ib)) {
    float v4;
    v4 = v_data[ia - 1];
    if (v4 < v_data[ia]) {
      if (v_data[ia] < v_data[ia + 1]) {
        im = ia + 1;
      } else if (v4 < v_data[ia + 1]) {
        im = ia + 2;
      } else {
        im = ia;
      }
    } else if (v4 < v_data[ia + 1]) {
      im = ia;
    } else if (v_data[ia] < v_data[ia + 1]) {
      im = ia + 2;
    } else {
      im = ia + 1;
    }
  } else {
    float v4;
    float v5;
    int j2;
    int j3;
    int j4;
    int j5;
    v4 = v_data[ia - 1];
    if (v4 < v_data[ia]) {
      if (v_data[ia] < v_data[ia + 1]) {
        im = ia;
        j2 = ia;
        j3 = ia + 2;
      } else if (v4 < v_data[ia + 1]) {
        im = ia;
        j2 = ia + 1;
        j3 = ia + 1;
      } else {
        im = ia + 2;
        j2 = ia - 1;
        j3 = ia + 1;
      }
    } else if (v4 < v_data[ia + 1]) {
      im = ia + 1;
      j2 = ia - 1;
      j3 = ia + 2;
    } else if (v_data[ia] < v_data[ia + 1]) {
      im = ia + 1;
      j2 = ia + 1;
      j3 = ia;
    } else {
      im = ia + 2;
      j2 = ia;
      j3 = ia;
    }
    j4 = ia;
    j5 = ia + 1;
    v4 = v_data[ia + 2];
    v5 = v_data[ia + 3];
    if (v5 < v4) {
      j4 = ia + 1;
      j5 = ia;
      v5 = v4;
      v4 = v_data[ia + 3];
    }
    if (!(v5 < v_data[im - 1])) {
      if (v5 < v_data[j2]) {
        im = j5 + 3;
      } else if (v4 < v_data[j2]) {
        im = j2 + 1;
      } else if (v4 < v_data[j3 - 1]) {
        im = j4 + 3;
      } else {
        im = j3;
      }
    }
  }
  return im;
}

float b_quickselect(emxArray_real32_T *v, int n, int vlen, int *nfirst,
                    int *nlast)
{
  float vn;
  float *v_data;
  int k;
  v_data = v->data;
  if (n > vlen) {
    vn = rtNaNF;
    *nfirst = 0;
    *nlast = 0;
  } else {
    int ia;
    int ib;
    int ifirst;
    int ilast;
    int ipiv;
    int oldnv;
    bool checkspeed;
    bool exitg1;
    bool isslow;
    ipiv = n;
    ia = 0;
    ib = vlen - 1;
    ifirst = 1;
    ilast = vlen - 1;
    oldnv = vlen;
    checkspeed = false;
    isslow = false;
    exitg1 = false;
    while ((!exitg1) && (ia + 1 < ib + 1)) {
      bool guard1;
      vn = v_data[ipiv - 1];
      v_data[ipiv - 1] = v_data[ib];
      v_data[ib] = vn;
      ilast = ia;
      ipiv = -1;
      for (k = ia + 1; k <= ib; k++) {
        float vk;
        vk = v_data[k - 1];
        if (vk == vn) {
          v_data[k - 1] = v_data[ilast];
          v_data[ilast] = vk;
          ipiv++;
          ilast++;
        } else if (vk < vn) {
          v_data[k - 1] = v_data[ilast];
          v_data[ilast] = vk;
          ilast++;
        }
      }
      v_data[ib] = v_data[ilast];
      v_data[ilast] = vn;
      guard1 = false;
      if (n <= ilast + 1) {
        ifirst = ilast - ipiv;
        if (n >= ifirst) {
          exitg1 = true;
        } else {
          ib = ilast - 1;
          guard1 = true;
        }
      } else {
        ia = ilast + 1;
        guard1 = true;
      }
      if (guard1) {
        ilast = (ib - ia) + 1;
        if (checkspeed) {
          isslow = (ilast > oldnv / 2);
          oldnv = ilast;
        }
        checkspeed = !checkspeed;
        if (isslow) {
          while (ilast > 1) {
            int b_nlast;
            int i;
            int ngroupsof5;
            ngroupsof5 = (int)((unsigned int)ilast / 5U);
            b_nlast = ilast - ngroupsof5 * 5;
            ilast = ngroupsof5;
            i = (unsigned char)ngroupsof5;
            for (k = 0; k < i; k++) {
              ipiv = (ia + k * 5) + 1;
              ipiv = thirdOfFive(v, ipiv, ipiv + 4) - 1;
              ifirst = ia + k;
              vn = v_data[ifirst];
              v_data[ifirst] = v_data[ipiv];
              v_data[ipiv] = vn;
            }
            if (b_nlast > 0) {
              ipiv = (ia + ngroupsof5 * 5) + 1;
              ipiv = thirdOfFive(v, ipiv, (ipiv + b_nlast) - 1) - 1;
              ifirst = ia + ngroupsof5;
              vn = v_data[ifirst];
              v_data[ifirst] = v_data[ipiv];
              v_data[ipiv] = vn;
              ilast = ngroupsof5 + 1;
            }
          }
        } else if (ilast >= 3) {
          ipiv = ia + (int)((unsigned int)(ilast - 1) >> 1);
          if (v_data[ia] < v_data[ipiv]) {
            if (!(v_data[ipiv] < v_data[ib])) {
              if (v_data[ia] < v_data[ib]) {
                ipiv = ib;
              } else {
                ipiv = ia;
              }
            }
          } else if (v_data[ia] < v_data[ib]) {
            ipiv = ia;
          } else if (v_data[ipiv] < v_data[ib]) {
            ipiv = ib;
          }
          if (ipiv + 1 > ia + 1) {
            vn = v_data[ia];
            v_data[ia] = v_data[ipiv];
            v_data[ipiv] = vn;
          }
        }
        ipiv = ia + 1;
        ifirst = ia + 1;
        ilast = ib;
      }
    }
    vn = v_data[ilast];
    *nfirst = ifirst;
    *nlast = ilast + 1;
  }
  return vn;
}

float c_quickselect(float v[10], int n, int vlen, int *nfirst, int *nlast)
{
  float vn;
  int k;
  if (n > vlen) {
    vn = rtNaNF;
    *nfirst = 0;
    *nlast = 0;
  } else {
    int ia;
    int ib;
    int ifirst;
    int ilast;
    int ipiv;
    int oldnv;
    bool checkspeed;
    bool exitg1;
    bool isslow;
    ipiv = n;
    ia = 0;
    ib = vlen - 1;
    ifirst = 1;
    ilast = vlen - 1;
    oldnv = vlen;
    checkspeed = false;
    isslow = false;
    exitg1 = false;
    while ((!exitg1) && (ia + 1 < ib + 1)) {
      bool guard1;
      vn = v[ipiv - 1];
      v[ipiv - 1] = v[ib];
      v[ib] = vn;
      ilast = ia;
      ipiv = -1;
      for (k = ia + 1; k <= ib; k++) {
        float vk;
        vk = v[k - 1];
        if (vk == vn) {
          v[k - 1] = v[ilast];
          v[ilast] = vk;
          ipiv++;
          ilast++;
        } else if (vk < vn) {
          v[k - 1] = v[ilast];
          v[ilast] = vk;
          ilast++;
        }
      }
      v[ib] = v[ilast];
      v[ilast] = vn;
      guard1 = false;
      if (n <= ilast + 1) {
        ifirst = ilast - ipiv;
        if (n >= ifirst) {
          exitg1 = true;
        } else {
          ib = ilast - 1;
          guard1 = true;
        }
      } else {
        ia = ilast + 1;
        guard1 = true;
      }
      if (guard1) {
        ilast = (ib - ia) + 1;
        if (checkspeed) {
          isslow = (ilast > oldnv / 2);
          oldnv = ilast;
        }
        checkspeed = !checkspeed;
        if (isslow) {
          while (ilast > 1) {
            int b_nlast;
            int i;
            int ngroupsof5;
            ngroupsof5 = (int)((unsigned int)ilast / 5U);
            b_nlast = ilast - ngroupsof5 * 5;
            ilast = ngroupsof5;
            i = (unsigned char)ngroupsof5;
            for (k = 0; k < i; k++) {
              ipiv = (ia + k * 5) + 1;
              ipiv = b_thirdOfFive(v, ipiv, ipiv + 4) - 1;
              ifirst = ia + k;
              vn = v[ifirst];
              v[ifirst] = v[ipiv];
              v[ipiv] = vn;
            }
            if (b_nlast > 0) {
              ipiv = (ia + ngroupsof5 * 5) + 1;
              ipiv = b_thirdOfFive(v, ipiv, (ipiv + b_nlast) - 1) - 1;
              ifirst = ia + ngroupsof5;
              vn = v[ifirst];
              v[ifirst] = v[ipiv];
              v[ipiv] = vn;
              ilast = ngroupsof5 + 1;
            }
          }
        } else if (ilast >= 3) {
          ipiv = ia + (int)((unsigned int)(ilast - 1) >> 1);
          if (v[ia] < v[ipiv]) {
            if (!(v[ipiv] < v[ib])) {
              if (v[ia] < v[ib]) {
                ipiv = ib;
              } else {
                ipiv = ia;
              }
            }
          } else if (v[ia] < v[ib]) {
            ipiv = ia;
          } else if (v[ipiv] < v[ib]) {
            ipiv = ib;
          }
          if (ipiv + 1 > ia + 1) {
            vn = v[ia];
            v[ia] = v[ipiv];
            v[ipiv] = vn;
          }
        }
        ipiv = ia + 1;
        ifirst = ia + 1;
        ilast = ib;
      }
    }
    vn = v[ilast];
    *nfirst = ifirst;
    *nlast = ilast + 1;
  }
  return vn;
}

float quickselect(emxArray_real32_T *v, int n, int vlen, int *nfirst,
                  int *nlast)
{
  float vn;
  float *v_data;
  int k;
  v_data = v->data;
  if (n > vlen) {
    vn = rtNaNF;
    *nfirst = 0;
    *nlast = 0;
  } else {
    int ia;
    int ib;
    int ifirst;
    int ilast;
    int ipiv;
    int oldnv;
    bool checkspeed;
    bool exitg1;
    bool isslow;
    ipiv = n;
    ia = 0;
    ib = vlen - 1;
    ifirst = 1;
    ilast = vlen - 1;
    oldnv = vlen;
    checkspeed = false;
    isslow = false;
    exitg1 = false;
    while ((!exitg1) && (ia + 1 < ib + 1)) {
      bool guard1;
      vn = v_data[ipiv - 1];
      v_data[ipiv - 1] = v_data[ib];
      v_data[ib] = vn;
      ilast = ia;
      ipiv = -1;
      for (k = ia + 1; k <= ib; k++) {
        float vk;
        vk = v_data[k - 1];
        if (vk == vn) {
          v_data[k - 1] = v_data[ilast];
          v_data[ilast] = vk;
          ipiv++;
          ilast++;
        } else if (vk < vn) {
          v_data[k - 1] = v_data[ilast];
          v_data[ilast] = vk;
          ilast++;
        }
      }
      v_data[ib] = v_data[ilast];
      v_data[ilast] = vn;
      guard1 = false;
      if (n <= ilast + 1) {
        ifirst = ilast - ipiv;
        if (n >= ifirst) {
          exitg1 = true;
        } else {
          ib = ilast - 1;
          guard1 = true;
        }
      } else {
        ia = ilast + 1;
        guard1 = true;
      }
      if (guard1) {
        ilast = (ib - ia) + 1;
        if (checkspeed) {
          isslow = (ilast > oldnv / 2);
          oldnv = ilast;
        }
        checkspeed = !checkspeed;
        if (isslow) {
          while (ilast > 1) {
            int b_nlast;
            int i;
            int ngroupsof5;
            ngroupsof5 = (int)((unsigned int)ilast / 5U);
            b_nlast = ilast - ngroupsof5 * 5;
            ilast = ngroupsof5;
            i = (unsigned char)ngroupsof5;
            for (k = 0; k < i; k++) {
              ipiv = (ia + k * 5) + 1;
              ipiv = thirdOfFive(v, ipiv, ipiv + 4) - 1;
              ifirst = ia + k;
              vn = v_data[ifirst];
              v_data[ifirst] = v_data[ipiv];
              v_data[ipiv] = vn;
            }
            if (b_nlast > 0) {
              ipiv = (ia + ngroupsof5 * 5) + 1;
              ipiv = thirdOfFive(v, ipiv, (ipiv + b_nlast) - 1) - 1;
              ifirst = ia + ngroupsof5;
              vn = v_data[ifirst];
              v_data[ifirst] = v_data[ipiv];
              v_data[ipiv] = vn;
              ilast = ngroupsof5 + 1;
            }
          }
        } else if (ilast >= 3) {
          ipiv = ia + (int)((unsigned int)(ilast - 1) >> 1);
          if (v_data[ia] < v_data[ipiv]) {
            if (!(v_data[ipiv] < v_data[ib])) {
              if (v_data[ia] < v_data[ib]) {
                ipiv = ib;
              } else {
                ipiv = ia;
              }
            }
          } else if (v_data[ia] < v_data[ib]) {
            ipiv = ia;
          } else if (v_data[ipiv] < v_data[ib]) {
            ipiv = ib;
          }
          if (ipiv + 1 > ia + 1) {
            vn = v_data[ia];
            v_data[ia] = v_data[ipiv];
            v_data[ipiv] = vn;
          }
        }
        ipiv = ia + 1;
        ifirst = ia + 1;
        ilast = ib;
      }
    }
    vn = v_data[ilast];
    *nfirst = ifirst;
    *nlast = ilast + 1;
  }
  return vn;
}

/* End of code generation (quickselect.c) */
