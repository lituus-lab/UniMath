# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Trigonometry tests: generic Taylor sin/cos/atan, fixed-point CORDIC,
## compile-time LUT, and the Chebyshev minimax tan. The fixed-point cores
## (CORDIC/LUT/Chebyshev) run on `Fixed[int64, 32]`; tolerances reflect each
## algorithm's design precision.
import std/[unittest, math]
import UniMath

suite "Taylor — generic sin/cos/atan":
  test "float64 near 0":
    check abs(sinTaylor(0.0) - 0.0) < 1e-12
    check abs(cosTaylor(0.0) - 1.0) < 1e-12
    check abs(atanTaylor(0.0) - 0.0) < 1e-12
  test "float64 small angles":
    check abs(sinTaylor(0.5) - sin(0.5)) < 1e-6
    check abs(cosTaylor(0.5) - cos(0.5)) < 1e-6
    check abs(atanTaylor(0.5) - arctan(0.5)) < 1e-6
  test "BigFloat":
    let p = 128
    check abs(toFloat64(sinTaylor(initBigFloat(0.5, p))) - sin(0.5)) < 1e-9
    check abs(toFloat64(cosTaylor(initBigFloat(0.5, p))) - cos(0.5)) < 1e-9

suite "CORDIC — fixed-point sin/cos/atan2":
  test "sin/cos at 0 and pi/2":
    let f0 = toFixed[int64, 32](0.0)
    check abs(toFloat64(sinCordic(f0)) - 0.0) < 1e-3
    check abs(toFloat64(cosCordic(f0)) - 1.0) < 1e-3
    let fHalf = toFixed[int64, 32](PI / 2)
    check abs(toFloat64(sinCordic(fHalf)) - 1.0) < 1e-3
    check abs(toFloat64(cosCordic(fHalf)) - 0.0) < 1e-3
  test "sin/cos at pi/4":
    let f = toFixed[int64, 32](PI / 4)
    check abs(toFloat64(sinCordic(f)) - sin(PI / 4)) < 1e-3
    check abs(toFloat64(cosCordic(f)) - cos(PI / 4)) < 1e-3
  test "atan2 quadrants":
    let one = toFixed[int64, 32](1.0)
    check abs(toFloat64(atan2Cordic(one, one)) - PI / 4) < 1e-3
    let mone = toFixed[int64, 32](-1.0)
    check abs(toFloat64(atan2Cordic(one, mone)) - 3 * PI / 4) < 1e-3

suite "LUT — compile-time sin/cos":
  test "nearest-neighbour":
    let f0 = toFixed[int64, 32](0.0)
    check abs(toFloat64(sin_lut(f0)) - 0.0) < 0.02
    check abs(toFloat64(cos_lut(f0)) - 1.0) < 0.02
    let fHalf = toFixed[int64, 32](PI / 2)
    check abs(toFloat64(sin_lut(fHalf)) - 1.0) < 0.02
  test "linear interpolation":
    let f = toFixed[int64, 32](0.5)
    check abs(toFloat64(sin_lut(f, itLinear)) - sin(0.5)) < 1e-3
    check abs(toFloat64(cos_lut(f, itLinear)) - cos(0.5)) < 1e-3
  test "overflow guard raises":
    expect OverflowDefect:
      discard getPiFixedLut[int16, 20]()

suite "Chebyshev — minimax tan":
  test "tan at 0":
    let f0 = toFixed[int64, 32](0.0)
    check abs(toFloat64(tanChebyshev(f0)) - 0.0) < 1e-3
  test "tan at 0.5 (inside [-pi/4, pi/4])":
    let f = toFixed[int64, 32](0.5)
    check abs(toFloat64(tanChebyshev(f)) - tan(0.5)) < 1e-3
