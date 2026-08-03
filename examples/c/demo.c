// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/* End-to-end C demo exercising the UniMath C ABI across the handle / value
 * surfaces: BigInt, Fixed (raw Q-format), BigFloat, Rational, the math_router
 * fixed transcendentals, and the cross-type conversions. Built by
 * `nimble cexample`. Every handle returned is freed; the ABI never raises. */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "UniMath.h"

/* Q32.32 scaling (32 fractional bits). */
#define Q32 4294967296.0
#define TO_Q32(x) ((long long)((x) * Q32))
#define FROM_Q32(q) ((double)(q) / Q32)

/* Print a BigInt handle as a decimal, then free it. */
static void show_bigint(const char *label, unimath_bigint h) {
  char buf[256];
  unimath_bigint_to_decimal(h, buf, sizeof buf);
  printf("%s = %s\n", label, buf);
  unimath_bigint_destroy(h);
}

int main(void) {
  if (!unimath_init()) { printf("unimath_init failed\n"); return 1; }
  printf("UniMath %s\n", unimath_version());

  /* ---- BigInt: 20! and (2^64)^2 via the handle ABI ---- */
  unimath_bigint acc = unimath_bigint_from_i64(1);
  for (int i = 1; i <= 20; i++) {
    unimath_bigint factor = unimath_bigint_from_i64(i);
    unimath_bigint next = unimath_bigint_mul(acc, factor);
    unimath_bigint_destroy(factor);
    unimath_bigint_destroy(acc);
    acc = next;
  }
  show_bigint("20!", acc);

  unimath_bigint two64 = unimath_bigint_from_i64(1);
  for (int i = 0; i < 64; i++) {
    unimath_bigint next = unimath_bigint_add(two64, two64); /* shl by 1 */
    unimath_bigint_destroy(two64);
    two64 = next;
  }
  unimath_bigint sq = unimath_bigint_mul(two64, two64);
  show_bigint("(2^64)^2", sq);
  unimath_bigint_destroy(two64);

  /* ---- Fixed: raw Q32.32 arithmetic ---- */
  printf("3 + 2 = %g\n", FROM_Q32(unimath_fixed_add(TO_Q32(3), TO_Q32(2))));
  printf("3 * 2 = %g\n",
         FROM_Q32(unimath_fixed_mul(TO_Q32(3), TO_Q32(2), 32)));
  printf("3 / 2 = %g\n",
         FROM_Q32(unimath_fixed_div(TO_Q32(3), TO_Q32(2), 32)));

  /* ---- BigFloat: range-reduced transcendentals ---- */
  unimath_bigfloat one = unimath_bigfloat_from_f64(1.0);
  unimath_bigfloat two_bf = unimath_bigfloat_from_f64(2.0);
  unimath_bigfloat s = unimath_bigfloat_sin(one);
  printf("sin(1)  = %g\n", unimath_bigfloat_to_f64(s));
  unimath_bigfloat_destroy(s);
  unimath_bigfloat e = unimath_bigfloat_exp(one);
  printf("exp(1)  = %g\n", unimath_bigfloat_to_f64(e));
  unimath_bigfloat_destroy(e);
  unimath_bigfloat l = unimath_bigfloat_ln(two_bf);
  printf("ln(2)   = %g\n", unimath_bigfloat_to_f64(l));
  unimath_bigfloat_destroy(l);
  unimath_bigfloat r = unimath_bigfloat_sqrt(two_bf);
  printf("sqrt(2) = %g\n", unimath_bigfloat_to_f64(r));
  unimath_bigfloat_destroy(r);
  unimath_bigfloat_destroy(one);
  unimath_bigfloat_destroy(two_bf);

  /* ---- Rational: exact 1/3, summed ---- */
  unimath_rational third = unimath_rational_from_i64(1, 3);
  unimath_rational sum = unimath_rational_add(third, third);
  unimath_rational tmp = unimath_rational_add(sum, third);
  unimath_rational_destroy(sum);
  sum = tmp;
  printf("1/3 + 1/3 + 1/3 = %g\n", unimath_rational_to_f64(sum));
  unimath_rational_destroy(third);
  unimath_rational_destroy(sum);

  /* ---- math_router: Fixed auto-dispatch (Q32.32) ---- */
  printf("fixed sqrt(2) = %g\n", FROM_Q32(unimath_fixed_sqrt(TO_Q32(2.0))));
  printf("fixed atan(1) = %g\n", FROM_Q32(unimath_fixed_atan(TO_Q32(1.0))));

  /* ---- conversions: cross-type round-trips ---- */
  unimath_rational half = unimath_rational_from_f64(0.5);
  printf("0.5 -> Rational -> f64 = %g\n", unimath_rational_to_f64(half));
  unimath_bigfloat bf_half = unimath_bigfloat_from_rational(half);
  printf("Rational 1/2 -> BigFloat = %g\n",
         unimath_bigfloat_to_f64(bf_half));
  unimath_interval iv = unimath_interval_from_bigfloat(bf_half);
  printf("BigFloat 1/2 -> Interval = [%g, %g]\n", iv.lo, iv.hi);
  unimath_rational_destroy(half);
  unimath_bigfloat_destroy(bf_half);

  unimath_cleanup();
  return 0;
}
