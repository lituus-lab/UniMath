// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/*
 * MPC complex oracle for UniMath Complex tests.
 *
 * MPC is the complex counterpart of MPFR (same authors, same build system):
 * correctly-rounded complex arithmetic and transcendentals at arbitrary
 * precision. It is the independent reference for `complex_math` -- the library
 * under test must not be its own oracle.
 *
 * Query modes, one per stdin line. Complex values cross as the raw IEEE-754
 * bit patterns of their two float64 components (Nim sends cast[uint64](x)), so
 * the argument is transferred exactly, with no decimal round-trip.
 *
 *   1. Correctly-rounded complex reference:
 *
 *        <op> <prec> <re_bits> <im_bits>
 *
 *      where <op> is one of
 *        sqrt exp log sin cos tan sinh cosh tanh
 *      and <prec> is the MPC working precision in bits (>= 53).
 *
 *      Prints one line, the two components of round-to-nearest-even of
 *      <op>(z) to binary64, as raw uint64 bit patterns:
 *
 *          <re_bits> <im_bits>
 *
 *   2. Binary arithmetic, same shape with a second operand:
 *
 *        bin <op> <prec> <a_re> <a_im> <b_re> <b_im>
 *
 *      <op> in {add, sub, mul, div, pow}. Prints the same two-word line.
 *
 *   3. Real-valued queries (modulus, argument):
 *
 *        real <op> <prec> <re_bits> <im_bits>
 *
 *      <op> in {abs, arg}. Prints ONE uint64: the correctly-rounded binary64.
 *
 *   4. Exact error of a candidate complex result vs the exact value:
 *
 *        err <op> <prec> <cand_re> <cand_im> <re_bits> <im_bits>
 *
 *      Accumulates R = <op>(z) at ACC_PREC (2048-bit), then prints one line
 *      with two high-precision decimal values:
 *
 *          abs_err  rel_err
 *
 *      where abs_err = |A - R| and rel_err = |A - R| / |R| (= abs_err when
 *      R == 0), both as complex moduli, computed exactly rather than through
 *      a float64 subtraction that would add its own rounding.
 *
 * Domain: only finite float64 components. `log` of the complex zero, and `div`
 * by the complex zero, are domain errors and exit non-zero (the Nim test
 * covers those through the raise-on-domain tests instead).
 *
 * Branch cuts: MPC takes the same principal values UniMath does -- arg in
 * (-pi, pi], the cut along the negative real axis -- so the two agree on
 * sqrt(-1) == +i without any convention shim. MPC does honour signed zero and
 * UniMath deliberately does not, so the Nim test never sends a negative zero
 * imaginary part.
 *
 * Build: see the `buildOracles` nimble task (links -lmpc -lmpfr -lgmp via
 * pkg-config). libmpc is LGPL and is linked only by this oracle binary, which
 * is gitignored and never shipped.
 * References: MPC manual (mpc_sqrt/exp/log/sin/cos/tan/sinh/cosh/tanh,
 *   mpc_abs, mpc_arg, mpc_pow); IEEE 754-2019 round-to-nearest-even;
 *   ISO C99 Annex G for the branch cuts.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <gmp.h>
#include <mpfr.h>
#include <mpc.h>

/* Accumulator precision for the err mode: 2048 bits. A float64 component is an
 * exact rational, so resolving a complex transcendental of it to a 53-bit
 * target needs the value to ~53 + guard bits; 2048 is far past that, which
 * makes R the de-facto exact value for a binary64 comparison. */
#define ACC_PREC 2048

/* Output precision (significant digits) for the err-mode values. */
#define ERR_DIGITS 20

static mpc_t z, r, a, b, d;
static mpfr_t rv, ev;

static double bits_to_double(unsigned long long u) {
  double out;
  memcpy(&out, &u, sizeof out);
  return out;
}

static unsigned long long double_to_bits(double v) {
  unsigned long long out;
  memcpy(&out, &v, sizeof out);
  return out;
}

/* Load an mpc_t exactly from the two raw component bit patterns. mpc_set_d_d
 * is exact: every finite double is representable at any precision >= 53. */
static void load(mpc_t dst, unsigned long long re, unsigned long long im) {
  mpc_set_d_d(dst, bits_to_double(re), bits_to_double(im), MPC_RNDNN);
}

static void print_complex(mpc_t v) {
  double re = mpfr_get_d(mpc_realref(v), MPFR_RNDN);
  double im = mpfr_get_d(mpc_imagref(v), MPFR_RNDN);
  printf("%llu %llu\n", double_to_bits(re), double_to_bits(im));
}

/* Apply a unary op by name. Returns 0 on success, non-zero on an unknown op or
 * a domain error. */
static int apply_unary(const char *op, mpc_t dst, mpc_t src) {
  if (strcmp(op, "sqrt") == 0) { mpc_sqrt(dst, src, MPC_RNDNN); return 0; }
  if (strcmp(op, "exp") == 0) { mpc_exp(dst, src, MPC_RNDNN); return 0; }
  if (strcmp(op, "log") == 0) {
    /* No branch of the complex log is finite at zero. */
    if (mpfr_zero_p(mpc_realref(src)) && mpfr_zero_p(mpc_imagref(src))) return 1;
    mpc_log(dst, src, MPC_RNDNN);
    return 0;
  }
  if (strcmp(op, "sin") == 0) { mpc_sin(dst, src, MPC_RNDNN); return 0; }
  if (strcmp(op, "cos") == 0) { mpc_cos(dst, src, MPC_RNDNN); return 0; }
  if (strcmp(op, "tan") == 0) { mpc_tan(dst, src, MPC_RNDNN); return 0; }
  if (strcmp(op, "sinh") == 0) { mpc_sinh(dst, src, MPC_RNDNN); return 0; }
  if (strcmp(op, "cosh") == 0) { mpc_cosh(dst, src, MPC_RNDNN); return 0; }
  if (strcmp(op, "tanh") == 0) { mpc_tanh(dst, src, MPC_RNDNN); return 0; }
  return 1;
}

static int apply_binary(const char *op, mpc_t dst, mpc_t x, mpc_t y) {
  if (strcmp(op, "add") == 0) { mpc_add(dst, x, y, MPC_RNDNN); return 0; }
  if (strcmp(op, "sub") == 0) { mpc_sub(dst, x, y, MPC_RNDNN); return 0; }
  if (strcmp(op, "mul") == 0) { mpc_mul(dst, x, y, MPC_RNDNN); return 0; }
  if (strcmp(op, "div") == 0) {
    if (mpfr_zero_p(mpc_realref(y)) && mpfr_zero_p(mpc_imagref(y))) return 1;
    mpc_div(dst, x, y, MPC_RNDNN);
    return 0;
  }
  if (strcmp(op, "pow") == 0) {
    if (mpfr_zero_p(mpc_realref(x)) && mpfr_zero_p(mpc_imagref(x))) return 1;
    mpc_pow(dst, x, y, MPC_RNDNN);
    return 0;
  }
  return 1;
}

int main(void) {
  char line[512];
  char kind[32], op[32];
  long prec;
  unsigned long long p1, p2, p3, p4, p5, p6;

  while (fgets(line, sizeof line, stdin)) {
    if (line[0] == '\n' || line[0] == '\0') continue;

    if (sscanf(line, "%31s", kind) != 1) return 2;

    if (strcmp(kind, "bin") == 0) {
      if (sscanf(line, "%*s %31s %ld %llu %llu %llu %llu",
                 op, &prec, &p1, &p2, &p3, &p4) != 6) return 2;
      if (prec < 53) return 2;
      mpc_init2(a, (mpfr_prec_t)prec);
      mpc_init2(b, (mpfr_prec_t)prec);
      mpc_init2(r, (mpfr_prec_t)prec);
      load(a, p1, p2);
      load(b, p3, p4);
      if (apply_binary(op, r, a, b) != 0) return 3;
      print_complex(r);
      mpc_clear(a); mpc_clear(b); mpc_clear(r);
      continue;
    }

    if (strcmp(kind, "real") == 0) {
      if (sscanf(line, "%*s %31s %ld %llu %llu", op, &prec, &p1, &p2) != 4)
        return 2;
      if (prec < 53) return 2;
      mpc_init2(z, (mpfr_prec_t)prec);
      mpfr_init2(rv, (mpfr_prec_t)prec);
      load(z, p1, p2);
      if (strcmp(op, "abs") == 0) mpc_abs(rv, z, MPFR_RNDN);
      else if (strcmp(op, "arg") == 0) mpc_arg(rv, z, MPFR_RNDN);
      else return 3;
      printf("%llu\n", double_to_bits(mpfr_get_d(rv, MPFR_RNDN)));
      mpc_clear(z); mpfr_clear(rv);
      continue;
    }

    if (strcmp(kind, "err") == 0) {
      if (sscanf(line, "%*s %31s %ld %llu %llu %llu %llu",
                 op, &prec, &p3, &p4, &p5, &p6) != 6) return 2;
      (void)prec; /* err always accumulates at ACC_PREC */
      mpc_init2(z, ACC_PREC);
      mpc_init2(r, ACC_PREC);
      mpc_init2(a, ACC_PREC);
      mpc_init2(d, ACC_PREC);
      mpfr_init2(ev, ACC_PREC);
      mpfr_init2(rv, ACC_PREC);
      load(z, p5, p6);
      load(a, p3, p4);
      if (apply_unary(op, r, z) != 0) return 3;
      mpc_sub(d, a, r, MPC_RNDNN);
      mpc_abs(ev, d, MPFR_RNDN);   /* abs_err = |A - R| */
      mpc_abs(rv, r, MPFR_RNDN);   /* |R| */
      mpfr_printf("%.*Rg ", ERR_DIGITS, ev);
      if (mpfr_zero_p(rv)) {
        mpfr_printf("%.*Rg\n", ERR_DIGITS, ev);
      } else {
        mpfr_div(ev, ev, rv, MPFR_RNDN);
        mpfr_printf("%.*Rg\n", ERR_DIGITS, ev);
      }
      mpc_clear(z); mpc_clear(r); mpc_clear(a); mpc_clear(d);
      mpfr_clear(ev); mpfr_clear(rv);
      continue;
    }

    /* Unary: <op> <prec> <re_bits> <im_bits> */
    if (sscanf(line, "%31s %ld %llu %llu", op, &prec, &p1, &p2) != 4) return 2;
    if (prec < 53) return 2;
    mpc_init2(z, (mpfr_prec_t)prec);
    mpc_init2(r, (mpfr_prec_t)prec);
    load(z, p1, p2);
    if (apply_unary(op, r, z) != 0) return 3;
    print_complex(r);
    mpc_clear(z); mpc_clear(r);
  }

  mpfr_free_cache();
  return 0;
}
