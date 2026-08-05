# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-point utilities: rounding, clamp, lerp, floor-mod, abs, sign. Rounding
## is cheap on Q-format numbers — floor discards fractional bits, ceil is floor
## plus one when a fractional part is non-zero, round adds the half-unit first.
import ./fixed_point
import ./arithmetic
import contracts

func floor*[T; FracBits: static[int]](a: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual, inline.} =
  ## Largest integer `<= a`. No inline `ensure:` (recursion doctrine).
  body:
    initFixed[T, FracBits](a.data and not ((T(1) shl FracBits) - T(1)))

func ceil*[T; FracBits: static[int]](a: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual.} =
  ## Smallest integer `>= a`. No inline `ensure:` (recursion doctrine).
  body:
    let oneF = T(1) shl FracBits
    let mask = oneF - T(1)
    if (a.data and mask) == T(0):
      return a
    # Floor then +1 via the overflow-checked Fixed `+` (raises on overflow
    # instead of silently wrapping the raw integer add).
    result = initFixed[T, FracBits](a.data and not mask) +
      initFixed[T, FracBits](oneF)

func round*[T; FracBits: static[int]](a: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual.} =
  ## Nearest integer (round half up). No inline `ensure:` (recursion doctrine).
  body:
    when FracBits == 0:
      return a
    let half = T(1) shl (FracBits - 1)
    let mask = (T(1) shl FracBits) - T(1)
    # Add the half-unit via the overflow-checked Fixed `+` (raises on overflow
    # instead of silently wrapping), then clear the fractional bits.
    result = initFixed[T, FracBits](a.data) + initFixed[T, FracBits](half)
    result.data = result.data and not mask

func clamp*[T; FracBits: static[int]](val, minVal, maxVal: Fixed[T,
    FracBits]): Fixed[T, FracBits] {.contractual, inline.} =
  ## Clamp `val` to `[minVal, maxVal]`. No inline `ensure:` (`minVal <= result
  ## <= maxVal` would use a Fixed comparison that delegates to the contracted
  ## `cmp` for `BigInt` storage — recursion doctrine).
  body:
    if val < minVal: return minVal
    if val > maxVal: return maxVal
    return val

func lerp*[T; FracBits: static[int]](a, b, t: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual, inline.} =
  ## Linear interpolation `a + (b - a) * t`. No inline `ensure:`: the body calls
  ## the contracted Fixed `*`/`+`/`-`, so a restating ensure would recurse.
  ## `b - a` must be representable: interpolating between the extreme storage
  ## bounds (`low(T)` to `high(T)`) raises `OverflowDefect` from the subtraction
  ## even though the result would be in range. Rewriting as `a*(1-t) + b*t`
  ## would avoid it but needs `toFixed(1)`, which is itself unrepresentable for
  ## near-full-width formats such as `Fixed[int32, 31]`.
  body:
    a + (b - a) * t

func floorMod*[T; FracBits: static[int]](a, b: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual, inline.} =
  ## Floored modulo. Division by zero raises `DivByZeroDefect` (body raise,
  ## survives release/danger). No inline `ensure:` (recursion doctrine).
  body:
    if b.data == T(0):
      raise newException(DivByZeroDefect, "floorMod: division by zero")
    let r = a.data mod b.data
    if (r > T(0) and b.data < T(0)) or (r < T(0) and b.data > T(0)):
      return initFixed[T, FracBits](r + b.data)
    return initFixed[T, FracBits](r)

func abs*[T; FracBits: static[int]](a: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual, inline.} =
  ## Absolute value. No inline `ensure:` (recursion doctrine).
  body:
    if a.data < T(0): -a else: a

func sign*[T; FracBits: static[int]](a: Fixed[T, FracBits]): int {.contractual, inline.} =
  ## Sign: `-1`, `0`, or `1`. Asserted over the integer result only — no Fixed
  ## comparison, no contracted call (recursion doctrine).
  ensure:
    result >= -1 and result <= 1
  body:
    if a.data > T(0): 1
    elif a.data < T(0): -1
    else: 0
