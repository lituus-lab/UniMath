# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniMath

suite "native float64 mathematics":
  test "roots, logarithms and exponentials follow native semantics":
    check sqrt(4.0) == 2.0
    # libm cbrt is not correctly rounded everywhere: glibc returns 3.0 + 1 ulp.
    check abs(cbrt(27.0) - 3.0) < 1e-15
    check sqrt(-1.0).isNaN
    check ln(1.0) == 0.0
    check ln(0.0) == -Inf
    check abs(log10(1000.0) - 3.0) < 1e-15
    check log2(8.0) == 3.0
    check log(8.0, 2.0) == 3.0
    check abs(log1p(1e-16) - 1e-16) < 1e-31
    check abs(exp(1.0) - E) < 1e-15
    check abs(expm1(1e-16) - 1e-16) < 1e-31
    check pow(2.0, 10.0) == 1024.0

  test "trigonometry exposes scalar and paired operations":
    check sin(0.0) == 0.0
    check cos(0.0) == 1.0
    let pair = sinCos(PI / 4.0)
    # Not `==`: sinCos binds its argument to a runtime value and calls libm,
    # while `sin(PI / 4.0)` hands the compiler a constant it is free to fold at
    # correctly-rounded precision. The two answers differ by one ulp on
    # Windows -- 0.7071067811865476 against 0.7071067811865475.
    check abs(pair.sin - sin(PI / 4.0)) < 1e-15
    check abs(pair.cos - cos(PI / 4.0)) < 1e-15
    check abs(pair.sin * pair.sin + pair.cos * pair.cos - 1.0) < 1e-15
    check abs(arctan2(1.0, 0.0) - PI / 2.0) < 1e-15
    check abs(tan(PI / 4.0) - 1.0) < 1e-15
    check abs(arcsin(1.0) - PI / 2.0) < 1e-15
    check arccos(1.0) == 0.0
    check arctan(0.0) == 0.0

  test "hyperbolic, special and rounding families are available":
    check sinh(0.0) == 0.0
    check cosh(0.0) == 1.0
    check tanh(0.0) == 0.0
    check arcsinh(0.0) == 0.0
    check arccosh(1.0) == 0.0
    check arctanh(0.0) == 0.0
    check erf(0.0) == 0.0
    check erfc(0.0) == 1.0
    check abs(gamma(5.0) - 24.0) < 1e-14
    check floor(1.75) == 1.0
    check ceil(1.25) == 2.0
    check trunc(-1.75) == -1.0
    check round(1.5) == 2.0
    check copySign(1.0, -0.0) == -1.0
    check nextUp(1.0) > 1.0
    check degToRad(180.0) == PI
    check radToDeg(PI) == 180.0
    let zeroParts = splitDecimal(-0.0)
    check classify(zeroParts.intpart) == fcNegZero
    check classify(zeroParts.floatpart) == fcNegZero

  test "hypotenuse scaling avoids intermediate overflow":
    check hypot(3.0, 4.0) == 5.0
    let large = hypot(1e308, 1e308)
    check classify(large) == fcNormal
    check large > 1e308

  test "non-finite inputs retain IEEE classifications":
    check exp(Inf) == Inf
    check ln(Inf) == Inf
    check hypot(Inf, 1.0) == Inf
    check sin(Inf).isNaN
    check cos(NaN).isNaN
    check arctan2(NaN, 1.0).isNaN
