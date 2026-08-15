# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## `math_router` dispatch tests over `Fixed[int64, 32]` (Q32.32). `Auto`
## selects the fixed-point kernels: CORDIC for `sin`/`cos`/`atan2`, Chebyshev
## for `tan`, hyperbolic-CORDIC for `exp`, exponential identities for the
## hyperbolics, Newton for `sqrt`, and range-reduced Taylor for `ln`.
import std/[unittest, math]
import UniMath
import UniMath/math_router

type F = Fixed[int64, 32]

proc f(v: float64): F = toFixed[int64, 32](v)

suite "math_router — trig (Auto = CORDIC/Chebyshev)":
  test "sin/cos zeros":
    check abs(toFloat64(sin(f(0.0)))) < 1e-3
    check abs(toFloat64(cos(f(0.0))) - 1.0) < 1e-3
  test "sin/cos values":
    check abs(toFloat64(sin(f(0.5))) - sin(0.5)) < 1e-3
    check abs(toFloat64(cos(f(0.5))) - cos(0.5)) < 1e-3
  test "tan (Chebyshev)":
    check abs(toFloat64(tan(f(0.0)))) < 1e-3
    check abs(toFloat64(tan(f(0.5))) - tan(0.5)) < 1e-3
  test "tan reduces beyond the Chebyshev domain":
    # tanChebyshev fits [-pi/4, pi/4]; without reduction the router returned
    # the raw polynomial past 0.785, including the wrong sign after pi/2.
    for v in [0.7, 1.0, 1.2, -1.2, 2.0, 3.5]:
      check abs(toFloat64(tan(f(v))) - tan(v)) < 2e-3

suite "math_router — inverse trig":
  test "atan2 quadrants":
    check abs(toFloat64(atan2(f(1.0), f(1.0))) - PI / 4) < 1e-3
    check abs(toFloat64(atan2(f(0.0), f(1.0)))) < 1e-3
  test "atan":
    check abs(toFloat64(atan(f(1.0))) - PI / 4) < 1e-3

suite "math_router — exp/ln":
  test "exp(0)=1, exp(1)=e (CORDIC in-domain)":
    check abs(toFloat64(exp(f(0.0))) - 1.0) < 1e-3
    check abs(toFloat64(exp(f(1.0))) - exp(1.0)) < 1e-3
  test "ln(1)=0, ln(1.5) (Taylor near 1)":
    check abs(toFloat64(ln(f(1.0)))) < 1e-6
    check abs(toFloat64(ln(f(1.5))) - ln(1.5)) < 1e-5
  test "ln range reduction remains accurate far from 1":
    for x in [6.0, 10.0, 100.0, 1000.0]:
      check abs(toFloat64(ln(f(x))) - ln(x)) < 3e-8

suite "math_router — sqrt (Newton)":
  test "sqrt":
    check abs(toFloat64(sqrt(f(4.0))) - 2.0) < 1e-6
    check abs(toFloat64(sqrt(f(2.0))) - sqrt(2.0)) < 1e-6
    check abs(toFloat64(sqrt(f(0.0)))) < 1e-6

suite "math_router — hyperbolic":
  test "zeros":
    check abs(toFloat64(sinh(f(0.0)))) < 1e-3
    check abs(toFloat64(cosh(f(0.0))) - 1.0) < 1e-3
    check abs(toFloat64(tanh(f(0.0)))) < 1e-3
  test "values |x| <= 1":
    check abs(toFloat64(sinh(f(1.0))) - sinh(1.0)) < 1e-3
    check abs(toFloat64(cosh(f(1.0))) - cosh(1.0)) < 1e-3
    check abs(toFloat64(tanh(f(1.0))) - tanh(1.0)) < 1e-3
  test "tanh has no CORDIC convergence limit":
    for x in [1.25, 2.0, 3.0, -3.0]:
      check abs(toFloat64(tanh(f(x))) - tanh(x)) < 2e-8
  test "sinh and cosh scale before exponentiation":
    for x in [22.0, -22.0]:
      check abs(toFloat64(sinh(f(x))) - sinh(x)) / sinh(22.0) < 2e-7
      check abs(toFloat64(cosh(f(x))) - cosh(x)) / cosh(22.0) < 2e-7

suite "math_router — special":
  test "factorial(5) = 120":
    check toFloat64(math_router.factorial[int64, 32](5)) == 120.0
  test "besselJ0(0) = 1":
    check abs(toFloat64(math_router.besselJ0(f(0.0))) - 1.0) < 1e-3

suite "math_router — domain guards":
  test "ln(0) raises ValueError":
    expect ValueError: discard ln(f(0.0))
  test "ln(negative) raises ValueError":
    expect ValueError: discard ln(f(-1.0))
  test "pow(base<=0) returns default":
    check toFloat64(pow(f(0.0), f(5.0))) == 0.0
  test "asin(|x|>1) returns default":
    check toFloat64(asin(f(2.0))) == 0.0
  test "atanh(|x|>=1) returns default":
    check toFloat64(atanh(f(1.0))) == 0.0
