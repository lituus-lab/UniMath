# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## `float_math` identity and domain tests. The transcendentals are approximate
## (range-reduced Taylor/Newton cores), so these check structural identities —
## `sin^2 + cos^2 = 1`, `exp(x)·exp(-x) = 1`, `ln(exp(x)) = x`, `sqrt(x)^2 = x`,
## `arctan(1) = pi/4` — against a float64 tolerance (the `BigFloat` result is
## reduced to its top 53 bits by `toFloat64`). Exact cases (`sin(0)`, `exp(0)`,
## `pow(_, 0)`) use `==`. Domain guards (`ln`/`pow`/`tan` singularities) assert
## the body `raise` survives.
import std/[unittest, math]
import UniMath

const Tol = 1e-12
const Terms = 30 # 30 terms: ~100 correct bits > float64 53

proc bf(x: float64, prec = 256): BigFloat = initBigFloat(x, prec)

suite "float_math — sin/cos":
  test "zeros":
    check toFloat64(sin(bf(0.0), Terms)) == 0.0
    check toFloat64(cos(bf(0.0), Terms)) == 1.0
  test "sin^2 + cos^2 = 1":
    for x in [0.3, 0.7, 1.1, 2.0, 3.0, -0.9]:
      let s = sin(bf(x), Terms)
      let c = cos(bf(x), Terms)
      check abs(toFloat64(s * s + c * c) - 1.0) < Tol
  test "sin is odd, cos is even":
    for x in [0.5, 1.0, 2.0]:
      check abs(toFloat64(sin(bf(x), Terms) + sin(bf(-x), Terms))) < Tol
      check abs(toFloat64(cos(bf(x), Terms) - cos(bf(-x), Terms))) < Tol
  test "sin(pi/2) = 1, cos(pi/2) = 0":
    check abs(toFloat64(sin(bf(PI / 2), Terms)) - 1.0) < Tol
    check abs(toFloat64(cos(bf(PI / 2), Terms))) < Tol
  test "large argument reduces (10 + 0.5)":
    let big = bf(10.0 * PI + 0.5)
    check abs(toFloat64(sin(big, Terms)) - sin(0.5)) < Tol

suite "float_math — exp/ln":
  test "exp(0) = 1, ln(1) = 0":
    check toFloat64(exp(bf(0.0), Terms)) == 1.0
    check abs(toFloat64(ln(bf(1.0), Terms))) < Tol
  test "exp(x)·exp(-x) = 1":
    for x in [0.5, 1.0, 2.0, 5.0, -3.0]:
      check abs(toFloat64(exp(bf(x), Terms) * exp(bf(-x), Terms)) - 1.0) < Tol
  test "ln(exp(x)) = x":
    for x in [0.5, 1.0, 2.0, -1.0]:
      check abs(toFloat64(ln(exp(bf(x), Terms), Terms)) - x) < Tol
  test "ln(2) and exp(1)":
    check abs(toFloat64(ln(bf(2.0), Terms)) - ln(2.0)) < Tol
    check abs(toFloat64(exp(bf(1.0), Terms)) - E) < Tol
  test "large exp by scaling (exp(20))":
    check abs(toFloat64(exp(bf(20.0), Terms)) - exp(20.0)) < Tol * exp(20.0)

suite "float_math — sqrt":
  test "sqrt(x)^2 = x":
    for x in [2.0, 3.0, 4.0, 9.0, 0.25]:
      let r = sqrt(bf(x))
      check abs(toFloat64(r * r) - x) < Tol
  test "sqrt(4) = 2":
    check abs(toFloat64(sqrt(bf(4.0))) - 2.0) < Tol

suite "float_math — tan":
  test "tan(0) = 0":
    check toFloat64(tan(bf(0.0), Terms)) == 0.0
  test "tan = sin/cos":
    for x in [0.3, 0.7, 1.0]:
      let t = toFloat64(tan(bf(x), Terms))
      let s = toFloat64(sin(bf(x), Terms))
      let c = toFloat64(cos(bf(x), Terms))
      check abs(t - s / c) < Tol

suite "float_math — pow":
  test "integer exponent":
    check toFloat64(pow(bf(2.0), 10)) == 1024.0
    check toFloat64(pow(bf(3.0), 0)) == 1.0
    check abs(toFloat64(pow(bf(2.0), -2)) - 0.25) < Tol
  test "real exponent (2^0.5 = sqrt(2))":
    check abs(toFloat64(pow(bf(2.0), bf(0.5), Terms)) - sqrt(2.0)) < Tol

suite "float_math — arctan/arctan2":
  test "arctan(0) = 0, arctan(1) = pi/4":
    check toFloat64(arctan(bf(0.0), Terms)) == 0.0
    check abs(toFloat64(arctan(bf(1.0), Terms)) - PI / 4) < Tol
  test "arctan is odd":
    for x in [0.5, 1.0, 2.0]:
      check abs(toFloat64(arctan(bf(x), Terms) + arctan(bf(-x), Terms))) < Tol
  test "arctan(tan(pi/8)+) reduction":
    check abs(toFloat64(arctan(bf(2.0), Terms)) - arctan(2.0)) < Tol
  test "arctan2 quadrants":
    check abs(toFloat64(arctan2(bf(1.0), bf(1.0), Terms)) - PI / 4) < Tol
    check abs(toFloat64(arctan2(bf(1.0), bf(0.0), Terms)) - PI / 2) < Tol
    check abs(toFloat64(arctan2(bf(0.0), bf(-1.0), Terms)) - PI) < Tol
    check toFloat64(arctan2(bf(0.0), bf(0.0), Terms)) == 0.0

suite "float_math — domain guards":
  test "ln(0) raises ValueError":
    expect ValueError: discard ln(bf(0.0), Terms)
  test "ln(negative) raises ValueError":
    expect ValueError: discard ln(bf(-1.0), Terms)
  test "pow(negative, fractional) raises ValueError":
    expect ValueError: discard pow(bf(-1.0), bf(0.5), Terms)
  test "tan(pi/2) is large (cos ~ 0, not exactly zero)":
    # cos(pi/2) is a tiny nonzero from the Taylor approximation, so the
    # DivByZeroDefect guard (exact-zero cos) does not fire; tan returns a
    # large value, consistent with the working precision.
    check abs(toFloat64(tan(bf(PI / 2), Terms))) > 1.0e10
