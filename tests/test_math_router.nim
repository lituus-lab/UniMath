# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## `math_router` dispatch tests over `Fixed[int64, 32]` (Q32.32). `Auto`
## selects the fixed-point kernels: CORDIC for `sin`/`cos`/`atan2`, Chebyshev
## for `tan`, hyperbolic-CORDIC for `exp`/`sinh`/`cosh`/`tanh`, Newton for
## `sqrt`, Taylor for `ln`. Tolerances reflect the fixed-point + truncation
## error (CORDIC ~1e-3 on Q32, Taylor/Newton tighter). The hyperbolic and
## `exp` cores converge only for `|z| <= ~1.1182`, so in-domain args are used.
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

suite "math_router — sqrt (Newton)":
  test "sqrt":
    check abs(toFloat64(sqrt(f(4.0))) - 2.0) < 1e-6
    check abs(toFloat64(sqrt(f(2.0))) - sqrt(2.0)) < 1e-6
    check abs(toFloat64(sqrt(f(0.0)))) < 1e-6

suite "math_router — hyperbolic (CORDIC, in-domain)":
  test "zeros":
    check abs(toFloat64(sinh(f(0.0)))) < 1e-3
    check abs(toFloat64(cosh(f(0.0))) - 1.0) < 1e-3
    check abs(toFloat64(tanh(f(0.0)))) < 1e-3
  test "values |x| <= 1":
    check abs(toFloat64(sinh(f(1.0))) - sinh(1.0)) < 1e-3
    check abs(toFloat64(cosh(f(1.0))) - cosh(1.0)) < 1e-3
    check abs(toFloat64(tanh(f(1.0))) - tanh(1.0)) < 1e-3

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
