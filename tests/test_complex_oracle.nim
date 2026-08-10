# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Complex transcendentals against the MPC oracle. Not in the default gate:
## needs `libmpc`/`libmpfr`/`libgmp` and the binary built by
## `nimble buildOracles`. Run with `nimble testOracle`.
import std/unittest
import std/math except sqrt
import UniMath
import oracles/oracle

const
  RefPrec = 2048
    ## MPC working precision for the correctly-rounded reference. Far past the
    ## double-rounding band, as the MPFR suite's own reference precision is.
  UlpTol = 1e-14
    ## Relative tolerance on the closed-form results. UniMath composes two or
    ## three real float64 transcendentals per component, so a handful of ulps
    ## is expected; MPC rounds the whole complex function once.

# Sample points that stay clear of the poles and of the branch cut's negative
# zero, which UniMath deliberately does not distinguish (see ADR-0009).
const Points = [
  (1.0, 2.0), (3.0, 4.0), (-3.0, 4.0), (-3.0, -4.0), (3.0, -4.0),
  (0.5, -0.25), (-1.0, 0.5), (0.0, 1.0), (2.0, 0.0), (-2.0, 0.0),
  (0.125, 8.0), (-0.75, -0.125),
]

proc relErr(got, want: float64): float64 =
  if want == 0.0: abs(got)
  else: abs(got - want) / abs(want)

proc checkAgainst(name: string, op: string, got: Complex[float64],
                  re, im: float64, tol = UlpTol) =
  let (wr, wi) = mpcRef(op, RefPrec, re, im)
  # Compare on the modulus of the difference, relative to the reference's:
  # a component that is near zero by cancellation carries no significance of
  # its own, and a per-component relative check would flag it spuriously.
  let scale = hypot(wr, wi)
  let err = hypot(got.re - wr, got.im - wi)
  let rel = if scale == 0.0: err else: err / scale
  check(rel <= tol)
  if rel > tol:
    echo name, " ", op, "(", re, ",", im, "): got (", got.re, ",", got.im,
         ") want (", wr, ",", wi, ") rel=", rel

suite "MPC oracle — complex transcendentals":
  test "sqrt matches the correctly-rounded reference":
    for (re, im) in Points:
      checkAgainst("sqrt", "sqrt", sqrt(complex(re, im)), re, im)
  test "exp matches":
    for (re, im) in Points:
      checkAgainst("exp", "exp", exp(complex(re, im)), re, im)
  test "ln matches":
    for (re, im) in Points:
      checkAgainst("ln", "log", ln(complex(re, im)), re, im)
  test "sin and cos match":
    for (re, im) in Points:
      checkAgainst("sin", "sin", sin(complex(re, im)), re, im)
      checkAgainst("cos", "cos", cos(complex(re, im)), re, im)
  test "tan matches":
    for (re, im) in Points:
      checkAgainst("tan", "tan", tan(complex(re, im)), re, im, 1e-13)
  test "sinh, cosh and tanh match":
    for (re, im) in Points:
      checkAgainst("sinh", "sinh", sinh(complex(re, im)), re, im)
      checkAgainst("cosh", "cosh", cosh(complex(re, im)), re, im)
      checkAgainst("tanh", "tanh", tanh(complex(re, im)), re, im, 1e-13)

suite "MPC oracle — modulus and argument":
  test "abs matches the correctly-rounded modulus":
    for (re, im) in Points:
      let want = mpcRealRef("abs", RefPrec, re, im)
      check relErr(abs(complex(re, im)), want) <= UlpTol
  test "arg matches the principal argument":
    for (re, im) in Points:
      let want = mpcRealRef("arg", RefPrec, re, im)
      # Absolute, not relative: arg passes through zero on the positive real
      # axis, where a relative bound is meaningless.
      check abs(arg(complex(re, im)) - want) <= 1e-15

suite "MPC oracle — arithmetic":
  test "add, sub and mul are exact against MPC":
    let a = complex(1.5, -2.25)
    let b = complex(-0.75, 4.0)
    for (op, got) in [("add", a + b), ("sub", a - b), ("mul", a * b)]:
      let (wr, wi) = mpcBinRef(op, RefPrec, a.re, a.im, b.re, b.im)
      # These operands are chosen so every product and sum is representable:
      # the agreement is bit-exact, not merely within tolerance.
      check got.re == wr and got.im == wi
  test "div matches within a few ulps":
    let a = complex(1.0, 2.0)
    let b = complex(3.0, -1.0)
    let (wr, wi) = mpcBinRef("div", RefPrec, a.re, a.im, b.re, b.im)
    let got = a / b
    check relErr(got.re, wr) <= UlpTol and relErr(got.im, wi) <= UlpTol
  test "Smith's algorithm agrees with MPC where the textbook formula fails":
    # norm2 of either operand is +Inf in float64; MPC has no such limit, so it
    # is the reference that proves the scaled form right, not just finite.
    let a = complex(1e300, 1e300)
    let (wr, wi) = mpcBinRef("div", RefPrec, a.re, a.im, a.re, a.im)
    let got = a / a
    check got.re == wr and got.im == wi
  test "the complex power matches":
    let a = complex(1.0, 2.0)
    let b = complex(0.5, 0.0)
    let (wr, wi) = mpcBinRef("pow", RefPrec, a.re, a.im, b.re, b.im)
    let got = pow(a, b)
    check relErr(got.re, wr) <= UlpTol and relErr(got.im, wi) <= UlpTol

suite "MPC oracle — the promoting entry points land on the reference":
  test "csqrt(-1) is MPC's sqrt(-1+0i)":
    let (wr, wi) = mpcRef("sqrt", RefPrec, -1.0, 0.0)
    let got = csqrt(-1.0)
    check got.re == wr and got.im == wi
  test "cln(-1) is MPC's log(-1+0i)":
    let (wr, wi) = mpcRef("log", RefPrec, -1.0, 0.0)
    let got = cln(-1.0)
    check relErr(got.re, wr) <= UlpTol or (got.re == 0.0 and wr == 0.0)
    check relErr(got.im, wi) <= UlpTol

suite "MPC oracle — exact error mode":
  test "the reported error of a correct candidate is a few ulps at most":
    for (re, im) in Points:
      let got = sqrt(complex(re, im))
      let (absErr, relE) = mpcErr("sqrt", got.re, got.im, re, im)
      check relE <= UlpTol
      check absErr >= 0.0
  test "a deliberately wrong candidate is reported as wrong":
    # Guards the oracle itself: a bridge that always reported zero error would
    # make every test above pass vacuously.
    let (_, relE) = mpcErr("sqrt", 1.0, 1.0, -1.0, 0.0)
    check relE > 0.1
