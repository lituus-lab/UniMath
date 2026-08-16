// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "UniMath.h"

static int failures = 0;

static void check_str(const char *name, const char *got, const char *want) {
  /* A NULL `got` means the handle or to_decimal failed. Report it: strcmp on
   * NULL would end the run in a segfault with no diagnostic. */
  if (got == NULL) {
    printf("FAIL %s: got NULL want \"%s\"\n", name, want); failures++; return;
  }
  if (strcmp(got, want) != 0) { printf("FAIL %s: got \"%s\" want \"%s\"\n", name, got, want); failures++; }
  else printf("ok   %s = \"%s\"\n", name, got);
}

static void check_int(const char *name, long long got, long long want) {
  if (got != want) { printf("FAIL %s: got %lld want %lld\n", name, got, want); failures++; }
  else printf("ok   %s = %lld\n", name, got);
}

static void check_u64(const char *name, unsigned long long got, unsigned long long want) {
  if (got != want) { printf("FAIL %s: got %llu want %llu\n", name, got, want); failures++; }
  else printf("ok   %s = %llu\n", name, got);
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

/* Spelled out, not <math.h>'s M_PI/M_E: those are POSIX, and the -std=c11 this
 * suite builds under exposes only the ISO C names. */
#define C_PI 3.14159265358979323846
#define C_E 2.71828182845904523536

/* Q32.32 fixed-point (32 fractional bits): convert a raw long long to double. */
#define Q32 4294967296.0
#define TO_Q32(x) ((long long)((x) * Q32))
#define FROM_Q32(q) ((double)(q) / Q32)

_Static_assert(sizeof(unimath_f64_pair) == 2 * sizeof(double),
               "unimath_f64_pair must contain exactly two doubles");
_Static_assert(offsetof(unimath_f64_pair, second) == sizeof(double),
               "unimath_f64_pair fields must be contiguous and ordered");

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

/* Read a BigInt's decimal into a caller-owned malloc'd buffer. */
static char *bigint_dec(unimath_bigint h) {
  size_t cap = 256;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) return NULL;
  int n = unimath_bigint_to_decimal(h, buf, cap);
  if (n < 0) { free(buf); return NULL; }
  if ((size_t)n >= cap) {
    char *larger = (char *)realloc(buf, (size_t)n + 1);
    if (larger == NULL) { free(buf); return NULL; }
    buf = larger;
    cap = (size_t)n + 1;
    n = unimath_bigint_to_decimal(h, buf, cap);
    if (n < 0 || (size_t)n >= cap) { free(buf); return NULL; }
  }
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

  /* ---- native float64 mathematics ---- */
  check_dbl("f64 sqrt", unimath_f64_sqrt(4.0), 2.0);
  check_dbl("f64 cbrt", unimath_f64_cbrt(27.0), 3.0);
  check_dbl("f64 ln", unimath_f64_ln(C_E), 1.0);
  check_dbl("f64 log", unimath_f64_log(8.0, 2.0), 3.0);
  check_dbl("f64 log2", unimath_f64_log2(8.0), 3.0);
  check_dbl("f64 log10", unimath_f64_log10(1000.0), 3.0);
  check_dbl_tol("f64 log1p", unimath_f64_log1p(1e-16), 1e-16, 1e-31);
  check_dbl("f64 exp", unimath_f64_exp(1.0), C_E);
  check_dbl_tol("f64 expm1", unimath_f64_expm1(1e-16), 1e-16, 1e-31);
  check_dbl("f64 pow", unimath_f64_pow(2.0, 10.0), 1024.0);
  check_dbl("f64 sin", unimath_f64_sin(0.0), 0.0);
  check_dbl("f64 cos", unimath_f64_cos(0.0), 1.0);
  check_dbl_tol("f64 tan", unimath_f64_tan(C_PI / 4.0), 1.0, 1e-15);
  {
    unimath_f64_pair pair = unimath_f64_sin_cos(C_PI / 4.0);
    check_dbl("f64 sin_cos first", pair.first, unimath_f64_sin(C_PI / 4.0));
    check_dbl("f64 sin_cos second", pair.second, unimath_f64_cos(C_PI / 4.0));
  }
  check_dbl("f64 atan2", unimath_f64_atan2(1.0, 0.0), C_PI / 2.0);
  check_dbl("f64 arcsin", unimath_f64_arcsin(0.0), 0.0);
  check_dbl("f64 arccos", unimath_f64_arccos(1.0), 0.0);
  check_dbl("f64 arctan", unimath_f64_arctan(0.0), 0.0);
  check_dbl("f64 sinh", unimath_f64_sinh(0.0), 0.0);
  check_dbl("f64 cosh", unimath_f64_cosh(0.0), 1.0);
  check_dbl("f64 tanh", unimath_f64_tanh(0.0), 0.0);
  check_dbl("f64 arcsinh", unimath_f64_arcsinh(0.0), 0.0);
  check_dbl("f64 arccosh", unimath_f64_arccosh(1.0), 0.0);
  check_dbl("f64 arctanh", unimath_f64_arctanh(0.0), 0.0);
  check_dbl("f64 hypot", unimath_f64_hypot(3.0, 4.0), 5.0);
  check_dbl("f64 erf", unimath_f64_erf(0.0), 0.0);
  check_dbl("f64 erfc", unimath_f64_erfc(0.0), 1.0);
  check_dbl_tol("f64 gamma", unimath_f64_gamma(5.0), 24.0, 1e-14);
  check_dbl("f64 floor", unimath_f64_floor(1.75), 1.0);
  check_dbl("f64 ceil", unimath_f64_ceil(1.25), 2.0);
  check_dbl("f64 trunc", unimath_f64_trunc(-1.75), -1.0);
  check_dbl("f64 round", unimath_f64_round(1.5), 2.0);
  check_dbl("f64 round places", unimath_f64_round_places(1.234, 2), 1.23);
  check_dbl("f64 copy sign", unimath_f64_copy_sign(1.0, -0.0), -1.0);
  check_dbl("f64 degrees", unimath_f64_deg_to_rad(180.0), C_PI);
  check_dbl("f64 radians", unimath_f64_rad_to_deg(C_PI), 180.0);
  {
    unimath_f64_pair parts = unimath_f64_split_decimal(-2.75);
    check_dbl("f64 split integer", parts.first, -2.0);
    check_dbl("f64 split fraction", parts.second, -0.75);
    parts = unimath_f64_split_decimal(-0.0);
    check_int("f64 split integer preserves -0", signbit(parts.first), 1);
    check_int("f64 split fraction preserves -0", signbit(parts.second), 1);
    int exponent = -1;
    check_dbl("f64 frexp fraction", unimath_f64_frexp(8.0, &exponent), 0.5);
    check_int("f64 frexp exponent", exponent, 4);
    check_dbl("f64 frexp NULL exponent", unimath_f64_frexp(8.0, NULL), 0.5);
  }
  check_int("f64 signbit negative zero", unimath_f64_signbit(-0.0), 1);
  check_int("f64 classify negative zero", unimath_f64_classify(-0.0),
            UNIMATH_F64_NEG_ZERO);
  check_int("f64 classify NaN", unimath_f64_classify(NAN), UNIMATH_F64_NAN);
  check_int("f64 almost equal", unimath_f64_almost_equal(1.0, 1.0, 4), 1);
  check_int("f64 almost equal invalid ulps",
            unimath_f64_almost_equal(1.0, 1.0, -1), 0);
  if (!isnan(unimath_f64_sqrt(-1.0))) {
    printf("FAIL f64 sqrt(-1) should be NaN\n"); failures++;
  } else printf("ok   f64 sqrt(-1) = NaN\n");
  if (!isfinite(unimath_f64_hypot(1e308, 1e308))) {
    printf("FAIL f64 hypot scaling should remain finite\n"); failures++;
  } else printf("ok   f64 hypot scaling remains finite\n");
  if (!isnan(unimath_f64_ln(-1.0)) || !isinf(unimath_f64_ln(0.0)) ||
      !isnan(unimath_f64_log1p(-2.0)) ||
      !isnan(unimath_f64_pow(-1.0, 0.5))) {
    printf("FAIL f64 IEEE domain classifications\n"); failures++;
  } else printf("ok   f64 IEEE domain classifications\n");

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
  {
    char small[4] = "xxx";
    check_int("to_decimal required size", unimath_bigint_to_decimal(x, small,
      sizeof small), 12);
    check_int("to_decimal zero-size query", unimath_bigint_to_decimal(x, small,
      0), 12);
    check_str("to_decimal small buffer unchanged", small, "xxx");
  }
  unimath_bigint_destroy(x);
  unimath_bigint_destroy(y);

  {
    unimath_bigint acc = unimath_bigint_from_i64(1);
    for (long long i = 2; i <= 20; i++) {
      unimath_bigint factor = unimath_bigint_from_i64(i);
      acc = unimath_bigint_mul_into(acc, factor);
      unimath_bigint_destroy(factor);
    }
    check_str("mul_into factorial(20)", dec_of("20!", acc),
      "2432902008176640000");
  }

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

  /* to_u64: negative clamps to 0/out_ok=0; in-range round-trips exactly. */
  int uok = 2;
  check_u64("to_u64(1000000000000000000000) clamps", unimath_bigint_to_u64(n, &uok), 18446744073709551615ULL);
  if (uok != 0) { printf("FAIL to_u64(1e21) out_ok should be 0\n"); failures++; }
  else printf("ok   to_u64(1e21) out_ok = 0\n");
  unimath_bigint u42 = unimath_bigint_from_i64(42);
  uok = 2;
  if (unimath_bigint_to_u64(u42, &uok) == 42ULL && uok == 1) printf("ok   to_u64(42) = 42, out_ok = 1\n");
  else { printf("FAIL to_u64(42) or out_ok wrong\n"); failures++; }
  unimath_bigint_destroy(u42);
  unimath_bigint negForU64 = unimath_bigint_from_i64(-7);
  uok = 2;
  unimath_bigint_to_u64(negForU64, &uok);
  if (uok != 0) { printf("FAIL to_u64(-7) out_ok should be 0\n"); failures++; }
  else printf("ok   to_u64(-7) out_ok = 0\n");
  unimath_bigint_destroy(negForU64);

  /* shl/shr: sign-preserving, GMP-comparable (mpz_fdiv_q_2exp for shr). */
  unimath_bigint sh = unimath_bigint_from_i64(3);
  check_str("shl(3,4)", dec_of("3<<4", unimath_bigint_shl(sh, 4)), "48");
  unimath_bigint fortyEight = unimath_bigint_from_decimal("48");
  check_str("shr(48,4)", dec_of("48>>4", unimath_bigint_shr(fortyEight, 4)), "3");
  /* floor(-7 / 2) = -4 (floor division, not truncation toward zero) */
  unimath_bigint negsh = unimath_bigint_from_i64(-7);
  check_str("shr(-7,1) floors", dec_of("-7>>1", unimath_bigint_shr(negsh, 1)), "-4");
  if (unimath_bigint_shl(sh, -1) != NULL) { printf("FAIL shl(3,-1) should be NULL\n"); failures++; }
  else printf("ok   shl(3,-1) = NULL\n");
  if (unimath_bigint_shr(sh, -1) != NULL) { printf("FAIL shr(3,-1) should be NULL\n"); failures++; }
  else printf("ok   shr(3,-1) = NULL\n");
  unimath_bigint_destroy(sh);
  unimath_bigint_destroy(negsh);

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

  /* scale-invariant utilities (any frac_bits, same on both sides) */
  check_int("fixed_cmp(2<<16,3<<16)", unimath_fixed_cmp(2LL << 16, 3LL << 16), -1);
  check_int("fixed_cmp(3<<16,2<<16)", unimath_fixed_cmp(3LL << 16, 2LL << 16), 1);
  check_int("fixed_cmp(3<<16,3<<16)", unimath_fixed_cmp(3LL << 16, 3LL << 16), 0);
  check_int("fixed_abs(-3<<16)", unimath_fixed_abs(-(3LL << 16)), 3LL << 16);
  check_int("fixed_abs(3<<16)", unimath_fixed_abs(3LL << 16), 3LL << 16);
  check_int("fixed_abs(INT64_MIN) clamps to INT64_MAX",
            unimath_fixed_abs(-9223372036854775807LL - 1), 9223372036854775807LL);
  check_int("fixed_sign(-3<<16)", unimath_fixed_sign(-(3LL << 16)), -1);
  check_int("fixed_sign(0)", unimath_fixed_sign(0), 0);
  check_int("fixed_sign(3<<16)", unimath_fixed_sign(3LL << 16), 1);
  check_int("fixed_clamp(5,1,3)", unimath_fixed_clamp(5, 1, 3), 3);
  check_int("fixed_clamp(-1,1,3)", unimath_fixed_clamp(-1, 1, 3), 1);
  check_int("fixed_clamp(2,1,3)", unimath_fixed_clamp(2, 1, 3), 2);
  /* floored modulo: floor(-7/2)*2 + r = -7 -> r = -1 as truncated mod, but
   * floored mod adjusts to a same-sign-as-divisor remainder: 1 */
  check_int("fixed_floor_mod(-7,2)", unimath_fixed_floor_mod(-7, 2), 1);
  check_int("fixed_floor_mod(7,-2)", unimath_fixed_floor_mod(7, -2), -1);
  check_int("fixed_floor_mod(7,2)", unimath_fixed_floor_mod(7, 2), 1);
  check_int("fixed_floor_mod by zero", unimath_fixed_floor_mod(7, 0), 0);

  /* Q32.32-only utilities (floor/ceil/round/lerp) */
  long long q32_2_5 = TO_Q32(2.5);
  check_int("fixed_floor(2.5)", unimath_fixed_floor(q32_2_5), TO_Q32(2.0));
  check_int("fixed_ceil(2.5)", unimath_fixed_ceil(q32_2_5), TO_Q32(3.0));
  check_int("fixed_ceil(2.0) exact", unimath_fixed_ceil(TO_Q32(2.0)), TO_Q32(2.0));
  check_int("fixed_round(2.5)", unimath_fixed_round(q32_2_5), TO_Q32(3.0));
  long long q32_neg2_5 = TO_Q32(-2.5);
  check_int("fixed_floor(-2.5)", unimath_fixed_floor(q32_neg2_5), TO_Q32(-3.0));
  check_int("fixed_ceil(-2.5)", unimath_fixed_ceil(q32_neg2_5), TO_Q32(-2.0));
  check_dbl_tol("fixed_lerp(0,10,0.5)", FROM_Q32(unimath_fixed_lerp(TO_Q32(0.0), TO_Q32(10.0), TO_Q32(0.5))), 5.0, 1e-9);
  check_dbl_tol("fixed_lerp(0,10,0)", FROM_Q32(unimath_fixed_lerp(TO_Q32(0.0), TO_Q32(10.0), TO_Q32(0.0))), 0.0, 1e-9);
  check_dbl_tol("fixed_lerp(0,10,1)", FROM_Q32(unimath_fixed_lerp(TO_Q32(0.0), TO_Q32(10.0), TO_Q32(1.0))), 10.0, 1e-9);

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
  /* is_zero, neg, abs */
  unimath_bigfloat fzero = unimath_bigfloat_from_f64(0.0);
  if (unimath_bigfloat_is_zero(fzero)) printf("ok   bigfloat_is_zero(0) = true\n");
  else { printf("FAIL bigfloat_is_zero(0) should be true\n"); failures++; }
  if (!unimath_bigfloat_is_zero(fa)) printf("ok   bigfloat_is_zero(10) = false\n");
  else { printf("FAIL bigfloat_is_zero(10) should be false\n"); failures++; }
  if (unimath_bigfloat_is_zero(NULL)) { printf("FAIL bigfloat_is_zero(NULL) should be false\n"); failures++; }
  else printf("ok   bigfloat_is_zero(NULL) = false\n");
  check_dbl("bigfloat_neg(10)", unimath_bigfloat_to_f64(unimath_bigfloat_neg(fa)), -10.0);
  check_dbl("bigfloat_abs(-10)", unimath_bigfloat_to_f64(unimath_bigfloat_abs(unimath_bigfloat_from_f64(-10.0))), 10.0);
  unimath_bigfloat_destroy(fzero);
  /* from_bigint: exact, no float64 detour */
  unimath_bigint bigForFloat = unimath_bigint_from_decimal("123456789012345678");
  check_dbl("bigfloat_from_bigint", unimath_bigfloat_to_f64(unimath_bigfloat_from_bigint(bigForFloat)), 123456789012345678.0);
  if (unimath_bigfloat_from_bigint(NULL) != NULL) { printf("FAIL bigfloat_from_bigint(NULL) should be NULL\n"); failures++; }
  else printf("ok   bigfloat_from_bigint(NULL) = NULL\n");
  unimath_bigint_destroy(bigForFloat);

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
  /* is_zero / is_one */
  unimath_rational rZero = unimath_rational_from_i64(0, 1);
  unimath_rational rOne = unimath_rational_from_i64(1, 1);
  if (unimath_rational_is_zero(rZero)) printf("ok   rational_is_zero(0/1) = true\n");
  else { printf("FAIL rational_is_zero(0/1) should be true\n"); failures++; }
  if (!unimath_rational_is_zero(ra)) printf("ok   rational_is_zero(1/2) = false\n");
  else { printf("FAIL rational_is_zero(1/2) should be false\n"); failures++; }
  if (unimath_rational_is_one(rOne)) printf("ok   rational_is_one(1/1) = true\n");
  else { printf("FAIL rational_is_one(1/1) should be true\n"); failures++; }
  if (!unimath_rational_is_one(ra)) printf("ok   rational_is_one(1/2) = false\n");
  else { printf("FAIL rational_is_one(1/2) should be false\n"); failures++; }
  if (unimath_rational_is_zero(NULL) || unimath_rational_is_one(NULL)) { printf("FAIL is_zero/is_one(NULL) should be false\n"); failures++; }
  else printf("ok   rational_is_zero/is_one(NULL) = false\n");
  unimath_rational_destroy(rZero);
  unimath_rational_destroy(rOne);

  unimath_rational_destroy(ra);
  unimath_rational_destroy(rb);

  /* ---- Interval (value type: two doubles, returned by value) ---- */
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
  if (sfull.lo <= 0.0 && sfull.lo > -1.0 && sfull.hi == 1.0) printf("ok   interval sin(0,pi) distinguishes extrema\n");
  else { printf("FAIL interval sin(0,pi) should be tight, got [%.17g, %.17g]\n", sfull.lo, sfull.hi); failures++; }
  /* cos over [-0.5, 0.5] encloses the 0 maximum -> full [-1, 1] */
  unimath_interval cfull = unimath_interval_cos(unimath_interval_from_f64(-0.5, 0.5));
  if (cfull.lo <= cos(0.5) && cfull.lo > -1.0 && cfull.hi == 1.0) printf("ok   interval cos(-0.5,0.5) distinguishes extrema\n");
  else { printf("FAIL interval cos(-0.5,0.5) should be tight, got [%.17g, %.17g]\n", cfull.lo, cfull.hi); failures++; }

  /* neg, pow, arctan, arctan2 */
  /* neg widens outward by a ULP like every other op (nextDown/nextUp), even
   * though negation itself is exact -- an enclosure check, not bit-exact. */
  check_enc("interval_neg([1,2])", unimath_interval_neg(unimath_interval_from_f64(1.0, 2.0)), -2.0, -1.0);
  check_enc("interval_pow([2,3],2)", unimath_interval_pow(unimath_interval_from_f64(2.0, 3.0), 2), 4.0, 9.0);
  unimath_interval powNegZero = unimath_interval_pow(unimath_interval_from_f64(-1.0, 1.0), -1);
  if (isnan(powNegZero.lo) && isnan(powNegZero.hi)) printf("ok   interval_pow([-1,1],-1) = NaN\n");
  else { printf("FAIL interval_pow([-1,1],-1) should be NaN, got [%.17g, %.17g]\n", powNegZero.lo, powNegZero.hi); failures++; }
  check_enc("interval_arctan([0,1])", unimath_interval_arctan(unimath_interval_from_f64(0.0, 1.0)), 0.0, atan(1.0));
  check_enc("interval_arctan2 box excl origin", unimath_interval_arctan2(unimath_interval_from_f64(1.0, 1.0), unimath_interval_from_f64(1.0, 1.0)), atan2(1.0, 1.0), atan2(1.0, 1.0));
  unimath_interval atan2Full = unimath_interval_arctan2(unimath_interval_from_f64(-1.0, 1.0), unimath_interval_from_f64(-1.0, 1.0));
  if (fabs(atan2Full.lo - (-C_PI)) < 1e-9 && fabs(atan2Full.hi - C_PI) < 1e-9) printf("ok   interval_arctan2 box encl origin = [-pi,pi]\n");
  else { printf("FAIL interval_arctan2 box encl origin should be [-pi,pi], got [%.17g, %.17g]\n", atan2Full.lo, atan2Full.hi); failures++; }

  /* is_valid, width, midpoint, contains, contains_interval, overlaps, hull,
   * intersect -- the set-theoretic predicates. */
  unimath_interval v12 = unimath_interval_from_f64(1.0, 2.0);
  unimath_interval v34 = unimath_interval_from_f64(3.0, 4.0);
  unimath_interval v15 = unimath_interval_from_f64(1.0, 5.0);
  unimath_interval invalidIv = unimath_interval_from_f64(2.0, 1.0);
  if (unimath_interval_is_valid(v12)) printf("ok   interval_is_valid([1,2]) = true\n");
  else { printf("FAIL interval_is_valid([1,2]) should be true\n"); failures++; }
  if (!unimath_interval_is_valid(invalidIv)) printf("ok   interval_is_valid([2,1]) = false\n");
  else { printf("FAIL interval_is_valid([2,1]) should be false\n"); failures++; }
  check_dbl("interval_width([1,2])", unimath_interval_width(v12), 1.0);
  check_dbl("interval_midpoint([1,2])", unimath_interval_midpoint(v12), 1.5);
  if (unimath_interval_contains(v12, 1.5)) printf("ok   interval_contains([1,2],1.5) = true\n");
  else { printf("FAIL interval_contains([1,2],1.5) should be true\n"); failures++; }
  if (!unimath_interval_contains(v12, 3.0)) printf("ok   interval_contains([1,2],3) = false\n");
  else { printf("FAIL interval_contains([1,2],3) should be false\n"); failures++; }
  if (unimath_interval_contains_interval(v15, v12)) printf("ok   interval_contains_interval([1,5],[1,2]) = true\n");
  else { printf("FAIL interval_contains_interval([1,5],[1,2]) should be true\n"); failures++; }
  if (!unimath_interval_contains_interval(v12, v15)) printf("ok   interval_contains_interval([1,2],[1,5]) = false\n");
  else { printf("FAIL interval_contains_interval([1,2],[1,5]) should be false\n"); failures++; }
  if (!unimath_interval_overlaps(v12, v34)) printf("ok   interval_overlaps([1,2],[3,4]) = false\n");
  else { printf("FAIL interval_overlaps([1,2],[3,4]) should be false\n"); failures++; }
  if (unimath_interval_overlaps(v12, v15)) printf("ok   interval_overlaps([1,2],[1,5]) = true\n");
  else { printf("FAIL interval_overlaps([1,2],[1,5]) should be true\n"); failures++; }
  unimath_interval hulled = unimath_interval_hull(v12, v34);
  if (hulled.lo == 1.0 && hulled.hi == 4.0) printf("ok   interval_hull([1,2],[3,4]) = [1,4]\n");
  else { printf("FAIL interval_hull([1,2],[3,4]) should be [1,4], got [%.17g, %.17g]\n", hulled.lo, hulled.hi); failures++; }
  unimath_interval intersected = unimath_interval_intersect(v12, v15);
  if (intersected.lo == 1.0 && intersected.hi == 2.0) printf("ok   interval_intersect([1,2],[1,5]) = [1,2]\n");
  else { printf("FAIL interval_intersect([1,2],[1,5]) should be [1,2], got [%.17g, %.17g]\n", intersected.lo, intersected.hi); failures++; }
  /* non-overlapping intersect is invalid (lo > hi) -- caller checks is_valid */
  unimath_interval notOverlapping = unimath_interval_intersect(v12, v34);
  if (!unimath_interval_is_valid(notOverlapping)) printf("ok   interval_intersect([1,2],[3,4]) is invalid\n");
  else { printf("FAIL interval_intersect([1,2],[3,4]) should be invalid, got [%.17g, %.17g]\n", notOverlapping.lo, notOverlapping.hi); failures++; }

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
  check_dbl_tol("erf(3)", unimath_erf(3.0), erf(3.0), 3e-14);
  check_dbl_tol("gamma(1)", unimath_gamma(1.0), 1.0, 1e-10);
  check_dbl_tol("gamma(5)", unimath_gamma(5.0), 24.0, 1e-9);
  check_dbl_tol("gamma(0.5)", unimath_gamma(0.5), sqrt(C_PI), 1e-10);
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
    check_dbl_tol("pi_bigfloat", unimath_bigfloat_to_f64(pi_h), C_PI, 1e-15);
    check_dbl_tol("e_bigfloat", unimath_bigfloat_to_f64(e_h), C_E, 1e-15);
    unimath_bigfloat_destroy(pi_h);
    unimath_bigfloat_destroy(e_h);
  }
  check_dbl_tol("pi_fixed", FROM_Q32(unimath_pi_fixed()), C_PI, 1e-9);
  check_dbl_tol("e_fixed", FROM_Q32(unimath_e_fixed()), C_E, 1e-9);

  /* ---- Reduction ----
   * BigFloat trig stage-1 reduction mod 2pi into [-pi, pi]. The handle is
   * destroyed after extraction. */
  {
    void *x = unimath_bigfloat_from_f64(2.0 * C_PI + 0.5);
    void *r = unimath_bigfloat_reduce(x);
    check_dbl_tol("bigfloat_reduce(2pi+0.5)", unimath_bigfloat_to_f64(r), 0.5, 1e-12);
    unimath_bigfloat_destroy(x);
    unimath_bigfloat_destroy(r);
  }

  /* ---- float_math ----
   * Range-reduced BigFloat transcendentals. Results are checked to float64
   * tolerance; domain errors return NULL (never raise). */
  check_bf_unary("bigfloat_sin(0)", unimath_bigfloat_sin, 0.0, 0.0, 1e-12);
  check_bf_unary("bigfloat_sin(pi/2)", unimath_bigfloat_sin, C_PI / 2, 1.0, 1e-12);
  check_bf_unary("bigfloat_cos(0)", unimath_bigfloat_cos, 0.0, 1.0, 1e-12);
  check_bf_unary("bigfloat_cos(pi/2)", unimath_bigfloat_cos, C_PI / 2, 0.0, 1e-12);
  check_bf_unary("bigfloat_exp(0)", unimath_bigfloat_exp, 0.0, 1.0, 1e-12);
  check_bf_unary("bigfloat_exp(1)", unimath_bigfloat_exp, 1.0, C_E, 1e-12);
  check_bf_unary("bigfloat_ln(1)", unimath_bigfloat_ln, 1.0, 0.0, 1e-12);
  check_bf_unary("bigfloat_ln(e)", unimath_bigfloat_ln, C_E, 1.0, 1e-12);
  check_bf_unary("bigfloat_sqrt(4)", unimath_bigfloat_sqrt, 4.0, 2.0, 1e-12);
  check_bf_unary("bigfloat_sqrt(2)", unimath_bigfloat_sqrt, 2.0, sqrt(2.0), 1e-12);
  check_bf_unary("bigfloat_arctan(1)", unimath_bigfloat_arctan, 1.0, C_PI / 4, 1e-12);
  {
    void *x = unimath_bigfloat_from_f64(5.0 / 13.0);
    void *r = unimath_bigfloat_arctan_terms(x, 120);
    check_dbl_tol("bigfloat_arctan_terms(5/13)", unimath_bigfloat_to_f64(r),
      atan(5.0 / 13.0), 1e-12);
    unimath_bigfloat_destroy(x);
    unimath_bigfloat_destroy(r);
  }
  {
    void *y = unimath_bigfloat_from_f64(1.0);
    void *x = unimath_bigfloat_from_f64(1.0);
    void *r = unimath_bigfloat_arctan2(y, x);
    check_dbl_tol("bigfloat_arctan2(1,1)", unimath_bigfloat_to_f64(r), C_PI / 4, 1e-12);
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
  check_fix_unary("fixed_ln(1000)", unimath_fixed_ln, 1000.0, log(1000.0), 3e-8);
  check_fix_unary("fixed_sqrt(4)", unimath_fixed_sqrt, 4.0, 2.0, 1e-6);
  check_fix_unary("fixed_sqrt(2)", unimath_fixed_sqrt, 2.0, sqrt(2.0), 1e-6);
  check_fix_unary("fixed_atan(1)", unimath_fixed_atan, 1.0, C_PI / 4, 1e-3);
  check_fix_unary("fixed_sinh(1)", unimath_fixed_sinh, 1.0, sinh(1.0), 1e-3);
  check_fix_unary("fixed_cosh(1)", unimath_fixed_cosh, 1.0, cosh(1.0), 1e-3);
  check_fix_unary("fixed_tanh(1)", unimath_fixed_tanh, 1.0, tanh(1.0), 1e-3);
  check_fix_unary("fixed_tanh(1.25)", unimath_fixed_tanh, 1.25, tanh(1.25), 2e-8);
  check_fix_unary("fixed_tanh(3)", unimath_fixed_tanh, 3.0, tanh(3.0), 2e-8);
  {
    long long qy = TO_Q32(1.0);
    long long qx = TO_Q32(1.0);
    long long r = unimath_fixed_atan2(qy, qx);
    check_dbl_tol("fixed_atan2(1,1)", FROM_Q32(r), C_PI / 4, 1e-3);
  }
  {
    long long base = TO_Q32(1.5);
    long long exponent = TO_Q32(1.0);
    long long r = unimath_fixed_pow(base, exponent);
    check_dbl_tol("fixed_pow(1.5,1)", FROM_Q32(r), 1.5, 2e-2);
  }
  check_dbl_tol("fixed_asin(0.5)", FROM_Q32(unimath_fixed_asin(TO_Q32(0.5))), asin(0.5), 2e-2);
  check_dbl_tol("fixed_acos(0.5)", FROM_Q32(unimath_fixed_acos(TO_Q32(0.5))), acos(0.5), 2e-2);
  check_int("fixed_asin(2.0) out-of-domain clamps", unimath_fixed_asin(TO_Q32(2.0)), 0);
  check_dbl_tol("fixed_asinh(1.0)", FROM_Q32(unimath_fixed_asinh(TO_Q32(1.0))), asinh(1.0), 2e-2);
  check_dbl_tol("fixed_acosh(1.5)", FROM_Q32(unimath_fixed_acosh(TO_Q32(1.5))), acosh(1.5), 2e-2);
  check_dbl_tol("fixed_atanh(0.5)", FROM_Q32(unimath_fixed_atanh(TO_Q32(0.5))), atanh(0.5), 2e-2);
  check_int("fixed_acosh(0.5) out-of-domain clamps", unimath_fixed_acosh(TO_Q32(0.5)), 0);
  check_int("fixed_atanh(2.0) out-of-domain clamps", unimath_fixed_atanh(TO_Q32(2.0)), 0);
  check_dbl_tol("fixed_factorial(5)", FROM_Q32(unimath_fixed_factorial(5)), 120.0, 1e-3);
  check_dbl_tol("fixed_erf(0.5)", FROM_Q32(unimath_fixed_erf(TO_Q32(0.5))), erf(0.5), 2e-2);
  check_dbl_tol("fixed_erf(3)", FROM_Q32(unimath_fixed_erf(TO_Q32(3.0))), erf(3.0), 2e-8);
  check_int("fixed_erf(50000) saturates", unimath_fixed_erf(TO_Q32(50000.0)), TO_Q32(1.0));
  check_int("fixed_erf(-50000) saturates", unimath_fixed_erf(TO_Q32(-50000.0)), TO_Q32(-1.0));
  check_dbl_tol("fixed_bessel_j0(0.5)", FROM_Q32(unimath_fixed_bessel_j0(TO_Q32(0.5))), 0.93846980724081297, 2e-2);
  /* Domain / out-of-convergence clamp to 0 (never raises). */
  if (unimath_fixed_ln(0) != 0) {
    printf("FAIL fixed_ln(0) should clamp to 0\n"); failures++;
  }
  if (unimath_fixed_sqrt(TO_Q32(-1.0)) != 0) {
    printf("FAIL fixed_sqrt(-1) should clamp to 0\n"); failures++;
  }
  /* exp/pow via scaling-and-squaring now cover far past the raw CORDIC
   * budget (~1.1182), up to the Q32.32 representable ceiling (~21.5). */
  check_dbl_tol("fixed_exp(2)", FROM_Q32(unimath_fixed_exp(TO_Q32(2.0))), exp(2.0), 1e-3);
  check_dbl_tol("fixed_exp(10)", FROM_Q32(unimath_fixed_exp(TO_Q32(10.0))), exp(10.0), 2e-2);
  check_dbl_tol("fixed_pow(2,10)", FROM_Q32(unimath_fixed_pow(TO_Q32(2.0), TO_Q32(10.0))), 1024.0, 2e-2);
  if (unimath_fixed_exp(TO_Q32(30.0)) != 0) {
    printf("FAIL fixed_exp(30) past the Q32.32 ceiling should clamp to 0\n"); failures++;
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
