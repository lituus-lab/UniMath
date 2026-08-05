# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Interval transcendentals. Monotonic functions (exp, ln, arctan) evaluate at
## the endpoints and widen by `down2`/`up2` (libm is not correctly rounded, so a
## two-ulp enclosure is the safe bound); `sqrt` is correctly rounded (one step).
## `sin`/`cos` scan for critical points (extrema) inside the interval and fall
## back to the full `[-1, 1]` enclosure when the argument is too large to scan
## (`ArgLimit`); `tan` widens to `(-Inf, Inf)` across a singularity. `pow` is
## the integer-exponent form (even/odd/negative parity). `ln` raises
## `ValueError` when the lower bound is non-positive.
import std/math
import contracts
import ./interval_type
import ./arithmetic

const
  ArgLimit* = 1e12 ## Beyond this width the trig critical-point scan is skipped.

func down2*(x: float64): float64 {.inline.} = nextDown(nextDown(x))
func up2*(x: float64): float64 {.inline.} = nextUp(nextUp(x))

func exp*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    result.lower = max(0.0, down2(exp(a.lower)))
    result.upper = up2(exp(a.upper))

func ln*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if a.lower <= 0.0: raise newException(ValueError,
        "ln of an interval with a non-positive lower bound")
    result.lower = down2(ln(a.lower))
    result.upper = up2(ln(a.upper))

func pow*(a: Interval[float64], n: int): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if n == 0:
      result = initInterval(1.0, 1.0)
    elif n < 0:
      if isUncertain(a): raise newException(DivByZeroDefect,
          "pow with negative exponent of an interval containing zero")
      let reciprocal = initInterval(1.0, 1.0) / a
      if n == low(int):
        # `-low(int)` is not representable: with overflow checks it raises, and
        # without them it wraps back to `low(int)` and recurses forever. Split
        # the exponent instead.
        result = pow(reciprocal, high(int)) * reciprocal
      else:
        result = pow(reciprocal, -n)
    elif n mod 2 == 0:
      let m = abs(a)
      result.lower = down2(`pow`(m.lower, float(n)))
      result.upper = up2(`pow`(m.upper, float(n)))
    else:
      result.lower = down2(`pow`(a.lower, float(n)))
      result.upper = up2(`pow`(a.upper, float(n)))

func containsCritical(lo, hi, offset, period: float64): bool =
  ## True if the interval `[lo, hi]` contains a critical point of the form
  ## `offset + k*period` (the extrema of sin/cos).
  if period <= 0.0: return false
  let
    kLow = ceil((lo - offset) / period)
    first = offset + kLow * period
  first <= hi

func sin*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if a.upper - a.lower > ArgLimit or a.upper - a.lower >= 2.0 * PI:
      result = initInterval(-1.0, 1.0)
    elif containsCritical(a.lower, a.upper, PI / 2.0, PI):
      result = initInterval(-1.0, 1.0)
    else:
      let
        sl = down2(sin(a.lower))
        su = up2(sin(a.upper))
      result.lower = min(sl, su)
      result.upper = max(sl, su)

func cos*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if a.upper - a.lower > ArgLimit or a.upper - a.lower >= 2.0 * PI:
      result = initInterval(-1.0, 1.0)
    elif containsCritical(a.lower, a.upper, 0.0, PI):
      result = initInterval(-1.0, 1.0)
    else:
      let
        cl = down2(cos(a.lower))
        cu = up2(cos(a.upper))
      result.lower = min(cl, cu)
      result.upper = max(cl, cu)

func tan*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if containsCritical(a.lower, a.upper, PI / 2.0, PI):
      result = initInterval(-Inf, Inf)
    else:
      result.lower = down2(tan(a.lower))
      result.upper = up2(tan(a.upper))

func arctan*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    result.lower = down2(arctan(a.lower))
    result.upper = up2(arctan(a.upper))

func arctan2*(y, x: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    y.lower <= y.upper and x.lower <= x.upper
  ensure:
    result.lower <= result.upper
  body:
    # The four corners of the (x, y) box; the angle range is their min/max,
    # unless the box encloses the origin, in which case the full [-pi, pi].
    # A box strictly left of the axis that straddles y = 0 also crosses the
    # branch cut: x = [-2, -1], y = [-1, 1] has corner angles near +-2.68 but
    # contains atan2(0, -1) == pi, which the corner max would exclude.
    if (x.lower <= 0.0 and x.upper >= 0.0 and
        y.lower <= 0.0 and y.upper >= 0.0) or
       (x.upper < 0.0 and y.lower < 0.0 and y.upper >= 0.0):
      result = initInterval(-PI, PI)
    else:
      let
        a1 = arctan2(y.lower, x.lower)
        a2 = arctan2(y.lower, x.upper)
        a3 = arctan2(y.upper, x.lower)
        a4 = arctan2(y.upper, x.upper)
      result.lower = down2(min(min(a1, a2), min(a3, a4)))
      result.upper = up2(max(max(a1, a2), max(a3, a4)))
