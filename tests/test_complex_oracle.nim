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
  # Small moduli. `sinh` and `cosh` built from `exp` alone cancel here, and a
  # sample that stopped at order 0.1 reported every function as correct while
  # `sin`/`tan`/`sinh`/`tanh` were 400 ulp out near the origin.
  (2.4e-3, -2.7e-3), (-2.2e-4, 1.3e-3), (7.7e-4, -7.3e-4),
  (1.0e-6, 1.0e-6), (-3.0e-8, 2.0e-8), (1.0e-10, -1.0e-10),
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

suite "MPC oracle — the ulp envelope":
  test "every function stays inside two ulp of the reference":
    # A bound, not a tolerance: it fails on a regression rather than absorbing
    # one. The measured maxima over 400 random points spanning 1e-3 to 1e2 in
    # modulus are sqrt 0.79, exp 1.06, sin 1.04, cos 1.06, tan 1.73,
    # sinh 0.86, cosh 0.96, tanh 1.81.
    const Unary = ["sqrt", "exp", "sin", "cos", "tan", "sinh", "cosh", "tanh"]
    for op in Unary:
      for (re, im) in Points:
        let got = case op
          of "sqrt": sqrt(complex(re, im))
          of "exp": exp(complex(re, im))
          of "sin": sin(complex(re, im))
          of "cos": cos(complex(re, im))
          of "tan": tan(complex(re, im))
          of "sinh": sinh(complex(re, im))
          of "cosh": cosh(complex(re, im))
          else: tanh(complex(re, im))
        let (_, rel) = mpcErr(op, got.re, got.im, re, im)
        # One binary64 ulp is at least 2^-53 of the value, so this converts a
        # relative error into a lower bound in ulps -- never flattering.
        let ulp = rel * pow(2.0, 52.0)
        check ulp <= 2.0
        if ulp > 2.0:
          echo op, "(", re, ",", im, ") is ", ulp, " ulp out"

  test "ln holds componentwise against the unit circle, not just in modulus":
    # Re(ln z) = ln|z| tends to zero there while |ln z| does not, so a
    # modulus-relative bound says nothing about it: it read 1.3 ulp while the
    # real part was 4.6e-5 out. Both are asserted here, the real part against
    # MPC's own correctly-rounded component.
    for k in [0, 3, 6, 9, 12]:
      let d = pow(10.0, -float64(k))
      let z = complex((1.0 + d) * cos(0.7), (1.0 + d) * sin(0.7))
      let got = ln(z)
      let (_, rel) = mpcErr("log", got.re, got.im, z.re, z.im)
      check rel * pow(2.0, 52.0) <= 2.0
      let (wr, _) = mpcRef("log", RefPrec, z.re, z.im)
      check relErr(got.re, wr) <= 1e-15

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
