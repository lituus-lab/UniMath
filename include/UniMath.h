// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#ifndef UNIMATH_H
#define UNIMATH_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNIMATH_VERSION_MAJOR 1
#define UNIMATH_VERSION_MINOR 0
#define UNIMATH_VERSION_PATCH 0
#define UNIMATH_VERSION "1.0.0"
#define UNIMATH_MAX_REGULARIZED_BETA_SHAPE_SUM 200000.0

#define UNIMATH_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNIMATH_VERSION_MAJOR > (ma)) || \
   (UNIMATH_VERSION_MAJOR == (ma) && UNIMATH_VERSION_MINOR > (mi)) || \
   (UNIMATH_VERSION_MAJOR == (ma) && UNIMATH_VERSION_MINOR == (mi) && \
    UNIMATH_VERSION_PATCH >= (pa)))

/* Error codes returned by some entry points and decoded by
 * unimath_get_error_string. The ABI never raises across the boundary. */
#define UNIMATH_OK            0
#define UNIMATH_ERR_DIV_BY_ZERO 1
#define UNIMATH_ERR_OVERFLOW    2
#define UNIMATH_ERR_INVALID     3
#define UNIMATH_ERR_OOM         4

/* Opaque handle to a heap-allocated, GC-pinned BigInt. Owned by the caller
 * until unimath_bigint_destroy. NULL marks an error / empty result. */
typedef void *unimath_bigint;

/* Static version string; do not free. */
const char *unimath_version(void);

/* Lifecycle. Call unimath_init() once before any other entry point so the
 * Nim/ARC runtime is up (handles persist Nim heap objects across the
 * boundary). Idempotent; returns 1 on success. unimath_cleanup() is a no-op
 * (handles are freed per-call by *_destroy).
 *
 * THREADING: this ABI is single-threaded. The host must serialise every call,
 * including the first unimath_init(). Handle lifetimes are tracked by ARC
 * reference counts that this build does not make atomic, so sharing a handle
 * across threads corrupts them and either leaks or frees early. */
int unimath_init(void);
void unimath_cleanup(void);

const char *unimath_get_error_string(int error_code);

/* ---- Native float64 mathematics ----
 * Value-only host-libm operations. Results preserve the platform's IEEE-754
 * classifications and may differ by a few ulps across libm implementations. */
typedef struct unimath_f64_pair {
  double first;
  double second;
} unimath_f64_pair;

typedef enum unimath_f64_class {
  UNIMATH_F64_NORMAL = 0,
  UNIMATH_F64_SUBNORMAL = 1,
  UNIMATH_F64_ZERO = 2,
  UNIMATH_F64_NEG_ZERO = 3,
  UNIMATH_F64_NAN = 4,
  UNIMATH_F64_INF = 5,
  UNIMATH_F64_NEG_INF = 6
} unimath_f64_class;

double unimath_f64_sqrt(double x);
double unimath_f64_cbrt(double x);
double unimath_f64_ln(double x);
double unimath_f64_log(double x, double base);
double unimath_f64_log2(double x);
double unimath_f64_log10(double x);
double unimath_f64_log1p(double x);
double unimath_f64_exp(double x);
double unimath_f64_expm1(double x);
double unimath_f64_pow(double base, double exponent);
double unimath_f64_sin(double x);
double unimath_f64_cos(double x);
double unimath_f64_tan(double x);
/* first = sin(x), second = cos(x). */
unimath_f64_pair unimath_f64_sin_cos(double x);
double unimath_f64_atan2(double y, double x);
double unimath_f64_arcsin(double x);
double unimath_f64_arccos(double x);
double unimath_f64_arctan(double x);
double unimath_f64_sinh(double x);
double unimath_f64_cosh(double x);
double unimath_f64_tanh(double x);
double unimath_f64_arcsinh(double x);
double unimath_f64_arccosh(double x);
double unimath_f64_arctanh(double x);
double unimath_f64_hypot(double x, double y);
double unimath_f64_erf(double x);
double unimath_f64_erfc(double x);
double unimath_f64_gamma(double x);
double unimath_f64_lgamma(double x);
/* Beta-family functions require positive finite a and b with a finite,
   representable sum. The regularized
   function additionally requires 0 <= x <= 1 and, unless a or b is exactly
   1, a + b <= UNIMATH_MAX_REGULARIZED_BETA_SHAPE_SUM. Invalid input or failure
   to converge returns NaN. */
double unimath_f64_log_beta(double a, double b);
double unimath_f64_beta(double a, double b);
double unimath_f64_regularized_incomplete_beta(double x, double a, double b);
double unimath_f64_floor(double x);
double unimath_f64_ceil(double x);
double unimath_f64_trunc(double x);
double unimath_f64_round(double x);
double unimath_f64_round_places(double x, int places);
double unimath_f64_copy_sign(double x, double sign);
double unimath_f64_next_after(double x, double direction);
double unimath_f64_deg_to_rad(double x);
double unimath_f64_rad_to_deg(double x);
/* first = integer part, second = fractional part; both preserve x's sign. */
unimath_f64_pair unimath_f64_split_decimal(double x);
/* Returns the fraction. Writes the exponent when exponent is non-NULL. */
double unimath_f64_frexp(double x, int *exponent);
int unimath_f64_signbit(double x);
int unimath_f64_classify(double x);
/* Returns 0 for a negative ulps argument. */
int unimath_f64_almost_equal(double x, double y, int ulps);

/* ---- BigInt ---- */
unimath_bigint unimath_bigint_from_i64(long long v);
unimath_bigint unimath_bigint_from_decimal(const char *s);

/* Write the NUL-terminated decimal into buf. Returns chars written (excluding
 * NUL), the required character count when the buffer is too small, or -1 on a
 * nil handle / nil buffer. A too-small buffer, including size == 0 with a
 * non-NULL buf, is left unchanged and returns the required character count. */
int unimath_bigint_to_decimal(unimath_bigint h, char *buf, size_t size);

unimath_bigint unimath_bigint_add(unimath_bigint a, unimath_bigint b);
unimath_bigint unimath_bigint_sub(unimath_bigint a, unimath_bigint b);
unimath_bigint unimath_bigint_mul(unimath_bigint a, unimath_bigint b);
/* Consume acc and return the handle that must replace it. Do not destroy acc
 * after this call. k remains owned by the caller. NULL k consumes acc and
 * returns NULL. */
unimath_bigint unimath_bigint_mul_into(unimath_bigint acc, unimath_bigint k);
unimath_bigint unimath_bigint_div(unimath_bigint a, unimath_bigint b);
unimath_bigint unimath_bigint_mod(unimath_bigint a, unimath_bigint b);
unimath_bigint unimath_bigint_neg(unimath_bigint a);
unimath_bigint unimath_bigint_abs(unimath_bigint a);

/* -1 / 0 / 1; 0 if either handle is nil. */
int unimath_bigint_cmp(unimath_bigint a, unimath_bigint b);

/* Best-effort int64, clamped to the int64 range. If out_ok is non-NULL,
 * *out_ok is 0 when the value was out of range (clamped) or the handle nil. */
long long unimath_bigint_to_i64(unimath_bigint h, int *out_ok);

/* Best-effort uint64, clamped to [0, UINT64_MAX]. If out_ok is non-NULL,
 * *out_ok is 0 when negative/out of range (clamped) or the handle nil. */
unsigned long long unimath_bigint_to_u64(unimath_bigint h, int *out_ok);

/* a << k / a >> k (arithmetic, sign-preserving). NULL on a nil handle or a
 * negative k. */
unimath_bigint unimath_bigint_shl(unimath_bigint a, int k);
unimath_bigint unimath_bigint_shr(unimath_bigint a, int k);

void unimath_bigint_destroy(unimath_bigint h);

/* ---- Fixed (raw int64 Q-format; frac_bits = fractional width) ----
 * Values are raw `data` integers scaled by 2^frac_bits. The ABI never raises:
 * out-of-range results clamp to the int64 range; division by zero returns 0.
 * frac_bits must be in 0..63 -- an int64 Q-format word carries no more --
 * and anything outside that range returns 0 (NULL for the conversions). */
long long unimath_fixed_from_int(long long val, int frac_bits);
long long unimath_fixed_to_int(long long q, int frac_bits);
long long unimath_fixed_add(long long a, long long b);
long long unimath_fixed_sub(long long a, long long b);
long long unimath_fixed_mul(long long a, long long b, int frac_bits);
long long unimath_fixed_div(long long a, long long b, int frac_bits);

/* -1 / 0 / 1; scale-invariant (same frac_bits on both sides). */
int unimath_fixed_cmp(long long a, long long b);
long long unimath_fixed_abs(long long a);
int unimath_fixed_sign(long long a);
long long unimath_fixed_clamp(long long val, long long lo, long long hi);
/* Floored modulo, scale-invariant. Returns 0 on division by zero. */
long long unimath_fixed_floor_mod(long long a, long long b);

/* Q32.32 only (no runtime frac_bits -- see the .nim source for why), clamped. */
long long unimath_fixed_floor(long long a);
long long unimath_fixed_ceil(long long a);
long long unimath_fixed_round(long long a);
long long unimath_fixed_lerp(long long a, long long b, long long t);

/* ---- BigFloat (handle = pinned ref BigFloat; default 256-bit precision) ----
 * The ABI never raises: NULL on nil handle / Inf/NaN input / division by zero;
 * to_f64 returns ±Inf/±0 on overflow/underflow. */
typedef void *unimath_bigfloat;

unimath_bigfloat unimath_bigfloat_from_f64(double v);
unimath_bigfloat unimath_bigfloat_from_i64(long long v);
double unimath_bigfloat_to_f64(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_add(unimath_bigfloat a, unimath_bigfloat b);
unimath_bigfloat unimath_bigfloat_sub(unimath_bigfloat a, unimath_bigfloat b);
unimath_bigfloat unimath_bigfloat_mul(unimath_bigfloat a, unimath_bigfloat b);
unimath_bigfloat unimath_bigfloat_div(unimath_bigfloat a, unimath_bigfloat b);

/* -1 / 0 / 1; 0 if either handle is nil. */
int unimath_bigfloat_cmp(unimath_bigfloat a, unimath_bigfloat b);

/* 0/1 (false on a nil handle -- not the zero value). */
int unimath_bigfloat_is_zero(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_neg(unimath_bigfloat a);
unimath_bigfloat unimath_bigfloat_abs(unimath_bigfloat a);
/* Exact conversion from a BigInt handle (no float64 detour). NULL on nil. */
unimath_bigfloat unimath_bigfloat_from_bigint(unimath_bigint h);

void unimath_bigfloat_destroy(unimath_bigfloat h);

/* ---- Rational (handle = pinned ref Rational[BigInt]; unbounded exact) ----
 * The ABI never raises: NULL on nil handle / zero denominator / division by
 * zero; to_f64 returns 0.0 on a nil handle. */
typedef void *unimath_rational;

unimath_rational unimath_rational_from_i64(long long num, long long den);
unimath_rational unimath_rational_from_bigint(unimath_bigint num,
                                               unimath_bigint den);
double unimath_rational_to_f64(unimath_rational h);
/* Numerator / denominator as new pinned BigInt handles (caller owns them). */
unimath_bigint unimath_rational_num(unimath_rational h);
unimath_bigint unimath_rational_den(unimath_rational h);
unimath_rational unimath_rational_add(unimath_rational a, unimath_rational b);
unimath_rational unimath_rational_sub(unimath_rational a, unimath_rational b);
unimath_rational unimath_rational_mul(unimath_rational a, unimath_rational b);
unimath_rational unimath_rational_div(unimath_rational a, unimath_rational b);
unimath_rational unimath_rational_neg(unimath_rational a);
unimath_rational unimath_rational_abs(unimath_rational a);

/* -1 / 0 / 1; 0 if either handle is nil. */
int unimath_rational_cmp(unimath_rational a, unimath_rational b);

/* 0/1 (false on a nil handle -- not the value itself). */
int unimath_rational_is_zero(unimath_rational h);
int unimath_rational_is_one(unimath_rational h);

void unimath_rational_destroy(unimath_rational h);

/* ---- Interval (value type: two doubles, returned by value) ----
 * The ABI never raises: domain errors clamp the input to the valid domain; a
 * wholly out-of-domain input (sqrt of a negative interval, ln of a non-positive
 * interval) returns the NaN interval (lo == hi == NaN) as a sentinel; division
 * by an interval containing zero is unbounded -> (-Inf, Inf). */
typedef struct unimath_interval {
  double lo;
  double hi;
} unimath_interval;

unimath_interval unimath_interval_from_f64(double lo, double hi);
double unimath_interval_lo(unimath_interval a);
double unimath_interval_hi(unimath_interval a);
unimath_interval unimath_interval_add(unimath_interval a, unimath_interval b);
unimath_interval unimath_interval_sub(unimath_interval a, unimath_interval b);
unimath_interval unimath_interval_mul(unimath_interval a, unimath_interval b);
unimath_interval unimath_interval_div(unimath_interval a, unimath_interval b);
unimath_interval unimath_interval_sqrt(unimath_interval a);
unimath_interval unimath_interval_exp(unimath_interval a);
unimath_interval unimath_interval_ln(unimath_interval a);
unimath_interval unimath_interval_sin(unimath_interval a);
unimath_interval unimath_interval_cos(unimath_interval a);
unimath_interval unimath_interval_neg(unimath_interval a);
/* a^n. The NaN interval on a negative n whose base interval contains zero. */
unimath_interval unimath_interval_pow(unimath_interval a, int n);
unimath_interval unimath_interval_arctan(unimath_interval a);
unimath_interval unimath_interval_arctan2(unimath_interval y, unimath_interval x);

/* 0/1. is_valid: lo <= hi. contains: x in [lo, hi]. contains_interval:
 * inner subseteq outer. overlaps: a n b != empty. */
int unimath_interval_is_valid(unimath_interval a);
double unimath_interval_width(unimath_interval a);
double unimath_interval_midpoint(unimath_interval a);
int unimath_interval_contains(unimath_interval a, double x);
int unimath_interval_contains_interval(unimath_interval outer,
                                        unimath_interval inner);
int unimath_interval_overlaps(unimath_interval a, unimath_interval b);
/* Smallest interval containing both a and b. */
unimath_interval unimath_interval_hull(unimath_interval a, unimath_interval b);
/* a n b. Valid (check unimath_interval_is_valid) iff
 * unimath_interval_overlaps(a, b). */
unimath_interval unimath_interval_intersect(unimath_interval a,
                                             unimath_interval b);

/* ---- Roots ----
 * Integer square root (raw int64) and Newton-Raphson square root (float64,
 * BigFloat handle). The ABI never raises: a negative input clamps to 0
 * (isqrt) / NaN (float64 sqrt) / NULL (BigFloat sqrt). */
long long unimath_isqrt_i64(long long n);
double unimath_sqrt_newton_f64(double x);
unimath_bigfloat unimath_sqrt_newton_bigfloat(unimath_bigfloat h);

/* ---- Exponential ----
 * Taylor exp, Taylor ln(1+x), and the generic ln(z), over float64 and BigFloat.
 * The ABI never raises: a nil BigFloat handle returns NULL; an out-of-domain
 * log (lnTaylor with x <= -1, lnGeneric with z <= 0) returns NaN / NULL. */
double unimath_exp_taylor_f64(double x);
double unimath_ln_taylor_f64(double x);
double unimath_ln_generic_f64(double z);
unimath_bigfloat unimath_exp_taylor_bigfloat(unimath_bigfloat h);
unimath_bigfloat unimath_ln_generic_bigfloat(unimath_bigfloat h);

/* ---- Trigonometry ----
 * Generic Taylor sin/cos/atan over float64, and the fixed-point CORDIC/LUT/
 * Chebyshev cores over Q32.32 (32 fractional bits). The fixed-point procs take
 * the raw Q-format long long: angles are mod-reduced to [0, 2pi) first,
 * coordinates are clamped so the CORDIC gain cannot overflow. The ABI never
 * raises. */
double unimath_taylor_sin_f64(double x);
double unimath_taylor_cos_f64(double x);
double unimath_taylor_atan_f64(double x);
long long unimath_cordic_sin(long long q);
long long unimath_cordic_cos(long long q);
long long unimath_cordic_atan2(long long y, long long x);
long long unimath_lut_sin(long long q);
long long unimath_lut_cos(long long q);
long long unimath_chebyshev_tan(long long q);

/* ---- Hyperbolic ----
 * Fixed-point CORDIC sinh/cosh/tanh/exp over Q32.32. Hyperbolic CORDIC
 * converges only for |z| <= ~1.1182 (no range reduction — not periodic); the
 * ABI clamps the angle to that domain first, so it never raises. Use the
 * BigFloat exp/sinh/cosh for larger arguments. */
long long unimath_cordic_sinh(long long q);
long long unimath_cordic_cosh(long long q);
long long unimath_cordic_tanh(long long q);
long long unimath_cordic_exp(long long q);

/* ---- Special ----
 * Orthogonal polynomials (Chebyshev T/U, Legendre, Hermite), the error
 * function, Gamma, factorial, and Bessel J0 — all float64. `gamma` returns
 * NaN at the non-positive-integer poles (the core raises there); `factorial`
 * returns 0 for n < 0. */
double unimath_chebyshev_t(int n, double x);
double unimath_chebyshev_u(int n, double x);
double unimath_legendre(int n, double x);
double unimath_hermite(int n, double x);
double unimath_erf(double x);
double unimath_gamma(double x);
double unimath_factorial(int n);
double unimath_bessel_j0(double x);

/* ---- Constants ----
 * `pi`/`e` as 256-bit BigFloat handles (destroy with `unimath_bigfloat_destroy`)
 * and as raw Q32.32 words. */
unimath_bigfloat unimath_pi_bigfloat(void);
unimath_bigfloat unimath_e_bigfloat(void);
long long unimath_pi_fixed(void);
long long unimath_e_fixed(void);

/* ---- Reduction ----
 * BigFloat trig stage-1 range reduction `r = x - round(x/2pi)·2pi` into
 * `[-pi, pi]`. Returns a new handle (destroy with `unimath_bigfloat_destroy`);
 * NULL in -> NULL out (never raises). */
unimath_bigfloat unimath_bigfloat_reduce(unimath_bigfloat h);

/* ---- float_math ----
 * Range-reduced BigFloat transcendentals. Each returns a new handle (destroy
 * with `unimath_bigfloat_destroy`); NULL in -> NULL out. Domain errors map to
 * NULL (never raises): ln/pow of a non-positive base, sqrt of a negative, tan
 * at a cos-zero singularity. Default calls derive their series budget from
 * the reduced argument and carried precision. The `_terms` variants use an
 * explicit positive budget; terms <= 0 selects the derived default. */
unimath_bigfloat unimath_bigfloat_sin(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_sin_terms(unimath_bigfloat h, int terms);
unimath_bigfloat unimath_bigfloat_cos(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_cos_terms(unimath_bigfloat h, int terms);
unimath_bigfloat unimath_bigfloat_tan(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_tan_terms(unimath_bigfloat h, int terms);
unimath_bigfloat unimath_bigfloat_exp(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_exp_terms(unimath_bigfloat h, int terms);
unimath_bigfloat unimath_bigfloat_ln(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_ln_terms(unimath_bigfloat h, int terms);
unimath_bigfloat unimath_bigfloat_sqrt(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_arctan(unimath_bigfloat h);
unimath_bigfloat unimath_bigfloat_arctan_terms(unimath_bigfloat h, int terms);
unimath_bigfloat unimath_bigfloat_arctan2(unimath_bigfloat y, unimath_bigfloat x);
unimath_bigfloat unimath_bigfloat_arctan2_terms(unimath_bigfloat y,
  unimath_bigfloat x, int terms);
unimath_bigfloat unimath_bigfloat_pow_int(unimath_bigfloat h, int n);
unimath_bigfloat unimath_bigfloat_pow(unimath_bigfloat h, unimath_bigfloat e);
unimath_bigfloat unimath_bigfloat_pow_terms(unimath_bigfloat h,
  unimath_bigfloat e, int terms);

/* ---- rational_math ----
 * Rational[BigInt] transcendentals (exact per term, truncated). Each returns a
 * new handle (destroy with `unimath_rational_destroy`); NULL in -> NULL out.
 * Domain errors map to NULL (never raises): ln/pow of a non-positive base, sqrt
 * of a negative, tan at a cos-zero singularity. */
unimath_rational unimath_rational_sin(unimath_rational h);
unimath_rational unimath_rational_cos(unimath_rational h);
unimath_rational unimath_rational_tan(unimath_rational h);
unimath_rational unimath_rational_exp(unimath_rational h);
unimath_rational unimath_rational_ln(unimath_rational h);
unimath_rational unimath_rational_sqrt(unimath_rational h);
unimath_rational unimath_rational_atan(unimath_rational h);
unimath_rational unimath_rational_atan2(unimath_rational y, unimath_rational x);
unimath_rational unimath_rational_pow(unimath_rational h, unimath_rational e);

/* ---- math_router ----
 * Fixed[int64, 32] (Q32.32) transcendentals via the auto-dispatch cores
 * (CORDIC / Chebyshev / Newton / Taylor). The raw Q32.32 word is the `data`
 * field of `Fixed[int64, 32]`. Never raises: a domain error or overflow clamps
 * to `0`. `pow` needs `base > 0`; `ln` needs `q > 0`; `sqrt` needs `q >= 0`.
 * The fixed sinh/cosh/tanh functions use range-reduced exponentials and have
 * no CORDIC convergence limit. */
long long unimath_fixed_sin(long long q);
long long unimath_fixed_cos(long long q);
long long unimath_fixed_tan(long long q);
long long unimath_fixed_exp(long long q);
long long unimath_fixed_ln(long long q);
long long unimath_fixed_sqrt(long long q);
long long unimath_fixed_atan(long long q);
long long unimath_fixed_atan2(long long y, long long x);
long long unimath_fixed_sinh(long long q);
long long unimath_fixed_cosh(long long q);
long long unimath_fixed_tanh(long long q);
long long unimath_fixed_pow(long long base, long long exponent);
long long unimath_fixed_asin(long long q);
long long unimath_fixed_acos(long long q);
long long unimath_fixed_asinh(long long q);
long long unimath_fixed_acosh(long long q);
long long unimath_fixed_atanh(long long q);
long long unimath_fixed_factorial(int n);
long long unimath_fixed_erf(long long q);
long long unimath_fixed_bessel_j0(long long q);

/* ---- conversions ----
 * The cross-type matrix across the handle / value surfaces. The ABI never
 * raises: NULL in -> NULL / 0 / NaN-interval out; a representation overflow
 * (fixed target) or a NaN/Inf source (rational target) clamps to 0 / NULL.
 * `unimath_rational_from_fixed` and `unimath_fixed_from_rational` take a raw
 * Q-format word plus its `frac_bits` (the fixed value is `q / 2^frac_bits`).
 * Interval procs return the value type by value. */
unimath_rational unimath_rational_from_f64(double v);
unimath_rational unimath_rational_from_fixed(long long q, int frac_bits);
unimath_bigfloat unimath_bigfloat_from_rational(unimath_rational h);
unimath_bigint unimath_bigint_from_bigfloat(unimath_bigfloat h);
unimath_bigint unimath_bigint_from_rational(unimath_rational h);
long long unimath_fixed_from_rational(unimath_rational h, int frac_bits);
unimath_interval unimath_interval_from_bigfloat(unimath_bigfloat h);
unimath_interval unimath_interval_from_rational(unimath_rational h);
unimath_interval unimath_interval_from_bigint(unimath_bigint h);

/* ---------------------------------------------------------------------------
 * Complex - value type (re, im doubles), passed and returned by value. No
 * handle, so nothing to destroy.
 *
 * Never raises: a domain error (division by zero, log of zero, a pole of
 * tan/tanh) returns the NaN complex. Test it with unimath_complex_is_nan, not
 * ==: NaN compares unequal to itself.
 *
 * Branch cuts: principal values, unimath_complex_arg in (-pi, pi], the cut
 * along the negative real axis. A negative real yields the +i root, so
 * unimath_csqrt(-1.0) is 0+1i. Signed zero is not honoured.
 * ------------------------------------------------------------------------- */
typedef struct unimath_complex {
  double re;
  double im;
} unimath_complex;

unimath_complex unimath_complex_from_f64(double re, double im);
double unimath_complex_re(unimath_complex z);
double unimath_complex_im(unimath_complex z);
int unimath_complex_is_nan(unimath_complex z);

unimath_complex unimath_complex_add(unimath_complex a, unimath_complex b);
unimath_complex unimath_complex_sub(unimath_complex a, unimath_complex b);
unimath_complex unimath_complex_mul(unimath_complex a, unimath_complex b);
unimath_complex unimath_complex_div(unimath_complex a, unimath_complex b);
unimath_complex unimath_complex_neg(unimath_complex a);
unimath_complex unimath_complex_conj(unimath_complex a);
unimath_complex unimath_complex_inv(unimath_complex a);

/* Modulus, scaled by the larger component: finite where norm2 overflows. */
double unimath_complex_abs(unimath_complex a);
double unimath_complex_norm2(unimath_complex a);
double unimath_complex_arg(unimath_complex a);
unimath_complex unimath_complex_rect(double r, double theta);

unimath_complex unimath_complex_sqrt(unimath_complex a);
unimath_complex unimath_complex_exp(unimath_complex a);
unimath_complex unimath_complex_ln(unimath_complex a);
unimath_complex unimath_complex_sin(unimath_complex a);
unimath_complex unimath_complex_cos(unimath_complex a);
unimath_complex unimath_complex_tan(unimath_complex a);
unimath_complex unimath_complex_sinh(unimath_complex a);
unimath_complex unimath_complex_cosh(unimath_complex a);
unimath_complex unimath_complex_tanh(unimath_complex a);

/* n == 0 is 1 for every base, zero included; a negative n on a zero base is
 * the NaN complex. */
unimath_complex unimath_complex_pow_int(unimath_complex a, int n);
/* Principal a^b = exp(b * ln a). A zero base is the NaN complex. */
unimath_complex unimath_complex_pow(unimath_complex a, unimath_complex b);

/* Square root and logarithm of a REAL, returned as a complex where the real
 * answer does not exist: unimath_csqrt(-1.0) is 0+1i, unimath_cln(-1.0) is
 * 0 + pi*i. The real entry points (unimath_sqrt_newton_f64, ...) keep their
 * NaN-on-domain-error contract. */
unimath_complex unimath_csqrt(double x);
unimath_complex unimath_cln(double x);

/* ---------------------------------------------------------------------------
 * Complex over BigFloat - handle-based, like the BigFloat scalars: destroy
 * every returned handle with unimath_complex_bigfloat_destroy (or
 * unimath_bigfloat_destroy for the ones typed unimath_bigfloat). This is the
 * multi-precision complex path.
 *
 * Never raises: NULL in -> NULL out; a domain error (zero divisor, log of
 * zero) returns NULL.
 * ------------------------------------------------------------------------- */
typedef void *unimath_complex_bigfloat;

/* The two component handles are copied in; the caller still owns them. */
unimath_complex_bigfloat unimath_complex_bigfloat_from_bigfloat(
    unimath_bigfloat re, unimath_bigfloat im);
/* NULL if either component is Inf or NaN. */
unimath_complex_bigfloat unimath_complex_bigfloat_from_f64(double re, double im);
/* NEW component handles; destroy them separately. */
unimath_bigfloat unimath_complex_bigfloat_re(unimath_complex_bigfloat h);
unimath_bigfloat unimath_complex_bigfloat_im(unimath_complex_bigfloat h);
int unimath_complex_bigfloat_is_zero(unimath_complex_bigfloat h);

unimath_complex_bigfloat unimath_complex_bigfloat_add(
    unimath_complex_bigfloat a, unimath_complex_bigfloat b);
unimath_complex_bigfloat unimath_complex_bigfloat_sub(
    unimath_complex_bigfloat a, unimath_complex_bigfloat b);
unimath_complex_bigfloat unimath_complex_bigfloat_mul(
    unimath_complex_bigfloat a, unimath_complex_bigfloat b);
unimath_complex_bigfloat unimath_complex_bigfloat_div(
    unimath_complex_bigfloat a, unimath_complex_bigfloat b);
unimath_complex_bigfloat unimath_complex_bigfloat_neg(unimath_complex_bigfloat a);
unimath_complex_bigfloat unimath_complex_bigfloat_conj(unimath_complex_bigfloat a);
unimath_complex_bigfloat unimath_complex_bigfloat_inv(unimath_complex_bigfloat a);

unimath_bigfloat unimath_complex_bigfloat_abs(unimath_complex_bigfloat a);
unimath_bigfloat unimath_complex_bigfloat_norm2(unimath_complex_bigfloat a);
unimath_bigfloat unimath_complex_bigfloat_arg(unimath_complex_bigfloat a);

unimath_complex_bigfloat unimath_complex_bigfloat_sqrt(unimath_complex_bigfloat a);
unimath_complex_bigfloat unimath_complex_bigfloat_exp(unimath_complex_bigfloat a);
unimath_complex_bigfloat unimath_complex_bigfloat_ln(unimath_complex_bigfloat a);
unimath_complex_bigfloat unimath_complex_bigfloat_sin(unimath_complex_bigfloat a);
unimath_complex_bigfloat unimath_complex_bigfloat_cos(unimath_complex_bigfloat a);
unimath_complex_bigfloat unimath_complex_bigfloat_pow_int(
    unimath_complex_bigfloat a, int n);
unimath_complex_bigfloat unimath_complex_bigfloat_pow(
    unimath_complex_bigfloat a, unimath_complex_bigfloat b);

/* Square root and logarithm of a REAL BigFloat handle, as a complex. */
unimath_complex_bigfloat unimath_csqrt_bigfloat(unimath_bigfloat h);
unimath_complex_bigfloat unimath_cln_bigfloat(unimath_bigfloat h);

void unimath_complex_bigfloat_destroy(unimath_complex_bigfloat h);

/* ---------------------------------------------------------------------------
 * Complex over Rational[BigInt] - handle-based, the EXACT complex path.
 * add/sub/mul/div, conj, norm2 and integer powers are exact Gaussian-rational
 * arithmetic, unbounded. abs and sqrt are the only approximate entries (a root
 * generally leaves the field). No exp/ln/sin/cos: each would compound two
 * truncated rational series per component - use the BigFloat complex above.
 *
 * Never raises: NULL in -> NULL out.
 * ------------------------------------------------------------------------- */
typedef void *unimath_complex_rational;

unimath_complex_rational unimath_complex_rational_from_rational(
    unimath_rational re, unimath_rational im);
/* NULL if either denominator is zero. */
unimath_complex_rational unimath_complex_rational_from_i64(
    long long re_num, long long re_den, long long im_num, long long im_den);
/* NEW component handles; destroy them separately. */
unimath_rational unimath_complex_rational_re(unimath_complex_rational h);
unimath_rational unimath_complex_rational_im(unimath_complex_rational h);
int unimath_complex_rational_is_zero(unimath_complex_rational h);

unimath_complex_rational unimath_complex_rational_add(
    unimath_complex_rational a, unimath_complex_rational b);
unimath_complex_rational unimath_complex_rational_sub(
    unimath_complex_rational a, unimath_complex_rational b);
unimath_complex_rational unimath_complex_rational_mul(
    unimath_complex_rational a, unimath_complex_rational b);
unimath_complex_rational unimath_complex_rational_div(
    unimath_complex_rational a, unimath_complex_rational b);
unimath_complex_rational unimath_complex_rational_neg(unimath_complex_rational a);
unimath_complex_rational unimath_complex_rational_conj(unimath_complex_rational a);
unimath_complex_rational unimath_complex_rational_inv(unimath_complex_rational a);

/* EXACT. */
unimath_rational unimath_complex_rational_norm2(unimath_complex_rational a);
unimath_complex_rational unimath_complex_rational_pow_int(
    unimath_complex_rational a, int n);
/* APPROXIMATE (Newton iterate: a root leaves the rationals). */
unimath_rational unimath_complex_rational_abs(unimath_complex_rational a);
unimath_complex_rational unimath_complex_rational_sqrt(unimath_complex_rational a);

/* Square root of a REAL Rational handle, as a complex: approximate in
 * magnitude, exact in which axis the result lands on. */
unimath_complex_rational unimath_csqrt_rational(unimath_rational h);

void unimath_complex_rational_destroy(unimath_complex_rational h);

/* ---------------------------------------------------------------------------
 * Complex over Fixed - two raw Q-format words, by value like the Fixed
 * scalars, so nothing to destroy. `frac_bits` is the shared fractional width
 * of both components: add/sub/neg/conj are scale-invariant, mul/div/norm2/
 * pow_int take it. abs/arg/sqrt are Q32.32 only, matching unimath_fixed_sqrt.
 *
 * Never raises: results clamp to the long long range through an exact BigInt
 * intermediate; division by zero returns the zero complex.
 * ------------------------------------------------------------------------- */
typedef struct unimath_complex_fixed {
  long long re;
  long long im;
} unimath_complex_fixed;

unimath_complex_fixed unimath_complex_fixed_from_int(long long re, long long im,
                                                     int frac_bits);
long long unimath_complex_fixed_re(unimath_complex_fixed z);
long long unimath_complex_fixed_im(unimath_complex_fixed z);

unimath_complex_fixed unimath_complex_fixed_add(unimath_complex_fixed a,
                                                unimath_complex_fixed b);
unimath_complex_fixed unimath_complex_fixed_sub(unimath_complex_fixed a,
                                                unimath_complex_fixed b);
unimath_complex_fixed unimath_complex_fixed_neg(unimath_complex_fixed a);
unimath_complex_fixed unimath_complex_fixed_conj(unimath_complex_fixed a);
unimath_complex_fixed unimath_complex_fixed_mul(unimath_complex_fixed a,
                                                unimath_complex_fixed b,
                                                int frac_bits);
unimath_complex_fixed unimath_complex_fixed_div(unimath_complex_fixed a,
                                                unimath_complex_fixed b,
                                                int frac_bits);
long long unimath_complex_fixed_norm2(unimath_complex_fixed a, int frac_bits);
unimath_complex_fixed unimath_complex_fixed_pow_int(unimath_complex_fixed a,
                                                    int n, int frac_bits);

/* Q32.32 only. */
long long unimath_complex_fixed_abs(unimath_complex_fixed a);
long long unimath_complex_fixed_arg(unimath_complex_fixed a);
unimath_complex_fixed unimath_complex_fixed_sqrt(unimath_complex_fixed a);
/* Square root of a REAL raw Q32.32 word, as a complex. */
unimath_complex_fixed unimath_csqrt_fixed(long long q);

#ifdef __cplusplus
}
#endif

#endif /* UNIMATH_H */
