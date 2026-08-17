/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
/* The one limb primitive that needs the toolchain's help: 64x64 -> 128 unsigned
 * multiply.
 *
 * WHY A HEADER AND NOT A NIM `{.emit.}`. `mulWide` is `{.inline.}`, so Nim
 * inlines its callers' calls into their own translation units. A `static
 * inline` definition emitted into `primitives.nim.c` alone is invisible there
 * and the link fails on `unimath_mulwide`; making it external-linkage instead
 * would link, but turn the inner loop of every multiplication into a function
 * call. A header included by each calling unit is what gets both.
 *
 * NO THIRD-PARTY CODE. Both bodies are one documented compiler facility each:
 * GCC/Clang `unsigned __int128`
 *   https://gcc.gnu.org/onlinedocs/gcc/_005f_005fint128.html
 *   "supported for targets which have an integer mode wide enough to hold 128
 *   bits"; `__SIZEOF_INT128__` is the detection macro.
 * MSVC `_umul128`
 *   https://learn.microsoft.com/en-us/cpp/intrinsics/umul128
 *   x64 only, declared in <intrin.h>:
 *   unsigned __int64 _umul128(unsigned __int64, unsigned __int64,
 *                             unsigned __int64 *HighProduct);
 *
 * The selection is made by the C compiler's own feature macros rather than by
 * the Nim `when`, so a target that Nim guessed wrong about produces a directed
 * #error naming the escape hatch instead of a mysterious miscompile.
 */
#ifndef UNIMATH_LIMB_INTRINSICS_H
#define UNIMATH_LIMB_INTRINSICS_H

#if defined(__SIZEOF_INT128__)

#define UNIMATH_HAVE_MUL_BASECASE 1

static inline unsigned long long unimath_mulwide(unsigned long long a,
                                                 unsigned long long b,
                                                 unsigned long long *hi) {
  unsigned __int128 p = (unsigned __int128)a * (unsigned __int128)b;
  *hi = (unsigned long long)(p >> 64);
  return (unsigned long long)p;
}

/* Schoolbook product of `a` (an limbs) by `b` (bn limbs) into `r`
 * (an + bn limbs). `r` need NOT be zeroed: the first row writes rather than
 * accumulates.
 *
 * WHY THIS EXISTS ALONGSIDE `mulwide`. The Nim loop accumulates with `mulAdd`,
 * which is one `mulq` plus two add-with-carry steps whose carries the Nim code
 * threads by hand through separate locals. Handing the 128-bit accumulator to
 * the compiler instead lets it keep the carry in the flags and schedule the
 * multiply against the adds. Measured against the hand-carried loop, both
 * writing into a preallocated buffer: 1.33x at 4 limbs, 1.56x at 8, 1.67x at
 * 16. (GMP's assembly is another 1.5x-1.9x beyond that and is not reachable
 * from portable C.)
 *
 * Column-wise accumulation was measured too and is slower than this at every
 * size, so the row form is what ships. */
static inline void unimath_mul_basecase(unsigned long long *r,
                                        const unsigned long long *a,
                                        long long an,
                                        const unsigned long long *b,
                                        long long bn) {
  {
    unsigned __int128 carry = 0;
    const unsigned long long a0 = a[0];
    for (long long j = 0; j < bn; j++) {
      unsigned __int128 t = (unsigned __int128)a0 * b[j]
                          + (unsigned long long)carry;
      r[j] = (unsigned long long)t;
      carry = t >> 64;
    }
    r[bn] = (unsigned long long)carry;
  }
  for (long long i = 1; i < an; i++) {
    unsigned __int128 carry = 0;
    const unsigned long long ai = a[i];
    for (long long j = 0; j < bn; j++) {
      unsigned __int128 t = (unsigned __int128)ai * b[j] + r[i + j]
                          + (unsigned long long)carry;
      r[i + j] = (unsigned long long)t;
      carry = t >> 64;
    }
    r[i + bn] = (unsigned long long)carry;
  }
}

#elif defined(_MSC_VER) && (defined(_M_X64) || defined(_M_AMD64))

#include <intrin.h>

static __forceinline unsigned __int64 unimath_mulwide(unsigned __int64 a,
                                                      unsigned __int64 b,
                                                      unsigned __int64 *hi) {
  return _umul128(a, b, hi);
}

#else

#error "UniMath: no 64x64->128 multiply on this target. Rebuild with \
-d:noInt128 to use the portable limb primitives."

#endif

#endif /* UNIMATH_LIMB_INTRINSICS_H */
