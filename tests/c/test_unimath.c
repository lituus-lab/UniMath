// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "UniMath.h"

static int failures = 0;

static void check_str(const char *name, const char *got, const char *want) {
  if (strcmp(got, want) != 0) { printf("FAIL %s: got \"%s\" want \"%s\"\n", name, got, want); failures++; }
  else printf("ok   %s = \"%s\"\n", name, got);
}

static void check_int(const char *name, long long got, long long want) {
  if (got != want) { printf("FAIL %s: got %lld want %lld\n", name, got, want); failures++; }
  else printf("ok   %s = %lld\n", name, got);
}

static void check_dbl(const char *name, double got, double want) {
  if (fabs(got - want) > 1e-12) { printf("FAIL %s: got %.17g want %.17g\n", name, got, want); failures++; }
  else printf("ok   %s = %.17g\n", name, got);
}

/* Approximate cores (Taylor with few terms, CORDIC, LUT, Chebyshev) are not
 * bit-exact: compare with an algorithm-specific tolerance. */
static void check_dbl_tol(const char *name, double got, double want, double tol) {
  if (fabs(got - want) > tol) { printf("FAIL %s: got %.17g want %.17g (tol %.0e)\n", name, got, want, tol); failures++; }
  else printf("ok   %s = %.17g\n", name, got);
}

/* Q32.32 fixed-point (32 fractional bits): convert a raw long long to double. */
#define Q32 4294967296.0
#define TO_Q32(x) ((long long)((x) * Q32))
#define FROM_Q32(q) ((double)(q) / Q32)

/* Interval results are widened enclosures: pass iff the result contains the
 * exact [wantLo, wantHi] and is itself a valid (lo <= hi) interval. */
static void check_enc(const char *name, unimath_interval got, double wantLo,
                       double wantHi) {
  if (got.lo <= wantLo && got.hi >= wantHi && got.lo <= got.hi)
    printf("ok   %s = [%.17g, %.17g]\n", name, got.lo, got.hi);
  else {
    printf("FAIL %s: got [%.17g, %.17g] must enclose [%.17g, %.17g]\n", name,
           got.lo, got.hi, wantLo, wantHi);
    failures++;
  }
}

/* Read a BigInt's decimal into a caller-owned malloc'd buffer. Returns NULL
 * if to_decimal reports the buffer is too small (should not happen at 256). */
static char *bigint_dec(unimath_bigint h) {
  size_t cap = 256;
  char *buf = (char *)malloc(cap);
  int n = unimath_bigint_to_decimal(h, buf, cap);
  if (n < 0) { free(buf); return NULL; }
  return buf;
}

/* Decimal of a freshly built BigInt, freed after use. */
static char *dec_of(const char *expr, unimath_bigint h) {
  (void)expr;
  char *s = bigint_dec(h);
  unimath_bigint_destroy(h);
  return s;
}

/* Apply a unary BigFloat transcendental to x, check the float64 result, and
 * destroy both handles. */
static void check_bf_unary(const char *name, unimath_bigfloat (*fn)(unimath_bigfloat),
                           double x, double want, double tol) {
  unimath_bigfloat h = unimath_bigfloat_from_f64(x);
  unimath_bigfloat r = fn(h);
  check_dbl_tol(name, unimath_bigfloat_to_f64(r), want, tol);
  unimath_bigfloat_destroy(h);
  unimath_bigfloat_destroy(r);
}

/* Apply a unary Rational transcendental to num/den, check the float64 result,
 * and destroy both handles. The series are truncated (5 trig / 10 exp-ln
 * terms), so the tolerance reflects the truncation, not rounding. */
static void check_rat_unary(const char *name, unimath_rational (*fn)(unimath_rational),
                            long long num, long long den, double want, double tol) {
  unimath_rational h = unimath_rational_from_i64(num, den);
  unimath_rational r = fn(h);
  check_dbl_tol(name, unimath_rational_to_f64(r), want, tol);
  unimath_rational_destroy(h);
  unimath_rational_destroy(r);
}

/* Apply a unary Q32.32 fixed transcendental to x, check the float64 result.
 * The raw Q32.32 word is `x * 2^32`; the result word is divided back. */
static void check_fix_unary(const char *name, long long (*fn)(long long),
                           double x, double want, double tol) {
  long long q = TO_Q32(x);
  long long r = fn(q);
  check_dbl_tol(name, FROM_Q32(r), want, tol);
}

int main(void) {
  if (!unimath_init()) { printf("FAIL: unimath_init returned 0\n"); return 1; }

  check_str("version", unimath_version(), UNIMATH_VERSION);

  /* ---- BigInt construction & round-trip ---- */
  unimath_bigint a = unimath_bigint_from_i64(-123456789);
  check_str("from_i64(-123456789)", dec_of("a", a), "-123456789");

  unimath_bigint b = unimath_bigint_from_decimal("1000000000000000000000");
  check_str("from_decimal(1e21)", dec_of("b", b), "1000000000000000000000");

  unimath_bigint bad = unimath_bigint_from_decimal("12abc");
  if (bad != NULL) { printf("FAIL from_decimal(\"12abc\") should be NULL\n"); failures++; unimath_bigint_destroy(bad); }
  else printf("ok   from_decimal(\"12abc\") = NULL\n");

  /* ---- arithmetic against known values ---- */
  unimath_bigint x = unimath_bigint_from_decimal("999999999999");
  unimath_bigint y = unimath_bigint_from_i64(1);
  check_str("add", dec_of("x+y", unimath_bigint_add(x, y)), "1000000000000");
  check_str("sub", dec_of("x-y", unimath_bigint_sub(x, y)), "999999999998");
  check_str("mul", dec_of("x*y", unimath_bigint_mul(x, y)), "999999999999");
  unimath_bigint_destroy(x);
  unimath_bigint_destroy(y);

  unimath_bigint n = unimath_bigint_from_decimal("1000000000000000000000");
  unimath_bigint d = unimath_bigint_from_decimal("7");
  check_str("div", dec_of("n/d", unimath_bigint_div(n, d)), "142857142857142857142");
  check_str("mod", dec_of("n mod d", unimath_bigint_mod(n, d)), "6");

  /* signed truncation: -7 div 2 = -3, -7 mod 2 = -1 */
  unimath_bigint s = unimath_bigint_from_i64(-7);
  unimath_bigint t = unimath_bigint_from_i64(2);
  check_str("(-7) div 2", dec_of("s div t", unimath_bigint_div(s, t)), "-3");
  check_str("(-7) mod 2", dec_of("s mod t", unimath_bigint_mod(s, t)), "-1");
  check_str("neg(-7)", dec_of("-s", unimath_bigint_neg(s)), "7");
  check_str("abs(-7)", dec_of("abs(s)", unimath_bigint_abs(s)), "7");
  check_int("cmp(-7,2)", unimath_bigint_cmp(s, t), -1);
  check_int("cmp(2,-7)", unimath_bigint_cmp(t, s), 1);
  check_int("cmp(2,2)", unimath_bigint_cmp(t, t), 0);
  unimath_bigint_destroy(s);
  unimath_bigint_destroy(t);

  /* div by zero returns NULL, never raises */
  unimath_bigint dz = unimath_bigint_div(n, unimath_bigint_from_i64(0));
  if (dz != NULL) { printf("FAIL div by zero should be NULL\n"); failures++; unimath_bigint_destroy(dz); }
  else printf("ok   div by zero = NULL\n");

  /* to_i64 clamps out-of-range; in-range sets out_ok. */
  int ok = 2;
  check_int("to_i64(1e21) clamps", unimath_bigint_to_i64(n, &ok), 9223372036854775807LL);
  if (ok != 0) { printf("FAIL to_i64(1e21) out_ok should be 0\n"); failures++; }
  else printf("ok   to_i64(1e21) out_ok = 0\n");
  unimath_bigint small = unimath_bigint_from_i64(-42);
  ok = 2;
  check_int("to_i64(-42)", unimath_bigint_to_i64(small, &ok), -42);
  if (ok != 1) { printf("FAIL to_i64(-42) out_ok should be 1\n"); failures++; }
  else printf("ok   to_i64(-42) out_ok = 1\n");
  unimath_bigint_destroy(small);
  unimath_bigint_destroy(n);
  unimath_bigint_destroy(d);

  /* ---- Fixed (raw int64 Q16.16) ---- */
  const int FB = 16;
  long long q3 = unimath_fixed_from_int(3, FB);      /* 3 << 16 */
  check_int("fixed_from_int(3)", q3, 3LL << 16);
  check_int("fixed_to_int(3<<16)", unimath_fixed_to_int(q3, FB), 3);
  check_int("fixed_add", unimath_fixed_add(q3, q3), 6LL << 16);
  check_int("fixed_sub", unimath_fixed_sub(q3, unimath_fixed_from_int(1, FB)), 2LL << 16);
  /* 2 * 3 = 6 real -> 6 << 16 */
  check_int("fixed_mul(2,3)", unimath_fixed_mul(2LL << 16, 3LL << 16, FB), 6LL << 16);
  /* 7 / 2 = 3.5 real -> 3.5 << 16 = 229376; to_int truncates to 3 */
  check_int("fixed_div(7,2)", unimath_fixed_div(7LL << 16, 2LL << 16, FB), 229376LL);
  check_int("fixed_div_to_int", unimath_fixed_to_int(229376LL, FB), 3);
  /* division by zero returns 0, never raises */
  check_int("fixed_div by zero", unimath_fixed_div(7LL << 16, 0, FB), 0);
  /* out-of-range shift clamps to int64 extremes */
  check_int("fixed_from_int clamps high", unimath_fixed_from_int(9223372036854775807LL, FB), 9223372036854775807LL);
  check_int("fixed_from_int clamps low", unimath_fixed_from_int(-9223372036854775807LL - 1, FB), -9223372036854775807LL - 1);

  /* ---- BigFloat (handle, default 256-bit precision) ---- */
  unimath_bigfloat fa = unimath_bigfloat_from_f64(10.0);
  unimath_bigfloat fb = unimath_bigfloat_from_f64(3.0);
  check_dbl("bigfloat_from_f64(10)", unimath_bigfloat_to_f64(fa), 10.0);
  check_dbl("bigfloat_from_f64(-0.125)", unimath_bigfloat_to_f64(unimath_bigfloat_from_f64(-0.125)), -0.125);
  check_dbl("bigfloat_add", unimath_bigfloat_to_f64(unimath_bigfloat_add(fa, fb)), 13.0);
  check_dbl("bigfloat_sub", unimath_bigfloat_to_f64(unimath_bigfloat_sub(fa, fb)), 7.0);
  check_dbl("bigfloat_mul", unimath_bigfloat_to_f64(unimath_bigfloat_mul(fa, fb)), 30.0);
  check_dbl("bigfloat_div", unimath_bigfloat_to_f64(unimath_bigfloat_div(fa, fb)), 10.0 / 3.0);
  /* from_i64 is exact (no float64 detour): 2^60 round-trips exactly. */
  check_dbl("bigfloat_from_i64(2^60)", unimath_bigfloat_to_f64(unimath_bigfloat_from_i64(1LL << 60)), (double)(1LL << 60));
  check_int("bigfloat_cmp(3,10)", unimath_bigfloat_cmp(fb, fa), -1);
  check_int("bigfloat_cmp(10,3)", unimath_bigfloat_cmp(fa, fb), 1);
  check_int("bigfloat_cmp(3,3)", unimath_bigfloat_cmp(fb, fb), 0);
  /* division by zero returns NULL, never raises */
  unimath_bigfloat dzf = unimath_bigfloat_div(fa, unimath_bigfloat_from_f64(0.0));
  if (dzf != NULL) { printf("FAIL bigfloat div by zero should be NULL\n"); failures++; unimath_bigfloat_destroy(dzf); }
  else printf("ok   bigfloat div by zero = NULL\n");
  /* Inf/NaN are not representable: from_f64 returns NULL */
  if (unimath_bigfloat_from_f64(INFINITY) != NULL) { printf("FAIL bigfloat_from_f64(Inf) should be NULL\n"); failures++; }
  else printf("ok   bigfloat_from_f64(Inf) = NULL\n");
  if (unimath_bigfloat_from_f64(NAN) != NULL) { printf("FAIL bigfloat_from_f64(NaN) should be NULL\n"); failures++; }
  else printf("ok   bigfloat_from_f64(NaN) = NULL\n");
  /* overflow to_f64 -> +Inf */
  unimath_bigfloat huge = unimath_bigfloat_mul(unimath_bigfloat_from_f64(1e308), unimath_bigfloat_from_f64(1e308));
  if (!isinf(unimath_bigfloat_to_f64(huge))) { printf("FAIL bigfloat overflow should be Inf\n"); failures++; }
  else printf("ok   bigfloat overflow = Inf\n");
  unimath_bigfloat_destroy(fa);
  unimath_bigfloat_destroy(fb);
  unimath_bigfloat_destroy(huge);

  /* ---- Rational (handle, unbounded exact Rational[BigInt]) ---- */
  unimath_rational ra = unimath_rational_from_i64(1, 2);
  unimath_rational rb = unimath_rational_from_i64(1, 3);
  check_dbl("rational_from_i64(1,2)", unimath_rational_to_f64(ra), 0.5);
  check_dbl("rational_add", unimath_rational_to_f64(unimath_rational_add(ra, rb)), 5.0 / 6.0);
  check_dbl("rational_sub", unimath_rational_to_f64(unimath_rational_sub(ra, rb)), 1.0 / 6.0);
  check_dbl("rational_mul", unimath_rational_to_f64(unimath_rational_mul(ra, rb)), 1.0 / 6.0);
  check_dbl("rational_div", unimath_rational_to_f64(unimath_rational_div(ra, rb)), 1.5);
  check_dbl("rational_neg", unimath_rational_to_f64(unimath_rational_neg(ra)), -0.5);
  check_dbl("rational_abs", unimath_rational_to_f64(unimath_rational_abs(unimath_rational_from_i64(-3, 4))), 0.75);
  check_int("rational_cmp(1/3,1/2)", unimath_rational_cmp(rb, ra), -1);
  check_int("rational_cmp(1/2,1/3)", unimath_rational_cmp(ra, rb), 1);
  check_int("rational_cmp(1/2,1/2)", unimath_rational_cmp(ra, ra), 0);
  /* from_bigint reduces 4/8 -> 1/2 */
  unimath_bigint bn = unimath_bigint_from_i64(4);
  unimath_bigint bd = unimath_bigint_from_i64(8);
  check_dbl("rational_from_bigint(4,8)", unimath_rational_to_f64(unimath_rational_from_bigint(bn, bd)), 0.5);
  unimath_bigint_destroy(bn);
  unimath_bigint_destroy(bd);
  /* zero denominator returns NULL, never raises */
  if (unimath_rational_from_i64(1, 0) != NULL) { printf("FAIL rational_from_i64(1,0) should be NULL\n"); failures++; }
  else printf("ok   rational_from_i64(1,0) = NULL\n");
  unimath_rational rz = unimath_rational_div(ra, unimath_rational_from_i64(0, 1));
  if (rz != NULL) { printf("FAIL rational div by zero should be NULL\n"); failures++; unimath_rational_destroy(rz); }
  else printf("ok   rational div by zero = NULL\n");
  unimath_rational_destroy(ra);
  unimath_rational_destroy(rb);

  /* ---- Interval (value type: two doubles, returned by value) ---- */
  const double C_PI = 3.14159265358979323846;
  const double C_E = 2.71828182845904523536;
  unimath_interval iv = unimath_interval_from_f64(1.0, 2.0);
  check_dbl("interval_lo", unimath_interval_lo(iv), 1.0);
  check_dbl("interval_hi", unimath_interval_hi(iv), 2.0);
  check_enc("interval_add", unimath_interval_add(unimath_interval_from_f64(1.0, 2.0),
                                                 unimath_interval_from_f64(3.0, 4.0)), 4.0, 6.0);
  check_enc("interval_sub", unimath_interval_sub(unimath_interval_from_f64(1.0, 2.0),
                                                 unimath_interval_from_f64(3.0, 4.0)), -3.0, -2.0);
  check_enc("interval_mul", unimath_interval_mul(unimath_interval_from_f64(2.0, 3.0),
                                                 unimath_interval_from_f64(4.0, 5.0)), 8.0, 15.0);
  check_enc("interval_div", unimath_interval_div(unimath_interval_from_f64(6.0, 8.0),
                                                 unimath_interval_from_f64(2.0, 4.0)), 1.5, 4.0);
  /* division by an interval containing zero is unbounded -> (-Inf, Inf) */
  unimath_interval dzv = unimath_interval_div(unimath_interval_from_f64(1.0, 2.0),
                                              unimath_interval_from_f64(-1.0, 1.0));
  if (isinf(dzv.lo) && dzv.lo < 0 && isinf(dzv.hi) && dzv.hi > 0)
    printf("ok   interval div by uncertain = (-Inf, Inf)\n");
  else { printf("FAIL interval div by uncertain should be (-Inf, Inf), got [%.17g, %.17g]\n", dzv.lo, dzv.hi); failures++; }
  check_enc("interval_sqrt", unimath_interval_sqrt(unimath_interval_from_f64(4.0, 9.0)), 2.0, 3.0);
  /* sqrt clamps a negative lower bound to 0 */
  check_enc("interval_sqrt clamp", unimath_interval_sqrt(unimath_interval_from_f64(-1.0, 4.0)), 0.0, 2.0);
  /* sqrt of a wholly negative interval -> NaN sentinel */
  unimath_interval sn = unimath_interval_sqrt(unimath_interval_from_f64(-4.0, -1.0));
  if (isnan(sn.lo) && isnan(sn.hi)) printf("ok   interval sqrt negative = NaN\n");
  else { printf("FAIL interval sqrt negative should be NaN, got [%.17g, %.17g]\n", sn.lo, sn.hi); failures++; }
  check_enc("interval_exp", unimath_interval_exp(unimath_interval_from_f64(0.0, 1.0)), 1.0, C_E);
  check_enc("interval_ln", unimath_interval_ln(unimath_interval_from_f64(1.0, C_E)), 0.0, 1.0);
  /* ln of an interval straddling zero -> (-Inf, ln(hi)] (clamp branch) */
  unimath_interval lnz = unimath_interval_ln(unimath_interval_from_f64(0.0, 1.0));
  if (isinf(lnz.lo) && lnz.lo < 0 && lnz.hi >= 0.0) printf("ok   interval ln(0,1) = (-Inf, <=0]\n");
  else { printf("FAIL interval ln(0,1) should start at -Inf, got [%.17g, %.17g]\n", lnz.lo, lnz.hi); failures++; }
  /* ln of a wholly non-positive interval -> NaN sentinel */
  unimath_interval lnn = unimath_interval_ln(unimath_interval_from_f64(-2.0, -1.0));
  if (isnan(lnn.lo) && isnan(lnn.hi)) printf("ok   interval ln negative = NaN\n");
  else { printf("FAIL interval ln negative should be NaN, got [%.17g, %.17g]\n", lnn.lo, lnn.hi); failures++; }
  /* sin over [0, pi] encloses the pi/2 maximum -> full [-1, 1] */
  unimath_interval sfull = unimath_interval_sin(unimath_interval_from_f64(0.0, C_PI));
  if (sfull.lo == -1.0 && sfull.hi == 1.0) printf("ok   interval sin(0,pi) = [-1, 1]\n");
  else { printf("FAIL interval sin(0,pi) should be [-1, 1], got [%.17g, %.17g]\n", sfull.lo, sfull.hi); failures++; }
  /* cos over [-0.5, 0.5] encloses the 0 maximum -> full [-1, 1] */
  unimath_interval cfull = unimath_interval_cos(unimath_interval_from_f64(-0.5, 0.5));
  if (cfull.lo == -1.0 && cfull.hi == 1.0) printf("ok   interval cos(-0.5,0.5) = [-1, 1]\n");
  else { printf("FAIL interval cos(-0.5,0.5) should be [-1, 1], got [%.17g, %.17g]\n", cfull.lo, cfull.hi); failures++; }

  /* ---- Roots ---- */
  check_int("isqrt(15)", unimath_isqrt_i64(15), 3);
  check_int("isqrt(16)", unimath_isqrt_i64(16), 4);
  check_int("isqrt(0)", unimath_isqrt_i64(0), 0);
  /* negative input clamps to 0 (never raises) */
  check_int("isqrt(-1) clamp", unimath_isqrt_i64(-1), 0);
  check_dbl("sqrt_newton_f64(4)", unimath_sqrt_newton_f64(4.0), 2.0);
  check_dbl("sqrt_newton_f64(2)", unimath_sqrt_newton_f64(2.0), sqrt(2.0));
  /* negative input -> NaN (never raises) */
  if (isnan(unimath_sqrt_newton_f64(-1.0))) printf("ok   sqrt_newton_f64(-1) = NaN\n");
  else { printf("FAIL sqrt_newton_f64(-1) should be NaN\n"); failures++; }
  /* BigFloat Newton sqrt of 4 -> 2 (within float64), then free the handle */
  unimath_bigfloat bf4 = unimath_bigfloat_from_f64(4.0);
  unimath_bigfloat bfs = unimath_sqrt_newton_bigfloat(bf4);
  check_dbl("sqrt_newton_bigfloat(4)", unimath_bigfloat_to_f64(bfs), 2.0);
  unimath_bigfloat_destroy(bf4);
  unimath_bigfloat_destroy(bfs);
  /* negative BigFloat -> NULL (never raises) */
  unimath_bigfloat bfneg = unimath_bigfloat_from_f64(-4.0);
  if (unimath_sqrt_newton_bigfloat(bfneg) == NULL) printf("ok   sqrt_newton_bigfloat(-4) = NULL\n");
  else { printf("FAIL sqrt_newton_bigfloat(-4) should be NULL\n"); failures++; }
  unimath_bigfloat_destroy(bfneg);

  /* ---- Exponential ---- */
  check_dbl("exp_taylor_f64(0)", unimath_exp_taylor_f64(0.0), 1.0);
  check_dbl("exp_taylor_f64(1)", unimath_exp_taylor_f64(1.0), C_E);
  check_dbl("ln_taylor_f64(0)", unimath_ln_taylor_f64(0.0), 0.0);
  /* ln(1+x) at x=0.5 -> ln(1.5), 15-term series converges to ~1e-5 */
  if (fabs(unimath_ln_taylor_f64(0.5) - log(1.5)) < 1e-4) printf("ok   ln_taylor_f64(0.5) ~ ln(1.5)\n");
  else { printf("FAIL ln_taylor_f64(0.5) = %.17g, want ~%.17g\n", unimath_ln_taylor_f64(0.5), log(1.5)); failures++; }
  /* x <= -1 is out of domain -> NaN */
  if (isnan(unimath_ln_taylor_f64(-1.0))) printf("ok   ln_taylor_f64(-1) = NaN\n");
  else { printf("FAIL ln_taylor_f64(-1) should be NaN\n"); failures++; }
  check_dbl("ln_generic_f64(1)", unimath_ln_generic_f64(1.0), 0.0);
  if (fabs(unimath_ln_generic_f64(2.0) - log(2.0)) < 1e-6) printf("ok   ln_generic_f64(2) ~ ln(2)\n");
  else { printf("FAIL ln_generic_f64(2) = %.17g, want ~%.17g\n", unimath_ln_generic_f64(2.0), log(2.0)); failures++; }
  /* z <= 0 is out of domain -> NaN */
  if (isnan(unimath_ln_generic_f64(0.0))) printf("ok   ln_generic_f64(0) = NaN\n");
  else { printf("FAIL ln_generic_f64(0) should be NaN\n"); failures++; }
  /* BigFloat exp(ln(2)) round trip within float64 */
  unimath_bigfloat bf2 = unimath_bigfloat_from_f64(2.0);
  unimath_bigfloat bfln = unimath_ln_generic_bigfloat(bf2);
  check_dbl("ln_generic_bigfloat(2)", unimath_bigfloat_to_f64(bfln), log(2.0));
  unimath_bigfloat bfexp = unimath_exp_taylor_bigfloat(bfln);
  check_dbl("exp_taylor_bigfloat(ln 2)", unimath_bigfloat_to_f64(bfexp), 2.0);
  unimath_bigfloat_destroy(bf2);
  unimath_bigfloat_destroy(bfln);
  unimath_bigfloat_destroy(bfexp);
  /* ln of a non-positive BigFloat -> NULL */
  unimath_bigfloat bf0 = unimath_bigfloat_from_f64(0.0);
  if (unimath_ln_generic_bigfloat(bf0) == NULL) printf("ok   ln_generic_bigfloat(0) = NULL\n");
  else { printf("FAIL ln_generic_bigfloat(0) should be NULL\n"); failures++; }
  unimath_bigfloat_destroy(bf0);

  /* ---- Trigonometry ----
   * Taylor sin/cos/atan over float64 (tol 1e-6, 5-term series), and the
   * fixed-point CORDIC/LUT/Chebyshev cores over Q32.32 (tol 1e-3 for CORDIC/
   * Chebyshev, 0.02 for nearest-neighbour LUT). */
  check_dbl_tol("taylor_sin_f64(0)", unimath_taylor_sin_f64(0.0), 0.0, 1e-6);
  check_dbl_tol("taylor_sin_f64(0.5)", unimath_taylor_sin_f64(0.5), sin(0.5), 1e-6);
  check_dbl_tol("taylor_cos_f64(0)", unimath_taylor_cos_f64(0.0), 1.0, 1e-6);
  check_dbl_tol("taylor_cos_f64(0.5)", unimath_taylor_cos_f64(0.5), cos(0.5), 1e-6);
  check_dbl_tol("taylor_atan_f64(0.5)", unimath_taylor_atan_f64(0.5), atan(0.5), 1e-6);
  check_dbl_tol("cordic_sin(0)", FROM_Q32(unimath_cordic_sin(0)), 0.0, 1e-3);
  check_dbl_tol("cordic_sin(0.5)", FROM_Q32(unimath_cordic_sin(TO_Q32(0.5))), sin(0.5), 1e-3);
  check_dbl_tol("cordic_cos(0)", FROM_Q32(unimath_cordic_cos(0)), 1.0, 1e-3);
  check_dbl_tol("cordic_cos(0.5)", FROM_Q32(unimath_cordic_cos(TO_Q32(0.5))), cos(0.5), 1e-3);
  check_dbl_tol("cordic_atan2(1,1)", FROM_Q32(unimath_cordic_atan2(TO_Q32(1.0), TO_Q32(1.0))), atan2(1.0, 1.0), 1e-3);
  check_dbl_tol("lut_sin(0)", FROM_Q32(unimath_lut_sin(0)), 0.0, 0.02);
  check_dbl_tol("lut_cos(0)", FROM_Q32(unimath_lut_cos(0)), 1.0, 0.02);
  check_dbl_tol("lut_sin(0.5)", FROM_Q32(unimath_lut_sin(TO_Q32(0.5))), sin(0.5), 0.02);
  check_dbl_tol("chebyshev_tan(0)", FROM_Q32(unimath_chebyshev_tan(0)), 0.0, 1e-3);
  check_dbl_tol("chebyshev_tan(0.5)", FROM_Q32(unimath_chebyshev_tan(TO_Q32(0.5))), tan(0.5), 1e-3);
  /* Hyperbolic CORDIC over Q32.32; angles clamped to the ~1.1182 domain. */
  check_dbl_tol("cordic_sinh(0)", FROM_Q32(unimath_cordic_sinh(0)), 0.0, 1e-3);
  check_dbl_tol("cordic_cosh(0)", FROM_Q32(unimath_cordic_cosh(0)), 1.0, 1e-3);
  check_dbl_tol("cordic_exp(0)", FROM_Q32(unimath_cordic_exp(0)), 1.0, 1e-3);
  check_dbl_tol("cordic_sinh(1)", FROM_Q32(unimath_cordic_sinh(TO_Q32(1.0))), sinh(1.0), 1e-3);
  check_dbl_tol("cordic_cosh(1)", FROM_Q32(unimath_cordic_cosh(TO_Q32(1.0))), cosh(1.0), 1e-3);
  check_dbl_tol("cordic_tanh(1)", FROM_Q32(unimath_cordic_tanh(TO_Q32(1.0))), tanh(1.0), 1e-3);
  check_dbl_tol("cordic_exp(1)", FROM_Q32(unimath_cordic_exp(TO_Q32(1.0))), exp(1.0), 1e-3);
  /* Out-of-domain (2.0 > ~1.1182 budget) is clamped, not raised: returns the
   * boundary value exp(1.10) within a loose tolerance. */
  check_dbl_tol("cordic_exp(2.0) clamped", FROM_Q32(unimath_cordic_exp(TO_Q32(2.0))), exp(1.10), 0.2);

  /* ---- Special ----
   * Orthogonal polynomials, erf, Gamma, factorial, Bessel J0 — all float64.
   * `gamma` returns NaN at the poles (never raises); `factorial` is 0 for n<0. */
  check_dbl_tol("chebyshev_t(2,0.5)", unimath_chebyshev_t(2, 0.5), -0.5, 1e-12);
  check_dbl_tol("chebyshev_u(2,0.5)", unimath_chebyshev_u(2, 0.5), 0.0, 1e-12);
  check_dbl_tol("legendre(2,0.5)", unimath_legendre(2, 0.5), -0.125, 1e-12);
  check_dbl_tol("hermite(3,0.5)", unimath_hermite(3, 0.5), -5.0, 1e-12);
  check_dbl_tol("erf(0)", unimath_erf(0.0), 0.0, 1e-12);
  check_dbl_tol("erf(0.5)", unimath_erf(0.5), 0.5205, 1e-3);
  check_dbl_tol("gamma(1)", unimath_gamma(1.0), 1.0, 1e-10);
  check_dbl_tol("gamma(5)", unimath_gamma(5.0), 24.0, 1e-9);
  check_dbl_tol("gamma(0.5)", unimath_gamma(0.5), sqrt(M_PI), 1e-10);
  /* poles return NaN, not a raise */
  if (!isnan(unimath_gamma(0.0))) { printf("FAIL gamma(0) should be NaN\n"); failures++; }
  if (!isnan(unimath_gamma(-1.0))) { printf("FAIL gamma(-1) should be NaN\n"); failures++; }
  check_dbl_tol("factorial(5)", unimath_factorial(5), 120.0, 1e-12);
  check_dbl_tol("factorial(0)", unimath_factorial(0), 1.0, 1e-12);
  check_dbl_tol("factorial(-1)", unimath_factorial(-1), 0.0, 1e-12);
  check_dbl_tol("bessel_j0(0)", unimath_bessel_j0(0.0), 1.0, 1e-12);
  check_dbl_tol("bessel_j0(0.5)", unimath_bessel_j0(0.5), 0.9385, 1e-3);

  /* ---- Constants ----
   * pi/e as 256-bit BigFloat handles (extract via to_f64, then destroy) and
   * as raw Q32.32 words. */
  {
    void *pi_h = unimath_pi_bigfloat();
    void *e_h = unimath_e_bigfloat();
    check_dbl_tol("pi_bigfloat", unimath_bigfloat_to_f64(pi_h), M_PI, 1e-15);
    check_dbl_tol("e_bigfloat", unimath_bigfloat_to_f64(e_h), M_E, 1e-15);
    unimath_bigfloat_destroy(pi_h);
    unimath_bigfloat_destroy(e_h);
  }
  check_dbl_tol("pi_fixed", FROM_Q32(unimath_pi_fixed()), M_PI, 1e-9);
  check_dbl_tol("e_fixed", FROM_Q32(unimath_e_fixed()), M_E, 1e-9);

  /* ---- Reduction ----
   * BigFloat trig stage-1 reduction mod 2pi into [-pi, pi]. The handle is
   * destroyed after extraction. */
  {
    void *x = unimath_bigfloat_from_f64(2.0 * M_PI + 0.5);
    void *r = unimath_bigfloat_reduce(x);
    check_dbl_tol("bigfloat_reduce(2pi+0.5)", unimath_bigfloat_to_f64(r), 0.5, 1e-12);
    unimath_bigfloat_destroy(x);
    unimath_bigfloat_destroy(r);
  }

  /* ---- float_math ----
   * Range-reduced BigFloat transcendentals. Results are checked to float64
   * tolerance; domain errors return NULL (never raise). */
  check_bf_unary("bigfloat_sin(0)", unimath_bigfloat_sin, 0.0, 0.0, 1e-12);
  check_bf_unary("bigfloat_sin(pi/2)", unimath_bigfloat_sin, M_PI / 2, 1.0, 1e-12);
  check_bf_unary("bigfloat_cos(0)", unimath_bigfloat_cos, 0.0, 1.0, 1e-12);
  check_bf_unary("bigfloat_cos(pi/2)", unimath_bigfloat_cos, M_PI / 2, 0.0, 1e-12);
  check_bf_unary("bigfloat_exp(0)", unimath_bigfloat_exp, 0.0, 1.0, 1e-12);
  check_bf_unary("bigfloat_exp(1)", unimath_bigfloat_exp, 1.0, M_E, 1e-12);
  check_bf_unary("bigfloat_ln(1)", unimath_bigfloat_ln, 1.0, 0.0, 1e-12);
  check_bf_unary("bigfloat_ln(e)", unimath_bigfloat_ln, M_E, 1.0, 1e-12);
  check_bf_unary("bigfloat_sqrt(4)", unimath_bigfloat_sqrt, 4.0, 2.0, 1e-12);
  check_bf_unary("bigfloat_sqrt(2)", unimath_bigfloat_sqrt, 2.0, sqrt(2.0), 1e-12);
  check_bf_unary("bigfloat_arctan(1)", unimath_bigfloat_arctan, 1.0, M_PI / 4, 1e-12);
  {
    void *y = unimath_bigfloat_from_f64(1.0);
    void *x = unimath_bigfloat_from_f64(1.0);
    void *r = unimath_bigfloat_arctan2(y, x);
    check_dbl_tol("bigfloat_arctan2(1,1)", unimath_bigfloat_to_f64(r), M_PI / 4, 1e-12);
    unimath_bigfloat_destroy(y);
    unimath_bigfloat_destroy(x);
    unimath_bigfloat_destroy(r);
  }
  {
    void *b = unimath_bigfloat_from_f64(2.0);
    void *r = unimath_bigfloat_pow_int(b, 10);
    check_dbl_tol("bigfloat_pow_int(2,10)", unimath_bigfloat_to_f64(r), 1024.0, 1e-9);
    unimath_bigfloat_destroy(b);
    unimath_bigfloat_destroy(r);
  }
  {
    void *b = unimath_bigfloat_from_f64(2.0);
    void *e = unimath_bigfloat_from_f64(0.5);
    void *r = unimath_bigfloat_pow(b, e);
    check_dbl_tol("bigfloat_pow(2,0.5)", unimath_bigfloat_to_f64(r), sqrt(2.0), 1e-12);
    unimath_bigfloat_destroy(b);
    unimath_bigfloat_destroy(e);
    unimath_bigfloat_destroy(r);
  }
  /* Domain errors map to NULL (never raise). */
  if (unimath_bigfloat_ln(unimath_bigfloat_from_f64(0.0)) != NULL) {
    printf("FAIL bigfloat_ln(0) should be NULL\n"); failures++;
  }
  if (unimath_bigfloat_sqrt(unimath_bigfloat_from_f64(-1.0)) != NULL) {
    printf("FAIL bigfloat_sqrt(-1) should be NULL\n"); failures++;
  }
  {
    void *b = unimath_bigfloat_from_f64(-1.0);
    void *e = unimath_bigfloat_from_f64(0.5);
    if (unimath_bigfloat_pow(b, e) != NULL) {
      printf("FAIL bigfloat_pow(-1,0.5) should be NULL\n"); failures++;
    }
    unimath_bigfloat_destroy(b);
    unimath_bigfloat_destroy(e);
  }

  /* ---- rational_math ----
   * Rational[BigInt] transcendentals (exact per term, truncated). Results are
   * checked to float64 tolerance reflecting the truncation; domain errors
   * return NULL (never raise). The BigInt backend does not overflow. */
  check_rat_unary("rational_sin(0)", unimath_rational_sin, 0, 1, 0.0, 1e-12);
  check_rat_unary("rational_cos(0)", unimath_rational_cos, 0, 1, 1.0, 1e-12);
  check_rat_unary("rational_sin(1/4)", unimath_rational_sin, 1, 4, sin(0.25), 1e-9);
  check_rat_unary("rational_cos(1/4)", unimath_rational_cos, 1, 4, cos(0.25), 1e-9);
  check_rat_unary("rational_exp(0)", unimath_rational_exp, 0, 1, 1.0, 1e-12);
  check_rat_unary("rational_exp(1/4)", unimath_rational_exp, 1, 4, exp(0.25), 1e-9);
  check_rat_unary("rational_ln(1)", unimath_rational_ln, 1, 1, 0.0, 1e-9);
  check_rat_unary("rational_ln(2)", unimath_rational_ln, 2, 1, log(2.0), 1e-9);
  check_rat_unary("rational_sqrt(4)", unimath_rational_sqrt, 4, 1, 2.0, 1e-9);
  check_rat_unary("rational_sqrt(2)", unimath_rational_sqrt, 2, 1, sqrt(2.0), 1e-6);
  check_rat_unary("rational_atan(1/3)", unimath_rational_atan, 1, 3, atan(1.0 / 3.0), 1e-5);
  check_rat_unary("rational_tan(0)", unimath_rational_tan, 0, 1, 0.0, 1e-12);
  {
    void *y = unimath_rational_from_i64(1, 1);
    void *x = unimath_rational_from_i64(3, 1);
    void *r = unimath_rational_atan2(y, x);
    check_dbl_tol("rational_atan2(1,3)", unimath_rational_to_f64(r), atan(1.0 / 3.0), 1e-5);
    unimath_rational_destroy(y);
    unimath_rational_destroy(x);
    unimath_rational_destroy(r);
  }
  {
    void *b = unimath_rational_from_i64(2, 1);
    void *e = unimath_rational_from_i64(1, 2);
    void *r = unimath_rational_pow(b, e);
    check_dbl_tol("rational_pow(2,1/2)", unimath_rational_to_f64(r), sqrt(2.0), 1e-6);
    unimath_rational_destroy(b);
    unimath_rational_destroy(e);
    unimath_rational_destroy(r);
  }
  /* Domain errors map to NULL (never raise). */
  if (unimath_rational_ln(unimath_rational_from_i64(0, 1)) != NULL) {
    printf("FAIL rational_ln(0) should be NULL\n"); failures++;
  }
  if (unimath_rational_sqrt(unimath_rational_from_i64(-1, 1)) != NULL) {
    printf("FAIL rational_sqrt(-1) should be NULL\n"); failures++;
  }
  {
    void *b = unimath_rational_from_i64(-1, 1);
    void *e = unimath_rational_from_i64(1, 2);
    if (unimath_rational_pow(b, e) != NULL) {
      printf("FAIL rational_pow(-1,1/2) should be NULL\n"); failures++;
    }
    unimath_rational_destroy(b);
    unimath_rational_destroy(e);
  }

  /* ---- math_router ----
   * Fixed[int64, 32] (Q32.32) transcendentals via the auto-dispatch cores. The
   * raw Q32.32 word is `x * 2^32`. Tolerances reflect CORDIC truncation (~1e-3)
   * and Newton/Taylor (tighter); domain/out-of-convergence clamps to 0. */
  check_fix_unary("fixed_sin(0)", unimath_fixed_sin, 0.0, 0.0, 1e-3);
  check_fix_unary("fixed_sin(0.5)", unimath_fixed_sin, 0.5, sin(0.5), 1e-3);
  check_fix_unary("fixed_cos(0)", unimath_fixed_cos, 0.0, 1.0, 1e-3);
  check_fix_unary("fixed_cos(0.5)", unimath_fixed_cos, 0.5, cos(0.5), 1e-3);
  check_fix_unary("fixed_tan(0.5)", unimath_fixed_tan, 0.5, tan(0.5), 1e-3);
  check_fix_unary("fixed_exp(1)", unimath_fixed_exp, 1.0, exp(1.0), 1e-3);
  check_fix_unary("fixed_ln(1)", unimath_fixed_ln, 1.0, 0.0, 1e-4);
  check_fix_unary("fixed_ln(1.5)", unimath_fixed_ln, 1.5, log(1.5), 1e-4);
  check_fix_unary("fixed_sqrt(4)", unimath_fixed_sqrt, 4.0, 2.0, 1e-6);
  check_fix_unary("fixed_sqrt(2)", unimath_fixed_sqrt, 2.0, sqrt(2.0), 1e-6);
  check_fix_unary("fixed_atan(1)", unimath_fixed_atan, 1.0, M_PI / 4, 1e-3);
  check_fix_unary("fixed_sinh(1)", unimath_fixed_sinh, 1.0, sinh(1.0), 1e-3);
  check_fix_unary("fixed_cosh(1)", unimath_fixed_cosh, 1.0, cosh(1.0), 1e-3);
  check_fix_unary("fixed_tanh(1)", unimath_fixed_tanh, 1.0, tanh(1.0), 1e-3);
  {
    long long qy = TO_Q32(1.0);
    long long qx = TO_Q32(1.0);
    long long r = unimath_fixed_atan2(qy, qx);
    check_dbl_tol("fixed_atan2(1,1)", FROM_Q32(r), M_PI / 4, 1e-3);
  }
  {
    long long base = TO_Q32(1.5);
    long long exponent = TO_Q32(1.0);
    long long r = unimath_fixed_pow(base, exponent);
    check_dbl_tol("fixed_pow(1.5,1)", FROM_Q32(r), 1.5, 2e-2);
  }
  /* Domain / out-of-convergence clamp to 0 (never raises). */
  if (unimath_fixed_ln(0) != 0) {
    printf("FAIL fixed_ln(0) should clamp to 0\n"); failures++;
  }
  if (unimath_fixed_sqrt(TO_Q32(-1.0)) != 0) {
    printf("FAIL fixed_sqrt(-1) should clamp to 0\n"); failures++;
  }
  if (unimath_fixed_exp(TO_Q32(2.0)) != 0) {
    printf("FAIL fixed_exp(2) out-of-convergence should clamp to 0\n"); failures++;
  }

  /* ---- conversions ----
   * Cross-type matrix across the handle / value surfaces. nil in -> NULL / 0 /
   * NaN-interval out; overflow (fixed target) and NaN/Inf (rational source)
   * clamp. Interval results are widened enclosures. */
  {
    unimath_rational r = unimath_rational_from_f64(0.5);
    check_dbl_tol("rational_from_f64(0.5)", unimath_rational_to_f64(r), 0.5, 1e-12);
    unimath_rational_destroy(r);
  }
  if (unimath_rational_from_f64(NAN) != NULL) {
    printf("FAIL rational_from_f64(NaN) should be NULL\n"); failures++;
  }
  if (unimath_rational_from_f64(INFINITY) != NULL) {
    printf("FAIL rational_from_f64(Inf) should be NULL\n"); failures++;
  }
  {
    unimath_rational r = unimath_rational_from_fixed(TO_Q32(2.5), 32);
    check_dbl_tol("rational_from_fixed(2.5)", unimath_rational_to_f64(r), 2.5, 1e-12);
    unimath_rational_destroy(r);
  }
  {
    unimath_rational h = unimath_rational_from_i64(1, 3);
    unimath_bigfloat bf = unimath_bigfloat_from_rational(h);
    check_dbl_tol("bigfloat_from_rational(1/3)", unimath_bigfloat_to_f64(bf), 1.0 / 3.0, 1e-6);
    unimath_rational_destroy(h);
    unimath_bigfloat_destroy(bf);
  }
  if (unimath_bigfloat_from_rational(NULL) != NULL) {
    printf("FAIL bigfloat_from_rational(NULL) should be NULL\n"); failures++;
  }
  {
    unimath_bigfloat h = unimath_bigfloat_from_f64(42.75);
    unimath_bigint b = unimath_bigint_from_bigfloat(h);
    char *s = bigint_dec(b);
    check_str("bigint_from_bigfloat(42.75)", s, "42");
    free(s); unimath_bigint_destroy(b); unimath_bigfloat_destroy(h);
  }
  {
    unimath_bigfloat h = unimath_bigfloat_from_f64(-42.75);
    unimath_bigint b = unimath_bigint_from_bigfloat(h);
    char *s = bigint_dec(b);
    check_str("bigint_from_bigfloat(-42.75)", s, "-42");
    free(s); unimath_bigint_destroy(b); unimath_bigfloat_destroy(h);
  }
  {
    unimath_rational h = unimath_rational_from_i64(7, 2);
    unimath_bigint b = unimath_bigint_from_rational(h);
    char *s = bigint_dec(b);
    check_str("bigint_from_rational(7/2)", s, "3");
    free(s); unimath_bigint_destroy(b); unimath_rational_destroy(h);
  }
  {
    unimath_rational h = unimath_rational_from_i64(-7, 2);
    unimath_bigint b = unimath_bigint_from_rational(h);
    char *s = bigint_dec(b);
    check_str("bigint_from_rational(-7/2)", s, "-3");
    free(s); unimath_bigint_destroy(b); unimath_rational_destroy(h);
  }
  {
    unimath_rational h = unimath_rational_from_i64(1, 3);
    long long q = unimath_fixed_from_rational(h, 32);
    check_dbl_tol("fixed_from_rational(1/3)", FROM_Q32(q), 1.0 / 3.0, pow(2.0, -31.0));
    unimath_rational_destroy(h);
  }
  {
    unimath_rational h = unimath_rational_from_i64(0x3FFFFFFFFFFFFFFFLL, 1);
    if (unimath_fixed_from_rational(h, 32) != 0) {
      printf("FAIL fixed_from_rational(overflow) should clamp to 0\n"); failures++;
    }
    unimath_rational_destroy(h);
  }
  {
    unimath_bigfloat h = unimath_bigfloat_from_f64(2.5);
    check_enc("interval_from_bigfloat(2.5)", unimath_interval_from_bigfloat(h), 2.5, 2.5);
    unimath_bigfloat_destroy(h);
  }
  {
    unimath_rational h = unimath_rational_from_i64(1, 3);
    check_enc("interval_from_rational(1/3)", unimath_interval_from_rational(h), 1.0 / 3.0, 1.0 / 3.0);
    unimath_rational_destroy(h);
  }
  {
    unimath_bigint h = unimath_bigint_from_i64(123456789);
    check_enc("interval_from_bigint", unimath_interval_from_bigint(h), 123456789.0, 123456789.0);
    unimath_bigint_destroy(h);
  }
  {
    unimath_interval i = unimath_interval_from_bigfloat(NULL);
    if (!isnan(i.lo) || !isnan(i.hi)) {
      printf("FAIL interval_from_bigfloat(NULL) should be NaN interval\n"); failures++;
    }
  }

  unimath_cleanup();

  if (failures == 0) { printf("\nAll C ABI tests passed.\n"); return 0; }
  printf("\n%d C ABI test(s) FAILED.\n", failures);
  return 1;
}