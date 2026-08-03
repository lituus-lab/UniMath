// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/*
 * GMP exact-arithmetic oracle for UniMath BigInt / Rational / Fixed tests.
 *
 * Independent cross-check (different library, different code path) of the
 * exact-type arithmetic: BigUInt/BigInt divmod reconstruction, Fixed `*`/`/`
 * via a BigInt intermediate, and Rational cross-multiply comparison. Pure
 * libgmp integer / mpq rational arithmetic — no MPFR.
 *
 * One query per stdin line. All integers are signed decimal strings (may
 * exceed int64; that is the point — UniMath's BigInt is unbounded). Output is
 * one line per query.
 *
 *   add|sub|mul a b            -> decimal result
 *   divmod a b                 -> "quo rem"  (mpz_tdiv_qr: truncated toward zero)
 *   udivmod a b                -> "quo rem"  (a,b >= 0; mpz_tdiv_qr = floor)
 *   reconstruct a b q r        -> "OK" if a == q*b + r and |r| < |b|, else
 *                                  "MISMATCH <computed-a>"
 *   cmp a b                    -> -1 | 0 | 1
 *
 *   Rational (mpq, auto-reduced):
 *     rcmp na da nb db         -> -1 | 0 | 1   (na/da vs nb/db)
 *     radd|rsub|rmul na da nb db -> "num den" (reduced)
 *
 *   Fixed (Qm.FracBits, signed .data):
 *     fmul frac a b            -> (a*b) >> frac   (arithmetic shift: floor)
 *     fdiv frac a b            -> (a << frac) / b (truncated toward zero)
 *
 * Build: see the `buildOracles` nimble task (links -lgmp via pkg-config).
 * References: GMP manual §6 (mpz), §7 (mpq); Knuth TAOCP Vol. 2 §4.1
 *   (integer division conventions).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gmp.h>

static mpz_t a, b, q, r, t;

/* Parse a signed decimal into z. */
static void mp_set(mpz_t z, const char *s) {
  if (mpz_set_str(z, s, 10) != 0) {
    fprintf(stderr, "gmp_oracle: bad integer '%s'\n", s);
    exit(1);
  }
}

static void print_mpz(const mpz_t z) {
  char *s = mpz_get_str(NULL, 10, z);
  fputs(s, stdout);
  free(s);
}

int main(void) {
  char *line = NULL;
  size_t cap = 0;
  ssize_t len;
  mpz_inits(a, b, q, r, t, (mpz_ptr)0);

  while ((len = getline(&line, &cap, stdin)) != -1) {
    char *save = NULL;
    char *op = strtok_r(line, " \t\r\n", &save);
    if (op == NULL) continue;

    if (strcmp(op, "add") == 0 || strcmp(op, "sub") == 0 ||
        strcmp(op, "mul") == 0) {
      char *sa = strtok_r(NULL, " \t\r\n", &save);
      char *sb = strtok_r(NULL, " \t\r\n", &save);
      if (!sa || !sb) { fprintf(stderr, "%s: need two args\n", op); exit(1); }
      mp_set(a, sa); mp_set(b, sb);
      if (strcmp(op, "add") == 0) mpz_add(t, a, b);
      else if (strcmp(op, "sub") == 0) mpz_sub(t, a, b);
      else mpz_mul(t, a, b);
      print_mpz(t); putchar('\n');

    } else if (strcmp(op, "divmod") == 0 || strcmp(op, "udivmod") == 0) {
      char *sa = strtok_r(NULL, " \t\r\n", &save);
      char *sb = strtok_r(NULL, " \t\r\n", &save);
      if (!sa || !sb) { fprintf(stderr, "%s: need two args\n", op); exit(1); }
      mp_set(a, sa); mp_set(b, sb);
      if (mpz_sgn(b) == 0) { fprintf(stderr, "%s: div by zero\n", op); exit(1); }
      /* mpz_tdiv_qr: truncated toward zero. For non-negative operands (udivmod)
       * this is floor division, matching UniMath's BigUInt divMod. */
      mpz_tdiv_qr(q, r, a, b);
      print_mpz(q); putchar(' '); print_mpz(r); putchar('\n');

    } else if (strcmp(op, "reconstruct") == 0) {
      char *sa = strtok_r(NULL, " \t\r\n", &save);
      char *sb = strtok_r(NULL, " \t\r\n", &save);
      char *sq = strtok_r(NULL, " \t\r\n", &save);
      char *sr = strtok_r(NULL, " \t\r\n", &save);
      if (!sa || !sb || !sq || !sr) {
        fprintf(stderr, "reconstruct: need a b q r\n"); exit(1);
      }
      if (sb[0] == '0' && sb[1] == '\0') {
        fprintf(stderr, "reconstruct: b == 0\n"); exit(1);
      }
      /* Dedicated temporaries (no slot reuse): computed = q*b + r must equal a,
       * with |r| < |b|. Convention-agnostic — any valid (q,r) pair passes. */
      mpz_t a0, b0, q0, r0, computed, absr, absb;
      mpz_inits(a0, b0, q0, r0, computed, absr, absb, (mpz_ptr)0);
      mp_set(a0, sa); mp_set(b0, sb); mp_set(q0, sq); mp_set(r0, sr);
      mpz_mul(computed, q0, b0);
      mpz_add(computed, computed, r0);
      mpz_abs(absr, r0);
      mpz_abs(absb, b0);
      int ok = (mpz_cmp(computed, a0) == 0) && (mpz_cmp(absr, absb) < 0);
      if (ok) {
        fputs("OK\n", stdout);
      } else {
        fputs("MISMATCH computed=", stdout); print_mpz(computed);
        fputs(" a=", stdout); print_mpz(a0);
        fputs(" |r|=", stdout); print_mpz(absr);
        fputs(" |b|=", stdout); print_mpz(absb);
        putchar('\n');
      }
      mpz_clears(a0, b0, q0, r0, computed, absr, absb, (mpz_ptr)0);

    } else if (strcmp(op, "cmp") == 0) {
      char *sa = strtok_r(NULL, " \t\r\n", &save);
      char *sb = strtok_r(NULL, " \t\r\n", &save);
      if (!sa || !sb) { fprintf(stderr, "cmp: need two args\n"); exit(1); }
      mp_set(a, sa); mp_set(b, sb);
      printf("%d\n", mpz_cmp(a, b));

    } else if (strcmp(op, "rcmp") == 0) {
      char *na = strtok_r(NULL, " \t\r\n", &save);
      char *da = strtok_r(NULL, " \t\r\n", &save);
      char *nb = strtok_r(NULL, " \t\r\n", &save);
      char *db = strtok_r(NULL, " \t\r\n", &save);
      if (!na || !da || !nb || !db) { fprintf(stderr, "rcmp: need 4\n"); exit(1); }
      mpq_t pa, pb;
      mpq_inits(pa, pb, (mpq_ptr)0);
      mpz_set_str(mpq_numref(pa), na, 10);
      mpz_set_str(mpq_denref(pa), da, 10);
      mpz_set_str(mpq_numref(pb), nb, 10);
      mpz_set_str(mpq_denref(pb), db, 10);
      mpq_canonicalize(pa); mpq_canonicalize(pb);
      printf("%d\n", mpq_cmp(pa, pb));
      mpq_clears(pa, pb, (mpq_ptr)0);

    } else if (strcmp(op, "radd") == 0 || strcmp(op, "rsub") == 0 ||
               strcmp(op, "rmul") == 0) {
      char *na = strtok_r(NULL, " \t\r\n", &save);
      char *da = strtok_r(NULL, " \t\r\n", &save);
      char *nb = strtok_r(NULL, " \t\r\n", &save);
      char *db = strtok_r(NULL, " \t\r\n", &save);
      if (!na || !da || !nb || !db) { fprintf(stderr, "%s: need 4\n", op); exit(1); }
      mpq_t pa, pb, pr;
      mpq_inits(pa, pb, pr, (mpq_ptr)0);
      mpz_set_str(mpq_numref(pa), na, 10);
      mpz_set_str(mpq_denref(pa), da, 10);
      mpz_set_str(mpq_numref(pb), nb, 10);
      mpz_set_str(mpq_denref(pb), db, 10);
      mpq_canonicalize(pa); mpq_canonicalize(pb);
      if (strcmp(op, "radd") == 0) mpq_add(pr, pa, pb);
      else if (strcmp(op, "rsub") == 0) mpq_sub(pr, pa, pb);
      else mpq_mul(pr, pa, pb);
      mpq_canonicalize(pr);
      char *sn = mpz_get_str(NULL, 10, mpq_numref(pr));
      char *sd = mpz_get_str(NULL, 10, mpq_denref(pr));
      printf("%s %s\n", sn, sd);
      free(sn); free(sd);
      mpq_clears(pa, pb, pr, (mpq_ptr)0);

    } else if (strcmp(op, "fmul") == 0) {
      char *sfrac = strtok_r(NULL, " \t\r\n", &save);
      char *sa = strtok_r(NULL, " \t\r\n", &save);
      char *sb = strtok_r(NULL, " \t\r\n", &save);
      if (!sfrac || !sa || !sb) { fprintf(stderr, "fmul: need frac a b\n"); exit(1); }
      long frac = strtol(sfrac, NULL, 10);
      if (frac < 0) { fprintf(stderr, "fmul: bad frac\n"); exit(1); }
      mp_set(a, sa); mp_set(b, sb);
      mpz_mul(t, a, b);
      /* arithmetic shift right = floor division by 2^frac (matches C >> on
       * signed for the common floor convention and UniMath's signed BigInt shr). */
      mpz_fdiv_q_2exp(t, t, (mp_bitcnt_t)frac);
      print_mpz(t); putchar('\n');

    } else if (strcmp(op, "fdiv") == 0) {
      char *sfrac = strtok_r(NULL, " \t\r\n", &save);
      char *sa = strtok_r(NULL, " \t\r\n", &save);
      char *sb = strtok_r(NULL, " \t\r\n", &save);
      if (!sfrac || !sa || !sb) { fprintf(stderr, "fdiv: need frac a b\n"); exit(1); }
      long frac = strtol(sfrac, NULL, 10);
      if (frac < 0) { fprintf(stderr, "fdiv: bad frac\n"); exit(1); }
      mp_set(a, sa); mp_set(b, sb);
      if (mpz_sgn(b) == 0) { fprintf(stderr, "fdiv: div by zero\n"); exit(1); }
      mpz_mul_2exp(t, a, (mp_bitcnt_t)frac);
      mpz_tdiv_q(t, t, b);   /* truncated toward zero (C integer division) */
      print_mpz(t); putchar('\n');

    } else {
      fprintf(stderr, "gmp_oracle: unknown op '%s'\n", op);
      exit(1);
    }
  }

  free(line);
  mpz_clears(a, b, q, r, t, (mpz_ptr)0);
  return 0;
}