// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/*
 * MPFR transcendental oracle for UniMath BigFloat tests.
 *
 * Verifies the BigFloat transcendentals (sin/cos/exp/ln/sqrt/gamma) against an
 * independent high-precision reference. Query modes, one per stdin line:
 *
 *   1. Correctly-rounded float64 reference:
 *
 *        <op> <prec> <x_bits>
 *
 *      where <op> in {sin, cos, exp, ln, sqrt, gamma}, <prec> is the MPFR
 *      working precision in bits (>= 53), and <x_bits> is the raw IEEE-754
 *      bit pattern of the float64 argument (Nim sends cast[uint64](x); the
 *      exact rational value of the double is loaded via mpfr_set_d).
 *
 *      Prints one line: round-to-nearest-even of <op>(x) to binary64, as the
 *      raw uint64 bit pattern. This is the single-rounded reference that a
 *      cast-then-round cannot always provide (no double rounding).
 *
 *   2. Exact error of a candidate result vs the exact real value:
 *
 *        err <op> <prec> <cand_bits> <x_bits>
 *
 *      Accumulates R = <op>(x) at ACC_PREC (2048-bit) precision — exact for
 *      any float64 argument (the function value is resolved far beyond the
 *      53-bit target) — then for the candidate A (loaded exactly from its
 *      bits) prints one line with three high-precision decimal values:
 *
 *          abs_err  rel_err  ulp_err
 *
 *      where:
 *        abs_err = |A - R|                  (exact)
 *        rel_err = |A - R| / |R|            (exact; = abs_err when R == 0)
 *        ulp_err = |A - R| / ulp(R)         (exact rational)
 *
 *      and ulp(R) = 2^(floor(log2|R|) - 52) for normal R (p = 53); for
 *      subnormal/zero R, ulp = 2^-1074 (the subnormal spacing). This is the
 *      Goldberg/Muller ULP error measured at the magnitude of the EXACT real
 *      value R, so a correctly-rounded candidate reports <= 0.5 and a faithful
 *      one <= 1, computed without the rounding error a float |A - R| would add.
 *
 *   3. Binary arithmetic (BigFloat + - * /), same two modes with a second
 *      operand:
 *
 *        bin  <op> <prec> <a_bits> <b_bits>            -> correctly-rounded ref
 *        berr <op> <prec> <cand_bits> <a_bits> <b_bits> -> abs/rel/ulp err
 *
 *      <op> in {add, sub, mul, div}; R = a op b at ACC_PREC. add/sub/mul are
 *      exact for any two float64 operands (the sum/difference/product fits in
 *      2048 bits); div is a correctly-rounded 2048-bit approximation, since the
 *      quotient is generally a non-terminating binary fraction. Division by
 *      zero is a domain error (non-zero exit).
 *
 * Domain: only finite float64 arguments with a finite transcendental value are
 * supported. sqrt/ln reject negative/zero domain errors with a non-zero exit
 * (the Nim test skips those — they are covered by the raise-on-domain tests).
 * gamma is defined for all finite non-pole float64 x; poles (0, -1, -2, ...)
 * are rejected. MPFR computes the function of the EXACT rational value of the
 * double argument, so this is the rigorous reference for the float64 result.
 *
 * Build: see the `buildOracles` nimble task (links -lmpfr -lgmp via pkg-config).
 * References: MPFR manual §5 (mpfr_sin/exp/log/sqrt/gamma, mpfr_get_d,
 *   mpfr_get_exp); Goldberg, ACM Computing Surveys 23(1), 1991,
 *   doi:10.1145/103162.103163; Muller et al., "Handbook of Floating-Point
 *   Arithmetic", Birkhauser 2010; IEEE 754-2019 round-to-nearest-even.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <gmp.h>
#define MPFR_USE_FILE
#include <mpfr.h>

/* Accumulator precision: 2048 bits. A float64 argument is an exact rational;
 * resolving its transcendental to a 53-bit target needs the function value to
 * ~53 + guard bits. 2048 bits (~616 decimal digits) is far more than enough
 * for sin/cos/exp/ln/sqrt/gamma of any finite float64 (MPFR performs argument
 * reduction internally at this precision), so R is the de-facto exact real
 * value for the purpose of a float64 comparison. Too small a precision would
 * silently round the reference and misreport a correct candidate as in error. */
#define ACC_PREC 2048

/* Output precision (significant digits) for the err-mode error values. */
#define ERR_DIGITS 20

static mpfr_t x, r, a, y, errv, relv, ulpv, minnorm;

/* Compute R = x op y at ACC_PREC for a binary arithmetic op (add/sub/mul/div).
 * Returns 0 on success, -1 on a domain error (division by zero). The operands
 * are the exact rational values of two float64s, already loaded into x and y. */
static int compute_bin(const char *op) {
  if (strcmp(op, "add") == 0)      mpfr_add(r, x, y, MPFR_RNDN);
  else if (strcmp(op, "sub") == 0) mpfr_sub(r, x, y, MPFR_RNDN);
  else if (strcmp(op, "mul") == 0) mpfr_mul(r, x, y, MPFR_RNDN);
  else if (strcmp(op, "div") == 0) {
    if (mpfr_zero_p(y)) return -1;
    mpfr_div(r, x, y, MPFR_RNDN);
  } else {
    fprintf(stderr, "mpfr_oracle: unknown binary op '%s'\n", op);
    exit(1);
  }
  return 0;
}

/* Compute R = op(x) at ACC_PREC. Returns 0 on success, -1 on a domain error
 * (the Nim test skips domain errors; they are covered by the raise tests). */
static int compute_ref(const char *op) {
  if (strcmp(op, "sin") == 0)       mpfr_sin(r, x, MPFR_RNDN);
  else if (strcmp(op, "cos") == 0)  mpfr_cos(r, x, MPFR_RNDN);
  else if (strcmp(op, "exp") == 0)  mpfr_exp(r, x, MPFR_RNDN);
  else if (strcmp(op, "ln") == 0) {
    if (mpfr_cmp_ui(x, 0) <= 0) return -1;
    mpfr_log(r, x, MPFR_RNDN);
  } else if (strcmp(op, "sqrt") == 0) {
    if (mpfr_cmp_ui(x, 0) < 0) return -1;
    mpfr_sqrt(r, x, MPFR_RNDN);
  } else if (strcmp(op, "gamma") == 0) {
    /* poles at 0, -1, -2, ...: mpfr_gamma returns NaN for non-positive
     * integers; reject those explicitly. */
    if (mpfr_integer_p(x) && mpfr_cmp_ui(x, 0) <= 0) return -1;
    mpfr_gamma(r, x, MPFR_RNDN);
  } else {
    fprintf(stderr, "mpfr_oracle: unknown op '%s'\n", op);
    exit(1);
  }
  return 0;
}

/* Emit abs_err/rel_err/ulp_err for candidate A (loaded from candbits) against
 * the exact real value already accumulated in r. Mirrors the UniAccurate
 * oracle's error definition (Goldberg/Muller ULP at the magnitude of R). */
static void emit_errors(double cand) {
  const int p = 53;
  const long subexp = -1074;
  mpfr_set_d(minnorm, ldexp(1.0, -1022), MPFR_RNDN);

  mpfr_set_d(a, cand, MPFR_RNDN);          /* a = candidate A (exact) */
  mpfr_sub(errv, a, r, MPFR_RNDN);          /* errv = A - R (exact, ACC_PREC) */
  mpfr_abs(errv, errv, MPFR_RNDN);          /* abs_err = |A - R| */

  if (mpfr_zero_p(r)) {
    mpfr_set(relv, errv, MPFR_RNDN);        /* rel_err = abs_err when R == 0 */
  } else {
    mpfr_abs(relv, r, MPFR_RNDN);           /* |R| */
    mpfr_div(relv, errv, relv, MPFR_RNDN);  /* rel_err = abs_err / |R| (exact) */
  }

  /* ulp(R): spacing at the magnitude of the EXACT real value R. */
  if (mpfr_cmpabs(r, minnorm) < 0) {
    mpfr_set_ui(ulpv, 1, MPFR_RNDN);
    mpfr_mul_2si(ulpv, ulpv, subexp, MPFR_RNDN);
  } else {
    mpfr_exp_t e = mpfr_get_exp(r);         /* |R| in [2^(e-1), 2^e) */
    mpfr_set_ui(ulpv, 1, MPFR_RNDN);
    mpfr_mul_2si(ulpv, ulpv, (long)e - p, MPFR_RNDN);
  }
  mpfr_div(ulpv, errv, ulpv, MPFR_RNDN);    /* ulp_err = abs_err / ulp(R) */

  mpfr_out_str(stdout, 10, ERR_DIGITS, errv, MPFR_RNDN);
  putchar(' ');
  mpfr_out_str(stdout, 10, ERR_DIGITS, relv, MPFR_RNDN);
  putchar(' ');
  mpfr_out_str(stdout, 10, ERR_DIGITS, ulpv, MPFR_RNDN);
  putchar('\n');
}

/* Load the exact rational value of a float64 (given by its raw uint64 bits)
 * into x. */
static void load_x(unsigned long long bits) {
  double d;
  memcpy(&d, &bits, sizeof(d));
  mpfr_set_d(x, d, MPFR_RNDN);              /* exact: x := rational value of d */
}

/* Load the second binary operand into y. */
static void load_y(unsigned long long bits) {
  double d;
  memcpy(&d, &bits, sizeof(d));
  mpfr_set_d(y, d, MPFR_RNDN);
}

int main(void) {
  char *line = NULL;
  size_t cap = 0;
  ssize_t len;
  mpfr_inits2(ACC_PREC, x, r, a, y, errv, relv, ulpv, minnorm, (mpfr_ptr)0);

  while ((len = getline(&line, &cap, stdin)) != -1) {
    char *save = NULL;
    char *tok = strtok_r(line, " \t\r\n", &save);
    if (tok == NULL) continue;

    int err_mode = 0, bin_mode = 0;
    char op[16] = {0};

    if (strcmp(tok, "err") == 0) {
      err_mode = 1;
      tok = strtok_r(NULL, " \t\r\n", &save);
      if (tok == NULL) { fprintf(stderr, "err: missing op\n"); exit(1); }
      strncpy(op, tok, sizeof(op) - 1);
    } else if (strcmp(tok, "bin") == 0) {
      bin_mode = 1;
      tok = strtok_r(NULL, " \t\r\n", &save);
      if (tok == NULL) { fprintf(stderr, "bin: missing op\n"); exit(1); }
      strncpy(op, tok, sizeof(op) - 1);
    } else if (strcmp(tok, "berr") == 0) {
      bin_mode = 1; err_mode = 1;
      tok = strtok_r(NULL, " \t\r\n", &save);
      if (tok == NULL) { fprintf(stderr, "berr: missing op\n"); exit(1); }
      strncpy(op, tok, sizeof(op) - 1);
    } else {
      strncpy(op, tok, sizeof(op) - 1);
    }

    /* working precision (reference mode uses it; err mode ignores it and uses
     * ACC_PREC for the exact R). */
    tok = strtok_r(NULL, " \t\r\n", &save);
    if (tok == NULL) { fprintf(stderr, "%s: missing precision\n", op); exit(1); }
    long prec = strtol(tok, NULL, 10);
    if (prec < 53) prec = 53;

    unsigned long long cand_bits = 0;
    if (err_mode) {
      tok = strtok_r(NULL, " \t\r\n", &save);
      if (tok == NULL) { fprintf(stderr, "err: missing cand bits\n"); exit(1); }
      cand_bits = strtoull(tok, NULL, 10);
    }

    tok = strtok_r(NULL, " \t\r\n", &save);
    if (tok == NULL) { fprintf(stderr, "%s: missing x bits\n", op); exit(1); }
    load_x(strtoull(tok, NULL, 10));
    if (bin_mode) {
      tok = strtok_r(NULL, " \t\r\n", &save);
      if (tok == NULL) { fprintf(stderr, "bin: missing y bits\n"); exit(1); }
      load_y(strtoull(tok, NULL, 10));
    }

    if (err_mode) {
      /* exact R at ACC_PREC */
      mpfr_set_prec(r, ACC_PREC);
      int dom = bin_mode ? compute_bin(op) : compute_ref(op);
      if (dom != 0) {
        fprintf(stderr, "err: domain error for %s\n", op);
        exit(2);
      }
      double cand;
      memcpy(&cand, &cand_bits, sizeof(cand));
      emit_errors(cand);
    } else {
      /* correctly-rounded float64 reference at the requested precision */
      mpfr_set_prec(r, prec);
      int dom = bin_mode ? compute_bin(op) : compute_ref(op);
      if (dom != 0) {
        fprintf(stderr, "%s: domain error\n", op);
        exit(2);
      }
      double d = mpfr_get_d(r, MPFR_RNDN);   /* single rounding to binary64 */
      uint64_t bits;
      memcpy(&bits, &d, sizeof(bits));
      printf("%llu\n", (unsigned long long)bits);
    }
  }

  free(line);
  mpfr_clears(x, r, a, y, errv, relv, ulpv, minnorm, (mpfr_ptr)0);
  return 0;
}

