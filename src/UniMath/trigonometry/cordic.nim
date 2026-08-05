# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## CORDIC trigonometry for fixed-point. Rotates a vector by successively
## smaller angles `atan(2^-i)`; because the rotation tangent is a power of 2,
## the multiply is a shift, so CORDIC uses only add/sub/shift — no multiply.
## Converges for angles in `[-pi/2, pi/2]`; `reduceAngle` folds any input into
## that range with quadrant sign adjustments. With `FracBits` iterations the
## result carries roughly `FracBits` bits; the gain compensation is itself
## rounded, so the core procs are `{.contractual.}` with `body:` and no
## `ensure:` — the precision envelope is verified externally against a
## reference.
import std/math
import contracts
import ../fixed
import ../arithmetic

func getCordicAngle[T; FracBits: static[int]](i: int): T =
  ## Fixed-point `atan(2^-i)`.
  mixin fromFloat
  let angle = arctan(pow(2.0, -float(i)))
  let scale = float(pow2f64(FracBits))
  fromFloat(T, angle * scale)

func getCordicGain[T; FracBits: static[int]](): T =
  ## CORDIC gain `K ~ 0.607252935` (pre-multiply by `1/1.647`).
  mixin fromFloat
  const gain = 0.6072529350088812561694
  let scale = float(pow2f64(FracBits))
  fromFloat(T, gain * scale)

func getPiFixed[T; FracBits: static[int]](): Fixed[T, FracBits] =
  ## `pi` in fixed-point.
  mixin fromFloat
  let scale = float(pow2f64(FracBits))
  initFixed[T, FracBits](fromFloat(T, 3.14159265358979323846 * scale))

func reduceAngle[T; FracBits: static[int]](
    angle: Fixed[T, FracBits]): tuple[reduced: Fixed[T, FracBits]; signSin,
    signCos: int] =
  ## Fold `angle` into `[-pi/2, pi/2]` and return the sin/cos sign multipliers.
  let pi = getPiFixed[T, FracBits]()
  let halfPi = initFixed[T, FracBits](pi.data shr 1)
  let twoPi = initFixed[T, FracBits](pi.data shl 1)
  let zero = initFixed[T, FracBits](default(T))

  var resultAngle = angle
  var signSin = 1
  var signCos = 1

  # One `mod` plus a negative-remainder correction. Stepping by whole periods
  # was linear in |angle|: a Fixed[int64, 32] angle near high(int32) radians
  # spent ~10^8 iterations here before crossing twoPi.
  if resultAngle < zero or resultAngle >= twoPi:
    var d = resultAngle.data mod twoPi.data
    if d < default(T): d = d + twoPi.data
    resultAngle = initFixed[T, FracBits](d)

  if resultAngle > halfPi and resultAngle <= pi:
    resultAngle = pi - resultAngle
    signCos = -1
  elif resultAngle > pi and resultAngle <= pi + halfPi:
    resultAngle = resultAngle - pi
    signSin = -1
    signCos = -1
  elif resultAngle > pi + halfPi:
    resultAngle = twoPi - resultAngle
    signSin = -1

  result.reduced = resultAngle
  result.signSin = signSin
  result.signCos = signCos

func sinCosCordic*[T; FracBits: static[int]](
    targetAngle: Fixed[T, FracBits]): tuple[sin, cos: Fixed[T,
        FracBits]] {.contractual.} =
  ## `sin` and `cos` together via CORDIC, with automatic range reduction.
  body:
    let (reducedAngle, signSin, signCos) = reduceAngle(targetAngle)

    var x = getCordicGain[T, FracBits]()
    var y = default(T)
    var z = reducedAngle.data
    let zero = default(T)
    let iterations = FracBits

    for i in 0 ..< iterations:
      let angleStep = getCordicAngle[T, FracBits](i)
      let xShifted = x shr i
      let yShifted = y shr i
      if z >= zero:
        x = x - yShifted
        y = y + xShifted
        z = z - angleStep
      else:
        x = x + yShifted
        y = y - xShifted
        z = z + angleStep

    let rawCos = initFixed[T, FracBits](x)
    let rawSin = initFixed[T, FracBits](y)
    result.cos = if signCos == -1: -rawCos else: rawCos
    result.sin = if signSin == -1: -rawSin else: rawSin

func sinCordic*[T; FracBits: static[int]](
    angle: Fixed[T, FracBits]): Fixed[T, FracBits] {.contractual, inline.} =
  ## `sin(angle)` — projection of `sinCosCordic`.
  body:
    let (s, _) = sinCosCordic(angle)
    return s

func cosCordic*[T; FracBits: static[int]](
    angle: Fixed[T, FracBits]): Fixed[T, FracBits] {.contractual, inline.} =
  ## `cos(angle)` — projection of `sinCosCordic`.
  body:
    let (_, c) = sinCosCordic(angle)
    return c

func cordicVectoring*[T; FracBits: static[int]](x0, y0: Fixed[T,
    FracBits]): tuple[angle, magnitude: Fixed[T, FracBits]] {.contractual.} =
  ## CORDIC vectoring mode: rotate `(x0, y0)` onto the X-axis. The accumulated
  ## angle is `atan2(y0, x0)`; the final X is `sqrt(x0^2+y0^2)` times the
  ## CORDIC gain.
  body:
    var x = x0.data
    var y = y0.data
    var z = default(T)
    let zero = default(T)
    let iterations = FracBits

    for i in 0 ..< iterations:
      let angleStep = getCordicAngle[T, FracBits](i)
      let xShifted = x shr i
      let yShifted = y shr i
      if y >= zero:
        x = x + yShifted
        y = y - xShifted
        z = z + angleStep
      else:
        x = x - yShifted
        y = y + xShifted
        z = z - angleStep

    result.angle = initFixed[T, FracBits](z)
    let gain = getCordicGain[T, FracBits]()
    result.magnitude = initFixed[T, FracBits](x) * initFixed[T, FracBits](gain)

func atan2Cordic*[T; FracBits: static[int]](y, x: Fixed[T,
    FracBits]): Fixed[T, FracBits] {.contractual.} =
  ## `atan2(y, x)` via CORDIC vectoring. Vectoring converges only for `x > 0`;
  ## the left half-plane and the axes use quadrant adjustments. The undefined
  ## origin returns 0 by convention (documented), not a raise.
  body:
    let zero = default(T)
    let pi = getPiFixed[T, FracBits]()
    let halfPi = initFixed[T, FracBits](pi.data shr 1)

    if x.data == zero:
      if y.data > zero: return halfPi
      if y.data < zero: return -halfPi
      return initFixed[T, FracBits](zero)
    elif x.data > zero:
      let (angle, _) = cordicVectoring(x, y)
      return angle
    else:
      if y.data >= zero:
        let (angle, _) = cordicVectoring(-x, y)
        return pi - angle
      else:
        let (angle, _) = cordicVectoring(-x, -y)
        return angle - pi
