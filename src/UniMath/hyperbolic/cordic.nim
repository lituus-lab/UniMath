# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## CORDIC hyperbolic mode for fixed-point `sinh`/`cosh`/`tanh`/`exp`. Like
## circular CORDIC but the rotation tangent is `atanh(2^-i)` (a shift, no
## multiply). A quirk of hyperbolic CORDIC: it does not converge if iterations
## run 1,2,3,...; iterations at `i = 4, 13, 40, 121, ...` (`k = 3k+1`) MUST be
## repeated.
##
## Convergence domain: hyperbolic functions are not periodic and `exp` grows
## without bound, so there is no finite range reduction. The rotation can drive
## `z -> 0` only when `|z|` does not exceed the total rotation budget
## `sum atanh(2^-i) ~ 1.1182` (the repeat schedule is the standard convergence
## guarantee, not extra budget). Beyond it the residual `z` never reaches 0 and
## the result silently saturates to a wrong value, so the core raises
## `ValueError` (a body `raise`, survives `-d:release`) when `|angle|` exceeds
## the budget computed from the actual iteration count. Callers wanting larger
## `|z|` use the BigFloat `exp`/`sinh`/`cosh` (scaling-and-squaring); fixed-point
## CORDIC is the pedagogical/MCU path with a bounded domain.
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

    # Convergence guard: sum the actual `atanh(2^-i)` steps (a repeat step at
    # i in {4,13,40,121} <= iterations) to get the precise consumable `|z|`,
    # then raise if the input exceeds it. Compare `z` against `+/-budget`
    # directly — do NOT negate `z` to form `|z|`: the most-negative angle has
    # `.data = low(int64)`, and `-low(int64)` wraps negative under `-d:danger`,
    # so an `absZ > budget` guard would silently fail. `budget` is a sum of
    # positive steps bounded by `~1.1182 * 2^FracBits` (< 2^63), so `-budget`
    # does not overflow.
    var budget = zero
    var bi = 1
    while bi <= iterations:
      let step = getCordicHyperbolicAngle[T, FracBits](bi)
      budget += step
      if isHyperbolicRepeat(bi):
        budget += step
      bi += 1
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
  ## `e^x = cosh(x) + sinh(x)` — projection over `sinhCoshCordic`.
  body:
    let (s, c) = sinhCoshCordic(angle)
    return c + s
