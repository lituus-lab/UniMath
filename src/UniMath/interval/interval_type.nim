# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Directed-rounding interval type `Interval[T] = object` (lower, upper) and the
## pure-Nim IEEE-754 `nextafter`/`nextUp`/`nextDown` that the directed-rounding
## arithmetic widens with. `nextafter` is bit-exact with libc (no `importc`:
## freestanding-safe). Ensures use only plain comparisons / `min` / `max`
## (recursion doctrine); compiled away under `-d:release`.
import contracts

type
  Interval*[T] = object
    ## Closed interval `[lower, upper]` containing the true value.
    lower*: T
    upper*: T

# ------------------------------------------------------------------------------
# Directed rounding — pure-Nim IEEE-754 nextafter (bit-exact with libc).
# ------------------------------------------------------------------------------

func nextafterF64*(x, y: float64): float64 {.contractual, inline.} =
  ## Next representable neighbor of `x` toward `y`. IEEE-754-2019 §5.3.1:
  ## `x == y` -> `y` (so ±0 yields y's sign); NaN -> NaN; otherwise the
  ## immediate neighbor strictly between `x` and `y`, equal to `y` only when
  ## `y` is that neighbor.
  ensure:
    (x == y and result == y) or
    (x != x and result != result) or (y != y and result != result) or
    (x < y and x < result and result <= y) or
    (y < x and y <= result and result < x)
  body:
    if x == y: return y
    if x != x or y != y: return x + y # NaN
    var ui = cast[uint64](x)
    if (ui and 0x7FFF_FFFF_FFFF_FFFF'u64) == 0: # ±0
      ui = if y < 0.0: 0x8000_0000_0000_0001'u64 else: 0x0000_0000_0000_0001'u64
      return cast[float64](ui)
    let signBit = ui shr 63
    # x > 0: toward zero iff y < x.  x < 0: toward zero iff y > x.
    let towardZero = if signBit == 0: (y < x) else: (y > x)
    if towardZero: ui -= 1'u64 else: ui += 1'u64
    # max double + 1 = +Inf; +Inf - 1 = max finite — falls out of the bit ops.
    return cast[float64](ui)

func nextafterF32*(x, y: float32): float32 {.contractual, inline.} =
  ## IEEE-754 nextafter for float32 — pure Nim, bit-exact with libc.
  ensure:
    (x == y and result == y) or
    (x != x and result != result) or (y != y and result != result) or
    (x < y and x < result and result <= y) or
    (y < x and y <= result and result < x)
  body:
    if x == y: return y
    if x != x or y != y: return x + y
    var ui = cast[uint32](x)
    if (ui and 0x7FFF_FFFF'u32) == 0:
      ui = if y < 0.0'f32: 0x8000_0001'u32 else: 0x0000_0001'u32
      return cast[float32](ui)
    let signBit = ui shr 31
    let towardZero = if signBit == 0: (y < x) else: (y > x)
    if towardZero: ui -= 1'u32 else: ui += 1'u32
    return cast[float32](ui)

func nextUp*(x: float64): float64 {.inline.} = nextafterF64(x, Inf)
func nextDown*(x: float64): float64 {.inline.} = nextafterF64(x, -Inf)
func nextUp*(x: float32): float32 {.inline.} = nextafterF32(x, float32(Inf))
func nextDown*(x: float32): float32 {.inline.} = nextafterF32(x, float32(-Inf))

# ------------------------------------------------------------------------------
# Constructors
# ------------------------------------------------------------------------------

func initInterval*[T](lower, upper: T): Interval[T] {.contractual.} =
  ensure:
    result.lower == lower and result.upper == upper
  body:
    result.lower = lower
    result.upper = upper

func initInterval*[T](val: T): Interval[T] {.contractual.} =
  ## Degenerate interval `[val, val]`.
  ensure:
    result.lower == val and result.upper == val
  body:
    result.lower = val
    result.upper = val

func isUncertain*(i: Interval[float64]): bool {.inline.} =
  ## True if the interval contains zero (sign uncertainty).
  i.lower <= 0.0 and i.upper >= 0.0

func isUncertain*(i: Interval[float32]): bool {.inline.} =
  i.lower <= 0.0f and i.upper >= 0.0f

func certaintySign*(i: Interval[float64]): int {.inline.} =
  ## Definitive sign (-1 or 1), or 0 if uncertain.
  if i.upper < 0.0: return -1
  if i.lower > 0.0: return 1
  return 0

# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------

func isValid*[T](i: Interval[T]): bool {.contractual, inline.} =
  ## `lower <= upper` (false if either bound is NaN).
  ensure:
    result == (i.lower <= i.upper)
  body:
    i.lower <= i.upper

func width*[T](i: Interval[T]): T {.inline.} =
  i.upper - i.lower

func midpoint*[T: float32 | float64](i: Interval[T]): T {.inline.} =
  i.lower + (i.upper - i.lower) / T(2)

func contains*[T](i: Interval[T], x: T): bool {.contractual, inline.} =
  ## `x in [lower, upper]` (closed bounds).
  ensure:
    result == (x >= i.lower and x <= i.upper)
  body:
    x >= i.lower and x <= i.upper

func contains*[T](outer, inner: Interval[T]): bool {.contractual, inline.} =
  ## `inner ⊆ outer`.
  ensure:
    result == (inner.lower >= outer.lower and inner.upper <= outer.upper)
  body:
    inner.lower >= outer.lower and inner.upper <= outer.upper

func overlaps*[T](a, b: Interval[T]): bool {.contractual, inline.} =
  ## `a ∩ b ≠ ∅`.
  ensure:
    result == (a.lower <= b.upper and b.lower <= a.upper)
  body:
    a.lower <= b.upper and b.lower <= a.upper

func hull*[T](a, b: Interval[T]): Interval[T] {.contractual, inline.} =
  ## Smallest interval containing both `a` and `b`.
  ensure:
    result.lower == min(a.lower, b.lower)
    result.upper == max(a.upper, b.upper)
  body:
    result.lower = min(a.lower, b.lower)
    result.upper = max(a.upper, b.upper)

func intersect*[T](a, b: Interval[T]): Interval[T] {.contractual.} =
  ## Intersection. Valid (`lower <= upper`) iff `overlaps(a, b)`; the caller
  ## guards that — otherwise the result is invalid (lower > upper).
  ensure:
    result.lower == max(a.lower, b.lower)
    result.upper == min(a.upper, b.upper)
  body:
    result.lower = max(a.lower, b.lower)
    result.upper = min(a.upper, b.upper)
