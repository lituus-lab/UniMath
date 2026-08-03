# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Special functions: orthogonal polynomials, the error function, the Gamma
## function and integer combinatorics, and the Bessel `J0`. Polynomials are
## exercised over float64 and BigFloat; `erf`/`gamma`/`besselJ0` over float64
## (the self-contained paths). The `erf`/`besselJ0` series use the term-ratio
## recurrence, so `terms = 30` is overflow-free past the old `21!` int64 cliff.
import std/[unittest, math]
import UniMath
import UniMath/special/gamma

proc sqrtF64(v: float64): float64 {.noSideEffect.} = math.sqrt(v)

suite "Orthogonal polynomials — float64":
  test "Chebyshev T":
    check chebyshevT(0, 0.5) == 1.0
    check chebyshevT(1, 0.5) == 0.5
    check abs(chebyshevT(2, 0.5) - (-0.5)) < 1e-12
    check abs(chebyshevT(3, 0.5) - (-1.0)) < 1e-12
  test "Chebyshev U":
    check chebyshevU(0, 0.5) == 1.0
    check chebyshevU(1, 0.5) == 1.0
    check abs(chebyshevU(2, 0.5) - 0.0) < 1e-12
  test "Legendre P":
    check legendreP(0, 0.5) == 1.0
    check legendreP(1, 0.5) == 0.5
    check abs(legendreP(2, 0.5) - (-0.125)) < 1e-12
    check abs(legendreP(3, 0.5) - (-0.4375)) < 1e-12
  test "Hermite H":
    check hermiteH(0, 0.5) == 1.0
    check hermiteH(1, 0.5) == 1.0
    check abs(hermiteH(2, 0.5) - (-1.0)) < 1e-12
    check abs(hermiteH(3, 0.5) - (-5.0)) < 1e-12

suite "Orthogonal polynomials — BigFloat":
  test "Chebyshev T3(0.5) = -1":
    let x = initBigFloat(0.5, 128)
    check abs(toFloat64(chebyshevT(3, x)) - (-1.0)) < 1e-10
  test "Legendre P2(0.5) = -0.125":
    let x = initBigFloat(0.5, 128)
    check abs(toFloat64(legendreP(2, x)) - (-0.125)) < 1e-10

suite "Error function — Taylor (float64)":
  test "erf(0) == 0":
    check erfTaylor(0.0, 15, PI, sqrtF64) == 0.0
  test "erf(0.5) ~ 0.5205":
    let r = erfTaylor(0.5, 15, PI, sqrtF64)
    check r > 0.50 and r < 0.55
  test "terms=30 overflow-free (past the 21! int64 cliff)":
    var raised = false
    let r = block:
      try:
        erfTaylor(0.5, 30, PI, sqrtF64)
      except OverflowDefect:
        raised = true
        NaN
    check not raised
    check classify(r) != fcNaN
    check r > 0.50 and r < 0.55

suite "Gamma — Lanczos (float64)":
  test "Gamma(1)=1, Gamma(2)=1, Gamma(5)=24":
    check abs(gammaLanczosFloat(1.0) - 1.0) < 1e-10
    check abs(gammaLanczosFloat(2.0) - 1.0) < 1e-10
    check abs(gammaLanczosFloat(5.0) - 24.0) < 1e-9
  test "Gamma(1/2) = sqrt(pi)":
    check abs(gammaLanczosFloat(0.5) - sqrt(PI)) < 1e-10
  test "reflection Gamma(-1/2) = -2*sqrt(pi)":
    check abs(gammaLanczosFloat(-0.5) - (-2.0 * sqrt(PI))) < 1e-9
  test "recurrence lift for 0 < x < 1 (no infinite recursion)":
    check abs(gammaLanczosFloat(0.25) - 3.625609908221908) < 1e-8
  test "poles at non-positive integers raise":
    expect ValueError:
      discard gammaLanczosFloat(0.0)
    expect ValueError:
      discard gammaLanczosFloat(-1.0)
    expect ValueError:
      discard gammaLanczosFloat(-3.0)

suite "Integer combinatorics":
  test "factorial":
    check gamma.factorial[float64](0) == 1.0
    check gamma.factorial[float64](5) == 120.0
    check gamma.factorial[float64](-1) == 0.0
    check abs(toFloat64(gamma.factorial[BigFloat](5)) - 120.0) < 1e-10
  test "doubleFactorial":
    check doubleFactorial[float64](6) == 48.0
    check doubleFactorial[float64](7) == 105.0
    check doubleFactorial[float64](0) == 1.0
  test "binomial":
    check binomial[float64](5, 2) == 10.0
    check binomial[float64](5, 0) == 1.0
    check binomial[float64](5, 5) == 1.0
    check binomial[float64](5, 6) == 0.0
    check binomial[float64](5, -1) == 0.0

suite "Bessel J0 — power series (float64)":
  test "J0(0) == 1":
    check besselJ0(0.0) == 1.0
  test "J0(0.5) ~ 0.9385":
    let r = besselJ0(0.5, 15)
    check r > 0.90 and r < 0.96
  test "terms=30 overflow-free":
    var raised = false
    let r = block:
      try:
        besselJ0(0.5, 30)
      except OverflowDefect:
        raised = true
        NaN
    check not raised
    check classify(r) != fcNaN
    check r > 0.90 and r < 0.96
