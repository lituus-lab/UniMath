# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## `rational_math` identity and domain tests over `Rational[int64]` (fast,
## int64-bounded — `terms` kept small to avoid `OverflowDefect`). The
## transcendentals are exact per term but truncated, so identities are checked
## via `toFloat64` against a tolerance reflecting the truncation (looser for
## `atan`, which uses the `355/113` pi convergent at ~2.7e-7). One `BigInt`
## case confirms the generic dispatches over the unbounded backend.
import std/[unittest, math]
import UniMath

type R = Rational[int64]

proc r(n, d: int): R = initRational(int64(n), int64(d))

suite "rational_math — sin/cos":
  test "zeros":
    check toFloat64(sin(r(0, 1))) == 0.0
    check toFloat64(cos(r(0, 1))) == 1.0
  test "sin is odd (exact per term)":
    let x = r(1, 4)
    check toFloat64(sin(x) + sin(-x)) == 0.0
  test "cos is even (exact per term)":
    let x = r(1, 4)
    check toFloat64(cos(x) - cos(-x)) == 0.0
  test "sin^2 + cos^2 = 1 (small x, 4 terms)":
    # The identity holds for the exact series; the truncation breaks it by
    # ~x^8, so test small x. 4 terms: denom 7!·d^7, squared fits int64
    # (5 terms overflow the square for d >= 3).
    for d in [4, 5]:
      let x = r(1, d)
      let s = sin(x, 4)
      let c = cos(x, 4)
      check abs(toFloat64(s * s + c * c) - 1.0) < 1e-4

suite "rational_math — exp/ln":
  test "exp(0) = 1, ln(1) = 0":
    check toFloat64(exp(r(0, 1))) == 1.0
    check abs(toFloat64(ln(r(1, 1)))) < 1e-9
  test "exp(x)·exp(-x) = 1":
    # 6 terms: exp(1/d) denom ~ 6!·d^6, product denom ~ (6!·d^6)^2 fits int64
    # (10 terms overflow the product before cross-simplification).
    for d in [2, 3, 4]:
      let x = r(1, d)
      check abs(toFloat64(exp(x, 6) * exp(-x, 6)) - 1.0) < 1e-4
  test "ln(exp(x)) = x (BigInt: compound denom growth overflows int64)":
    let x = initRational(initBigInt(1), initBigInt(4))
    check abs(toFloat64(ln(exp(x, 10), 10)) - 0.25) < 1e-5

suite "rational_math — sqrt":
  test "sqrt(4) = 2":
    check abs(toFloat64(sqrt(r(4, 1))) - 2.0) < 1e-9
  test "sqrt(2)^2 = 2":
    let s = sqrt(r(2, 1))
    check abs(toFloat64(s * s) - 2.0) < 1e-6
  test "sqrt(0) = 0":
    check toFloat64(sqrt(r(0, 1))) == 0.0
  test "BigInt backend dispatches":
    let s = sqrt(initRational(initBigInt(2), initBigInt(1)))
    check abs(toFloat64(s * s) - 2.0) < 1e-6

suite "rational_math — atan/atan2":
  test "atan(small) converges fast":
    # atan(1/3): the Gregory series at |x|<=1/3 needs ~5 terms for 1e-6.
    check abs(toFloat64(atan(r(1, 3))) - math.arctan(1.0 / 3.0)) < 1e-5
  test "atan(|x|>1) range-reduces":
    # atan(2) = pi/2 - atan(1/2); bounded by the 355/113 pi convergent (~2.7e-7).
    check abs(toFloat64(atan(r(2, 1))) - math.arctan(2.0)) < 1e-4
  test "atan is odd":
    let x = r(1, 3)
    check abs(toFloat64(atan(x) + atan(-x))) < 1e-5
  test "atan2 quadrants":
    check abs(toFloat64(atan2(r(1, 1), r(3, 1))) - math.arctan(1.0 / 3.0)) < 1e-5
    check abs(toFloat64(atan2(r(1, 1), r(0, 1))) - PI / 2) < 1e-6 # halfPi = 355/226
    check abs(toFloat64(atan2(r(0, 1), r(-1, 1))) - PI) < 1e-6 # pi = 355/113
    check toFloat64(atan2(r(0, 1), r(0, 1))) == 0.0

suite "rational_math — hyperbolic":
  test "cosh(0) = 1, sinh(0) = 0, tanh(0) = 0":
    check toFloat64(cosh(r(0, 1))) == 1.0
    check toFloat64(sinh(r(0, 1))) == 0.0
    check toFloat64(tanh(r(0, 1))) == 0.0
  test "cosh/sinh match float64 (no squaring: overflows int64)":
    let x = r(1, 4)
    check abs(toFloat64(cosh(x, 6)) - math.cosh(0.25)) < 1e-5
    check abs(toFloat64(sinh(x, 6)) - math.sinh(0.25)) < 1e-5
  test "cosh^2 - sinh^2 = 1 (BigInt backend, unbounded)":
    let x = initRational(initBigInt(1), initBigInt(4))
    let sh = sinh(x, 6)
    let ch = cosh(x, 6)
    check abs(toFloat64(ch * ch - sh * sh) - 1.0) < 1e-6

suite "rational_math — special":
  test "factorial(5) = 120":
    check toFloat64(factorial[int64](5)) == 120.0
  test "erf (BigInt backend: sqrt(pi) overflows int64)":
    let pi = initRational(initBigInt(355), initBigInt(113))
    let zero = initRational(initBigInt(0), initBigInt(1))
    let half = initRational(initBigInt(1), initBigInt(2))
    check toFloat64(erf(zero, 10, pi)) == 0.0
    check abs(toFloat64(erf(half, 10, pi)) - 0.5204998778) < 1e-4
  test "besselJ0(0) = 1":
    check toFloat64(besselJ0(r(0, 1))) == 1.0

suite "rational_math — domain guards":
  test "ln(0) raises ValueError":
    expect ValueError: discard ln(r(0, 1))
  test "ln(negative) raises ValueError":
    expect ValueError: discard ln(r(-1, 1))
  test "pow(negative, fractional) raises ValueError":
    expect ValueError: discard pow(r(-1, 1), r(1, 2))

suite "rational_math domain guards":
  test "sqrt of a negative rational raises":
    expect(ValueError):
      discard sqrt(initRational(-4, 1))
  test "erf reaches the bounded backend with a smaller sqrt budget":
    # The default budget suits BigInt; int64 needs sqrtIters = 1, which still
    # lands within 1e-4 of erf(0.5) = 0.5205 because truncation dominates.
    let r = erf(initRational(1'i64, 2'i64), 10, initRational(355'i64, 113'i64), 1)
    check abs(toFloat64(r) - 0.5205) < 1e-3
  test "sqrt iteration budget on int64 follows operand magnitude":
    # Not perfect-squareness: 2/1 sustains 5 steps, 355/113 overflows at 4.
    check abs(toFloat64(sqrt(initRational(2'i64, 1'i64), 5)) - 1.41421356) < 1e-6
    expect(Defect):
      discard sqrt(initRational(355'i64, 113'i64), 4)
