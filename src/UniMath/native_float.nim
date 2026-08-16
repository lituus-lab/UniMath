# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Native mathematics routed through Nim's host-math module.
##
## These functions provide one stable UniMath dependency surface for Uni*
## consumers. They preserve libm's IEEE-754 semantics; they do not promise
## bit-identical results across different libm implementations.
import std/math except gcd, lcm, splitDecimal
export math except gcd, lcm, splitDecimal

func cLog1p(x: float64): float64 {.
    importc: "log1p", header: "<math.h>", noSideEffect.}
func cExpm1(x: float64): float64 {.
    importc: "expm1", header: "<math.h>", noSideEffect.}

template log1p*(x: float64): float64 = cLog1p(x)

template expm1*(x: float64): float64 = cExpm1(x)

template sinCos*(x: float64): tuple[sin, cos: float64] =
  block:
    let value = x
    (math.sin(value), math.cos(value))

func splitDecimal*[T: float32 | float64](x: T):
    tuple[intpart, floatpart: T] =
  ## Split while preserving both signed-zero results, unlike std/math 2.2.
  if x == T(0) and math.signbit(x):
    let negativeZero = math.copySign(T(0), x)
    (negativeZero, negativeZero)
  else:
    math.splitDecimal(x)
