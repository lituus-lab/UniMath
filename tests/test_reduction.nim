# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## BigFloat range-reduction infrastructure: power-of-two scaling, the cached
## `pi`, `floor`/`round` over `BigFloat`, and `reduceModTwoPi` (trig stage-1
## reduction into `[-pi, pi]`). The transcendentals that consume these (and the
## MPFR precision oracle) land with `float_math`; here we exercise the
## primitives directly. Integer-valued results are exact (the BigFloat integer
## round-trips through float64), so they use `==`; `reduceModTwoPi` carries
## float64 input rounding, so it uses a tolerance.
import std/[unittest, math]
import UniMath

suite "Reduction — power-of-two scaling":
  test "scaleByPow2 adjusts the exponent only":
    check toFloat64(scaleByPow2(initBigFloat(1.0), 2)) == 4.0
    check toFloat64(scaleByPow2(initBigFloat(4.0), -2)) == 1.0
    check toFloat64(scaleByPow2(initBigFloat(3.0), 0)) == 3.0

suite "Reduction — cached pi":
  test "piConst is the float64 pi":
    check toFloat64(piConst()) == PI

suite "Reduction — floor/round over BigFloat":
  test "floor":
    check toFloat64(floorBigFloat(initBigFloat(2.7))) == 2.0
    check toFloat64(floorBigFloat(initBigFloat(-2.7))) == -3.0
    check toFloat64(floorBigFloat(initBigFloat(3.0))) == 3.0
    check toFloat64(floorBigFloat(initBigFloat(0.0))) == 0.0
  test "round (half up)":
    check toFloat64(roundBigFloat(initBigFloat(2.4))) == 2.0
    check toFloat64(roundBigFloat(initBigFloat(2.6))) == 3.0
    check toFloat64(roundBigFloat(initBigFloat(2.5))) == 3.0
    check toFloat64(roundBigFloat(initBigFloat(-2.5))) == -2.0

suite "Reduction — reduceModTwoPi":
  test "2pi + 0.5 reduces to 0.5":
    let r = reduceModTwoPi(initBigFloat(2.0 * PI + 0.5))
    check abs(toFloat64(r) - 0.5) < 1e-12
  test "small argument is unchanged (n = 0)":
    let r = reduceModTwoPi(initBigFloat(0.5))
    check abs(toFloat64(r) - 0.5) < 1e-12
  test "pi + 0.1 reduces into [-pi, pi]":
    let r = reduceModTwoPi(initBigFloat(PI + 0.1))
    check abs(toFloat64(r) - (-PI + 0.1)) < 1e-12
