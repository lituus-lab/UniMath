# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Interval tests: pure-Nim nextafter bit-exactness, construction, set ops,
## directed-rounding arithmetic, comparison, and transcendentals. Domain errors
## use `expect(Defect)` for `DivByZeroDefect` and `expect(Exception)` for
## `ValueError` (a `CatchableError`, not a `Defect`).
import std/[unittest, math]
import UniMath

suite "nextafter":
  test "x == y returns y":
    check nextafterF64(1.0, 1.0) == 1.0
  test "toward larger":
    let r = nextafterF64(1.0, 2.0)
    check r > 1.0 and r < 2.0
  test "toward smaller":
    let r = nextafterF64(1.0, 0.0)
    check r < 1.0 and r > 0.0
  test "from zero toward positive":
    check nextafterF64(0.0, 1.0) > 0.0
  test "NaN propagates":
    let n = nextafterF64(NaN, 1.0)
    check n != n
  test "nextUp / nextDown":
    check nextUp(1.0) > 1.0
    check nextDown(1.0) < 1.0
  test "float32 variant":
    check nextafterF32(1.0'f32, 2.0'f32) > 1.0'f32

suite "construction":
  test "two-arg":
    let i = initInterval(1.0, 2.0)
    check i.lower == 1.0 and i.upper == 2.0
  test "degenerate":
    let i = initInterval(3.0)
    check i.lower == 3.0 and i.upper == 3.0
  test "isValid":
    check initInterval(1.0, 2.0).isValid
    check not initInterval(2.0, 1.0).isValid
  test "width / midpoint":
    check width(initInterval(1.0, 3.0)) == 2.0
    check midpoint(initInterval(1.0, 3.0)) == 2.0
  test "isUncertain / certaintySign":
    check isUncertain(initInterval(-1.0, 1.0))
    check not isUncertain(initInterval(2.0, 3.0))
    check certaintySign(initInterval(2.0, 3.0)) == 1
    check certaintySign(initInterval(-3.0, -2.0)) == -1
    check certaintySign(initInterval(-1.0, 1.0)) == 0
  test "$ is [lower, upper]":
    check $initInterval(1.0, 2.5) == "[1.0, 2.5]"

suite "set ops":
  test "contains point":
    check contains(initInterval(1.0, 3.0), 2.0)
    check not contains(initInterval(1.0, 3.0), 4.0)
  test "contains interval":
    check contains(initInterval(1.0, 4.0), initInterval(2.0, 3.0))
    check not contains(initInterval(1.0, 4.0), initInterval(2.0, 5.0))
  test "overlaps":
    check overlaps(initInterval(1.0, 3.0), initInterval(2.0, 4.0))
    check not overlaps(initInterval(1.0, 2.0), initInterval(3.0, 4.0))
  test "hull":
    let h = hull(initInterval(1.0, 2.0), initInterval(4.0, 5.0))
    check h.lower == 1.0 and h.upper == 5.0
  test "intersect":
    let i = intersect(initInterval(1.0, 3.0), initInterval(2.0, 4.0))
    check i.lower == 2.0 and i.upper == 3.0

suite "arithmetic":
  test "add":
    let r = initInterval(1.0, 2.0) + initInterval(3.0, 4.0)
    check r.lower <= 4.0 and r.upper >= 6.0
    check r.lower <= r.upper
  test "sub":
    let r = initInterval(1.0, 2.0) - initInterval(3.0, 4.0)
    check r.lower <= -3.0 and r.upper >= -2.0
  test "mul positive":
    let r = initInterval(2.0, 3.0) * initInterval(4.0, 5.0)
    check r.lower <= 8.0 and r.upper >= 15.0
  test "mul mixed sign":
    let r = initInterval(-2.0, 3.0) * initInterval(-4.0, 5.0)
    check r.lower <= -12.0 and r.upper >= 15.0
  test "div":
    let r = initInterval(6.0, 8.0) / initInterval(2.0, 4.0)
    check r.lower <= 1.5 and r.upper >= 4.0
  test "div by uncertain raises":
    expect(Defect): discard initInterval(1.0, 2.0) / initInterval(-1.0, 1.0)
  test "unary neg":
    let r = -initInterval(1.0, 2.0)
    check r.lower <= -2.0 and r.upper >= -1.0
  test "abs all positive":
    let r = abs(initInterval(2.0, 3.0))
    check r.lower <= 2.0 and r.upper >= 3.0
  test "abs all negative":
    let r = abs(initInterval(-3.0, -2.0))
    check r.lower <= 2.0 and r.upper >= 3.0
  test "abs straddles zero":
    let r = abs(initInterval(-2.0, 3.0))
    check r.lower == 0.0 and r.upper >= 3.0
  test "sqrt":
    let r = sqrt(initInterval(4.0, 9.0))
    check r.lower <= 2.0 and r.upper >= 3.0
  test "sqrt negative lower raises":
    expect(Exception): discard sqrt(initInterval(-1.0, 4.0))

suite "comparison":
  test "eq is set equality and reflexive":
    check initInterval(2.0, 2.0) == initInterval(2.0, 2.0)
    check initInterval(1.0, 2.0) == initInterval(1.0, 2.0)
    check not (initInterval(1.0, 2.0) == initInterval(1.0, 3.0))
  test "certainlyEqual only degenerate and equal":
    check certainlyEqual(initInterval(2.0, 2.0), initInterval(2.0, 2.0))
    check not certainlyEqual(initInterval(1.0, 2.0), initInterval(1.0, 2.0))
  test "arctan2 encloses the negative-axis branch cut":
    # The box is left of the axis and straddles y = 0, so it contains
    # atan2(0, -1) == PI even though it does not enclose the origin.
    let r = arctan2(initInterval(-1.0, 1.0), initInterval(-2.0, -1.0))
    check r.lower <= -PI and r.upper >= PI
  test "certainly less":
    check initInterval(1.0, 2.0) < initInterval(3.0, 4.0)
    check not (initInterval(1.0, 3.0) < initInterval(2.0, 4.0))
  test "certainly at-or-below":
    check initInterval(1.0, 2.0) <= initInterval(2.0, 4.0)

suite "transcendentals":
  test "exp":
    let r = exp(initInterval(0.0, 1.0))
    check r.lower <= 1.0 and r.upper >= E
  test "ln":
    let r = ln(initInterval(1.0, E))
    check r.lower <= 0.0 and r.upper >= 1.0
  test "ln non-positive raises":
    expect(Exception): discard ln(initInterval(0.0, 1.0))
    expect(Exception): discard ln(initInterval(-1.0, 1.0))
  test "pow even":
    let r = pow(initInterval(-2.0, 3.0), 2)
    check r.lower <= 0.0 and r.upper >= 9.0
  test "pow odd":
    let r = pow(initInterval(-2.0, 3.0), 3)
    check r.lower <= -8.0 and r.upper >= 27.0
  test "pow zero is one":
    let r = pow(initInterval(-2.0, 3.0), 0)
    check r.lower == 1.0 and r.upper == 1.0
  test "pow negative exponent":
    let r = pow(initInterval(2.0, 4.0), -1)
    check r.lower <= 0.25 and r.upper >= 0.5
  test "pow neg exp of uncertain raises":
    expect(Defect): discard pow(initInterval(-1.0, 1.0), -1)
  test "sin monotonic region":
    let r = sin(initInterval(0.0, 0.5))
    check r.lower <= 0.0 and r.upper >= sin(0.5)
  test "sin distinguishes a maximum from a minimum":
    let r = sin(initInterval(0.0, 2.0))
    check r.lower <= 0.0 and r.lower > -1.0
    check r.upper == 1.0
  test "sin enclosing both extrema is full":
    let r = sin(initInterval(-PI / 2.0, PI / 2.0))
    check r.lower == -1.0 and r.upper == 1.0
  test "cos distinguishes a maximum from a minimum":
    let r = cos(initInterval(-0.5, 0.5))
    check r.lower <= cos(0.5) and r.lower > -1.0
    check r.upper == 1.0
  test "correctly-rounded backend widens by one ulp":
    let r = exp(initInterval(0.0, 0.0))
    when defined(correctlyRoundedLibm):
      check r.lower == nextDown(1.0)
      check r.upper == nextUp(1.0)
    else:
      check r.lower == nextDown(nextDown(1.0))
      check r.upper == nextUp(nextUp(1.0))
  test "tan across singularity":
    let r = tan(initInterval(0.0, PI))
    check r.lower == -Inf and r.upper == Inf
  test "arctan":
    let r = arctan(initInterval(-1.0, 1.0))
    check r.lower <= -PI / 4.0 and r.upper >= PI / 4.0
  test "arctan2 enclosing origin is full":
    let r = arctan2(initInterval(-1.0, 1.0), initInterval(-1.0, 1.0))
    check r.lower == -PI and r.upper == PI
