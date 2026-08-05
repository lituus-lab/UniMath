# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## CORDIC hyperbolic mode for fixed-point `sinh`/`cosh`/`tanh`/`exp`. Like
## circular CORDIC but the rotation tangent is `atanh(2^-i)` (a shift, no
## multiply). A quirk of hyperbolic CORDIC: it does not converge if iterations
## run 1,2,3,...; iterations at `i = 4, 13, 40, 121, ...` (`k = 3k+1`) MUST be
## repeated.
##
## Convergence domain: hyperbolic functions are not periodic and `exp` grows
## without bound, so there is no finite range reduction for a single rotation.
## The rotation can drive `z -> 0` only when `|z|` does not exceed the total
## rotation budget `sum atanh(2^-i) ~ 1.1182` (the repeat schedule is the
## standard convergence guarantee, not extra budget). Beyond it the residual
## `z` never reaches 0 and the result silently saturates to a wrong value, so
## `sinhCoshCordic`/`sinhCordic`/`coshCordic`/`tanhCordic` raise `ValueError`
## (a body `raise`, survives `-d:release`) when `|angle|` exceeds the budget.
## `expCordicScaled` lifts this for `exp` alone via scaling-and-squaring
## (`exp(x) = exp(x/2^k)^(2^k)`, mirroring `BigFloat.exp`), extending the
## domain to `T`'s own representable ceiling (`~2^31` for Q32.32, i.e. `x` up
## to `~21.5`) instead of `~1.1182`; `sinh`/`cosh`/`tanh` stay bounded.
##
## Approximate algorithm: `{.contractual.}` with `body:` and no `ensure:` — the
## precision envelope is verified externally against a reference.
import std/math
import contracts
import ../fixed
import ../arithmetic

func isHyperbolicRepeat(i: int): bool {.inline.} =
  ## Hyperbolic CORDIC must repeat iterations at `i = 4, 13, 40, 121, 364,
  ## ...` (each term is `3*prev + 1`) for convergence. Generated from the
  ## recurrence instead of a fixed list so wider `FracBits` repeat at 40,
  ## 121, 364, ...; Q32.32 only reaches i = 4, 13.
  if i < 4: return false
  var k = 4
  while k < i:
    k = 3 * k + 1
  k == i

func getCordicHyperbolicAngle[T; FracBits: static[int]](i: int): T =
  ## Fixed-point `atanh(2^-i)`.
  mixin fromFloat
  let angle = arctanh(pow(2.0, -float(i)))
  let scale = float(pow2f64(FracBits))
  fromFloat(T, angle * scale)

func getCordicHyperbolicGain[T; FracBits: static[int]](): T =
  ## Hyperbolic CORDIC gain `1/K ~ 1.207497` (the vector shrinks, so start
  ## larger to end at a unit vector).
  mixin fromFloat
  const gainCompensation = 1.2074970677630952
  let scale = float(pow2f64(FracBits))
  fromFloat(T, gainCompensation * scale)

func hyperbolicConvergenceBudget[T; FracBits: static[int]](): T =
  ## Sum of the actual `atanh(2^-i)` CORDIC steps (a repeat step at
  ## `i in {4,13,40,121} <= FracBits` counted twice) -- the largest `|angle|`
  ## `sinhCoshCordic` consumes without scaling. A sum of positive steps
  ## bounded by `~1.1182 * 2^FracBits` (< 2^63 for Q32.32), so negating it
  ## (see callers) never overflows. Not cheap (~32 `arctanh`/`pow` calls) --
  ## `expCordicScaled` only pays for it on the out-of-budget path, never on
  ## every call (see its own doc comment).
  let zero = default(T)
  result = zero
  var bi = 1
  while bi <= FracBits:
    let step = getCordicHyperbolicAngle[T, FracBits](bi)
    result += step
    if isHyperbolicRepeat(bi):
      result += step
    bi += 1

func sinhCoshCordic*[T; FracBits: static[int]](
    targetAngle: Fixed[T, FracBits]): tuple[sinh, cosh: Fixed[T,
        FracBits]] {.contractual.} =
  ## `sinh` and `cosh` together via hyperbolic CORDIC. Raises `ValueError` when
  ## `|angle|` exceeds the convergence budget (see module header).
  body:
    var x = getCordicHyperbolicGain[T, FracBits]()
    var y = default(T)
    var z = targetAngle.data

    let zero = default(T)
    let iterations = FracBits

    # Convergence guard: compare `z` against `+/-budget` directly — do NOT
    # negate `z` to form `|z|`: the most-negative angle has `.data =
    # low(int64)`, and `-low(int64)` wraps negative under `-d:danger`, so an
    # `absZ > budget` guard would silently fail.
    let budget = hyperbolicConvergenceBudget[T, FracBits]()
    let negBudget = -budget
    if z < negBudget or z > budget:
      let zMag = abs(float(z)) / float(pow2f64(FracBits))
      let bFloat = float(budget) / float(pow2f64(FracBits))
      raise newException(ValueError,
        "sinhCoshCordic: |angle| " & $zMag & " exceeds the CORDIC hyperbolic " &
        "convergence budget " & $bFloat &
        " (<= sum atanh(2^-i) ~ 1.1182); use " &
        "the BigFloat exp/sinh/cosh (scaling-and-squaring) for larger arguments")

    var i = 1 # Hyperbolic CORDIC starts at i=1.

    while i <= iterations:
      let angleStep = getCordicHyperbolicAngle[T, FracBits](i)

      let xShifted = x shr i
      let yShifted = y shr i

      if z >= zero:
        x = x + yShifted
        y = y + xShifted
        z = z - angleStep
      else:
        x = x - yShifted
        y = y - xShifted
        z = z + angleStep

      # Repeat iterations at i = 4, 13, 40, 121 (k = 3k+1) for convergence.
      if isHyperbolicRepeat(i):
        let xShifted2 = x shr i
        let yShifted2 = y shr i
        if z >= zero:
          x = x + yShifted2
          y = y + xShifted2
          z = z - angleStep
        else:
          x = x - yShifted2
          y = y - xShifted2
          z = z + angleStep

      i += 1

    result.cosh = initFixed[T, FracBits](x)
    result.sinh = initFixed[T, FracBits](y)

func sinhCordic*[T; FracBits: static[int]](
    angle: Fixed[T, FracBits]): Fixed[T, FracBits] {.contractual, inline.} =
  ## `sinh(angle)` — projection of `sinhCoshCordic`.
  body:
    let (s, _) = sinhCoshCordic(angle)
    return s

func coshCordic*[T; FracBits: static[int]](
    angle: Fixed[T, FracBits]): Fixed[T, FracBits] {.contractual, inline.} =
  ## `cosh(angle)` — projection of `sinhCoshCordic`.
  body:
    let (_, c) = sinhCoshCordic(angle)
    return c

func tanhCordic*[T; FracBits: static[int]](
    angle: Fixed[T, FracBits]): Fixed[T, FracBits] {.contractual, inline.} =
  ## `tanh(angle) = sinh/cosh` — projection over `sinhCoshCordic`.
  body:
    let (s, c) = sinhCoshCordic(angle)
    return s / c

func expCordic*[T; FracBits: static[int]](
    angle: Fixed[T, FracBits]): Fixed[T, FracBits] {.contractual, inline.} =
  ## `e^x = cosh(x) + sinh(x)` — projection over `sinhCoshCordic`. Raises
  ## `ValueError` when `|x|` exceeds the raw convergence budget (~1.1182);
  ## `expCordicScaled` lifts this via scaling-and-squaring.
  body:
    let (s, c) = sinhCoshCordic(angle)
    return c + s

func expCordicScaled*[T; FracBits: static[int]](
    x: Fixed[T, FracBits]): Fixed[T, FracBits] {.contractual.} =
  ## `exp(x)` via CORDIC scaling-and-squaring: `exp(x) = exp(x/2^k)^(2^k)`,
  ## `k` the smallest halving count bringing `|x|` inside
  ## `sinhCoshCordic`'s convergence budget (~1.1182). Mirrors `BigFloat.exp`'s
  ## scaling-and-squaring (`float_math.nim`); extends `Fixed`'s domain to
  ## `T`'s own representable ceiling (`~2^31` for Q32.32, i.e. `x` up to
  ## `~21.5`) instead of `expCordic`'s narrow `~1.1182` window. Tries the
  ## direct (unscaled) path first, which is both the common case and the only
  ## one needing `hyperbolicConvergenceBudget`'s ~32-term sum, so no in-budget
  ## call pays for it -- an earlier version computed the budget unconditionally
  ## and measured 464 -> 731 ns/op slower on `exp(1.0)` (well inside budget)
  ## for exactly that reason. Each squaring is a `Fixed` `*`, which raises
  ## `OverflowDefect` once the growing magnitude exceeds `T`'s range -- the
  ## type's own ceiling, not a separate guard here.
  ##
  ## The extended domain is symmetric in `x`, not in output precision: for
  ## very negative `x` approaching the ceiling, `exp(x)` itself approaches
  ## `T`'s smallest representable magnitude (`2^-FracBits`, `~2.3e-10` for
  ## Q32.32) and loses most of its significant digits to quantization --
  ## confirmed by real execution: `exp(-20.0)` has ~10% relative error
  ## (true `2.061e-9`, only ~9 ULPs above the Q32.32 floor) versus ~2e-8 for
  ## `exp(20.0)` at the same `|x|`. Inherent to any fixed-point
  ## representation of a value that close to zero, not an artifact of
  ## scaling-and-squaring itself.
  body:
    try:
      return expCordic(x)
    except ValueError:
      discard
    let budget = hyperbolicConvergenceBudget[T, FracBits]()
    let negBudget = -budget
    var k = 0
    while x.data shr k > budget or x.data shr k < negBudget:
      inc k
    result = expCordic(initFixed[T, FracBits](x.data shr k))
    for _ in 1 .. k:
      result = result * result
