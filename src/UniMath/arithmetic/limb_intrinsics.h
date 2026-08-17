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

static inline unsigned long long unimath_mulwide(unsigned long long a,
                                                 unsigned long long b,
                                                 unsigned long long *hi) {
  unsigned __int128 p = (unsigned __int128)a * (unsigned __int128)b;
  *hi = (unsigned long long)(p >> 64);
  return (unsigned long long)p;
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
