# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Interval transcendentals. Monotonic functions (exp, ln, arctan) evaluate at
## the endpoints and widen by two ulps for the host libm, or one ulp under
## `-d:correctlyRoundedLibm`; `sqrt` is correctly rounded (one step).
## `sin`/`cos` scan maxima and minima independently. `tan` widens to
## `(-Inf, Inf)` across a singularity. `pow` is
## the integer-exponent form (even/odd/negative parity). `ln` raises
## `ValueError` when the lower bound is non-positive.
import std/math
import contracts
import ./interval_type
import ./arithmetic

const
  ArgLimit* = 1e12 ## Compatibility threshold; critical scans now use a margin.

func down1*(x: float64): float64 {.contractual, inline.} =
  body: nextDown(x)
func up1*(x: float64): float64 {.contractual, inline.} =
  body: nextUp(x)
func down2*(x: float64): float64 {.contractual, inline.} =
  body: nextDown(nextDown(x))
func up2*(x: float64): float64 {.contractual, inline.} =
  body: nextUp(nextUp(x))

func downTrans(x: float64): float64 {.contractual, inline.} =
  body:
    when defined(correctlyRoundedLibm): down1(x)
    else: down2(x)

func upTrans(x: float64): float64 {.contractual, inline.} =
  body:
    when defined(correctlyRoundedLibm): up1(x)
    else: up2(x)

func exp*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    result.lower = max(0.0, downTrans(exp(a.lower)))
    result.upper = upTrans(exp(a.upper))

func ln*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if a.lower <= 0.0: raise newException(ValueError,
        "ln of an interval with a non-positive lower bound")
    result.lower = downTrans(ln(a.lower))
    result.upper = upTrans(ln(a.upper))

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
      result.lower = downTrans(`pow`(m.lower, float(n)))
      result.upper = upTrans(`pow`(m.upper, float(n)))
    else:
      result.lower = downTrans(`pow`(a.lower, float(n)))
      result.upper = upTrans(`pow`(a.upper, float(n)))

func containsCritical(lo, hi, offset, period: float64): bool {.contractual.} =
  ## True if the interval `[lo, hi]` contains a critical point of the form
  ## `offset + k*period` (the extrema of sin/cos).
  body:
    if period <= 0.0: return false
    let
      kLow = ceil((lo - offset) / period)
      first = offset + kLow * period
      scale = max(1.0, max(abs(lo), max(abs(hi), abs(first))))
      margin = 8.0 * 2.220446049250313e-16 * scale
    margin >= period or first <= hi + margin

func sin*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if a.upper - a.lower >= 2.0 * PI:
      result = initInterval(-1.0, 1.0)
    else:
      let
        sl = downTrans(sin(a.lower))
        su = upTrans(sin(a.upper))
      result.lower = min(sl, su)
      result.upper = max(sl, su)
      if containsCritical(a.lower, a.upper, PI / 2.0, 2.0 * PI):
        result.upper = 1.0
      if containsCritical(a.lower, a.upper, -PI / 2.0, 2.0 * PI):
        result.lower = -1.0

func cos*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if a.upper - a.lower >= 2.0 * PI:
      result = initInterval(-1.0, 1.0)
    else:
      let
        cl = downTrans(cos(a.lower))
        cu = upTrans(cos(a.upper))
      result.lower = min(cl, cu)
      result.upper = max(cl, cu)
      if containsCritical(a.lower, a.upper, 0.0, 2.0 * PI):
        result.upper = 1.0
      if containsCritical(a.lower, a.upper, PI, 2.0 * PI):
        result.lower = -1.0

func tan*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if containsCritical(a.lower, a.upper, PI / 2.0, PI):
      result = initInterval(-Inf, Inf)
    else:
      result.lower = downTrans(tan(a.lower))
      result.upper = upTrans(tan(a.upper))

func arctan*(a: Interval[float64]): Interval[float64] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    result.lower = downTrans(arctan(a.lower))
    result.upper = upTrans(arctan(a.upper))

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
      result.lower = downTrans(min(min(a1, a2), min(a3, a4)))
      result.upper = upTrans(max(max(a1, a2), max(a3, a4)))
