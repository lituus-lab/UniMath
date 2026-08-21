# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Beta-family functions for finite float64 inputs.
import std/math except gcd, lcm
import contracts
import ../native_float

const
  BetaMaxIterations = 256
  BetaEpsilon = 3.0e-14
  BetaMinDenominator = 1.0e-300
  MaximumRegularizedBetaShapeSum* = 200_000.0

func validBetaParameters(a, b: float64): bool {.inline.} =
  classify(a) notin {fcNan, fcInf, fcNegInf} and
  classify(b) notin {fcNan, fcInf, fcNegInf} and a > 0.0 and b > 0.0 and
  classify(a + b) notin {fcNan, fcInf, fcNegInf}

func isFiniteValue(value: float64): bool {.inline.} =
  classify(value) notin {fcNan, fcInf, fcNegInf}

func validRegularizedBetaParameters(a, b: float64): bool {.inline.} =
  validBetaParameters(a, b) and classify(a) != fcSubnormal and
    classify(b) != fcSubnormal and
    (a == 1.0 or b == 1.0 or a + b <= MaximumRegularizedBetaShapeSum)

func stirlingCorrection(value: float64): float64 {.inline.} =
  let inverse = 1.0 / value
  let inverseSquared = inverse * inverse
  inverse * (1.0 / 12.0 + inverseSquared *
    (-1.0 / 360.0 + inverseSquared * (1.0 / 1260.0)))

func stableLogBeta(a, b: float64): float64 =
  if a == 1.0:
    return -ln(b)
  if b == 1.0:
    return -ln(a)

  let
    larger = max(a, b)
    smaller = min(a, b)
    sum = a + b
  if larger < 1.0e6:
    let direct = lgamma(a) + lgamma(b) - lgamma(sum)
    if isFiniteValue(direct):
      return direct

  if smaller < 8.0:
    let
      inverse = 1.0 / larger
      second = smaller * (smaller - 1.0) *
        (smaller - 0.5) / (6.0) * inverse * inverse
      third = -smaller * smaller * (smaller - 1.0) *
        (smaller - 1.0) / 12.0 * inverse * inverse * inverse
    return lgamma(smaller) - smaller * ln(larger) -
      smaller * (smaller - 1.0) * 0.5 * inverse + second + third

  let
    ratio = smaller / larger
    logScale = log1p(ratio)
    largeTerm = (larger - 0.5) * (-logScale)
    smallTerm = (smaller - 0.5) * (ln(ratio) - logScale)
    logSum = ln(larger) + logScale
  largeTerm + smallTerm - 0.5 * logSum + 0.5 * ln(2.0 * PI) +
    stirlingCorrection(larger) + stirlingCorrection(smaller) -
    stirlingCorrection(sum)

func logBeta*(a, b: float64): float64 {.contractual.} =
  ## Natural logarithm of `Beta(a, b)` for positive finite parameters.
  require:
    validBetaParameters(a, b)
  body:
    if not validBetaParameters(a, b):
      raise newException(ValueError,
        "logBeta requires positive finite parameters")
    stableLogBeta(a, b)

func beta*(a, b: float64): float64 {.contractual.} =
  ## `Beta(a, b)` evaluated through its logarithm.
  require:
    validBetaParameters(a, b)
  body:
    if not validBetaParameters(a, b):
      raise newException(ValueError,
        "beta requires positive finite parameters")
    if a == 1.0:
      return 1.0 / b
    if b == 1.0:
      return 1.0 / a
    exp(logBeta(a, b))

func betaContinuedFraction(a, b, x: float64): float64 =
  let qab = a + b
  let qap = a + 1.0
  let qam = a - 1.0
  var c = 1.0
  var d = 1.0 - qab * x / qap
  if abs(d) < BetaMinDenominator:
    d = BetaMinDenominator
  d = 1.0 / d
  var h = d

  for m in 1 .. BetaMaxIterations:
    let mFloat = float64(m)
    let m2 = 2.0 * mFloat
    var coefficient = mFloat * (b - mFloat) * x /
      ((qam + m2) * (a + m2))
    d = 1.0 + coefficient * d
    if abs(d) < BetaMinDenominator:
      d = BetaMinDenominator
    c = 1.0 + coefficient / c
    if abs(c) < BetaMinDenominator:
      c = BetaMinDenominator
    d = 1.0 / d
    h *= d * c

    coefficient = -(a + mFloat) * (qab + mFloat) * x /
      ((a + m2) * (qap + m2))
    d = 1.0 + coefficient * d
    if abs(d) < BetaMinDenominator:
      d = BetaMinDenominator
    c = 1.0 + coefficient / c
    if abs(c) < BetaMinDenominator:
      c = BetaMinDenominator
    d = 1.0 / d
    let delta = d * c
    h *= delta
    if abs(delta - 1.0) <= BetaEpsilon:
      return h

  raise newException(ValueError,
    "regularizedIncompleteBeta did not converge")

func regularizedIncompleteBeta*(x, a, b: float64): float64 {.contractual.} =
  ## Regularized incomplete beta `I_x(a, b)` for `0 <= x <= 1`.
  require:
    isFiniteValue(x) and x >= 0.0 and x <= 1.0
    validRegularizedBetaParameters(a, b)
  ensure:
    result >= 0.0 and result <= 1.0
  body:
    if not isFiniteValue(x) or x < 0.0 or x > 1.0 or
        not validRegularizedBetaParameters(a, b):
      raise newException(ValueError,
        "regularizedIncompleteBeta requires 0 <= x <= 1 and positive finite parameters within the supported shape sum")
    if x == 0.0:
      return 0.0
    if x == 1.0:
      return 1.0
    if b == 1.0:
      return exp(a * ln(x))
    if a == 1.0:
      return -expm1(b * log1p(-x))

    let logFront = -stableLogBeta(a, b) +
      a * ln(x) + b * log1p(-x)
    let front = exp(logFront)
    if x < (a + 1.0) / (a + b + 2.0):
      result = (front / a) * betaContinuedFraction(a, b, x)
    else:
      result = 1.0 - (front / b) *
        betaContinuedFraction(b, a, 1.0 - x)
    result = min(1.0, max(0.0, result))
