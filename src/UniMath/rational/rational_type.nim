# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Generic exact rational `Rational[T] = object` (num, den) over any integer-like
## `T` (built-in integers and `BigInt`). Invariants, enforced by `initRational`
## via `simplify`: `den > 0` (sign in `num`), `gcd(|num|, den) == 1`, and zero is
## the canonical `0/1`. Bodies only where an `ensure:` would recurse into `T`'s
## contracted `cmp` (recursion doctrine); the invariants are exercised by the
## rational tests.
import ../arithmetic
import ./gcd
import contracts

type
  Rational*[T] = object
    ## Exact fraction. `den` is always positive and the fraction irreducible.
    num*: T
    den*: T

func simplify*[T](a: var Rational[T]) {.contractual.} =
  ## Reduces `a` to lowest terms and moves the sign into `num`. Assumes
  ## `a.den != 0` (caller validates). The `den > 0` invariant is enforced
  ## structurally here, not restated as an `ensure:` (recursion doctrine).
  require:
    a.den != default(T)
  body:
    let zero = default(T)
    if a.num == zero:
      a.den = a.den div a.den # 0/x -> 0/1
      return
    if a.den < zero:
      # Negating `MinInt` would silently wrap in release; force the check so it
      # raises `OverflowDefect` (no-op for `BigInt`; unsigned `T` never here).
      {.push overflowChecks: on.}
      a.num = -a.num
      a.den = -a.den
      {.pop.}
    let g = gcd(a.num, a.den)
    a.num = a.num div g
    a.den = a.den div g

func toFloat64*[T](a: Rational[T]): float64 {.contractual.} =
  ## Approximate `float64` of `a` (rounded division). No `ensure:` — the result
  ## is an approximation (approximated-algo doctrine).
  body:
    mixin toFloat64
    return toFloat64(a.num) / toFloat64(a.den)

func initRational*[T](num, den: T): Rational[T] {.contractual.} =
  ## Safe constructor: validates `den != 0` (body `raise DivByZeroDefect`,
  ## survives release) then simplifies. The `den > 0` invariant is enforced by
  ## `simplify`, not restated as an `ensure:` (recursion doctrine).
  body:
    if den == default(T):
      raise newException(DivByZeroDefect,
        "initRational: denominator cannot be zero")
    result.num = num
    result.den = den
    result.simplify()

func initRationalUnchecked*[T](num, den: T): Rational[T] {.contractual.} =
  ## Escape hatch: stores `num`/`den` verbatim with no validation or
  ## normalization. The `den > 0` invariant does NOT hold here; the caller owns
  ## it. No `require:`/`ensure:` (recursion doctrine).
  body:
    result.num = num
    result.den = den

func toRational*[T](num: T): Rational[T] {.contractual.} =
  ## `num / 1` via the uniform `fromInt(T, 1)` concept construction. No inline
  ## `ensure:` (recursion doctrine — delegates to `initRational`/`simplify`).
  body:
    result = initRational(num, fromInt(T, 1))

# Concept construction: `fromInt(Rational[T], v)` = v/1, so generic series can
# build coefficients without an injected constructor. No `fromFloat` overload:
# an exact float->Rational is an approximation (the opt-in converters below).
func fromInt*[T](TT: typedesc[Rational[T]], v: int): Rational[T] {.inline.} =
  initRational(fromInt(T, v), fromInt(T, 1))

func isZero*[T](a: Rational[T]): bool {.inline.} =
  a.num == default(T)

func isOne*[T](a: Rational[T]): bool {.inline.} =
  a.num == a.den

# Opt-in narrowing converters (`Rational[int64](2)`, `Rational[int64](2.0)`).
# Implicit conversions across packages collide, so they are gated by
# `-d:umConverters`. Out-of-range input raises `OverflowDefect` in debug and
# clamps in release/danger — never a silent wrap.
when defined(umConverters):
  func intToRational[Tgt: SomeSignedInt](val: SomeSignedInt): Rational[
      Tgt] {.inline.} =
    if val < low(Tgt) or val > high(Tgt):
      when defined(release) or defined(danger):
        initRational(if val < low(Tgt): low(Tgt) else: high(Tgt), Tgt(1))
      else:
        raise newException(OverflowDefect,
          "int-to-Rational overflow: value out of target range")
    else:
      initRational(Tgt(val), Tgt(1))

  func intToRational[Tgt: SomeSignedInt](val: SomeUnsignedInt): Rational[
      Tgt] {.inline.} =
    if uint64(val) > uint64(high(Tgt)):
      when defined(release) or defined(danger):
        initRational(high(Tgt), Tgt(1))
      else:
        raise newException(OverflowDefect,
          "int-to-Rational overflow: unsigned value exceeds target range")
    else:
      initRational(Tgt(val), Tgt(1))

  converter toRational64FromInt*(val: SomeInteger): Rational[int64] {.inline.} =
    intToRational[int64](val)

  converter toRational32FromInt*(val: SomeInteger): Rational[int32] {.inline.} =
    intToRational[int32](val)

  converter toRational64FromFloat*(val: SomeFloat): Rational[int64] {.inline.} =
    ## Approximate float->Rational with a denominator of 1000000. NaN is rejected
    ## (ValueError; no rational approximation exists). The scaled numerator is
    ## rounded to the nearest integer (error <= 0.5/maxDen); a value out of
    ## int64 range raises (debug) or clamps (release).
    const maxDen = int64(1000000)
    let f = float64(val)
    if f != f:
      raise newException(ValueError,
        "float-to-Rational[int64]: NaN has no rational approximation")
    let scaled = f * float64(maxDen)
    if scaled >= float64(high(int64)) or scaled < float64(low(int64)):
      when defined(release) or defined(danger):
        let clamped = if scaled >= float64(high(int64)): high(int64) else: low(int64)
        initRational(clamped, maxDen)
      else:
        raise newException(OverflowDefect,
          "float-to-Rational[int64] overflow: value out of int64 range")
    else:
      let rounded = if scaled >= 0.0: int64(scaled + 0.5) else: int64(scaled - 0.5)
      initRational(rounded, maxDen)

  converter toRational32FromFloat*(val: SomeFloat): Rational[int32] {.inline.} =
    ## Approximate float->Rational with a denominator of 10000. NaN is rejected
    ## (ValueError; no rational approximation exists). The scaled numerator is
    ## rounded to the nearest integer (error <= 0.5/maxDen); a value out of
    ## int32 range raises (debug) or clamps (release).
    const maxDen = int32(10000)
    let f = float64(val)
    if f != f:
      raise newException(ValueError,
        "float-to-Rational[int32]: NaN has no rational approximation")
    let scaled = f * float64(maxDen)
    if scaled >= float64(high(int32)) or scaled < float64(low(int32)):
      when defined(release) or defined(danger):
        let clamped = if scaled >= float64(high(int32)): high(int32) else: low(int32)
        initRational(clamped, maxDen)
      else:
        raise newException(OverflowDefect,
          "float-to-Rational[int32] overflow: value out of int32 range")
    else:
      let rounded = if scaled >= 0.0: int32(scaled + 0.5) else: int32(scaled - 0.5)
      initRational(rounded, maxDen)
