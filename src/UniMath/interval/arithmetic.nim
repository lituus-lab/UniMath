# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Interval arithmetic with directed rounding. Each binary op widens the result
## with `nextDown`/`nextUp` so the exact value is enclosed; `*` splits the four
## extreme products on the sign quadrants; `/` raises `DivByZeroDefect` when the
## divisor straddles zero. `sqrt` raises `ValueError` on a negative lower bound.
import std/math
import contracts
import ./interval_type

{.push overflowChecks: off.}

func `+`*[T](a, b: Interval[T]): Interval[T] {.contractual, inline.} =
  require:
    a.lower <= a.upper and b.lower <= b.upper
  ensure:
    result.lower <= result.upper
  body:
    result.lower = nextDown(a.lower + b.lower)
    result.upper = nextUp(a.upper + b.upper)

func `-`*[T](a, b: Interval[T]): Interval[T] {.contractual, inline.} =
  require:
    a.lower <= a.upper and b.lower <= b.upper
  ensure:
    result.lower <= result.upper
  body:
    result.lower = nextDown(a.lower - b.upper)
    result.upper = nextUp(a.upper - b.lower)

func `-`*[T](a: Interval[T]): Interval[T] {.contractual, inline.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    result.lower = nextDown(-a.upper)
    result.upper = nextUp(-a.lower)

func `*`*[T](a, b: Interval[T]): Interval[T] {.contractual, inline.} =
  require:
    a.lower <= a.upper and b.lower <= b.upper
  ensure:
    result.lower <= result.upper
  body:
    let
      ll = a.lower * b.lower
      lu = a.lower * b.upper
      ul = a.upper * b.lower
      uu = a.upper * b.upper
      lo = min(min(ll, lu), min(ul, uu))
      hi = max(max(ll, lu), max(ul, uu))
    result.lower = nextDown(lo)
    result.upper = nextUp(hi)

func `/`*[T](a, b: Interval[T]): Interval[T] {.contractual, inline.} =
  require:
    a.lower <= a.upper and b.lower <= b.upper
  ensure:
    result.lower <= result.upper
  body:
    if isUncertain(b): raise newException(DivByZeroDefect,
        "interval division by an interval containing zero")
    let
      bl = if b.lower == 0.0: T(0.0) else: b.lower
      bu = if b.upper == 0.0: T(0.0) else: b.upper
    let
      ll = a.lower / bl
      lu = a.lower / bu
      ul = a.upper / bl
      uu = a.upper / bu
      lo = min(min(ll, lu), min(ul, uu))
      hi = max(max(ll, lu), max(ul, uu))
    result.lower = nextDown(lo)
    result.upper = nextUp(hi)

func abs*[T](a: Interval[T]): Interval[T] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if a.lower >= 0.0:
      result.lower = nextDown(a.lower)
      result.upper = nextUp(a.upper)
    elif a.upper <= 0.0:
      result.lower = nextDown(-a.upper)
      result.upper = nextUp(-a.lower)
    else:
      result.lower = 0.0
      result.upper = nextUp(max(abs(a.lower), abs(a.upper)))

func sqrt*[T](a: Interval[T]): Interval[T] {.contractual.} =
  require:
    a.lower <= a.upper
  ensure:
    result.lower <= result.upper
  body:
    if a.lower < 0.0: raise newException(ValueError,
        "sqrt of an interval with a negative lower bound")
    # `sqrt(0) = 0` exactly; `nextDown(0.0)` is `-5e-324` (negative, wrong for
    # a sqrt lower bound), so pin the zero case and only step down otherwise.
    result.lower = if a.lower == 0.0: 0.0 else: nextDown(sqrt(a.lower))
    result.upper = nextUp(sqrt(a.upper))

{.pop.}
